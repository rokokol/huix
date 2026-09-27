{ pkgs, ... }:

let
  hyprlandPortalConfig = {
    "org.freedesktop.impl.portal.AppChooser" = [ "gtk" ];
    # yazi in a kitty window, set up in home-manager/programs/yazi/desktop.nix; GTK's own
    # dialog when that backend cannot start
    "org.freedesktop.impl.portal.FileChooser" = [
      "termfilechooser"
      "gtk"
    ];
    "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
    "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
    "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];

    default = [
      "gtk"
      "hyprland"
    ];
  };
in
{
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
      xdg-desktop-portal-termfilechooser
    ];
    configPackages = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];

    config = {
      common = hyprlandPortalConfig;
      hyprland = hyprlandPortalConfig;
    };
  };
}
