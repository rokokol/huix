{
  config,
  lib,
  pkgs,
  huixDir,
  inputs,
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
        # IfcOpenShell fails against Boost 1.91; see WORKAROUNDS.md
        stable.freecad
        geary
        gnome-disk-utility
        gnome-text-editor
        obs-studio
        obsidian
        super-productivity
        tauon

        # --- CLI ---
        curl
        dig
        exiftool
        fastfetch
        file
        gthumb
        imagemagick
        jq
        killall
        lazygit
        libreoffice-stable
        matlab
        pup
        python3Packages.huggingface-hub
        ripgrep
        shellcheck
        shfmt
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
            pyyaml
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
          # Keep the NVIDIA-only wrapper separate so the main build remains substitutable; see WORKAROUNDS.md
          (symlinkJoin {
            name = "bambu-studio-nvidia";
            paths = [ bambu-studio ];
            nativeBuildInputs = [ makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/bambu-studio \
                --set __GLX_VENDOR_LIBRARY_NAME mesa \
                --set __EGL_VENDOR_LIBRARY_FILENAMES /run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json \
                --set MESA_LOADER_DRIVER_OVERRIDE zink \
                --set GALLIUM_DRIVER zink
            '';
          })
          stable.discord
          jan # local LLM chat client (Ollama frontend, KaTeX)
          vial
          feather

          # --- Creative & audio ---
          stable.aseprite
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
