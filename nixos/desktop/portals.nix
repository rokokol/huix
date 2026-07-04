{ pkgs, ... }:

let
  hyprlandPortalConfig = {
    "org.freedesktop.impl.portal.AppChooser" = [ "gtk" ];
    "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
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

  # environment.sessionVariables.XDG_DATA_DIRS = [
  #   "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
  #   "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
  # ];

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
