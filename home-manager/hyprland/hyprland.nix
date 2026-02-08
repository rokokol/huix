{ ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = ''
      source = /home/rokokol/huix/home-manager/hyprland/hyprland.conf
    '';
  };
}
