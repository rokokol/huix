{ pkgs, inputs, ... }:

{
  # ============================================================================
  #  PROGRAMS & SERVICES CONFIGURATION
  # ============================================================================

  # --- Core & Shell ---
  programs.zsh.enable = true;
  programs.starship.enable = true;
  programs.gnupg.agent.enable = true;

  # --- Internet & Privacy ---
  programs.firefox.enable = true;
  programs.amnezia-vpn.enable = true;
  services.tor.enable = true;
  services.tor.client.enable = true;
  programs.geary.enable = true;

  # --- Desktop Environment Integrations ---
  services.flatpak.enable = true;
  programs.appimage.enable = true;
  programs.gpaste.enable = true; # Clipboard history
  services.zeitgeist.enable = true; # Activity logging (needed for some GNOME features)

  # --- Gaming ---
  programs.steam.enable = true;

  # ============================================================================
  #  SYSTEM PACKAGES
  # ============================================================================

  environment.systemPackages =
    with pkgs;
    [
      # --- 1. CORE UTILITIES & CLI ---
      wget
      curl
      git
      lazygit
      btop-cuda # Resource monitor patched
      nvtopPackages.nvidia
      fastfetch # System info
      usbutils # lsusb, etc.
      lm_sensors # Hardware sensors
      killall
      unzip
      trash-cli # Trash manipulation
      yt-dlp # video download
      imagemagick
      gdu
      ffmpeg_7

      # --- 2. DEVELOPMENT & PROGRAMMING ---
      # Core Editors & Tools
      neovim
      kitty # GPU-accelerated terminal
      gh # GitHub CLI
      steam-run # FHS environment to run binaries

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
      # To better GUI
      (pkgs.symlinkJoin {
        name = "octave-wrapped";
        paths = [ pkgs.octaveFull ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/octave --set QT_QPA_PLATFORM xcb
        '';
      })

      # --- 3. DESKTOP, UI & WAYLAND TOOLS ---
      papirus-icon-theme
      gnome-tweaks
      gnomeExtensions.vitals # System monitoring in panel
      gnomeExtensions.appindicator # Tray icons support
      # gradia # The Flameshot alternative
      (pkgs.flameshot.overrideAttrs (oldAttrs: {
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
        postInstall = (oldAttrs.postInstall or "") + ''
          wrapProgram $out/bin/flameshot \
            --set QT_QPA_PLATFORM xcb \
            --set SDL_VIDEODRIVER x11 \
        '';
      }))

      wl-clipboard # Clipboard utils for Wayland
      libnotify # Notifications

      # --- 4. PRODUCTIVITY & OFFICE ---
      obsidian # Notes (Second brain)
      geary # Email client
      dialect # Translator
      normcap # OCR screen capture (extract text from screen)
      pureref # Reference image viewer

      # --- 5. INTERNET & COMMUNICATION ---
      ayugram-desktop # Telegram client
      vesktop # Discord client with Vencord
      tor-browser # Privacy browsing

      # --- 6. CREATIVITY, HARDWARE & AUDIO ---
      bambu-studio # 3D Printing Slicer
      easyeffects # Audio processing (EQ, Noise reduction) - Crucial for mic/guitar
      vial # Mechanical keyboard configuration (QMK/Vial)
      solvespace # 3D CAD
      darktable # RAW editor
      stable.kdePackages.kdenlive # Video editor
      gimp2-with-plugins # Shitty image manipulation
      gimpPlugins.gmic
      krita # Drawing program
      aseprite # Pixel art
    ]
    ++ (with inputs; [
      freesmlauncher.packages.${pkgs.stdenv.hostPlatform.system}.default # Minecraft
    ]);

  # Exclude basic X11 terminal
  services.xserver.excludePackages = [ pkgs.xterm ];
}
