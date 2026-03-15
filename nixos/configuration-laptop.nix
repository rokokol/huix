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
    pythonPackages = with pkgs.python3Packages; [
      matplotlib
      pandas
      seaborn
      numpy
      sympy
      librosa

      scikit-learn
      transformers
      (torch-bin.override { cudaSupport = false; })
      (torchvision-bin.override { cudaSupport = false; })
      (torchaudio-bin.override { cudaSupport = false; })

      ipywidgets
    ];
  };
  services.ollama.package = pkgs.ollama-cpu;
}
