{ ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitor = [
        ",preferred,auto,1.33"
      ];

      input = {
        kb_layout = "us,ru";
        kb_variant = "";
        kb_options = "grp:shifts_toggle,ctrl:swapcaps";

        follow_mouse = 1;

        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.

        touchpad = {
          natural_scroll = true;
        };
      };
    };

    extraConfig = ''
      source = /home/rokokol/huix/home-manager/hyprland/hyprland.conf
    '';
  };
}
