{ config, pkgs, ... }:

let
  homeDir = config.users.users.rokokol.home;

  python-datascience = pkgs.python3.withPackages (
    ps: with ps; [
      ipykernel

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
    ]
  );
in
{

  services.jupyter = {
    enable = true;
    user = "rokokol";
    group = "users";
    command = "jupyter-lab";
    notebookDir = "${homeDir}/Notebooks";
    password = "argon2:$argon2id$v=19$m=10240,t=10,p=8$QQIsyCtNwAb7GSPc4f/fsQ$dJMkGhSyoVxKje2lMomM8mD0Y62GROuZOF1IzZwbZwo";
    ip = "0.0.0.0";
    port = 8888;

    notebookConfig = ''
      c.KernelSpecManager.ensure_native_kernel = False

      visible_kernels = {'python-datascience', 'octave'}
      c.KernelSpecManager.whitelist = visible_kernels
    '';

    kernels = {
      # clojure = pkgs.clojupyter.definition;

      octave = pkgs.octave-kernel.definition;

      python-datascience = {
        displayName = "Python (Data Science)";
        argv = [
          "${python-datascience.interpreter}"
          "-m"
          "ipykernel_launcher"
          "-f"
          "{connection_file}"
        ];
        language = "python";
        logo32 = "${python-datascience}/${python-datascience.sitePackages}/ipykernel/resources/logo-32x32.png";
        logo64 = "${python-datascience}/${python-datascience.sitePackages}/ipykernel/resources/logo-64x64.png";
      };
    };
  };

  systemd.services.jupyter.path = with pkgs; [
    octave
    gnuplot
    ghostscript
  ];

  networking.firewall.allowedTCPPorts = [ 8888 ];
  systemd.tmpfiles.rules = [
    "d ${homeDir}/Notebooks 0755 rokokol users -"
  ];
}
