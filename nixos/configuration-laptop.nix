{ pkgs, ... }:

{
  imports = [
    ./desktop/portals.nix
    ./fonts/fonts.nix
    ./laptop/hardware-configuration.nix
    ./laptop/boot.nix
    ./laptop/keyboard.nix
    ./laptop/hardware.nix
    ./laptop/packages.nix
    ./laptop/system.nix
    ./services/file-manager.nix
    ./services/wl-clip-persist.nix
    ./services/sddm.nix
    ./services/jupyter.nix
    ./services/ssh-askpass.nix
    ./services/amnezia-vpn.nix
    ./services/syncting.nix
    ./services/ollama.nix
    ./services/cachix.nix
    ./services/tor.nix
  ];

  system.stateVersion = "25.11";
  services.jupyter = {
    pythonPackages = with pkgs.python3Packages; [
      matplotlib
      pandas
      seaborn
      numpy
      sympy
      librosa

      scikit-learn
      transformers
      torch
      torchvision
      torchaudio

      pytesseract
      pymupdf
      python-docx
      striprtf
      openpyxl

      faker
      ipywidgets
    ];
  };

  services.ollama.package = pkgs.ollama-cpu;
}
