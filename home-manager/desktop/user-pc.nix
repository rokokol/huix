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
      appimage-run

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

      # C++
      gcc
      cmake
      openmpi
      eigen
      pkg-config
      llvmPackages.openmp

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
      ayugram-desktop
      obsidian
      gnome-disk-utility
      swayimg
      celluloid
      gthumb
      evince
      file-roller
      vesktop # Discord client with Vencord
      tor-browser # Privacy browsing

      # --- CREATIVITY, HARDWARE & AUDIO ---
      easyeffects # Audio processing (EQ, Noise reduction) - Crucial for mic/guitar
      solvespace # 3D CAD
      darktable # RAW editor
      stable.kdePackages.kdenlive # Video editor
      gimp2-with-plugins # Shitty image manipulation
      gimpPlugins.gmic
      krita # Drawing program
      aseprite # Pixel art
      obs-studio
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
  };

  # Directories
  systemd.user.tmpfiles.rules = [
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

  # Global session variables
  home.sessionVariables = {
    NIXPKGS_ALLOW_UNFREE = "1";
    EDITOR = "nvim";
    TERMINAL = "kitty";
    BROWSER = "firefox";
    HUIX = "$HOME/huix";
  };
}
