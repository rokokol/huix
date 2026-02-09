{ pkgs, inputs, ... }:

{
  home.username = "rokokol";
  home.homeDirectory = "/home/rokokol";
  home.stateVersion = "25.11";
  home.file.".face".source = ../../logo.jpg;

  # Global packages not bound to specific program configs
  home.packages =
    with pkgs;
    [
      # --- CLI ---
      nvtopPackages.nvidia
      fastfetch # System info
      usbutils # lsusb, etc.
      lm_sensors # Hardware sensors
      unzip
      trash-cli # Trash manipulation
      yt-dlp # video download
      gdu

      # --- DEVELOPMENT & PROGRAMMING ---
      # Python
      uv # Fast Python package installer
      (python313.withPackages (
        ps: with ps; [
          matplotlib
          pandas
          scipy
          seaborn
          numpy
          sympy
        ]
      ))

      # MATLAB & Octave
      matlab
      (pkgs.symlinkJoin {
        name = "octave-wrapped";
        paths = [ pkgs.octaveFull ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/octave --set QT_QPA_PLATFORM xcb
        '';
      })

      # --- SOFTWARE, UI ---
      vial # Mechanical keyboard configuration (QMK/Vial)
      kitty
      ayugram-desktop
      obsidian
      bambu-studio
      gnome-disk-utility
      celluloid
      swayimg
      loupe
      file-roller
      vesktop # Discord client with Vencord
      tor-browser # Privacy browsing

      # --- HYPRLAND & DESKTOP ---
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

      # --- CREATIVITY, HARDWARE & AUDIO ---
      bambu-studio # 3D Printing Slicer
      easyeffects # Audio processing (EQ, Noise reduction) - Crucial for mic/guitar
      solvespace # 3D CAD
      darktable # RAW editor
      stable.kdePackages.kdenlive # Video editor
      gimp2-with-plugins # Shitty image manipulation
      gimpPlugins.gmic
      krita # Drawing program
      aseprite # Pixel art

      # --- ICONS AND SHIT ---
      adwaita-icon-theme
      libsForQt5.qt5.qtwayland
      qt6.qtwayland
    ]
    ++ (with inputs; [
      freesmlauncher.packages.${pkgs.stdenv.hostPlatform.system}.default # Minecraft
    ]);

  xdg.userDirs = {
    enable = true;
    createDirectories = true;

    music = "/home/rokokol/govno/Music";
    documents = "/home/rokokol/govno/Documents";
    pictures = "/home/rokokol/govno/Pictures";
    videos = "/home/rokokol/govno/Videos";

    download = "/home/rokokol/Downloads";

    desktop = null;
    templates = null;
    publicShare = null;
  };

  gtk = {
    enable = true;
    gtk3.bookmarks = [
      "file:///home/rokokol/Downloads/"
      "file:///home/rokokol/huix/"
      "file:///home/rokokol/Temp/"
      "file:///home/rokokol/myWiki/media/"
      "file:///"
    ];

    theme = {
      name = "rose-pine-dawn";
      package = pkgs.rose-pine-gtk-theme;
    };
    iconTheme = {
      name = "rose-pine-dawn";
      package = pkgs.rose-pine-icon-theme;
    };
  };

  # Directories
  systemd.user.tmpfiles.rules = [
    "d %h/notebooks 0755 - - -"
    "d %h/Projects 0755 - - -"
    "d %h/govno/Pictures/Screenshots 0700 - - 30d"
    "D %h/Temp 0777 - - -"
  ];

  # Files
  home.file.".octaverc".text = ''
    PS1('>> ');
    # to disable octave warn
    warning('off', 'Octave:graphics-toolkit-gnuplot');
  '';

  home.file.".config/matlab/nix.sh".text = ''
    INSTALL_DIR=$HOME/MATLAB2025a/ 
  '';

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

  # Global session variables
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
}
