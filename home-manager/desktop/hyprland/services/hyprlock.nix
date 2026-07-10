{ pkgs, huixDir, ... }:

# Экран блокировки в стиле DDLC. Фон — НЕ скриншот: скриншотный фон hyprlock
# (дефолт) захватывает кадр уже с применённым decoration:screen_shader, после
# чего компоситор прогоняет поверхность hyprlock через тот же шейдер ещё раз —
# эффект и софт-яркость применялись дважды. Со статичной картинкой шейдер
# применяется ровно один раз (ночной режим на локскрине сохраняется).
#
# Макет — как в игре: широкое «диалоговое окно» внизу с плашкой Monika и её
# репликами из Act 3 (scripts/hyprlock-quote.sh: экспоненциальные паузы,
# глитч с вероятностью 1/3), над ним бродят и прыгают стикеры персонажей
# (scripts/hyprlock-stickers.sh: image-виджет с посекундным reload), под ним
# полоска меню «History Skip Auto...». Часы сверху, поле пароля по центру.
let
  # Фон в духе главного меню игры: розовый градиент, диагональный «горошек»
  # из кружочков, мягкое свечение по центру. Генерируется из SVG на этапе
  # сборки — в репо не лежит ни одного бинарного ассета.
  #
  # Горошек ДВИЖЕТСЯ: reload_time у hyprlock — целые секунды, каждая смена
  # картинки идёт через кроссфейд по анимации fadeIn. Раз в reloadPeriod
  # подставляется следующий кадр цикла (паттерн сдвинут на шаг вдоль своей
  # диагонали). Кадры зациклены: тайл паттерна 128px, frameCount кадров по
  # (128/frameCount)px. @TX@ в SVG — подстановка сдвига.
  #
  # ВАЖНО: кроссфейд (fadeIn) обязан быть КОРОЧЕ reloadPeriod. Если новый
  # кадр прилетает, пока предыдущий кроссфейд ещё идёт, CBackground::
  # onAssetUpdate перезаписывает pendingAsset и подменяет коллбек — старая
  # текстура повисает, и renderTextureMix падает по SIGSEGV (проверено
  # coredump-ами: fadeIn = периоду валил hyprlock за минуты). Плюс на случай
  # любого краша локера есть hyprlock-guard ниже.
  #
  # GIF/видео hyprlock не умеет в принципе (только статичные текстуры),
  # так что плавность добывается малым шагом: 4px раз в секунду, из которых
  # 0.6s занимает растворение, — почти непрерывный дрейф с запасом 0.4s
  # до следующего кадра.
  frameCount = 32; # тайл 128px → шаг 4px
  reloadPeriod = 1;

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
        <pattern id="dots" width="128" height="128" patternUnits="userSpaceOnUse" patternTransform="rotate(15) translate(-@TX@ 0)">
          <circle cx="32" cy="32" r="24" fill="#ffffff" fill-opacity="0.30"/>
          <circle cx="96" cy="96" r="24" fill="#ffffff" fill-opacity="0.30"/>
        </pattern>
      </defs>
      <rect width="2560" height="1440" fill="url(#bg)"/>
      <rect width="2560" height="1440" fill="url(#dots)"/>
      <ellipse cx="1280" cy="660" rx="980" ry="600" fill="url(#glow)"/>
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

  # Кадр цикла по текущему времени — reload_cmd отдаёт новый путь раз в
  # reloadPeriod секунд.
  nextFrame = pkgs.writeShellScript "hyprlock-ddlc-bg-frame" ''
    printf '%s/frame-%02d.png' ${backgroundFrames} \
      $(( ( $(date +%s) / ${toString reloadPeriod} ) % ${toString frameCount} ))
  '';

  # Стартовый (пустой прозрачный) кадр полосы стикеров: размер должен
  # совпадать с канвой hyprlock-stickers.sh, иначе image-виджет отскейлит
  # первый настоящий кадр.
  stickersPlaceholder =
    pkgs.runCommand "hyprlock-stickers-placeholder.png" { nativeBuildInputs = [ pkgs.librsvg ]; }
      ''
        rsvg-convert -w 1920 -h 340 ${pkgs.writeText "empty.svg" ''<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="340"/>''} -o "$out"
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
    pkgs.imagemagick # композер кадров hyprlock-stickers.sh
  ];

  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };

      # fadeIn управляет и появлением локскрина, и кроссфейдом фона при
      # reload. 6 ds = 0.6s — короче reloadPeriod, иначе кроссфейды
      # перекрываются и hyprlock падает (см. комментарий к reloadPeriod).
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
          path = "${backgroundFrames}/frame-00.png";
          reload_time = reloadPeriod;
          reload_cmd = "${nextFrame}";
          color = "rgb(ffa7d6)"; # запасной цвет, если картинка не загрузится
        }
      ];

      # Бродящие стикеры позади диалогового окна. image-виджет меняет ассет
      # мгновенно (без кроссфейда) и защищён от наслоения запросов, так что
      # посекундный reload тут безопасен; сам кадр рисуется фоном (двойной
      # буфер в скрипте), путь стабильный — hyprlock перечитывает по mtime.
      # z-порядок: фон(-1) < стикеры(0) < плашки(1) < текст(2).
      image = [
        {
          monitor = "";
          path = "${stickersPlaceholder}";
          size = 340; # = меньшая сторона канвы 1920x340 → рендер 1:1
          rounding = 0;
          border_size = 0;
          reload_time = 1;
          reload_cmd = "${huixDir}/scripts/hyprlock-stickers.sh";
          zindex = 0;
          position = "0, 340";
          halign = "center";
          valign = "bottom";
        }
      ];

      shape = [
        # «Диалоговое окно» внизу, как в игре
        {
          monitor = "";
          size = "1400, 230";
          color = "rgba(ffffffe6)";
          rounding = 18;
          border_size = 3;
          border_color = "rgba(ff7fbfff)";
          zindex = 1;
          position = "0, 150";
          halign = "center";
          valign = "bottom";
        }
        # Плашка с именем на верхнем левом краю окна
        {
          monitor = "";
          size = "220, 60";
          color = "rgba(ffffffee)";
          rounding = 12;
          border_size = 3;
          border_color = "rgba(ff7fbfff)";
          zindex = 1;
          position = "-565, 350";
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
        # Имя на плашке
        {
          monitor = "";
          text = "Monika";
          font_family = "Doki";
          font_size = 26;
          color = "rgb(d8559b)";
          zindex = 2;
          position = "-565, 362";
          halign = "center";
          valign = "bottom";
        }
        # Реплика в диалоговом окне: скрипт поллится ежесекундно, но реплику
        # меняет сам — по экспоненциальной паузе, с глитчем в 1/3 случаев
        {
          monitor = "";
          text = "cmd[update:1000] ${huixDir}/scripts/hyprlock-quote.sh";
          font_family = "Doki";
          font_size = 28;
          color = "rgb(4a3547)";
          text_align = "center";
          zindex = 2;
          position = "0, 215";
          halign = "center";
          valign = "bottom";
        }
        # Полоска меню под окном, как в игре
        {
          monitor = "";
          text = "History    Skip    Auto    Save    Load    Settings";
          font_family = "Doki";
          font_size = 20;
          color = "rgba(d8559bcc)";
          position = "0, 85";
          halign = "center";
          valign = "bottom";
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
          zindex = 1;
          position = "0, -20";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
