{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:

let
  homeDir = "/home/${rokokolName}";

  cfg = config.custom.jupyter;

  # чтобы не собирать transformers
  # внезапно, у него есть поддержка cuda
  myPython =
    if cfg.withCuda then
      pkgs.stable.python3.override {
        packageOverrides = _: super: {
          torch = super.torch-bin;
          torchvision = super.torchvision-bin;
          torchaudio = super.torchaudio-bin;
        };
      }
    else
      pkgs.stable.python3;

  pythonDatascience = myPython.withPackages (
    ps: with ps; [
      ipykernel
      ipywidgets
      librosa
      matplotlib
      numpy
      pandas
      pytesseract
      scikit-learn
      seaborn
      sympy
      torch
      torchaudio
      torchvision
      tqdm
      transformers
    ]
  );
in
{
  options.custom.jupyter = {
    enable = lib.mkEnableOption "Custom Jupyter Server";
    withCuda = lib.mkEnableOption "CUDA support for Jupyter Python Kernel";
  };

  config = lib.mkIf cfg.enable {
    services.jupyter = {
      enable = true;
      user = rokokolName;
      group = "users";
      command = "jupyter-lab";
      notebookDir = "${homeDir}/Notebooks";
      password = "argon2:$argon2id$v=19$m=10240,t=10,p=8$QQIsyCtNwAb7GSPc4f/fsQ$dJMkGhSyoVxKje2lMomM8mD0Y62GROuZOF1IzZwbZwo";
      ip = "127.0.0.1";
      port = 8888;

      notebookConfig = ''
        c.KernelSpecManager.ensure_native_kernel = False

        visible_kernels = {'pythondatascience', 'octave'}
        c.KernelSpecManager.allowed_kernelspecs = visible_kernels
      '';

      kernels = {
        # clojure = pkgs.clojupyter.definition;

        octave = pkgs.octave-kernel.definition;

        pythondatascience = {
          displayName = "Python (Data Science)";
          argv = [
            "${pythonDatascience.interpreter}"
            "-m"
            "ipykernel_launcher"
            "-f"
            "{connection_file}"
          ];
          language = "python";
          logo32 = "${pythonDatascience}/${pythonDatascience.sitePackages}/ipykernel/resources/logo-32x32.png";
          logo64 = "${pythonDatascience}/${pythonDatascience.sitePackages}/ipykernel/resources/logo-64x64.png";
        };
      };
    };

    systemd.services.jupyter.path = with pkgs; [
      ghostscript
      gnuplot
      octave
    ];

    systemd.tmpfiles.rules = [
      "d ${homeDir}/Notebooks 0755 ${rokokolName} users -"
    ];
  };
}
