{ stdenvNoCC, elixir, rebar, rebar3, git, cacert }:

{ name ? null, src, sha256 ? null, env ? "prod" }:

stdenvNoCC.mkDerivation {
  name = "mix-deps" + (if name != null then "-${name}" else "");

  nativeBuildInputs = [ elixir git cacert ];

  inherit src;

  configurePhase = ''
    export MIX_ENV="${env}"

    export HEX_HOME="$PWD/hex"
    export MIX_HOME="$PWD/mix"
    export MIX_DEPS_PATH="$out"
    export MIX_REBAR="${rebar}/bin/rebar"
    export MIX_REBAR3="${rebar3}/bin/rebar3"
    export REBAR_GLOBAL_CONFIG_DIR="$PWD/rebar3"
    export REBAR_CACHE_DIR="$PWD/rebar3.cache"

    mix local.hex --force
    '';

  buildPhase = ''
    mix deps.get
    find "$out" -path '*/.git/*' -a ! -name HEAD -exec rm -rf {} +
    '';

  dontInstall = true;

  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = sha256;

  impureEnvVars = stdenvNoCC.lib.fetchers.proxyImpureEnvVars;
}
