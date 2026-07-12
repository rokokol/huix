# Sayori Cursor V2 — анимированная тема курсора в стиле DDLC
# Автор: sev (https://ko-fi.com/sevverae)
# Оригинал: https://ko-fi.com/s/8e05db90c4
#
# Тема двухформатная: xcursor (index.theme + cursors/) И hyprcursor
# (manifest.hl + hyprcursors/) в одном каталоге assets/sayori-cursor-v2.
# Hyprcursor-часть сгенерена из xcursor-темы (hyprcursor-util --extract|--create,
# кадры и хотспоты сохранены) и закоммичена как ассет — деривация ничего не
# генерит, просто копирует оба формата.
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
  # В теме запечён единственный размер — 32px (12 кадров анимации). Другой размер
  # вынуждал бы рендереры масштабировать; ставим нативные 32 — точное совпадение
  # размера везде.
  cursorSize = 32;
in
{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    # Hyprland (и клиенты через cursor-shape-v1: часть Qt/GTK4/Chromium, XWayland)
    # предпочитает hyprcursor-формат. Без него эти курсоры Hyprland отдаёт статичным
    # фолбэком, тогда как xcursor-приложения анимируются — отсюда «часть статичная».
    # Включаем hyprcursor-тему (выставляет HYPRCURSOR_THEME/SIZE) → анимация везде.
    hyprcursor = {
      enable = true;
      size = cursorSize;
    };
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
