{ pkgs, huixDir, ... }:

# Экран блокировки в стиле DDLC. Фон — статичная картинка (не скриншот:
# скриншотный фон hyprlock захватывает кадр с уже применённым screen_shader,
# после чего компоситор прогоняет поверхность hyprlock через тот же шейдер
# ещё раз — эффект и софт-яркость удваиваются).
#
# Макет: фон just_monika.png, внизу — диалоговое окно из PNG-ассета с плашкой
# Monika и её репликами (scripts/hyprlock-quote.sh: экспоненциальные паузы
# λ=1/60, глитч текста при неправильном пароле). Часы сверху, поле пароля
# по центру. Появление плавное (fadeIn).
let
  assetsDir = ../../../../assets/ddlc-stickers;
  backgroundImage = ../../../../assets/just_monika.png;

  # Диалоговое окно: оригинал 1280x720 RGBA (сам бокс внизу, остальное —
  # прозрачность). Вырезаем непрозрачную область (trim) и масштабируем под
  # ширину диалога. PNG уже содержит name plate и полоску меню.
  dialogBox =
    pkgs.runCommand "hyprlock-ddlc-dialog.png" { nativeBuildInputs = [ pkgs.imagemagick ]; }
      ''
        magick ${assetsDir}/dialog_box.png -trim +repage -resize "1400x" "$out"
      '';

  # Сторожок: если hyprlock умер, не сняв лок (краш), Hyprland оставляет
  # сессию залоченной «красным экраном», и без tty её не спасти. Ненулевой
  # выход hyprlock = краш → перезапускаем (allow_session_lock_restore в
  # hyprland.conf разрешает новому инстансу перехватить лок); нормальный
  # unlock = выход 0 → цикл завершается.
  hyprlockGuard = pkgs.writeShellScriptBin "hyprlock-guard" ''
    while ! hyprlock "$@"; do
      sleep 1
    done
  '';
in
{
  home.packages = [
    hyprlockGuard # лок дёргает hypridle (lock_cmd)
  ];

  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };

      # Плавное появление локскрина.
      animations = {
        enabled = true;
        bezier = "linear, 1, 1, 0, 0";
        animation = [
          "fadeIn, 1, 6, linear"
          "fadeOut, 1, 3, linear"
        ];
      };

      background = [
        {
          monitor = "";
          path = "${backgroundImage}";
          color = "rgb(2a1a2e)"; # запасной цвет
        }
      ];

      # Диалоговое окно (PNG-ассет из DDLC, содержит плашку и меню)
      image = [
        {
          monitor = "";
          path = "${dialogBox}";
          size = 280;
          rounding = 0;
          border_size = 0;
          zindex = 1;
          position = "0, 10";
          halign = "center";
          valign = "bottom";
        }
      ];

      label = [
        # Часы
        {
          monitor = "";
          text = "$TIME";
          font_family = "Doki";
          font_size = 150;
          color = "rgba(ffffffff)";
          shadow_passes = 3;
          shadow_size = 6;
          shadow_color = "rgba(ff64a6dd)";
          position = "0, -70";
          halign = "center";
          valign = "top";
        }
        # Дата
        {
          monitor = "";
          text = ''cmd[update:60000] date +"%A, %B %-d"'';
          font_family = "Doki";
          font_size = 30;
          color = "rgba(ffffffe6)";
          shadow_passes = 2;
          shadow_size = 3;
          shadow_color = "rgba(e2679baa)";
          position = "0, -250";
          halign = "center";
          valign = "top";
        }
        # Имя на плашке диалогового окна — белый текст с розовой обводкой
        {
          monitor = "";
          text = "Monika";
          font_family = "Doki";
          font_size = 26;
          color = "rgba(ffffffff)";
          shadow_passes = 3;
          shadow_size = 4;
          shadow_color = "rgba(ff7fbfff)";
          zindex = 2;
          position = "-480, 280";
          halign = "center";
          valign = "bottom";
        }
        # Реплика в диалоговом окне — белый текст с чёрной обводкой.
        # Скрипт поллится ежесекундно, но реплику меняет сам — по
        # экспоненциальной паузе (λ=1/60). Глитч текста при неправильном
        # пароле (определяется через faillock).
        {
          monitor = "";
          text = "cmd[update:1000] ${huixDir}/scripts/hyprlock-quote.sh";
          font_family = "Doki";
          font_size = 28;
          color = "rgba(ffffffff)";
          shadow_passes = 3;
          shadow_size = 4;
          shadow_color = "rgba(000000ff)";
          text_align = "center";
          zindex = 2;
          position = "0, 120";
          halign = "center";
          valign = "bottom";
        }
      ];

      "input-field" = [
        {
          monitor = "";
          size = "380, 64";
          outline_thickness = 4;
          rounding = 22;
          outer_color = "rgb(ff7fbf)";
          inner_color = "rgb(ffffff)";
          font_color = "rgb(b3487f)";
          font_family = "Doki";
          placeholder_text = "<i>Скажи что-нибудь милое...</i>";
          fail_text = "Это не то... ($ATTEMPTS)";
          check_color = "rgb(6cbf6c)";
          fail_color = "rgb(d64d7a)";
          capslock_color = "rgb(ffb347)";
          dots_text_format = "♥";
          dots_spacing = 0.2;
          fade_on_empty = false;
          zindex = 1;
          position = "0, -20";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
