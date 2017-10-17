While you can develop ElixirLS on its own, it's easiest to test out changes if you clone the [vscode-elixir-ls](https://github.com/JakeBecker/vscode-elixir-ls) repository instead. It includes ElixirLS as a Git submodule, so you can make your changes in the submodule directory and launch the extension from the parent directory via the included "Launch Extension" configuration in `launch.json`. See the README on that repo for more details.

### Building and running

To build for release, run the `release.sh` script. It compiles these two apps to escripts in the `release` folder. If doing a public release, compile it with Erlang OTP 19, since OTP 20 builds are not backwards-compatible with earlier versions of Erlang.

Elixir escripts typically embed Elixir, which is not what we want because users will want to run it against their own system Elixir installation. In order to support this, there are scripts in the `bin` folder that look for the system-wide Elixir installation and set the `ERL_LIBS` environment variable prior to running the escripts. These scripts are copied to the `release` folder by `release.sh`.
