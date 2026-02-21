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
  ];

  system.stateVersion = "25.11";
  _module.args.pythonPackages = with pkgs.python3Packages; [
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
