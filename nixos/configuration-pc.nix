{ pkgs, ... }:

let
  # to avoid transformers build
  myPython = pkgs.stable.python3.override {
    packageOverrides = _: super: {
      torch = super.torch-bin;
      torchvision = super.torchvision-bin;
      torchaudio = super.torchaudio-bin;
    };
  };
in
{
  imports = [
    ./default.nix
    ./pc/default.nix
    ./services/services-pc.nix
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

      pytesseract
      ipywidgets
    ];
  };
  services.ollama.package = pkgs.ollama-cuda;
}
