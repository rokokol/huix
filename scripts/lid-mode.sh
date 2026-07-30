#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
lid-mode.sh — режим "крышка гасит экран, а не усыпляет" (бинд SUPER+SHIFT+A)

Команды:
  toggle    включить/выключить режим
  on|off    включить/выключить явно
  close     обработчик закрытия крышки (bindl switch:on:Lid Switch)
  open      обработчик открытия крышки (bindl switch:off:Lid Switch)
  status    показать текущее состояние (on|off) — для скриптов
  help      эта справка

Как это работает. Обычно крышку обрабатывает logind (HandleLidSwitch=suspend) и
по умолчанию ИГНОРИРУЕТ inhibitor-локи на неё (LidSwitchIgnoreInhibited=yes).
На ноутбуке этот игнор выключен (nixos/laptop/logind.nix), поэтому "режим" —
это просто живой лок systemd-inhibit --what=handle-lid-switch в транзиентном
юните huix-lid-inhibit: пока он держится, logind крышку не трогает, а Hyprland
по switch-биндам гасит через dpms только встроенную панель — внешний монитор,
если он подключён, продолжает работать.

Состояние НЕ хранится в файле: источник правды — активен ли юнит. Значит режим
живёт только внутри сессии и после ребута/релогина ноутбук снова засыпает от
крышки — намеренно, чтобы не забыть его включённым в рюкзаке.
EOF
}

UNIT="huix-lid-inhibit"
LOGIND_CONF="/etc/systemd/logind.conf"

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Lid mode error (╯°□°）╯︵ ┻━┻" "$1" && return
  fi
  printf '%s\n' "$1" >&2
}

notify_info() {
  command -v notify-send >/dev/null 2>&1 && notify-send -u low "$1" "$2" || true
}

is_on() {
  systemctl --user is-active --quiet "$UNIT.service"
}

# Гасим только встроенную панель: с подключённым внешним монитором закрытая
# крышка не должна тушить и его. Не нашли внутренний выход — гасим всё.
internal_monitor() {
  hyprctl monitors -j 2>/dev/null |
    jq -r 'map(select(.name | test("^(eDP|LVDS|DSI)"; "i"))) | .[0].name // empty' 2>/dev/null || true
}

dpms() {
  local mon
  mon="$(internal_monitor)"
  hyprctl dispatch dpms "$1" ${mon:+"$mon"} >/dev/null 2>&1 || true
}

# Лок бесполезен, если система всё ещё игнорирует inhibitor'ы крышки — обычно
# это значит, что nixos-rebuild с nixos/laptop/logind.nix ещё не применён.
warn_if_inhibitor_ignored() {
  grep -qiE '^\s*LidSwitchIgnoreInhibited\s*=\s*(no|false|0)\s*$' "$LOGIND_CONF" 2>/dev/null && return 0
  notify_error "logind игнорирует локи крышки: нет LidSwitchIgnoreInhibited=no в $LOGIND_CONF (нужен nixos-rebuild)"
}

cmd_on() {
  if ! is_on; then
    systemd-run --user --collect --quiet \
      --unit="$UNIT" \
      --description="huix: крышка гасит экран, а не усыпляет" \
      systemd-inhibit \
      --what=handle-lid-switch \
      --mode=block \
      --who="huix lid-mode" \
      --why="закрытая крышка только гасит экран" \
      sleep infinity || true

    # systemd-run возвращается сразу; ждём, пока юнит реально поднимется
    for _ in {1..20}; do
      is_on && break
      sleep 0.05
    done

    if ! is_on; then
      notify_error "Не удалось взять лок handle-lid-switch ヽ(ﾟДﾟ)ﾉ"
      exit 1
    fi

    warn_if_inhibitor_ignored || true
  fi

  notify_info "Крышка не усыпляет (´∇ﾉ｀*)ノ" "Закрытие крышки только гасит экран"
}

cmd_off() {
  systemctl --user stop "$UNIT.service" 2>/dev/null || true

  # Страховка: режим могли выключить с внешней клавиатуры при погашенной панели
  dpms on

  notify_info "Крышка усыпляет （-＾〇＾-）" "Обычное поведение: закрытие крышки — сон"
}

cmd_close() {
  # Режим выключен — ничего не делаем, крышку обрабатывает logind (suspend)
  is_on || exit 0
  dpms off
}

cmd_status() {
  if is_on; then echo "on"; else echo "off"; fi
}

case "${1:-}" in
toggle)
  if is_on; then cmd_off; else cmd_on; fi
  ;;
on) cmd_on ;;
off) cmd_off ;;
close) cmd_close ;;
open) dpms on ;;
status) cmd_status ;;
help | -h | --help) usage ;;
*)
  usage >&2
  notify_error "Usage: lid-mode.sh toggle|on|off|close|open|status|help"
  exit 1
  ;;
esac
