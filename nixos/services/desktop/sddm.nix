{ pkgs, inputs, ... }:

let
  # DDLC-тема для SDDM и курсор-голова Сайори — только для экрана логина,
  # в сессии остаётся Bibata (home-manager/desktop/theme/cursor.nix)
  # inputs пробрасываем, чтобы модули брали ассеты через ${inputs.self}
  ddlcTheme = pkgs.callPackage ./sddm-ddlc/theme-package.nix { inherit inputs; };
  sayoriCursors = pkgs.callPackage ./sddm-ddlc/sayori-cursor.nix { inherit inputs; };
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    # weston не рисует курсор greeter'а на части железа (в т.ч. на ноуте) —
    # kwin_wayland рисует его надёжно. Это только композитор для экрана
    # логина, а не весь KDE
    wayland.compositor = "kwin";
    theme = "ddlc";

    # DotsBackground использует QtQuick.Shapes, а глитч/сшакаливание —
    # QtQuick.Effects. В дефолтном QML-пути greeter'а этих модулей нет
    # (стандартным темам они не нужны), поэтому докидываем qtdeclarative —
    # иначе тема падает с «module QtQuick.Shapes is not installed»
    extraPackages = [ pkgs.qt6.qtdeclarative ];

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
