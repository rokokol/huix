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

  # Программный курсор на экране логина: грубер SDDM работает на KWin, а на NVIDIA
  # аппаратный курсор под Wayland глючит. (WLR_NO_HARDWARE_CURSORS убрана — она от
  # wlroots, а ни KWin, ни Hyprland 0.55/Aquamarine её не читают.)
  environment.variables = {
    KWIN_FORCE_SW_CURSOR = "1";
  };

  environment.systemPackages = with pkgs; [
    catppuccin-cursors.mochaMaroon
    (pkgs.catppuccin-sddm.override {
      flavor = "mocha";
      accent = "maroon";
    })
  ];
}
