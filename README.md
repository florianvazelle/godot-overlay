# Nix Flake for Godot

This repository is a Nix flake packaging the [Godot Engine](https://godotengine.org).
The flake mirrors the binaries built officially by Godot and
does not build them from source.

This repository is meant to be consumed primarily as a flake but the
`default.nix` can also be imported directly by non-flakes, too.

The flake outputs are documented in `flake.nix` but an overview:

  * Default package and "app" is the latest released version
  * `packages.<version>` for a tagged release
  * `packages.default` for the latest stable release
  * `packages.latest` for the latest release
  * `overlays.default` is an overlay that adds `godotpkgs` to be the packages
    exposed by this flake

## Usage

### Flake

In your `flake.nix` file:

```nix
{
  inputs.godot.url = "github:florianvazelle/godot-overlay";

  outputs = { self, godot, ... }: {
    ...
  };
}
```

In a shell:

```sh
# run the latest stable released version
$ nix run 'github:florianvazelle/godot-overlay'
# open a shell with any version (rc for example)
$ nix shell 'github:florianvazelle/godot-overlay#4_4_1_rc1'
# open a shell with latest version
$ nix shell 'github:florianvazelle/godot-overlay#latest'
```
