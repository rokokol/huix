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
      # Use GTK portal for chooser/open dialogs, keep Hyprland portal available
      # for compositor-specific interfaces like screencasting.
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      "org.freedesktop.impl.portal.OpenURI" = [ "gtk" ];

      default = [
        "hyprland"
        "gtk"
      ];
    };
  };
}
