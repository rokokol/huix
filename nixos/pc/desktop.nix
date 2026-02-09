{ pkgs, ... }:

{
  # Keyboard layouts
  services.xserver.xkb = {
    layout = "us,ru";
    variant = "";
    options = "grp:win_space_toggle";
  };

  # Portals (apps & system interaction)
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];

    config.common = {
      default = [
        "hyprland"
        "gtk"
      ];
      # "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
      # "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
    };
  };
}
