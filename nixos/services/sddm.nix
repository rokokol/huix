{ ... }:

{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    wayland.compositor = "kwin";
    theme = "catppuccin-mocha-maroon";
  };
}
