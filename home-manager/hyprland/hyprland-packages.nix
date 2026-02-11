{ pkgs, ... }:

{
  services.swayosd.enable = true;
  services.playerctld.enable = true;

  home.packages = with pkgs; [
    swww
    hypridle
    hyprlock
    hyprpolkitagent
    hyprpicker
    libnotify
    seahorse
    (symlinkJoin {
      name = "pavucontrol";
      paths = [ pavucontrol ];
      buildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/pavucontrol \
          --set GTK_THEME Adwaita
      '';
    })
    cliphist
    grim
    slurp
    satty
    brightnessctl
    swayosd
    (tesseract5.override {
      enableLanguages = [
        "rus"
        "eng"
      ];
    })
  ];

  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    SSH_ASKPASS = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/keyring/ssh";
  };

  home.file.".config/swayimg/config".text = ''
    [info]
    show = no

    [keys.viewer]
    Ctrl+c = exec sh -c 'wl-copy < "%"' 
    c = exec wl-copy < "%"
    i = info
    Left = prev_file
    Right = next_file
    r = rotate_right
    m = flip_horizontal
  '';
}
