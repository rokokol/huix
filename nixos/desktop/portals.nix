{ pkgs, ... }:

{
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];

    config.common = {
      # Use GTK portal for chooser/open dialogs, keep Hyprland portal available
      # for compositor-specific interfaces like screencasting.
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      "org.freedesktop.impl.portal.Settings" = [ "gtk" ];

      default = [
        "hyprland"
        "gtk"
      ];
    };
  };
}
