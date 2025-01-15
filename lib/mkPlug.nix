# This module attempts to mimic gd-plug in a nix way.
{
  stdenv,
  fetchFromGitHub,
}: {
  owner,
  repo,
  rev,
  hash ? "",
}:
stdenv.mkDerivation {
  pname = repo;
  version = "0.0.0";

  src = fetchFromGitHub {
    inherit owner repo;
    inherit rev;
    inherit hash;
  };

  strictDeps = true;

  unpackPhase = ''
    cp -r $src/addons $out
  '';
}
