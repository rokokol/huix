{ pkgs, ... }:

{
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gnome
    ];

    config.hyprland = {
      "org.freedesktop.impl.portal.FileChooser" = [ "gnome" ];
      "org.freedesktop.impl.portal.OpenURI" = [ "gnome" ];
      "org.freedesktop.impl.portal.Settings" = [ "gnome" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];

      default = [
        "hyprland"
        "gnome"
      ];
    };
  };
}
