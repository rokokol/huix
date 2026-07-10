{ pkgs, huixDir, ... }:

# Экран блокировки в стиле DDLC. Фон — НЕ скриншот: скриншотный фон hyprlock
# (дефолт) захватывает кадр уже с применённым decoration:screen_shader, после
# чего компоситор прогоняет поверхность hyprlock через тот же шейдер ещё раз —
# эффект и софт-яркость применялись дважды. Со статичной картинкой шейдер
# применяется ровно один раз (ночной режим на локскрине сохраняется).
#
# Макет — как в игре: статичный розовый фон с горошком, по краям экрана стоят
# спрайты четырёх героинь (по 2 на каждый край), внизу — диалоговое окно из
# PNG-ассета с плашкой Monika и её репликами (scripts/hyprlock-quote.sh:
# гауссовские паузы, глитч при неправильном пароле). Часы сверху, поле пароля
# по центру. Анимации отключены — весь фон статичен.
let
  assetsDir = ../../../../assets/ddlc-stickers;

  # Фон в духе главного меню игры: розовый градиент, диагональный «горошек»
  # из кружочков, мягкое свечение по центру. Генерируется из SVG на этапе
  # сборки. Статичный — без анимации/reload.
  backgroundSvg = pkgs.writeText "hyprlock-ddlc-bg.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1440">
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#ffe6f3"/>
          <stop offset="0.55" stop-color="#ffc7e6"/>
          <stop offset="1" stop-color="#ffa7d6"/>
        </linearGradient>
        <radialGradient id="glow" cx="0.5" cy="0.46" r="0.6">
          <stop offset="0" stop-color="#ffffff" stop-opacity="0.5"/>
          <stop offset="0.7" stop-color="#ffffff" stop-opacity="0.12"/>
          <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
        </radialGradient>
        <pattern id="dots" width="128" height="128" patternUnits="userSpaceOnUse" patternTransform="rotate(15)">
          <circle cx="32" cy="32" r="24" fill="#ffffff" fill-opacity="0.30"/>
          <circle cx="96" cy="96" r="24" fill="#ffffff" fill-opacity="0.30"/>
        </pattern>
      </defs>
      <rect width="2560" height="1440" fill="url(#bg)"/>
      <rect width="2560" height="1440" fill="url(#dots)"/>
      <ellipse cx="1280" cy="660" rx="980" ry="600" fill="url(#glow)"/>
    </svg>
  '';

  staticBackground =
    pkgs.runCommand "hyprlock-ddlc-bg.png" { nativeBuildInputs = [ pkgs.librsvg ]; }
      ''
        rsvg-convert -w 2560 -h 1440 ${backgroundSvg} -o "$out"
      '';

  # Спрайты героинь: webp→png без масштабирования (оригинальный размер ~170px).
  # Располагаются статично по нижним углам экрана (по 2 на каждый угол).
  stickerPngs =
    pkgs.runCommand "hyprlock-ddlc-stickers" { nativeBuildInputs = [ pkgs.imagemagick ]; }
      ''
        mkdir -p "$out"
        magick ${assetsDir}/Sayori_Sticker_Calm.webp    "$out/sayori.png"
        magick ${assetsDir}/Natsuki_sticker_Excited.webp "$out/natsuki.png"
        magick ${assetsDir}/Yuri_sticker_Calm.webp       "$out/yuri.png"
        magick ${assetsDir}/Monika_Sticker_Calm.webp     "$out/monika.png"
      '';

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

      # Анимации отключены — фон статичен, нет кроссфейдов.
      animations = {
        enabled = false;
      };

      background = [
        {
          monitor = "";
          path = "${staticBackground}";
          color = "rgb(ffa7d6)"; # запасной цвет, если картинка не загрузится
        }
      ];

      # Статичные спрайты героинь по нижним углам экрана.
      # z-порядок: фон(-1) < спрайты(0) < диалог(1) < текст(2).
      #
      # Расположение (2560x1440):
      #   Нижний левый угол:  Sayori, Monika
      #   Нижний правый угол: Natsuki, Yuri
      image = [
        # Sayori — нижний левый угол, ближе к краю
        {
          monitor = "";
          path = "${stickerPngs}/sayori.png";
          size = 170;
          rounding = 0;
          border_size = 0;
          zindex = 0;
          position = "20, 15";
          halign = "left";
          valign = "bottom";
        }
        # Monika — нижний левый угол, правее Sayori
        {
          monitor = "";
          path = "${stickerPngs}/monika.png";
          size = 170;
          rounding = 0;
          border_size = 0;
          zindex = 0;
          position = "170, 15";
          halign = "left";
          valign = "bottom";
        }
        # Natsuki — нижний правый угол, левее Yuri
        {
          monitor = "";
          path = "${stickerPngs}/natsuki.png";
          size = 170;
          rounding = 0;
          border_size = 0;
          zindex = 0;
          position = "-170, 15";
          halign = "right";
          valign = "bottom";
        }
        # Yuri — нижний правый угол, ближе к краю
        {
          monitor = "";
          path = "${stickerPngs}/yuri.png";
          size = 170;
          rounding = 0;
          border_size = 0;
          zindex = 0;
          position = "-20, 15";
          halign = "right";
          valign = "bottom";
        }
        # Диалоговое окно (PNG-ассет из DDLC, содержит плашку и меню)
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
        # Имя на плашке диалогового окна
        {
          monitor = "";
          text = "Monika";
          font_family = "Doki";
          font_size = 26;
          color = "rgb(d8559b)";
          zindex = 2;
          position = "-480, 265";
          halign = "center";
          valign = "bottom";
        }
        # Реплика в диалоговом окне: скрипт поллится ежесекундно, но реплику
        # меняет сам — по гауссовской паузе. Глитч при неправильном пароле
        # (определяется через faillock).
        {
          monitor = "";
          text = "cmd[update:1000] ${huixDir}/scripts/hyprlock-quote.sh";
          font_family = "Doki";
          font_size = 28;
          color = "rgb(4a3547)";
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
          fail_text = "Э̸̰т̵̢о̸̝ ̷̡н̵̟е̵̗ ̸̰т̷̡о̶̢.̸̝.̵̟.̷̗ ($ATTEMPTS)";
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
