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
    swayimg
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
    gsettings-desktop-schemas
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

      "image/jpeg" = "swayimg.desktop"; # jpg, JPG
      "image/png" = "swayimg.desktop"; # png
      "image/gif" = "swayimg.desktop"; # gif
      "image/x-canon-cr2" = "swayimg.desktop"; # cr2
      "image/x-raw" = "swayimg.desktop"; # raw
      "image/x-dcraw" = "swayimg.desktop";
      "image/tiff" = "swayimg.desktop";
      "image/bmp" = "swayimg.desktop";
      "image/webp" = "swayimg.desktop";

      "video/mp4" = "io.github.celluloid_player.Celluloid.desktop";
      "video/x-matroska" = "io.github.celluloid_player.Celluloid.desktop";
      "video/webm" = "io.github.celluloid_player.Celluloid.desktop";
      "video/quicktime" = "io.github.celluloid_player.Celluloid.desktop";
      "video/x-msvideo" = "io.github.celluloid_player.Celluloid.desktop";
      "video/mpeg" = "io.github.celluloid_player.Celluloid.desktop";
      "video/3gpp" = "io.github.celluloid_player.Celluloid.desktop";
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
