{ pkgs, inputs, ... }:

{
  home.packages =
    with pkgs;
    [
      # --- CLI & system tools ---
      cuda.appimage-run
      cuda.fastfetch
      gdu
      ncdu
      nvtopPackages.nvidia
      trash-cli
      unzip
      yt-dlp

      # --- Development ---
      # C++
      cmake
      eigen
      gcc
      llvmPackages.openmp
      openmpi
      pkg-config

      # Python
      cuda.uv
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
      cuda.ayugram-desktop
      cuda.obsidian
      cuda.vesktop
      tor-browser

      # --- Desktop apps ---
      antigravity-fhs
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
