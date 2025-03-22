{
  description = "Godot Engine binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    treefmt-nix,
    ...
  }: let
    systems = ["i686-linux" "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    outputs = flake-utils.lib.eachSystem systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      # Eval the treefmt modules from ./treefmt.nix
      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
    in rec {
      # The packages exported by the Flake:
      #  - default - latest released version
      #  - <version> - tagged version
      packages = import ./default.nix {inherit system pkgs;};

      # "Apps" so that `nix run` works. If you run `nix run .` then
      # this will use the latest default.
      apps = rec {
        default = flake-utils.lib.mkApp {drv = packages.default;};
        latest = flake-utils.lib.mkApp {drv = packages.latest;};
      };

      # nix fmt
      formatter = treefmtEval.config.build.wrapper;
    });
  in
    outputs
    // {
      # Overlay that can be imported so you can access the packages
      # using godotpkgs.latest or whatever you'd like.
      overlays.default = _final: prev: {
        godotpkgs = outputs.packages.${prev.system};
        mkNixosPatch = prev.callPackage ./mkNixosPatch.nix {};
      };
    };
}
