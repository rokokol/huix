{ pkgs, ... }:

{
  # AppImage support (programs.appimage.* incl. binfmt) lives in
  # nixos/services/system/appimage.nix — single source of truth
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  programs.zsh.enable = true;
  services.flatpak.enable = true;

  # The agent that answers these prompts is hyprpolkitagent, started from hyprland.lua
  security.polkit.enable = true;

  services.xserver.excludePackages = with pkgs; [ xterm ];
}
