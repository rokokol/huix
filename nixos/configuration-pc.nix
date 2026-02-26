{ pkgs, ... }:

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
  ];

  system.stateVersion = "25.11";
  _module.args.pythonPackages = with pkgs.cuda.python3Packages; [
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
  ];
}
