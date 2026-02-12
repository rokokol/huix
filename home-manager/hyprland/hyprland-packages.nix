{ pkgs, ... }:

{
  services.swayosd.enable = true;
  services.playerctld.enable = true;

  home.packages = with pkgs; [
    kitty
    swww
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
    brightnessctl
    swayosd
    gtk3
    dex
    (tesseract5.override {
      enableLanguages = [
        "rus"
        "eng"
      ];
    })

    libsForQt5.qt5.qtwayland
    qt6.qtwayland
    gtk-engine-murrine
    gnome-themes-extra
  ];

  gtk = {
    theme = {
      name = "Gruvbox-Light";
      package = pkgs.gruvbox-gtk-theme;
    };

    iconTheme = {
      name = "rose-pine-dawn";
      package = pkgs.rose-pine-icon-theme;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 0;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 0;
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
    };
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
