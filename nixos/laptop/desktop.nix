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
      default = [
        "hyprland"
        "gtk"
      ];
    };
  };
}
