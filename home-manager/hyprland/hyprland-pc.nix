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

  home.file.".config/hypr/xdph.conf".text = ''
    screencopy {
      # Work around DMA-BUF allocation failures seen on the NVIDIA desktop.
      force_shm = true
    }
  '';

  imports = [
    ./hyprland-packages.nix
    ./waybar-pc.nix
  ];
}
