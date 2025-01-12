# This modules patch a given Godot project derivation, to make it runnable on Nixos.
{ lib
, stdenv
, mkGodot
, copyDesktopItems
, installShellFiles
, autoPatchelfHook
, xorg
, vulkan-loader
, libGL
, libxkbcommon
, alsa-lib
}:

{ pname
, version
, src
, desktopItems ? [ ]
}:

stdenv.mkDerivation rec {
  inherit pname version src desktopItems;

  nativeBuildInputs = [
    autoPatchelfHook
    installShellFiles
    copyDesktopItems
  ];

  runtimeDependencies = [
    vulkan-loader
    libGL
    xorg.libX11
    xorg.libXcursor
    xorg.libXinerama
    xorg.libXext
    xorg.libXrandr
    xorg.libXrender
    xorg.libXi
    xorg.libXfixes
    libxkbcommon
    alsa-lib
  ];

  postPatch = ''
    patchShebangs scripts
  '';

  installPhase = ''
    runHook preInstall

    mkdir $out
    mv bin/* bin/${pname} || true # Rename fails if pname is the same
    cp -r * $out

    runHook postInstall
  '';
}