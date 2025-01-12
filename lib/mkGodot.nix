# This modules create a Godot project derivation.
{ lib
, stdenv
, buildEnv
, godot_4
, makeWrapper
}:

{ pname
, version
, src
, preset
, addons
, exportTemplates # absolute path to the nix store
}: let 
  addonsEnv = buildEnv {
    name = "addons";
    paths = addons;
  };

in stdenv.mkDerivation rec {
  inherit pname version src;

  nativeBuildInputs = addons;
  buildInputs = [godot_4 makeWrapper];

  postPatch = ''
    patchShebangs scripts
  '';

  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)

    # Remove custom_template path if it doesn't point to the nix store
    sed -i -e '/custom_template/!b' -e '/\/nix\/store/b' -e 's/"[^"]*"/""/g' -e 't' export_presets.cfg

    mkdir -p $HOME/.local/share/godot/export_templates
    ln -s ${exportTemplates} $HOME/.local/share/godot/export_templates/4.3.stable

    cp -r ${addonsEnv}/* ./addons
    godot4 --headless --import 

    mkdir -p ./build
    godot4 --headless --export-release "${preset}" ./build/${pname}.x86_64

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

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