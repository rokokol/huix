{ pkgs, ... }:

let
  # to avoid transformers build
  myPython = pkgs.cuda.python3.override {
    packageOverrides = _: super: {
      torch = super.torch-bin;
      torchvision = super.torchvision-bin;
      torchaudio = super.torchaudio-bin;
    };
  };
in
{
  imports = [
    ./fonts/fonts.nix
    ./pc/hardware-configuration.nix
    ./pc/boot.nix
    ./pc/nvidia.nix
    ./pc/system.nix
    ./pc/hardware.nix
    ./pc/sound.nix
    ./pc/desktop.nix
    ./pc/packages.nix
    ./services/docker.nix
    ./services/jupyter.nix
    ./services/virtualization.nix
    ./services/searxng.nix
    ./services/wl-clip-persist.nix
    ./services/sddm.nix
    ./services/tablet.nix
    ./services/printing.nix
    ./services/keys.nix
    ./services/cachix.nix
    ./services/arduino.nix
    ./services/nix-ld.nix
    ./services/amnezia-vpn.nix
    ./services/ollama.nix
    ./services/openwebui.nix
    ./services/syncting.nix
  ];

  system.stateVersion = "25.11";
  services.jupyter = {
    pythonInterpreter = myPython;
    pythonPackages = with myPython.pkgs; [
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
  services.ollama.package = pkgs.ollama-cuda;
}
