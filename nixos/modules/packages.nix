{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  # ============================================================================
  #  PROGRAMS & SERVICES CONFIGURATION
  # ============================================================================

  # --- Core & Shell ---
  programs.zsh.enable = true;
  programs.starship.enable = true;
  programs.nix-ld.enable = true; # Essential for running unpatched binaries
  programs.gnupg.agent.enable = true;
  programs.dconf.enable = true;

  # --- Internet & Privacy ---
  programs.firefox.enable = true;
  programs.amnezia-vpn.enable = true;
  services.tor.enable = true;
  services.tor.client.enable = true;

  # --- Desktop Environment Integrations ---
  services.flatpak.enable = true;
  programs.appimage.enable = true;
  programs.gpaste.enable = true; # Clipboard history
  services.zeitgeist.enable = true; # Activity logging (needed for some GNOME features)
  services.gnome.gnome-browser-connector.enable = true; # Gnome extensions in browser

  # --- Gaming ---
  programs.steam.enable = true;

  # ============================================================================
  #  SYSTEM PACKAGES
  # ============================================================================

  environment.systemPackages = with pkgs; [

    # --- 1. CORE UTILITIES & CLI ---
    wget
    curl
    git
    btop # Resource monitor
    fastfetch # System info
    usbutils # lsusb, etc.
    lm_sensors # Hardware sensors
    killall
    unzip

    # --- 2. DEVELOPMENT & PROGRAMMING ---
    # Core Editors & Tools
    neovim
    kitty # GPU-accelerated terminal
    gh # GitHub CLI
    steam-run # FHS environment to run binaries
    trash-cli # Trash manipulation

    # Python
    python3
    uv # Fast Python package installer

    # MATLAB
    matlab
    matlab-language-server

    # --- 3. DESKTOP, UI & WAYLAND TOOLS ---
    papirus-icon-theme
    gnome-tweaks
    gnomeExtensions.vitals # System monitoring in panel
    gnomeExtensions.appindicator # Tray icons support

    wl-clipboard # Clipboard utils for Wayland
    xdotool # Window automation (X11/XWayland)
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
  ];

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

