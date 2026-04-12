{ pkgs, inputs, ... }:

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

      # Python
      uv
      (cuda.python313.withPackages (
        ps: with ps; [
          matplotlib
          numpy
          pandas
          scipy
          seaborn
          sympy
        ]
      ))

      # MATLAB & Octave
      matlab
      (pkgs.symlinkJoin {
        name = "octave-wrapped";
        paths = [ pkgs.octaveFull ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/octave --set QT_QPA_PLATFORM xcb
        '';
      })

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
      cuda.gimp2-with-plugins
      cuda.gimpPlugins.gmic
      cuda.kdePackages.kdenlive
      cuda.obs-studio
      easyeffects
      krita
      solvespace
    ]
    ++ (with inputs; [
      freesmlauncher.packages.${pkgs.stdenv.hostPlatform.system}.default
    ]);
}
