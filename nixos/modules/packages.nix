{ pkgs, inputs, ... }:

{
  nixpkgs.config.allowUnfree = true;

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

  # --- Desktop Environment Integrations ---
  # services.flatpak.enable = true;
  programs.appimage.enable = true;
  programs.gpaste.enable = true; # Clipboard history
  services.zeitgeist.enable = true; # Activity logging (needed for some GNOME features)
  # services.gnome.gnome-browser-connector.enable = true; # Gnome extensions in browser

  # --- Gaming ---
  programs.steam.enable = true;

  # --- Nautilus ---
  # programs.nautilus-open-any-terminal.enable = true;
  # programs.nautilus-open-any-terminal.terminal = "kitty";

  # ============================================================================
  #  SYSTEM PACKAGES
  # ============================================================================

  environment.systemPackages = with pkgs; [

    # --- 1. CORE UTILITIES & CLI ---
    wget
    curl
    git
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

    # --- 2. DEVELOPMENT & PROGRAMMING ---
    # Core Editors & Tools
    neovim
    kitty # GPU-accelerated terminal
    gh # GitHub CLI
    steam-run # FHS environment to run binaries

    # Python
    uv # Fast Python package installer
    (python313.withPackages (ps: with ps; [
      matplotlib
      pandas
      scipy
      seaborn
      numpy
      sympy
    ]))

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
    gradia # The Flameshot alternative

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
    kdePackages.kdenlive # Video editor
    gimp2-with-plugins # Shitty image manipulation
    gimpPlugins.gmic
    krita # Drawing program
    aseprite # Pixel art
  ] ++ (with inputs; [
    freesmlauncher.packages.${pkgs.system}.default # Minecraft
  ]);

  # ============================================================================
  #  CLEANUP & EXCLUSIONS
  # ============================================================================

  # Remove default GNOME bloatware
  environment.gnome.excludePackages = (with pkgs; [
    gnome-software
    epiphany # Default web browser
    gnome-maps
    snapshot # Camera app
    gnome-tour
    simple-scan
  ]);

  # Exclude basic X11 terminal
  services.xserver.excludePackages = [ pkgs.xterm ];
}

