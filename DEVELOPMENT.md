# Development

It's best to disable ElixirLS when working on ElixirLS and elixir_sense. Without that modules from edited code conflict with modules from the running language server.

## Building and testing

### Installing

Clone the repo and run

```shell
mix deps.get
```

### Running tests

Use normal mix commands for running tests.

```shell
mix test
```

### Testing in VSCode

It's easiest to test ElixirLS with [VSCode extension](https://github.com/elixir-lsp/vscode-elixir-ls) with ElixirLS as a git submodule. Refer to that repo for detailed instructions.

### Local release

You can run a local release of language server and debug adapter with launch scripts from `scripts` directory with `ELS_LOCAL=1` environment variable. This will make the install script use source, lockfile and config from the local ElixirLS directory.

```shell
cd path/to/my_project
ELS_LOCAL=1 /path/to/elixir-ls/scripts/language_server.sh
```

#### Docker based test environment

You are able to run the project in a container (based on Elixir Alpine) to quickly try different platforms or shells.

To build and run the container (tagged `els` to make docker operations easier) run:

```shell
docker build -t els .
docker run -it els
```
Please keep in mind that in this will take the current project contents and copy it into the container once when the
container is being built.

Since the container contains its own little Linux os the project content is copied into the `/app` directory to avoid
interference with the surrounding system, when you enter the container using the interactive terminal (with the command
above) you will start in that `/app` directory. The following examples expect you being in that project directory.

The following example runs the language server in the default shell of Alpine Linux, which is the Almquist shell (`ash`):

```shell
ELS_LOCAL=1 SHELL=ash scripts/language_server.sh
```
Since `ash` is already the default shell for Alpine Linux we don't need to explicitly call a shell to run the script with.

To run the same command with the `bash` you need to actually pass the shell as well:

```shell
ELS_LOCAL=1 SHELL=bash bash scripts/language_server.sh
```

### Formatting

You may need to separately run `mix format` in the ElixirLS root and in `apps/language_server` directory.

## Packaging

Follow those instructions when publishing a new release.

1. Bump the changelog
2. Bump the version number in `VERSION`
3. Make PR
4. Merge PR
5. Pull down the latest master
6. Make the tag from the new master matching version number with `v` prefix (e.g. `v0.1.2`)
7. Push the tag (`git push upstream --tags`)
8. Wait for github actions to push up a draft release https://github.com/elixir-lsp/elixir-ls/releases (Semver tags (e.g. `v0.1.0-rc.0`) will create a prerelease)
9. Edit the draft release with a link to the changelog
10. Publish the draft release

## Debugging

If you're debugging a running server than `IO.inspect` or `dbg()` is a good approach, any messages you create with it will be sent to your LSP client as a log message

To debug in tests you can use `IO.inspect(Process.whereis(:user), message, label: "message")` to send your output directly to the group leader of the test process.

## Documenting configuration options

Use this jq program to extract configuration option from VSCode extension [package.json](https://github.com/elixir-lsp/vscode-elixir-ls/blob/master/package.json)

```shell
jq -r '.contributes.configuration.properties | to_entries | map("<dt>\(.key)</dt><dd>\(.value.description)</dd>") | join("\n")' package.json
```

## Documentation website

The documentation website is built using the [Mkdocs](https://www.mkdocs.org) static website generator. The content is written in Markdown format in the directory [docs](./docs) and is configured via the [mkdocs.yml](./mkdocs.yml) file.

### Documentation Development

Make sure you have a recent version of Python 3 and [Pip](https://pip.readthedocs.io/en/stable/installing/) installed.

Install `mkdocs` and the `material` theme with Pip:

```shell
pip install mkdocs mkdocs-material
```

Once installed, simply run `mkdocs serve` from the project root. This will start a local web server with a file watcher.

### Build

To compile the website for deployment, run `mkdocs build` from the project root. The built static assets will be located in the `site` directory. These can then be served by any web hosting solution.
