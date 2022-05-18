# LSP Server initialization

When launching the elixir_ls server using the scripts, the initialization steps are like:

1. Replace default IO with Json RPC notifications
2. Starts Mix
3. Starts the :language_server application
4. Overrides default Mix.Shell
5. Ensure the Hex version is accepted
6. Start receiving requests/responses
7. Gets the "initialize" request
8. Starts building/analyzing the project

## Replace default IO with Json RPC notifications

The Language Server protocol mandates that all communication between servers are made using UTF-16. BEAM is UTF-8 as default currently (was latin1 in the past which is a type of UTF-16). So, in order to have this kind of encoding/decoding out of the way, it first overrides two processes started by all BEAM instances: `:user` and `:stderr`.

The first process is the name for standard IO while the second is the the standard error. They are both IO servers, that means, `:gen_server` implementations that follows the [IO protocol](http://erlang.org/doc/apps/stdlib/io_protocol.html).

The servers delegate the callbacks to the module `ElixirLS.LanguageServer.JsonRpc`.

## Starts Mix

ElixirLS uses standard Mix tooling. It will need this to retrieve project configuration, dependencies and so on. It heavily uses private Mix APIs here to start and retrieve paths for dependencies, archives and so on.

## Starts the :language_server application

The main entry point for the language server is its application module `ElixirLS.LanguageServer`. It starts a supervisor with a few children.

The first one is the server itself `ElixirLS.LanguageServer.Server`. This is a named `GenServer` that holds the state for the project. That state has things like:

- the server current capabilities (will be negotiated with the client);
- project dir and root uri;
- settings;
- build and Dialyzer diagnostics;
- flags to know and control the build process;
- map of requests to match with responses;
- current open files in the client;

Upon start the server initializes its state with defaults (mostly empty values) and then waits for messages. It is important to know that up to now the server does not have a project directory set (nor its root uri).

After this `GenServer` is started, the next in line is the `ElixirLS.LanguageServer.JsonRpc` server. This is the one responsible for handling JSON RPC requests and responses. It is another `GenServer` that receives and sends packets through standard IO and standard error set on the first step of initialization.

## Overrides default Mix.Shell

Mix might have some "yes or no" questions that would not be possible to reply in the LSP paradigm. So, the server replaces the default `Mix.Shell` for providing the yes/no questions through LSP request/responses. This way the client can show them to the user through its interface and pass back the response to the server.

## Ensure the Hex version is accepted

Before building the project and start answering requests from the client, it must ensure that the Hex version is correct. If it is not, it might have trouble building things.

This is also a private Mix API.

## Start receiving request/responses

To start receiving packets, it uses `Stream.resource/3` reading with `IO.binread/2` until `:eof` is received. It is a very simple but functional implementation of a server that uses standard IO for communication.

Up until this point there is no compiling or analyzing running with the project context. It is the initialize request that properly starts the context for the project.

Starting the project using the shell scripts would reach up to this point without generating an `.elixir_ls` folder or downloading deps specifically for the language server.

Any requests coming from a LSP client will now follow this path:

- The `ElixirLS.Utils.PacketStream` will read input from standard IO in the already mentioned `Stream.resource/3` call;
- Each request has a header and a body. Both will be parsed to maps;
- The request will be handled by `ElixirLS.LanguageServer.JsonRpc.receive_packet/1`;
- A match is made with the request body content to check if its a:
  - [notification](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#notificationMessage)
  - [request](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#requestMessage)
  - [response with/without response_errors](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#responseMessage)

In case of notifications or requests, it delegates to the actual `ElixirLS.LanguageServer.Server`.

## Gets the "initialize" request

Upon receiving the [initialize request](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#initialize) the server:

- updates the state with the root path/uri of the project the client is handling;
- updates the state with the supported client capabilities;
- sends a delayed message for starting the build with the default config and the file watchers (if supported by the client)

The delayed message is important because some clients might send a message `workspace/didChangeConfiguration`. If that happens, it will start the build with a different configuration (for example, a different MIX_ENV).

If a notification `workspace/didChangeConfiguration` or the delayed message is handled, it updates the server settings and triggers builders/analyzers and so on.

## Starts building/analyzing the project

The trigger for the first build is handled on the function `set_settings/2` of the server. After some initialization of mixEnv and other settings, it calls `trigger_build/1`.

The build process itself is handled by `ElixirLS.LanguageServer.Build` module. It does that on a separate process and so the function only returns a reference.

This is where it will load the `mix.exs` project file, check if it needs to update/download dependencies and compiles plus analyzes the project.

Here we have the following steps:

- Loads cached deps from Mix. This is needed to compare if it needs to update/download things;
- After keeping a reference to old cached deps, it clears deps;
- Then reloads the project. A great many deal of things happen here as we will see in more detail later;
- With all configuration set, it fetches dependencies if needed;
- Compiles all sources and retrieve the diagnostics;
- Sends the result to the server process so that it can keep current result.

### Reloading the project

The core of the language server is having all the code in a project loaded on a running BEAM instance. Many of its functionality needs to call the `:code` APIs or other introspection modules. Many of its server capabilities use [Elixir Sense](https://github.com/elixir-lsp/elixir_sense) to reply back to the client. This library also needs modules to be loaded in a running BEAM instance so that it can call the same APIs.

Loaded modules are managed in the BEAM by the [code server](http://erlang.org/doc/man/code.html). It is this service that provides things like hot-code reloading. In the code server, every module might have two versions: current code and old code. When doing a hot-reload, for example, it loads the new code, tags the current as old code, purges the old old code and then sends a message to all running processes about the code change. Some important notes on hot-code loading can be read [here](https://learnyousomeerlang.com/designing-a-concurrent-application#hot-code-loving).

When the language server needs to "reload" the project it must first:

- purge/delete old code;
- compile only the project's `mix.exs` file. This is to ensure it is properly sourced and that it can use it for reading project metadata;
- ensure that it does not override the server logger config;

This process is handled on the private function `reload_project/0`. One interesting trick it uses is that it sets a different build path using `Mix.ProjectStack.post_config/1` (which is a private API). This is the point where it will create a `.elixir_ls` directory on your project.

After reloading, the BEAM instance is free of old code and is ready to fetch/compile/analyze the project.

### Analyzing the project

Even after build is finished, things are not yet done. Both ElixirLS and ElixirSense need dialyzer information for some introspection. So, after build is done it sends a message that is handled at `ElixirLS.LanguageServer.Server.handle_build_result/3`.

The build might not be successful, but if it is, it will trigger a call to `dialyze/1` which will delegate to `ElixirLS.LanguageServer.Dialyzer`.

Here is the point in time where it will build the [PLT (a Persistent Lookup Table)](http://erlang.org/doc/apps/dialyzer/dialyzer_chapter.html#the-persistent-lookup-table) for the instance of Erlang/Elixir/project deps and source. This is mighty resource hungry and it is usually where CPUs start spinning.

There are many things done in this module. It tries to be smart about analyzing only the modules that have changed. It does that by first checking the integrity of the PLT and then loading all modules from the PLT using `:dialyzer_plt.all_modules/1`.

If it finds that there is a difference, than it calculates this difference (using `MapSet`) to separate stale modules from non-stale. Then it delegates do the `ElixirLS.LanguageServer.Dialyzer.Analyzer` module for the proper analysis run.

In the end it will publish a message that the analysis has finished, which will be delegated all the way back to the server module. There it handles the results accordingly and finally it will be ready to introspect code.
