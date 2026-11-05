{
  lib,
  pkgs,
  osConfig,
  inputs,
  ...
}:

{
  home.packages = lib.optionals osConfig.rokokol.drive-backup.enable [
    (pkgs.callPackage ../../../lib/drive-backup-package.nix { inherit inputs; })
  ];
}
