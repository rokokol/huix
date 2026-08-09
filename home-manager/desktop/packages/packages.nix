{
  config,
  lib,
  pkgs,
  inputs,
  huixDir,
  ...
}:

let
  cfg = config.rokokol.packages;
in
{
  imports = [ ./mime-apps.nix ];

  options.rokokol.packages = {
    pc = lib.mkEnableOption "workstation packages (CUDA, heavy desktop, creative)";
    laptop = lib.mkEnableOption "laptop packages (backlight, camera, power)";
  };

  config = lib.mkMerge [
    # --- Shared by both hosts ---
    {
      home.packages = with pkgs; [
        # --- Common desktop apps ---
        ayugram-desktop
        baobab
        celluloid
        chromium
        evince
        freecad
        gnome-disk-utility
        gnome-text-editor
        obs-studio
        obsidian
        super-productivity
        tauon

        # --- CLI ---
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
        texliveFull
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

      # MATLAB may re-create this autostart entry; Hidden=true makes dex skip it,
      # force overwrites whatever MATLAB left instead of failing on a .bak collision
      home.file.".config/autostart/mathworks-service-host.desktop" = {
        force = true;
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Mathworks Service Host
          Hidden=true
        '';
      };
    }

    (lib.mkIf cfg.pc {
      home.packages =
        with pkgs;
        [
          # --- CLI & system tools ---
          # NVENC/NVDEC work in stock ffmpeg (nv-codec-headers included);
          # cudaSupport is only needed for CUDA filters (scale_cuda etc.)
          ffmpeg-headless
          nvtopPackages.nvidia

          # --- Development ---
          # C++
          cmake
          eigen
          gcc
          llvmPackages.openmp
          pkg-config

          # Web
          nodejs

          # --- Desktop apps ---
          (bambu-studio.override { withNvidiaGLWorkaround = true; })
          stable.discord
          jan # local LLM chat client (Ollama frontend, KaTeX)
          vial

          # --- Creative & audio ---
          aseprite
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
        powertop
      ];
    })
  ];
}
