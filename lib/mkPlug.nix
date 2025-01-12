# This module attempts to mimic gd-plug in a nix way.
{ lib
, stdenv
, fetchFromGitHub
}:

{ repo
, rev
, hash ? ""
}: let 
  repoData = lib.strings.splitString "/" repo;
in stdenv.mkDerivation {
  pname = builtins.elemAt repoData 1;
  version = "0.0.0";

  src = fetchFromGitHub {
    owner = builtins.elemAt repoData 0;
    repo = builtins.elemAt repoData 1;
    rev = rev;
    hash = hash;
  };
      
  strictDeps = true;

  unpackPhase = ''
    cp -r $src/addons $out
  '';
}