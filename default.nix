{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
}: let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (lib.strings.fileContents ./sources.json);

  # mkBinaryInstall makes a derivation that installs Godot from a binary.
  mkBinaryInstall = {
    url,
    version,
    sha512,
  }:
    pkgs.stdenv.mkDerivation {
      inherit version;

      pname = "godot";
      src = pkgs.fetchurl {inherit url sha512;};
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;
      nativeBuildInputs = [pkgs.unzip];
      unpackPhase = ''
        unzip $src -d $out
      '';
      installPhase = ''
        mkdir -p $out/bin
        cp $out/Godot_v${version}* $out/bin/godot
      '';

      meta = {
        homepage = "https://godotengine.org";
        description = "Free and Open Source 2D and 3D game engine";
        license = lib.licenses.mit;
        # platforms = [system];
        maintainers = [lib.maintainers.florianvazelle];
      };
    };

  # The packages that are tagged releases
  taggedPackages =
    lib.attrsets.mapAttrs
    (k: v: mkBinaryInstall {inherit (v.${system}) version url sha512;})
    (
      lib.attrsets.filterAttrs
      (k: v: (builtins.hasAttr system v) && (v.${system}.url != null) && (v.${system}.sha512 != null))
      sources
    );

  # This determines the latest released version.
  latest = lib.lists.last (
    builtins.sort
    (x: y: (builtins.compareVersions x y) < 0)
    (builtins.attrNames taggedPackages)
  );
in
  # We want the packages but also add a "default" that just points to the
  # latest released version.
  taggedPackages // {"default" = taggedPackages.${latest};}
