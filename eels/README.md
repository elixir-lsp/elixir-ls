# "Embedded" LSP Server

## New Elixir LSP Server design

The old/current elixir-ls project starts a language server per project, running the language server in the
project's directory so that things like asdf-vm pick up the project's version of OTP and Elixir, which is
what we want. This has two major drawbacks:

* Elixir-LS gets compiled with the lowest supported OTP/Elixir versions, but that can introduce incompatibilities
  between the two versions that are now in play (compile time and run time). This happened, for example, with the
  big logging overhauls in Erlang.

* The server that gets started now contains the language server applications, including their dependencies, which
  may include common dependencies like a JSON parser. This can cause conflicts between elixir-ls dependencies and
  project dependencies.

The new design tries to solve this by running a BEAM instance per project and one "controller" that runs the show. The
controller contains all of Elixir-LS, and the per-project BEAM instances contain just a very small application with
a random (and therefore hopefully unique) name and no dependencies. Inter-BEAM communications works through Erlang
clustering.

The new startup sequence is:

* The wrapper script compiles, using the project OTP/Elixir, this application caches it (done);
* The wrapper script starts the just-compiled application (done);
* The application enables clustering and tries to find the Elixir-LS process under a well-known global name (done);
* If it is not found, Elixir-LS is started using its distribution in the background and the finding is retried (done);
* The embedded server registers with Elixir-LS and starts piping stdin/stdout to it;
* Elixir-LS handles the LSP protocol, as usual, but calls back to the embedded server for anything it needs
  to figure out.

It is a little bit roundabout and makes implementing Elixir-LS somewhat harder because of all the remote calls, but
it solves all the versioning problems.

This application contains the per-beam code and therefore cannot contain any dependencies; also, it is compiled
at run-time to make sure that there are no incompatibilities.

Note that there is a potential for conflict with another application called `eels`. This can be alleviated simply
by renaming this application to something obscure, like `eels_24692c715a9dc2f8c3a88632dbb18704` but that's probably
best postponed to when it actually is needed. To reduce the change of this happening, `eels` is published as
a Hex package.

Because we need the source code at runtime, this app has `lib/` moved under `priv/`, in case you're wondering.
