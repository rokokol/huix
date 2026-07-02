{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.custom.packages;
in
{
  imports = [ ./packages-common.nix ];

  options.custom.packages = {
    pc = lib.mkEnableOption "пакеты рабочей станции (CUDA, тяжёлый десктоп, creative)";
    laptop = lib.mkEnableOption "пакеты ноутбука (подсветка, камера, энергия)";
  };

  config = lib.mkMerge [
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
          kdePackages.kdenlive
          krita
          solvespace
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
