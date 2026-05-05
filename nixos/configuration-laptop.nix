{ pkgs, ... }:

{
  imports = [
    ./default.nix
    ./laptop/default.nix
    ./services/services-laptop.nix
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
