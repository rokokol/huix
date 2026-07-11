{ config, huixDir, ... }:

# DDLC-локскрин. Фон — картинка, не скриншот: скриншотный фон ловит кадр с
# уже применённым screen_shader, и компоситор прогоняет его через шейдер
# второй раз (эффект и софт-яркость удваиваются).
#
# Диалог (бокс + имя + реплика) — один PNG, который целиком рендерит
# scripts/hyprlock-quote.sh ImageMagick'ом: настоящая обводка и пиксельная
# вёрстка, недостижимые для label (у него нет ни stroke, ни ширины).
# image-виджет опрашивает скрипт раз в секунду (reload_time — целые секунды,
# минимум 1; reload_cmd синхронный, поэтому скрипт лишь печатает путь, а
# рендер уходит в фон). Путь к кадру стабилен и захардкожен в скрипте —
# hyprlock перечитывает его по mtime. Все пути — через huixDir (живой
# репозиторий, ничего не печётся на сборке).
let
  backgroundImage = "${huixDir}/assets/just_monika.png";
  quoteScript = "${huixDir}/scripts/hyprlock-quote.sh";
  dialogFrame = "${config.xdg.cacheHome}/huix/hyprlock-dialog.png";
in
{
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
          path = backgroundImage;
          color = "rgb(2a1a2e)"; # запасной цвет
        }
      ];

      # Кадр диалога; size = меньшая сторона картинки (высота бокса).
      image = [
        {
          monitor = "";
          path = dialogFrame;
          reload_time = 1;
          reload_cmd = "${quoteScript} frame";
          size = 280;
          rounding = 0;
          border_size = 0;
          position = "0, 30";
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
          shadow_color = "rgba(bf936edd)"; # тёплый медно-бежевый из фона
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
          shadow_color = "rgba(9f543caa)"; # тёмно-оранжевый из фона
          position = "0, -250";
          halign = "center";
          valign = "top";
        }
        # Раскладка справа от поля ввода ($LAYOUT обновляется сам)
        {
          monitor = "";
          text = "$LAYOUT[EN,RU]";
          font_family = "Doki";
          font_size = 20;
          color = "rgba(ffffffdd)";
          shadow_passes = 2;
          shadow_size = 3;
          shadow_color = "rgba(e2679baa)";
          position = "260, -20";
          halign = "center";
          valign = "center";
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
          placeholder_text = "<i>Дай мне пароль...</i>";
          fail_text = "Это не то... ($ATTEMPTS)";
          # проверка пароля подсвечивается тем же красным, что и ошибка
          check_color = "rgb(d64d7a)";
          fail_color = "rgb(d64d7a)";
          capslock_color = "rgb(ffb347)";
          dots_text_format = "♥";
          dots_spacing = 0.2;
          fade_on_empty = false;
          position = "0, -20";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
