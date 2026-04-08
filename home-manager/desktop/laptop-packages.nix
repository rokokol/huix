{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # --- Utilities ---
    brightnessctl
    fastfetch

    # --- Communication & web ---
    ayugram-desktop
    obsidian

    # --- Desktop apps ---
    cheese

    # --- Creative & study ---
    obs-studio
    octaveFull
  ];
}
