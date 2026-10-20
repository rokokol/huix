{
  config,
  lib,
  inputs,
  ...
}:

# nix-flatpak installs what services.flatpak.packages lists and removes what leaves the list.
# uninstallUnmanaged stays off, so an app installed by hand stays installed
{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  options.rokokol.flatpak.enable = lib.mkEnableOption "Flatpak with declared apps" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.flatpak.enable {
    services.flatpak.enable = true;
  };
}
