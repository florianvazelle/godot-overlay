{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
}: let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (lib.strings.fileContents ./sources.json);

  # mkBinaryInstall makes a derivation that installs Godot from a binary.
  mkBinaryInstall = {
    editor,
    export_templates,
  }: let

    buildInputs = [
      pkgs.alsa-lib
      pkgs.dbus
      pkgs.dbus.lib
      pkgs.fontconfig
      pkgs.fontconfig.lib
      pkgs.libdecor
      pkgs.libGL
      pkgs.libpulseaudio
      pkgs.libxkbcommon
      pkgs.mesa
      pkgs.speechd-minimal
      pkgs.udev
      pkgs.vulkan-loader
      pkgs.wayland
      pkgs.xorg.libX11
      pkgs.xorg.libXcursor
      pkgs.xorg.libXext
      pkgs.xorg.libXfixes
      pkgs.xorg.libXi
      pkgs.xorg.libXinerama
      pkgs.xorg.libXrandr
      pkgs.xorg.libXrender
    ];
    

    godot-export-templates = pkgs.stdenv.mkDerivation {
      inherit (export_templates) version;

      pname = "godot-export-templates";
      src = pkgs.fetchurl {inherit (export_templates) url sha512;};
      
      strictDeps = true;
      nativeBuildInputs = [pkgs.unzip];
      
      unpackPhase = ''
        unzip $src -d $out

        interpreter=$(cat $NIX_CC/nix-support/dynamic-linker)
        patchelf --set-interpreter $interpreter $out/templates/linux_*
      '';
    };

    godot-editor = pkgs.stdenv.mkDerivation {
      inherit (editor) version;

      pname = "godot-editor";
      src = pkgs.fetchurl {inherit (editor) url sha512;};
      
      strictDeps = true;
      nativeBuildInputs = [pkgs.autoPatchelfHook pkgs.unzip];

      unpackPhase = ''
        unzip $src -d $out
      '';
      
      installPhase = ''
        mkdir -p $out/bin
        cp $out/Godot_v${editor.version}* $out/bin/godot
        rm $out/Godot_v${editor.version}*
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
      targetPkgs = _pkgs: buildInputs ++ [godot-editor godot-export-templates];
      runScript = "godot";
      extraInstallCommands = ''
        cp -r ${godot-export-templates}/* $out/
      '';
    };

  # Godot Editor packages that are tagged releases
  editorPackages =
    lib.attrsets.mapAttrs
    (
      _k: v:
        mkBinaryInstall {
          editor = v.${system};
          inherit (v) export_templates;
        }
    )
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
  editorPackages // {"default" = editorPackages.${latest};}
