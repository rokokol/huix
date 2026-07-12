{ pkgs, inputs, ... }:

let
  ddlcTheme = pkgs.callPackage ./sddm-ddlc/theme-package.nix { inherit inputs; };
  sayoriCursors = pkgs.callPackage ./sddm-ddlc/sayori-cursor.nix { inherit inputs; };
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    wayland.compositor = "kwin";
    theme = "ddlc";

    settings = {
      # Greeter грузит тему по стабильному пути /run/current-system/…, а все
      # файлы в /nix/store имеют mtime=1970 → Qt-кэш QML считает тему
      # неизменной и отдаёт устаревший скомпилированный QML: правки не видны
      # на реальном логине (в test-mode путь уникальный — там всё свежее).
      # Отключаем дисковый кэш QML у greeter, он короткоживущий и кэш ему не нужен.
      General.GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell,QML_DISABLE_DISK_CACHE=1";

      Theme = {
        CursorTheme = "sayori-cursors";
        CursorSize = 32;
      };
    };
  };

  security.pam.services.login.nodelay = true;
  environment.systemPackages = [
    ddlcTheme
    sayoriCursors
  ];
}
