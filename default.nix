{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
}: let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (lib.strings.fileContents ./sources.json);

  # mkExportTemplates makes a derivation that installs pre-compiled Godot Export Templates.
  mkExportTemplates = {
    version,
    url,
    sha512,
  }:
    pkgs.stdenv.mkDerivation {
      inherit version;

      pname = "godot-export-templates";
      src = pkgs.fetchurl {inherit url sha512;};

      strictDeps = true;
      nativeBuildInputs = [pkgs.unzip];

      unpackPhase = ''
        unzip $src -d $out

        interpreter=$(cat $NIX_CC/nix-support/dynamic-linker)
        patchelf --set-interpreter $interpreter $out/templates/linux_*
      '';

      meta = {
        homepage = "https://godotengine.org";
        description = "Free and Open Source 2D and 3D game engine";
        license = lib.licenses.mit;
        platforms = lib.platforms.all;
        maintainers = [lib.maintainers.florianvazelle];
      };
    };

  # Godot Export Templates packages that are tagged releases
  exportTemplatesPackages =
    lib.attrsets.mapAttrs
    (_k: v: mkExportTemplates {inherit (v.export_templates) version url sha512;})
    (
      lib.attrsets.filterAttrs
      (_k: v: (builtins.hasAttr system v) && (v.${system}.url != null) && (v.${system}.sha512 != null))
      sources
    );

  # mkEditor makes a derivation that installs pre-compiled Godot Editor.
  mkEditor = {
    version,
    url,
    sha512,
  }: let
    drv = pkgs.stdenv.mkDerivation {
      inherit version;

      pname = "godot-editor";
      src = pkgs.fetchurl {inherit url sha512;};

      strictDeps = true;
      nativeBuildInputs = [pkgs.unzip];

      unpackPhase = ''
        unzip $src -d $out
      '';

      installPhase = ''
        mkdir -p $out/bin
        cp $out/Godot_v${version}* $out/bin/godot
        rm $out/Godot_v${version}*
      '';

      meta = {
        homepage = "https://godotengine.org";
        description = "Free and Open Source 2D and 3D game engine";
        license = lib.licenses.mit;
        # platforms = [system];
        maintainers = [lib.maintainers.florianvazelle];
      };
    };
  in
    pkgs.buildFHSUserEnv {
      name = "godot";
      inherit version;
      targetPkgs = _pkgs: [drv];
      runScript = "godot";
    };

  # Godot Editor packages that are tagged releases
  editorPackages =
    lib.attrsets.mapAttrs
    (_k: v: let
      editor = mkEditor {inherit (v.${system}) version url sha512;};
    in
      editor
      // {
        "mkGodot" = pkgs.callPackage ./mkGodot.nix {
          godot = editor;
          exportTemplates = "${exportTemplatesPackages.${v.${system}.version}}/templates";
        };
      })
    (
      lib.attrsets.filterAttrs
      (_k: v: (builtins.hasAttr system v) && (v.${system}.url != null) && (v.${system}.sha512 != null))
      sources
    );

  # This determines the latest Godot Editor released version.
  latest = lib.lists.last (
    builtins.sort
    (x: y: (builtins.compareVersions x y) < 0)
    (builtins.attrNames editorPackages)
  );
in
  # We want packages but also add a "default" that just points to the
  # latest Godot Editor released version.
  editorPackages // { "default" = editorPackages.${latest}; }
