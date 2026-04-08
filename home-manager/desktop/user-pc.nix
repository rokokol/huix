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
      # --- CLI & system tools ---
      cuda.appimage-run
      cuda.fastfetch # System info
      gdu
      lm_sensors # Hardware sensors
      ncdu
      nvtopPackages.nvidia
      trash-cli # Trash manipulation
      unzip
      usbutils # lsusb, etc.
      yt-dlp # video download

      # --- Development ---
      # C++
      cmake
      eigen
      gcc
      llvmPackages.openmp
      openmpi
      pkg-config

      # Python
      cuda.uv # Fast Python package installer
      (cuda.python313.withPackages (
        ps: with ps; [
          matplotlib
          numpy
          pandas
          scipy
          seaborn
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
      texlive.combined.scheme-full

      # --- Communication & web ---
      cuda.ayugram-desktop
      cuda.obsidian
      cuda.vesktop # Discord client with Vencord
      tor-browser # Privacy browsing

      # --- Desktop & media ---
      antigravity-fhs
      celluloid
      codex
      evince
      file-roller
      gnome-disk-utility
      gthumb
      swayimg
      vial # Mechanical keyboard configuration (QMK/Vial)

      # --- Creative & audio ---
      aseprite # Pixel art
      cuda.darktable # RAW editor
      cuda.gimp2-with-plugins # Shitty image manipulation
      cuda.gimpPlugins.gmic
      cuda.kdePackages.kdenlive # Video editor
      cuda.obs-studio
      easyeffects # Audio processing (EQ, Noise reduction) - Crucial for mic/guitar
      krita # Drawing program
      solvespace # 3D CAD
    ]
    ++ (with inputs; [
      freesmlauncher.packages.${pkgs.stdenv.hostPlatform.system}.default # Minecraft
    ]);

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true;

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
      "file:///home/rokokol/Projects/"
      "file:///home/rokokol/myWiki/media/"
      "file:///home/rokokol/govno/"
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
