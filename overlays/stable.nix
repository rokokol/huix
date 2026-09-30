{
  inputs,
  nixpkgsConfig,
  system,
  ...
}:
# pkgs.stable: the last release, under the same config as the unstable set
_final: _prev: {
  stable = import inputs.nixpkgs-stable {
    inherit system;
    config = nixpkgsConfig;
  };
}
