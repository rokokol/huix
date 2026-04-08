{ pkgs, config, ... }:
{
  services.swayosd.enable = true;
  services.playerctld.enable = true;

  dconf.enable = true;

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
    evince
    baobab
    gnome-disk-utility
    gnome-text-editor
    gtk3
    lm_sensors
    pup
    jq
    rofimoji
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
    enable = true;
    gtk4.theme = config.gtk.theme;

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

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";

      "image/jpeg" = "swayimg.desktop";
      "image/png" = "swayimg.desktop";
      "image/gif" = "swayimg.desktop";
      "image/x-canon-cr2" = "swayimg.desktop";
      "image/x-raw" = "swayimg.desktop";
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

      "application/pdf" = "org.gnome.Evince.desktop";
      "application/x-bzpdf" = "org.gnome.Evince.desktop";
      "application/x-gzpdf" = "org.gnome.Evince.desktop";
      "application/x-ext-pdf" = "org.gnome.Evince.desktop";
      "application/postscript" = "org.gnome.Evince.desktop";
      "application/x-bzpostscript" = "org.gnome.Evince.desktop";
      "application/x-gzpostscript" = "org.gnome.Evince.desktop";
      "image/vnd.djvu" = "org.gnome.Evince.desktop";
      "application/x-ext-djvu" = "org.gnome.Evince.desktop";
      "application/x-cbz" = "org.gnome.Evince.desktop";
      "application/x-cbr" = "org.gnome.Evince.desktop";
      "application/epub+zip" = "org.gnome.Evince.desktop";

      "text/markdown" = "org.gnome.TextEditor.desktop";
      "text/plain" = "org.gnome.TextEditor.desktop";
      "text/x-markdown" = "org.gnome.TextEditor.desktop";
      "application/x-zerosize" = "org.gnome.TextEditor.desktop";
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
