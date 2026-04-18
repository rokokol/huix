{
  pkgs,
  inputs,
  ...
}:

{
  home.packages =
    with pkgs;
    [
      # --- CLI & system tools ---
      appimage-run
      fastfetch
      gdu
      ncdu
      nvtopPackages.nvidia
      trash-cli
      unzip

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

      # --- Communication & web ---
      ayugram-desktop
      obsidian
      vesktop
      tor-browser

      # --- Desktop apps ---
      vial

      # --- Creative & audio ---
      aseprite
      cuda.darktable
      gimp2-with-plugins
      gimpPlugins.gmic
      kdePackages.kdenlive
      cuda.obs-studio
      easyeffects
      krita
      solvespace
    ]
    ++ (with inputs; [
      freesmlauncher.packages.${pkgs.stdenv.hostPlatform.system}.default
    ]);
}
