{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:

let
  homeDir = "/home/${rokokolName}";

  cfg = config.rokokol.jupyter;

  pythonDatascience = pkgs.stable.python3.withPackages (
    ps:
    with ps;
    [
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
      tqdm
    ]
    # torch stack is a heavy CUDA build on the PC; keep it CPU-only (laptop)
    ++ lib.optionals cfg.withTorch [
      torch
      torchaudio
      torchvision
      transformers
    ]
  );
in
{
  options.rokokol.jupyter = {
    enable = lib.mkEnableOption "Custom Jupyter Server";
    withTorch = lib.mkEnableOption "torch/transformers stack in the Python kernel";
  };

  config = lib.mkIf cfg.enable {
    # jupyter runs as the login user, so the secret must be readable by them
    sops.secrets."jupyter-password".owner = rokokolName;

    services.jupyter = {
      enable = true;
      user = rokokolName;
      group = "users";
      command = "jupyter-lab";
      notebookDir = "${homeDir}/Notebooks";
      # The module emits this verbatim as c.ServerApp.password = "<value>", after notebookConfig,
      # so it cannot be overridden from there — closing the quote turns the assignment into a call
      # of the helper defined above. A store path is not an option: the secret must stay out of the
      # world-readable store
      password = ''" + _huix_password() + "'';
      ip = "127.0.0.1";
      port = 8888;

      notebookConfig = ''
        c.KernelSpecManager.ensure_native_kernel = False

        visible_kernels = {'pythondatascience', 'octave'}
        c.KernelSpecManager.allowed_kernelspecs = visible_kernels

        # Only the plaintext password is stored; hashing it here keeps one source of truth,
        # instead of a second sops entry that silently rots when the password is changed
        def _huix_password():
            from jupyter_server.auth import passwd
            with open("${config.sops.secrets."jupyter-password".path}") as f:
                return passwd(f.read().strip(), algorithm="argon2")
      '';

      kernels = {
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
