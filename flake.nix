{
  description = "Godot Engine binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }: let
    systems = ["i686-linux" "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    outputs = flake-utils.lib.eachSystem systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in rec {
      # The packages exported by the Flake:
      #  - default - latest released version
      #  - <version> - tagged version
      packages = import ./default.nix {inherit system pkgs;};

      # "Apps" so that `nix run` works. If you run `nix run .` then
      # this will use the latest default.
      apps = rec {
        default = apps.godot;
        godot = flake-utils.lib.mkApp {drv = packages.default;};
      };

      # nix fmt
      formatter = pkgs.alejandra;
    });
  in
    outputs
    // {
      # Overlay that can be imported so you can access the packages
      # using godotpkgs.latest or whatever you'd like.
      overlays.default = final: prev: {
        godotpkgs = outputs.packages.${prev.system};
      };
    };
}
