{ pkgs, huixDir, ... }:

{
  imports = [ ./mime-apps.nix ];

  home.packages = with pkgs; [
    # --- Common desktop apps ---
    ayugram-desktop
    baobab
    celluloid
    evince
    file-roller
    gnome-disk-utility
    gnome-text-editor
    obsidian
    super-productivity
    tauon

    # --- CLI ---
    appimage-run
    claude-code
    codex
    curl
    exiftool
    fastfetch
    file
    gemini-cli
    gthumb
    imagemagick
    jq
    killall
    lazygit
    libreoffice-fresh
    matlab
    pup
    python3Packages.huggingface-hub
    ripgrep
    texlive.combined.scheme-full
    tree
    unzip
    usbutils
    wget

    # Python
    (python313.withPackages (
      ps: with ps; [
        matplotlib
        numpy
        pandas
        requests
        rich
        scipy
        sympy
        tqdm
      ]
    ))
    uv
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    TERMINAL = "kitty";
    HUIX = huixDir;
    NIXOS_OZONE_WL = "1";
  };

  home.file.".config/matlab/nix.sh".text = ''
    INSTALL_DIR=$HOME/MATLAB2025a/ 
  '';
}
