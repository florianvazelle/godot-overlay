_: {
  projectRootFile = "flake.nix";

  # Nix
  programs.alejandra.enable = true;
  programs.deadnix.enable = true;
  programs.statix.enable = true;
  programs.statix.disabled-lints = [
    "repeated_keys" # Avoid repeated keys in attribute sets
  ];

  # Python
  programs.ruff-check.enable = true;
  programs.ruff-format.enable = true;
}
