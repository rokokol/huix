{
  config,
  pkgs,
  lib,
  ...
}:

let
  homeDir = config.users.users.rokokol.home;

  python-datascience = config.services.jupyter.pythonInterpreter.withPackages (
    ps:
    with ps;
    [
      ipykernel
    ]
    ++ config.services.jupyter.pythonPackages
  );
in
{
  options.services.jupyter = {
    pythonInterpreter = lib.mkOption {
      type = lib.types.package;
      default = pkgs.python3;
      description = "Python interpreter for Jupyter";
    };

    pythonPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional Python packages";
    };
  };

  config = {
    services.jupyter = {
      enable = true;
      user = "rokokol";
      group = "users";
      command = "jupyter-lab";
      notebookDir = "${homeDir}/Notebooks";
      password = "argon2:$argon2id$v=19$m=10240,t=10,p=8$QQIsyCtNwAb7GSPc4f/fsQ$dJMkGhSyoVxKje2lMomM8mD0Y62GROuZOF1IzZwbZwo";
      ip = "127.0.0.1";
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

    systemd.tmpfiles.rules = [
      "d ${homeDir}/Notebooks 0755 rokokol users -"
    ];
  };
}
