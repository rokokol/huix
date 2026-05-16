{ pkgs, inputs, ... }:

let
  vesktopWithPipewire = pkgs.symlinkJoin {
    name = "vesktop-with-pipewire";
    paths = [ pkgs.vesktop ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm $out/bin/vesktop
      makeWrapper ${pkgs.vesktop}/bin/vesktop $out/bin/vesktop \
        --add-flags "--ozone-platform=wayland" \
        --add-flags "--enable-features=WebRTCPipeWireCapturer,WaylandWindowDecorations"
    '';
  };
in
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
      vesktopWithPipewire
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
