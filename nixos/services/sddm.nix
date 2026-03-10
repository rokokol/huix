{ ... }:

{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    wayland.compositor = "kwin";
    theme = "catppuccin-mocha-maroon";
  };

  environment.variables = {
    KWIN_FORCE_SW_CURSOR = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
