{ huixDir, ... }:

# DDLC-локскрин. Фон — картинка, не скриншот: скриншотный фон ловит кадр с
# уже применённым screen_shader, и компоситор прогоняет его через шейдер
# второй раз (эффект и софт-яркость удваиваются).
#
# Диалог = игровой PNG-бокс как есть + два label'а поверх (имя и реплики),
# оба рисует scripts/hyprlock-quote.sh. Именно label, а не текст в PNG:
# image-виджет hyprlock перезагружается максимум раз в секунду и ждёт
# reload_cmd синхронно, а label обновляется в мс и асинхронно — только так
# возможна побуквенная печать. Скрипт держит размер текстуры реплики
# постоянным (вся реплика рендерится сразу, ненапечатанный хвост прозрачен —
# приём Ren'Py), поэтому текст прибит к левому верху текстовой области без
# измерений шрифта. Все пути — через huixDir (живой репозиторий, ничего не
# печётся на сборке); геометрия — производные от размеров ассета (src ниже).
let
  backgroundImage = "${huixDir}/assets/just-monika.png";
  dialogAsset = "${huixDir}/assets/ddlc-stickers/dialog-box.png";
  quoteScript = "${huixDir}/scripts/hyprlock-quote.sh";

  # Геометрия ассета: холст 1280x720, видимый бокс на нём (по x центрирован,
  # снизу прозрачный хвост) и его внутренности, px холста.
  src = {
    w = 1280;
    h = 720;
    boxY = 527; # верх бокса на холсте
    boxW = 816;
    boxH = 185;
    insetX = 40; # поля текстовой области внутри бокса
    menuH = 35; # полоска меню по низу бокса
    plateCx = 118; # центр плашки имени от левого верха бокса
    plateCy = 19;
  };

  boxH = 280; # высота бокса на экране; остальное — производные
  bottom = 30; # отступ бокса от низа экрана
  k = boxH / (1.0 * src.boxH);
  px = v: builtins.floor (v * k + 0.5);

  imgSize = px src.h; # size виджета = меньшая сторона холста (высота)
  imgY = bottom - px (src.h - src.boxY - src.boxH); # компенсация хвоста холста
  textW = px (src.boxW - 2 * src.insetX); # ширина текстовой области
  quoteY = bottom + px src.menuH - 6; # низ лейбла реплики (над меню)
  nameX = px (src.plateCx - src.boxW / 2); # центр плашки от центра экрана
  nameY = bottom + px (src.boxH - src.plateCy) - 26; # низ лейбла имени

  quoteFontSize = 24;
  fontPx = quoteFontSize * 4 / 3; # pango pt -> px @ 96dpi: метрики переноса

  # Все лейблы — на всех мониторах и одним шрифтом.
  mkLabel =
    l:
    {
      monitor = "";
      font_family = "Doki";
    }
    // l;
in
{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
        # кадр реплики добит пустыми строками до постоянной высоты —
        # обрезка схлопнула бы текстуру и текст прыгал бы.
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
          path = backgroundImage;
          color = "rgb(2a1a2e)"; # запасной цвет
        }
      ];

      # Бокс диалога — статичный, текст живёт в лейблах поверх.
      image = [
        {
          monitor = "";
          path = dialogAsset;
          size = imgSize;
          rounding = 0;
          border_size = 0;
          zindex = 0; # сортировка по zindex нестабильная — фиксируем явно
          position = "0, ${toString imgY}";
          halign = "center";
          valign = "bottom";
        }
      ];

      label = map mkLabel [
        # Часы
        {
          text = "$TIME";
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
          text = ''cmd[update:60000] date +"%A, %B %-d" | tr -d '\n' '';
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
        # вместе с текстом и с той же частотой. Розовая «обводка» — тень.
        {
          text = "cmd[update:33] ${quoteScript} name";
          font_size = 28;
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
        # Реплика: постоянный размер текстуры (см. шапку) + halign center
        # + valign bottom дают прибитый левый верх текста ровно у поля
        # текстовой области. Чёрная «обводка» — тень. Опрос 33 мс = плавная
        # печать ~1 символ/кадр при CPS=30.
        {
          text = "cmd[update:33] TEXT_W=${toString textW} FONT_PX=${toString fontPx} ${quoteScript} frame";
          font_size = quoteFontSize;
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
          text = "$LAYOUT[EN,RU]";
          font_size = 24;
          color = "rgba(ffffffdd)";
          shadow_passes = 2;
          shadow_size = 3;
          shadow_color = "rgba(e2679baa)";
          position = "240, -20";
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
