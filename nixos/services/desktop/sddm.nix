{ pkgs, ... }:

{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    wayland.compositor = "kwin";
    theme = "catppuccin-mocha-maroon";

    settings = {
      Theme = {
        CursorTheme = "catppuccin-mocha-maroon-cursors";
        CursorSize = 24;
      };
    };
  };

  environment.variables = {
    KWIN_FORCE_SW_CURSOR = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  environment.systemPackages = with pkgs; [
    catppuccin-cursors.mochaMaroon
    (pkgs.catppuccin-sddm.override {
      flavor = "mocha";
      accent = "maroon";
    })
  ];
}
