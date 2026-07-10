{ pkgs, huixDir, ... }:

# Экран блокировки в стиле DDLC. Фон — картинка (не скриншот: скриншотный фон
# hyprlock захватывает кадр с уже применённым screen_shader, после чего
# компоситор прогоняет поверхность hyprlock через тот же шейдер ещё раз —
# эффект и софт-яркость удваиваются).
#
# Диалоговое окно = статичный PNG-бокс (собирается здесь) + label с репликами
# Моники: scripts/hyprlock-quote.sh отдаёт pango-разметку кадра раз в 150 мс —
# побуквенная печать, паузы Exp(1/7) между репликами и Exp(1/60) между
# топиками, глитчи текста со «сломанной кодировкой» (спонтанные по Пуассону и
# на каждый неправильный пароль). Первый диалог — случайный блок из
# monika-reentry.txt (Act 3 re-entry). Текст — именно label, а не рендер в
# PNG: image-виджет перезагружается максимум раз в секунду и к тому же ждёт
# reload_cmd синхронно, а label обновляется в мс и асинхронно.
let
  backgroundImage = ../../../../assets/just_monika.png;
  dialogAsset = ../../../../assets/ddlc-stickers/dialog_box.png;
  dokiFont = ../../../../nixos/fonts/doki.otf;

  # Бокс диалога: игровой ассет (обрезаем прозрачные поля, 2x для чёткости ->
  # 1632x370) с впечённым именем на плашке. Обводка имени — дилатация альфы
  # того же рендера (один проход текста, идеальное совмещение заливки и
  # контура). Текстовая область бокса согласована с WRAP/RULER в hyprlock-quote.sh.
  dialogBase =
    pkgs.runCommand "hyprlock-dialog-base.png" { nativeBuildInputs = [ pkgs.imagemagick ]; }
      ''
        magick ${dialogAsset} -trim +repage -resize 200% \
          \( -background none -font ${dokiFont} -pointsize 52 -fill white \
             label:"Monika" -bordercolor none -border 8 \
             \( +clone -channel A -morphology dilate disk:3.5 +channel \
                -fill "#e2679b" -channel RGB -colorize 100 +channel \) \
             +swap -composite -gravity center -background none -extent 336x76 \) \
          -gravity northwest -geometry +68+0 -composite \
          "$out"
      '';
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
          path = "${backgroundImage}";
          color = "rgb(2a1a2e)"; # запасной цвет
        }
      ];

      # Бокс диалога — статичный, текст живёт в лейбле поверх.
      image = [
        {
          monitor = "";
          path = "${dialogBase}";
          size = 280; # оригинальный размер диалогового окна
          rounding = 0;
          border_size = 0;
          zindex = 0; # сортировка по zindex нестабильная — фиксируем явно
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
        # Реплика: скрипт держит размер текстуры постоянным (невидимая линейка
        # + скрытый хвост реплики), поэтому halign center + valign bottom дают
        # прибитый левый верхний угол текста в боксе. Чёрная «обводка» — тень.
        {
          monitor = "";
          text = "cmd[update:33] ${huixDir}/scripts/hyprlock-quote.sh";
          font_family = "Doki";
          font_size = 24;
          color = "rgba(ffffffff)";
          shadow_passes = 3;
          shadow_size = 2;
          shadow_color = "rgba(000000ff)";
          text_align = "left";
          zindex = 1; # поверх бокса
          position = "0, 88";
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
