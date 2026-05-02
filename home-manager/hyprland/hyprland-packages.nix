{ pkgs, huixDir, ... }:

{
  services.swayosd.enable = true;
  services.playerctld.enable = true;

  imports = [
    ./cursor.nix
    ./hypridle.nix
    ./systemd.nix
  ];

  home.packages = with pkgs; [
    kitty
    awww
    hypridle
    hyprlock
    hyprpolkitagent
    hyprpicker
    libnotify
    pavucontrol
    cliphist
    grim
    slurp
    satty
    swayosd
    swayimg
    lm_sensors
    pup
    jq
    rofimoji
    translate-shell
    (tesseract5.override {
      enableLanguages = [
        "rus"
        "eng"
      ];
    })
  ];

  wayland.windowManager.hyprland.extraConfig = ''
    source = ${huixDir}/home-manager/hyprland/hyprland.conf
  '';

  home.file.".config/swayimg/config".text = ''
    [info]
    show = no

    [keys.viewer]
    Ctrl+c = exec sh -c 'wl-copy < "%"' 
    c = exec wl-copy < "%"
    i = info
    Left = prev_file
    Right = next_file
    h = prev_file
    l = next_file
    r = rotate_right
    m = flip_horizontal

    Ctrl+с = exec sh -c 'wl-copy < "%"' 
    с = exec wl-copy < "%"
    ш = info
    р = prev_file
    д = next_file
    к = rotate_right
    ь = flip_horizontal
  '';
}
