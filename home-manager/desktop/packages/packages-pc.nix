{ pkgs, inputs, ... }:

{
  imports = [ ./packages-common.nix ];

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
      stable.discord
      vesktop
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
}
