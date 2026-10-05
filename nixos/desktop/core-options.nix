{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:

# The umbrella of every desktop and workstation module: each of them defaults its own
# rokokol.<name>.enable to this one, so a host turns the whole desktop on with a single line
# and still can turn one piece off. The modules of nixos/desktop have no use apart from the
# desktop, so they read the umbrella itself and declare no flag of their own
{
  options.rokokol.workstation.enable = lib.mkEnableOption "the desktop session and the workstation services";

  config = lib.mkIf config.rokokol.workstation.enable {
    # AppImage support (programs.appimage.* incl. binfmt) lives in
    # nixos/services/system/appimage.nix — single source of truth
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };
    services.flatpak.enable = true;

    # The agent that answers these prompts is hyprpolkitagent, started from hyprland.lua
    security.polkit.enable = true;

    services.xserver.excludePackages = with pkgs; [ xterm ];

    # A desktop roams between networks; a server keeps a fixed link without NetworkManager
    networking.networkmanager.enable = true;
    users.users.${rokokolName}.extraGroups = [ "networkmanager" ];

    services.xserver.desktopManager.runXdgAutostartIfNone = true;
  };
}
