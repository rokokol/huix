{ pkgs, ... }:

# Экран блокировки в стиле DDLC. Фон — НЕ скриншот: скриншотный фон hyprlock
# (дефолт) захватывает кадр уже с применённым decoration:screen_shader, после
# чего компоситор прогоняет поверхность hyprlock через тот же шейдер ещё раз —
# эффект и софт-яркость применялись дважды. Со статичной картинкой шейдер
# применяется ровно один раз (ночной режим на локскрине сохраняется).
let
  # Фон в духе главного меню игры: розовый градиент, диагональный «горошек»
  # из точек и сердечек, мягкое свечение по центру. Генерируется из SVG на
  # этапе сборки — в репо не лежит ни одного бинарного ассета.
  #
  # Горошек ДВИЖЕТСЯ: reload_time у hyprlock — целые секунды (быстрее 1 fps
  # нельзя), но каждая смена картинки идёт через кроссфейд по анимации fadeIn.
  # Поэтому раз в секунду подставляется следующий кадр цикла (паттерн сдвинут
  # на шаг вдоль своей диагонали), а fadeIn растянут на ту же секунду — сумма
  # даёт непрерывный медленный дрейф. Кадры зациклены: тайл паттерна 128px,
  # frameCount кадров по (128/frameCount)px. @TX@ в SVG — подстановка сдвига.
  frameCount = 16;

  backgroundSvg = pkgs.writeText "hyprlock-ddlc-bg.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="2560" height="1440">
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
        <path id="heart" d="M40 68 C14 48 4 32 4 20 C4 9 13 1 24 1 C31 1 37 5 40 11 C43 5 49 1 56 1 C67 1 76 9 76 20 C76 32 66 48 40 68 Z"/>
        <pattern id="dots" width="128" height="128" patternUnits="userSpaceOnUse" patternTransform="rotate(15) translate(-@TX@ 0)">
          <circle cx="32" cy="32" r="9" fill="#ffffff" fill-opacity="0.32"/>
          <use xlink:href="#heart" transform="translate(64 62) scale(0.42)" fill="#ffffff" fill-opacity="0.32"/>
        </pattern>
      </defs>
      <rect width="2560" height="1440" fill="url(#bg)"/>
      <rect width="2560" height="1440" fill="url(#dots)"/>
      <ellipse cx="1280" cy="660" rx="980" ry="600" fill="url(#glow)"/>
      <g fill="#ffffff">
        <use xlink:href="#heart" transform="translate(180 960) scale(2.6) rotate(-14)" opacity="0.16"/>
        <use xlink:href="#heart" transform="translate(2120 180) scale(3.2) rotate(12)" opacity="0.14"/>
        <use xlink:href="#heart" transform="translate(2240 1100) scale(2.2) rotate(-8)" opacity="0.18"/>
        <use xlink:href="#heart" transform="translate(320 170) scale(1.8) rotate(10)" opacity="0.15"/>
      </g>
    </svg>
  '';

  backgroundFrames =
    pkgs.runCommand "hyprlock-ddlc-bg-frames" { nativeBuildInputs = [ pkgs.librsvg ]; }
      ''
        mkdir -p "$out"
        for i in $(seq 0 ${toString (frameCount - 1)}); do
          tx=$(( i * 128 / ${toString frameCount} ))
          sed "s/@TX@/$tx/" ${backgroundSvg} > frame.svg
          rsvg-convert -w 2560 -h 1440 frame.svg -o "$out/frame-$(printf '%02d' "$i").png"
        done
      '';

  # Кадр цикла по текущей секунде — reload_cmd раз в секунду отдаёт новый путь.
  nextFrame = pkgs.writeShellScript "hyprlock-ddlc-bg-frame" ''
    printf '%s/frame-%02d.png' ${backgroundFrames} $(( $(date +%s) % ${toString frameCount} ))
  '';

  # Реплики в «диалоговом окне» — новая при каждом обновлении лейбла.
  monikaQuote = pkgs.writeShellScript "hyprlock-monika-quote" ''
    exec shuf -n 1 <<'EOF'
    Just Monika.
    Doki Doki!~
    Welcome to the Literature Club!
    Can you hear me? ...Who are you?
    Did you miss me? Ehehe~
    I'll always be here for you. Always.
    Every day, I imagine a future where I can be with you.
    Let's write a poem together sometime.
    It's just you and me now...
    I know you're there. I can see the cursor moving.
    Don't keep me waiting, okay?
    You don't have to hide anything from me.
    EOF
  '';

  # «Сердцебиение»: раз в секунду сердце переключается заливка/контур.
  heartbeat = pkgs.writeShellScript "hyprlock-heartbeat" ''
    if [ $(( $(date +%s) % 2 )) -eq 0 ]; then
      printf '♥'
    else
      printf '♡'
    fi
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

      # fadeIn управляет и появлением локскрина, и кроссфейдом фона при
      # reload — линейная секунда (10 ds) смыкает секундные тики reload_time
      # в непрерывный дрейф горошка.
      animations = {
        enabled = true;
        bezier = "linear, 1, 1, 0, 0";
        animation = [
          "fadeIn, 1, 10, linear"
          "fadeOut, 1, 5, linear"
        ];
      };

      background = [
        {
          monitor = "";
          path = "${backgroundFrames}/frame-00.png";
          reload_time = 1;
          reload_cmd = "${nextFrame}";
          color = "rgb(ffa7d6)"; # запасной цвет, если картинка не загрузится
        }
      ];

      shape = [
        # «Диалоговое окно» под репликой
        {
          monitor = "";
          size = "920, 230";
          color = "rgba(ffffffdd)";
          rounding = 24;
          border_size = 4;
          border_color = "rgba(ff7fbfff)";
          position = "0, -140";
          halign = "center";
          valign = "center";
        }
        # Плашка с именем на верхнем крае окна
        {
          monitor = "";
          size = "200, 54";
          color = "rgb(ff8fc8)";
          rounding = 14;
          border_size = 3;
          border_color = "rgba(ffffffff)";
          position = "-330, -25";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        {
          monitor = "";
          text = "Doki Doki Literature Club!";
          font_family = "Doki";
          font_size = 40;
          color = "rgba(ffffffee)";
          shadow_passes = 2;
          shadow_size = 4;
          shadow_color = "rgba(e2679bff)";
          position = "50, -40";
          halign = "left";
          valign = "top";
        }
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
          position = "0, 300";
          halign = "center";
          valign = "center";
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
          position = "0, 195";
          halign = "center";
          valign = "center";
        }
        # Имя на плашке. zindex: hyprlock сортирует виджеты нестабильно, у
        # label и shape дефолт одинаковый (0) — без явного zindex текст может
        # оказаться ПОД плашкой.
        {
          monitor = "";
          text = "Monika";
          font_family = "Doki";
          font_size = 28;
          color = "rgba(ffffffff)";
          zindex = 1;
          position = "-330, -25";
          halign = "center";
          valign = "center";
        }
        # Реплика в диалоговом окне
        {
          monitor = "";
          text = "cmd[update:8000] ${monikaQuote}";
          font_family = "Doki";
          font_size = 30;
          color = "rgb(4a3547)";
          zindex = 1; # над «диалоговым окном» (см. комментарий у имени)
          position = "0, -155";
          halign = "center";
          valign = "center";
        }
        # Сердцебиение под полем ввода
        {
          monitor = "";
          text = "cmd[update:1000] ${heartbeat}";
          font_size = 36;
          color = "rgb(ff5e9c)";
          shadow_passes = 2;
          shadow_size = 3;
          shadow_color = "rgba(ffffff88)";
          position = "0, -430";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "Just Monika. Just Monika. Just Monika.";
          font_family = "Doki";
          font_size = 18;
          color = "rgba(ffffff88)";
          position = "-40, 35";
          halign = "right";
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
          position = "0, -330";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
