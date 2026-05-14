{ pkgs, ... }:

{
  programs.appimage.enable = true;
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  programs.zsh.enable = true;
  services.flatpak.enable = true;

  services.xserver.excludePackages = [ pkgs.xterm ];
}
