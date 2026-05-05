{ ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitor = [
        ",preferred,auto,1"
      ];

      input = {
        kb_layout = "us,ru";
        kb_variant = "";
        kb_options = "grp:win_space_toggle";

        follow_mouse = 1;

        sensitivity = 0;
      };
    };
  };

  imports = [
    ./servces/wallpapaer_collager.nix
    ./services/hyprland-packages.nix
    ./services/waybar-pc.nix
  ];
}
