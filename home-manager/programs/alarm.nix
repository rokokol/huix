{ pkgs, ... }:

let
  # freedesktop sound theme ships a proper alarm clip; reference it directly.
  alarmSound = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga";

  alarm = pkgs.writeShellApplication {
    name = "alarm";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnused
      procps
      rofi
      libnotify
      wireplumber
      pipewire
      systemd
    ];
    text = ''
      ALARM_SOUND="${alarmSound}"
      RTCWAKE="/run/current-system/sw/bin/rtcwake"
      DEFAULT_PHRASE="я проснулся и больше не лягу"

      usage() {
        cat <<'EOF'
      alarm — будильник через suspend: компьютер засыпает, RTC будит его и
      начинает звенеть, пока ты не введёшь заданную фразу.

      Использование:
        alarm <часы> [фраза]       спать N часов (можно дробно: 7.5), потом будить
        alarm --at HH:MM [фраза]   разбудить в ближайшее HH:MM
        alarm -h | --help

      Фраза по умолчанию: «я проснулся и больше не лягу».
      EOF
      }

      phrase="$DEFAULT_PHRASE"
      target=""

      case "''${1:-}" in
        -h|--help|"")
          usage
          exit 0
          ;;
        --at)
          [ -n "''${2:-}" ] || { echo "Нужно время в формате HH:MM" >&2; exit 1; }
          target=$(date -d "today ''${2}" +%s)
          if [ "$target" -le "$(date +%s)" ]; then
            target=$(date -d "tomorrow ''${2}" +%s)
          fi
          [ -n "''${3:-}" ] && phrase="''${3}"
          ;;
        *)
          hours="''${1}"
          if ! printf '%s' "$hours" | grep -Eq '^[0-9]+([.][0-9]+)?$'; then
            echo "Часы должны быть числом, например 8 или 7.5" >&2
            exit 1
          fi
          secs=$(awk -v h="$hours" 'BEGIN { printf "%d", h * 3600 }')
          target=$(( $(date +%s) + secs ))
          [ -n "''${2:-}" ] && phrase="''${2}"
          ;;
      esac

      delay=$(( target - $(date +%s) ))
      if [ "$delay" -lt 60 ]; then
        echo "Слишком близко: нужно хотя бы 60 секунд до подъёма" >&2
        exit 1
      fi

      wake_human=$(date -d "@$target" '+%H:%M %d.%m')
      echo "Сон до $wake_human. Фраза для отключения: «$phrase»"
      notify-send -u critical "⏰ Будильник заведён" "Подъём в $wake_human"
      sleep 3

      # Don't let hypridle lock the session around this suspend.
      hypridle_was_running=0
      if systemctl --user --quiet is-active hypridle.service; then
        hypridle_was_running=1
        systemctl --user stop hypridle.service || true
      fi

      SOUND_PID=""
      restore() {
        if [ -n "''${SOUND_PID:-}" ]; then
          kill "$SOUND_PID" 2>/dev/null || true
          pkill -P "$SOUND_PID" 2>/dev/null || true
        fi
        if [ "$hypridle_was_running" = 1 ]; then
          systemctl --user start hypridle.service 2>/dev/null || true
        fi
      }
      trap restore EXIT INT TERM

      # Sleep in a loop so an early wake (power button, lid, USB) doesn't ring
      # by mistake. `-m mem` suspends the kernel directly, bypassing logind, so
      # hypridle's before_sleep lock never fires. Relative `-s` dodges RTC
      # timezone issues. rtcwake returns on ANY wake, so after each resume we
      # check the clock: if it's not time yet, offer a 20s cancel window and
      # otherwise go back to sleep.
      while :; do
        delay=$(( target - $(date +%s) ))
        if [ "$delay" -le 10 ]; then
          break
        fi
        [ "$delay" -lt 30 ] && delay=30
        sudo "$RTCWAKE" -m mem -s "$delay"

        # Woke at (or past) target -> fall through to the alarm.
        [ "$(date +%s)" -ge $(( target - 10 )) ] && break

        # Early wake: show a cancel window. Typing the phrase aborts the alarm;
        # a wrong/empty answer or the 20s timeout sends us back to sleep.
        hyprctl dispatch dpms on >/dev/null 2>&1 || true
        wake_human=$(date -d "@$target" '+%H:%M %d.%m')
        early=$(timeout 20 rofi -dmenu \
          -p "Рано" \
          -mesg "Подъём в $wake_human. Введи фразу, чтобы ОТМЕНИТЬ будильник; иначе сон через 20 c." \
          -theme-str 'window { width: 60%; } listview { enabled: false; }' \
          < /dev/null 2>/dev/null || true)
        early=$(printf '%s' "$early" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [ "$early" = "$phrase" ]; then
          notify-send "🔕 Будильник отменён" "Досрочное пробуждение"
          exit 0
        fi
      done

      # ---- time to ring ----
      hyprctl dispatch dpms on >/dev/null 2>&1 || true
      wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 || true
      wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0 || true

      ( while :; do pw-play "$ALARM_SOUND" || sleep 1; done ) &
      SOUND_PID=$!

      notify-send -u critical "⏰ ПОДЪЁМ" "Введи фразу, чтобы выключить будильник"

      # Demand the exact phrase. rofi reopens on every wrong/empty/escaped
      # answer, so it can't be dismissed without typing it.
      answer=""
      while [ "$answer" != "$phrase" ]; do
        answer=$(rofi -dmenu \
          -p "Будильник" \
          -mesg "Чтобы выключить, введи ровно: $phrase" \
          -theme-str 'window { width: 60%; } listview { enabled: false; }' \
          < /dev/null 2>/dev/null || true)
        answer=$(printf '%s' "$answer" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      done

      notify-send "✅ Будильник выключен" "Доброе утро!"
    '';
  };
in
{
  home.packages = [ alarm ];
}
