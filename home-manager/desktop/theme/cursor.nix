# Sayori Cursor V2 — анимированная тема курсора в стиле DDLC
# Автор: sev (https://ko-fi.com/sevverae)
# Оригинал: https://ko-fi.com/s/8e05db90c4
{ pkgs, inputs, ... }:

let
  # Тема лежит в двух форматах сразу: cursors/ (XCursor) и hyprcursors/ (hyprcursor,
  # manifest.hl). Просто раскладываем её в share/icons — оба варианта нужны, см. ниже.
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
  cursorSize = 32;
in
{
  home.pointerCursor = {
    package = sayori-cursor;
    name = cursorName;
    size = cursorSize;

    # Три канала ниже — не дубли, они обслуживают РАЗНЫЕ группы приложений и
    # дополняют друг друга (стандартная связка для Hyprland):
    #
    #   x11        — XCURSOR_THEME/SIZE + ~/.icons/default. Универсальный XCursor-путь:
    #                XWayland-приложения и нативные Wayland на libwayland-cursor
    #                (GTK3/Tauon, старые тулкиты). Базовый, убирать нельзя.
    #   gtk        — gtk-cursor-theme-name/size в настройках GTK, чтобы GTK-приложения
    #                не откатывались на курсор Adwaita.
    #   hyprcursor — HYPRCURSOR_THEME/SIZE. Родной формат Hyprland: им компоситор рисует
    #                сам курсор и обслуживает cursor-shape-v1 клиентов (slurp и почти все
    #                современные Wayland-приложения). Самый чёткий путь на Hyprland.
    #
    # Нужен ли hyprcursor, если есть XCursor? Да: без него Hyprland рисовал бы курсор
    # из XCursor-варианта (сработает, но это фолбэк, не родной путь). XCursor при этом
    # тоже нельзя выкинуть — на нём держатся XWayland и легаси-приложения. Поэтому оба.
    x11.enable = true;
    gtk.enable = true;
    hyprcursor.enable = true;
  };
}
