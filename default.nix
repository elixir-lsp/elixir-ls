{ nixpkgs ? import <nixpkgs> {} }:

let
  packages = nixpkgs.beam.packages.erlang;
in rec {
  elixirLS = packages.callPackage nix/package.nix {};
}
