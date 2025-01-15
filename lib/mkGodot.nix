# This modules create a Godot project derivation.
{
  lib,
  stdenv,
  buildEnv,
  makeWrapper,
  godot,
  exportTemplates, # absolute path to the nix store
}: {
  pname,
  version,
  src,
  preset,
  addons ? [],
  preBuildPhase ? "",
  preInstallPhase ? "",

}: let
  addonsEnv = buildEnv {
    name = "addons";
    paths = addons;
  };

  godotVersionFfolder = lib.replaceStrings ["-"] ["."] godot.version;
in
  stdenv.mkDerivation rec {
    inherit pname version src;

    nativeBuildInputs = addons;
    buildInputs = [godot makeWrapper];

    postPatch = ''
      patchShebangs scripts
    '';

    buildPhase = ''
      runHook preBuild

      ${preBuildPhase}

      export HOME=$(mktemp -d)

      # Remove custom_template path if it doesn't point to the nix store
      sed -i -e '/custom_template/!b' -e '/\/nix\/store/b' -e 's/"[^"]*"/""/g' -e 't' export_presets.cfg

      mkdir -p $HOME/.local/share/godot/export_templates
      ln -s ${exportTemplates} $HOME/.local/share/godot/export_templates/${godotVersionFfolder}

      cp -r ${addonsEnv}/* ./addons
      godot --headless --import

      mkdir -p ./build
      godot --headless --export-release "${preset}" ./build/${pname}.x86_64

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      ${preInstallPhase}

      install -D -m 755 -t $out/share/${pname} ./build/${pname}.x86_64
      install -D -m 644 -t $out/share/${pname} ./build/${pname}.pck
      install -d -m 755 $out/bin

      makeWrapper $out/share/${pname}/${pname}.x86_64 $out/bin/${pname} \
        --add-flags "--main-pack" \
        --add-flags "$out/share/${pname}/${pname}.pck"

      patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 $out/share/${pname}/${pname}.x86_64

      runHook postInstall
    '';
  }
