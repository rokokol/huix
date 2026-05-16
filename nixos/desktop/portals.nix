{ pkgs, ... }:

let
  hyprlandPortalConfig = {
    "org.freedesktop.impl.portal.AppChooser" = [ "gtk" ];
    "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
    "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
    "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];

    default = [ "gtk" ];
  };
in
{
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
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
