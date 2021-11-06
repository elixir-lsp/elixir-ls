# Welcome to ElixirLS

Implementing features such as _auto-complete_ or _go-to-definition_
for a programming language is not trivial. Traditionally, this work
had to be repeated for each development tool and it required a mix of
expertise in both the targeted programming language and the
programming language internally used by the development tool of
choice.

The [Elixir Language Server][git] (ElixirLS) provides a server that runs in the background, providing IDEs, editors, and other tools with information about Elixir Mix projects. It adheres to the _LSP_, a standard for frontend-independent IDE support. Debugger integration is accomplished through the similar VS Code Debug Protocol.

These pages contain all the information needed to configure your
favourite text editor or IDE and to work with the ElixirLS. You will also
find instructions on how to configure the server to recognize the
structure of your projects and to troubleshoot your installation when
things do not work as expected.

[git]:https://github.com/elixir-lsp/elixir-ls
[lsp]:https://microsoft.github.io/language-server-protocol/
[elixir]:https://www.elixir-lang.org
[issue]:https://github.com/elixir-lsp/elixir-ls/issues
