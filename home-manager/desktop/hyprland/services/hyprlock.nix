{ pkgs, huixDir, ... }:

# Экран блокировки в стиле DDLC. Фон — картинка (не скриншот: скриншотный фон
# hyprlock захватывает кадр с уже применённым screen_shader, после чего
# компоситор прогоняет поверхность hyprlock через тот же шейдер ещё раз —
# эффект и софт-яркость удваиваются).
#
# Диалоговое окно — один image-виджет: scripts/hyprlock-quote.sh рендерит
# реплики Моники (assets/monika-talk.txt) поверх base-шаблона, собранного
# здесь на этапе сборки. Он же коротко глитчит экран при неправильном пароле
# (screen-shader.sh flash glitch).
let
  backgroundImage = ../../../../assets/just_monika.png;
  dialogAsset = ../../../../assets/ddlc-stickers/dialog_box.png;
  dokiFont = ../../../../nixos/fonts/doki.otf;

  # Base-шаблон диалога: игровой бокс (обрезаем прозрачные поля, 2x для
  # чёткости -> 1632x370) с впечённым именем на плашке — белое с розовой
  # обводкой, отцентровано (обводка = проход stroke + проход fill поверх).
  # Geometry согласована с рендером текста в hyprlock-quote.sh.
  dialogBase =
    pkgs.runCommand "hyprlock-dialog-base.png" { nativeBuildInputs = [ pkgs.imagemagick ]; }
      ''
        magick ${dialogAsset} -trim +repage -resize 200% \
          \( -background none -font ${dokiFont} -pointsize 52 \
             -fill white -stroke "#e2679b" -strokewidth 4 label:"Monika" \
             -gravity center -background none -extent 336x76 \) \
          -gravity northwest -geometry +68+0 -composite \
          \( -background none -font ${dokiFont} -pointsize 52 \
             -fill white -stroke none label:"Monika" \
             -gravity center -background none -extent 336x76 \) \
          -gravity northwest -geometry +68+0 -composite \
          "$out"
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

      # Диалоговое окно. Стартуем с пустого шаблона; через секунду скрипт
      # отдаёт кадр с первой репликой (reload по mtime/смене пути).
      image = [
        {
          monitor = "";
          path = "${dialogBase}";
          size = 280; # меньшая сторона (высота) — как пропорция бокса в игре на 1080p
          rounding = 0;
          border_size = 0;
          reload_time = 1;
          reload_cmd = "${huixDir}/scripts/hyprlock-quote.sh ${dialogBase}";
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
          fail_text = "Это не то...";
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
