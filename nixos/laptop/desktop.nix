{ pkgs, ... }:

{
  # Configure keymap in X11
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us,ru";
      variant = "";
      options = "grp:shifts_toggle,ctrl:swapcaps";
    };
  };

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

      default = [
        "hyprland"
        "gtk"
      ];
    };
  };
}
