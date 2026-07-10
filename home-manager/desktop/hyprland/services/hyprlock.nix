{ pkgs, huixDir, ... }:

# DDLC-локскрин. Фон — картинка, не скриншот: скриншотный фон ловит кадр с
# уже применённым screen_shader, и компоситор прогоняет его через шейдер
# второй раз (эффект и софт-яркость удваиваются).
#
# Диалог = статичный PNG-бокс + два label'а поверх (имя и реплики), оба
# рисует scripts/hyprlock-quote.sh. Именно label, а не текст в PNG:
# image-виджет hyprlock перезагружается максимум раз в секунду и ждёт
# reload_cmd синхронно, а label обновляется в мс и асинхронно — только так
# возможна побуквенная печать. Вся геометрия — производные от размеров
# игрового ассета (src ниже), таблица ширин глифов для пиксельного переноса
# строк собирается на этапе сборки.
let
  # Рантайм-пути — через huixDir (живой репозиторий). Входы деривации ниже
  # обязаны быть nix-путями (копируются в стор на этапе сборки), поэтому
  # для них — корень репо путём; huixDir-строка туда не годится.
  huixSrc = ../../../..;
  backgroundImage = "${huixDir}/assets/just_monika.png";
  dialogAsset = huixSrc + "/assets/ddlc-stickers/dialog_box.png";
  dokiFont = huixSrc + "/nixos/fonts/doki.otf";

  # Исходник бокса после trim+2x (см. dialogAssets) и его внутренности, px.
  src = {
    w = 1632;
    h = 370;
    insetX = 100; # поля текстовой области слева/справа
    menuH = 70; # полоска меню по низу бокса
    plateCx = 236; # центр плашки имени
    plateCy = 38;
  };

  boxH = 280; # высота бокса на экране; остальное — производные
  bottom = 30; # отступ бокса от низа экрана
  scale = boxH / (1.0 * src.h);
  px = v: builtins.floor (v * scale + 0.5);

  textW = px (src.w - 2 * src.insetX); # ширина текстовой области
  quoteY = bottom + px src.menuH + 6; # низ лейбла реплики (над меню)
  nameX = px (src.plateCx - src.w / 2); # центр плашки от центра экрана
  nameY = bottom + px (src.h - src.plateCy) - 18; # низ лейбла имени

  # Бокс (trim прозрачных полей, 2x для чёткости) + таблица ширин глифов
  # Doki при кегле 24pt (32px @ 96dpi — так pango hyprlock его и рендерит):
  # advance(c) = width("x"+c+"x") - width("xx").
  dialogAssets =
    pkgs.runCommand "hyprlock-ddlc-assets" { nativeBuildInputs = [ pkgs.imagemagick ]; }
      ''
        mkdir -p "$out"
        magick ${dialogAsset} -trim +repage -resize 200% "$out/box.png"

        xx=$(magick -background none -font ${dokiFont} -pointsize 32 \
          label:"xx" -format "%w" info:)
        for i in $(seq 32 126); do
          c=$(printf "\\$(printf '%03o' "$i")")
          case "$c" in
            '%') s="x%%x" ;;
            '\\') s="x\\\\x" ;;
            *) s="x''${c}x" ;;
          esac
          w=$(magick -background none -font ${dokiFont} -pointsize 32 \
            label:"$s" -format "%w" info:)
          printf '%s %s\n' "$c" "$((w - xx))" >>"$out/advances.txt"
        done
      '';

  quoteScript = "${huixDir}/scripts/hyprlock-quote.sh";
in
{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
        # cmd-лейблы отдают кадры с ведущими переносами строк (пустой бокс)
        # — обрезка схлопнула бы высоту текстуры и текст прыгал бы.
        text_trim = false;
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

      # Бокс диалога — статичный, текст живёт в лейблах поверх.
      image = [
        {
          monitor = "";
          path = "${dialogAssets}/box.png";
          size = boxH;
          rounding = 0;
          border_size = 0;
          zindex = 0; # сортировка по zindex нестабильная — фиксируем явно
          position = "0, ${toString bottom}";
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
        # Дата (tr -d: text_trim выключен, хвостовой \n стал бы второй строкой)
        {
          monitor = "";
          text = ''cmd[update:60000] date +"%A, %B %-d" | tr -d '\n' '';
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
        # Имя на плашке: отдельный лейбл (не впечён в PNG), чтобы глитчиться
        # вместе с текстом. Розовая «обводка» — тень.
        {
          monitor = "";
          text = "cmd[update:1000] ${quoteScript} name";
          font_family = "Doki";
          font_size = 26;
          color = "rgba(ffffffff)";
          shadow_passes = 3;
          shadow_size = 3;
          shadow_boost = 1.6;
          shadow_color = "rgba(e2679bff)";
          zindex = 2;
          position = "${toString nameX}, ${toString nameY}";
          halign = "center";
          valign = "bottom";
        }
        # Реплика: скрипт держит размер текстуры постоянным (невидимая
        # линейка шириной textW + добивка до 3 строк), поэтому halign center
        # + valign bottom дают прибитый левый верх текста ровно у поля
        # текстовой области. Чёрная «обводка» — тень. Опрос 33 мс = плавная
        # печать ~1 символ/кадр при CPS=30 (тёплый тик скрипта ~10 мс).
        {
          monitor = "";
          text = "cmd[update:33] TEXT_W=${toString textW} ADVANCES=${dialogAssets}/advances.txt ${quoteScript} frame";
          font_family = "Doki";
          font_size = 24;
          color = "rgba(ffffffff)";
          shadow_passes = 4;
          shadow_size = 2;
          shadow_boost = 1.6;
          shadow_color = "rgba(000000ff)";
          text_align = "left";
          zindex = 1; # поверх бокса
          position = "0, ${toString quoteY}";
          halign = "center";
          valign = "bottom";
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
