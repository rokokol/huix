{ pkgs, ... }:

{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    wayland.compositor = "weston";
    theme = "catppuccin-mocha-maroon";

    settings = {
      Theme = {
        CursorTheme = "catppuccin-mocha-maroon-cursors";
        CursorSize = 24;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    catppuccin-cursors.mochaMaroon
    (pkgs.catppuccin-sddm.override {
      flavor = "mocha";
      accent = "maroon";
    })
  ];
}
