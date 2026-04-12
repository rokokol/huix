{ pkgs, ... }:
let
  sharedConfig = pkgs.substituteAll {
    src = ./hyprland.conf;
    scriptsDir = ./scripts;
  };
in
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

    extraConfig = ''
      source = ${sharedConfig}
    '';
  };

  imports = [
    ./hyprland-packages.nix
    ./waybar-pc.nix
  ];
}
