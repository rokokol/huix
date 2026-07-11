{ pkgs, ... }:

let
  # DDLC-тема для SDDM и курсор-голова Сайори — только для экрана логина,
  # в сессии остаётся Bibata (home-manager/desktop/theme/cursor.nix)
  ddlcTheme = pkgs.callPackage ./sddm-ddlc/theme-package.nix { };
  sayoriCursors = pkgs.callPackage ./sddm-ddlc/sayori-cursor.nix { };
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    wayland.compositor = "weston";
    theme = "ddlc";

    settings = {
      Theme = {
        CursorTheme = "sayori-cursors";
        CursorSize = 32;
      };
    };
  };

  environment.systemPackages = [
    ddlcTheme
    sayoriCursors
  ];
}
