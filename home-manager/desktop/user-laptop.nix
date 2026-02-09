{ pkgs, ... }:

{
  home.username = "rokokol";
  home.homeDirectory = "/home/rokokol";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    # hyprland & desktop
    kitty
    swww
    hypridle
    hyprlock
    hyprpolkitagent
    waybar
    libsForQt5.qt5.qtwayland
    qt6.qtwayland
    brightnessctl
    cliphist
    grim
    slurp
    satty
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

    # programs
    ayugram-desktop
    adwaita-icon-theme
    obsidian
    bambu-studio
    gnome-disk-utility
    celluloid
    swayimg
    loupe
    file-roller
    octaveFull
  ];

  home.sessionVariables = {
    NIXPKGS_ALLOW_UNFREE = "1";
    EDITOR = "nvim";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    TERMINAL = "kitty";
    BROWSER = "firefox";
    SSH_ASKPASS = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
    SSH_ASKPASS_REQUIRE = "force";
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/keyring/ssh";
    GTK_THEME = "rose-pine-dawn";
  };

  gtk = {
    enable = true;
    theme = {
      name = "rose-pine-dawn";
      package = pkgs.rose-pine-gtk-theme;
    };
    iconTheme = {
      name = "rose-pine-dawn";
      package = pkgs.rose-pine-icon-theme;
    };
  };

  home.file.".config/swayimg/config".text = ''
    [info]
    show = no

    [keys.viewer]
    Ctrl+c = exec wl-copy < "%"
    i = info
    Left = prev_file
    Right = next_file
    r = rotate_right
    m = flip_horizontal
  '';
}
