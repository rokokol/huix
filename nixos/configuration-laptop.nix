{ pkgs, ... }:

{
  imports = [
    ./fonts/fonts.nix
    ./laptop/hardware-configuration.nix
    ./laptop/boot.nix
    ./laptop/desktop.nix
    ./laptop/hardware.nix
    ./laptop/packages.nix
    ./laptop/system.nix
    ./services/wl-clip-persist.nix
    ./services/sddm.nix
    ./services/jupyter.nix
    ./services/keys.nix
    ./services/amnezia-vpn.nix
    ./services/syncting.nix
    ./services/ollama.nix
  ];

  system.stateVersion = "25.11";
  services.jupyter = {
    pythonPackages = with pkgs; [
      matplotlib
      pandas
      seaborn
      numpy
      sympy
      librosa

      scikit-learn
      transformers
      torch-bin
      torchvision-bin
      torchaudio-bin

      ipywidgets
    ];
  };
  services.ollama.package = pkgs.ollama-cpu;
}
