# Sayori Cursor V2 — анимированная тема курсора в стиле DDLC
# Автор: sev (https://ko-fi.com/sevverae)
# Оригинал: https://ko-fi.com/s/8e05db90c4
{ pkgs, inputs, ... }:

let
  sayori-cursor = pkgs.stdenv.mkDerivation {
    name = "sayori-cursor-v2";
    src = "${inputs.self}/assets/sayori-cursor-v2";
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/share/icons/Sayori-Cursor-V2
      cp -a $src/* $out/share/icons/Sayori-Cursor-V2/
    '';
  };

  cursorName = "Sayori-Cursor-V2";
  # В теме запечён единственный размер — 32px (12 кадров анимации). Любой другой
  # размер вынуждает рендереры масштабировать: компоситор рисует уменьшенную
  # анимацию, а часть клиентов/XWayland грузит нативный 32-й кадр без анимации —
  # отсюда разнобой «где-то маленький анимированный, где-то статичный нормальный».
  # Ставим нативные 32: точное совпадение размера у всех, полная анимация везде.
  cursorSize = 32;
in
{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = sayori-cursor;
    name = cursorName;
    size = cursorSize;
  };

  # Курсор дублируем в dconf, чтобы приложения через dconf-мост (а не только
  # settings.ini) запрашивали тот же нативный размер темы Sayori — иначе часть
  # из них берёт дефолтный размер и рассинхронивается по размеру/анимации.
  dconf.settings."org/gnome/desktop/interface" = {
    cursor-theme = cursorName;
    cursor-size = cursorSize;
  };
}
