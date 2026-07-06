{
  config,
  lib,
  pkgs,
  inputs,
  huixDir,
  ...
}:

let
  cfg = config.custom.packages;
in
{
  imports = [ ./mime-apps.nix ];

  options.custom.packages = {
    pc = lib.mkEnableOption "пакеты рабочей станции (CUDA, тяжёлый десктоп, creative)";
    laptop = lib.mkEnableOption "пакеты ноутбука (подсветка, камера, энергия)";
  };

  config = lib.mkMerge [
    # --- Общие для обоих хостов ---
    {
      home.packages = with pkgs; [
        # --- Common desktop apps ---
        ayugram-desktop
        baobab
        claude-desktop
        celluloid
        evince
        file-roller
        freecad
        gnome-disk-utility
        gnome-text-editor
        obsidian
        super-productivity
        tauon

        # --- CLI ---
        antigravity-cli
        claude-code
        codex
        curl
        exiftool
        fastfetch
        file
        gthumb
        imagemagick
        jq
        killall
        lazygit
        libreoffice-fresh
        matlab
        pup
        python3Packages.huggingface-hub
        ripgrep
        texlive.combined.scheme-full
        tree
        unzip
        usbutils
        wget

        # Python
        (python313.withPackages (
          ps: with ps; [
            matplotlib
            numpy
            pandas
            requests
            rich
            scipy
            sympy
            tqdm
          ]
        ))
        uv
      ];

      home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
        TERMINAL = "kitty";
        HUIX = huixDir;
        NIXOS_OZONE_WL = "1";
      };

      home.file.".config/matlab/nix.sh".text = ''
        INSTALL_DIR=$HOME/MATLAB2025a/
      '';
    }

    (lib.mkIf cfg.pc {
      home.packages =
        with pkgs;
        [
          # --- CLI & system tools ---
          cuda.ffmpeg-headless
          nvtopPackages.nvidia

          # --- Development ---
          # C++
          cmake
          eigen
          gcc
          llvmPackages.openmp
          openmpi
          pkg-config

          # Web
          nodejs

          # --- Desktop apps ---
          (bambu-studio.override { withNvidiaGLWorkaround = true; })
          stable.discord
          vial

          # --- Creative & audio ---
          aseprite
          cuda.darktable
          cuda.obs-studio
          easyeffects
          stable.gimp
          stable.gimpPlugins.gmic
          krita
        ]
        ++ (with inputs; [
          freesmlauncher.packages.${pkgs.stdenv.hostPlatform.system}.default
        ]);
    })

    (lib.mkIf cfg.laptop {
      home.packages = with pkgs; [
        brightnessctl
        cheese
        obs-studio
        powertop
      ];
    })
  ];
}
