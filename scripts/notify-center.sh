#!/usr/bin/env bash

# Центр уведомлений поверх mako: режим "не беспокоить", история, waybar-индикатор.
#
# У mako нет команд "удалить одно уведомление из истории" и "показать снова
# произвольное" — есть только restore (возвращает на экран САМОЕ СВЕЖЕЕ из
# истории) и dismiss [-h|--no-history]. Поэтому обе операции сделаны цепочкой:
# под служебным невидимым режимом (mode=silent, см. mako.nix) restore-им записи
# с верхушки истории до целевой, делаем своё дело и возвращаем лишние обратно
# повторным dismiss — он кладёт их в историю сверху, так что порядок
# сохраняется, если возвращать от старых к новым. Попапы при этом не мигают.
#
# Вызвать action у уведомления ИЗ ИСТОРИИ mako не умеет (makoctl invoke молча
# возвращает 0, но действие не доставляется — проверено), поэтому invoke для
# исторической записи сначала тихо восстанавливает её на экран той же цепочкой
# и только потом вызывает действие. Если приложение-отправитель уже умерло,
# действие уйдёт в пустоту — это ограничение самого механизма ActionInvoked.
#
# Все команды работают с ЛЕНТОЙ (видимые попапы + история): для видимых —
# прямые вызовы makoctl, для истории — цепочки.
#
# Режимы mako живут в рантайме демона: DND переживает reload Hyprland и
# nixos-rebuild, но сбрасывается при перезапуске сессии — для "временно
# отключить" это ожидаемое поведение, restore-на-старте не нужен.
#
# Использование:
#   notify-center.sh status          — JSON для waybar (custom/notifications)
#   notify-center.sh dnd toggle|on|off — переключить "не беспокоить"
#   notify-center.sh dnd status      — печатает on|off (для rofi-notify.sh)
#   notify-center.sh clear           — очистить всю историю
#   notify-center.sh delete <id>     — убрать запись (с экрана или из истории)
#   notify-center.sh invoke <id> <key> — вызвать действие уведомления
#   notify-center.sh actions <id>    — строки "key<TAB>label" действий записи
#   notify-center.sh menu            — строки "id<TAB>icon<TAB>label" для rofi
#   notify-center.sh text <id>       — текст уведомления (для копирования)
#   notify-center.sh nav up|down     — листать ленту в тултипе (колесо на waybar)

set -euo pipefail

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Notify center error (╯°□°）╯︵ ┻━┻" "$1" && return
  fi
  printf '%s\n' "$1" >&2
}

# Пинаем waybar перечитать индикатор (модуль слушает SIGRTMIN+N). Номер сигнала
# задаёт Nix (waybar-notifications.nix) и кладёт в WAYBAR_NOTIF_SIGNAL — единый
# источник правды. В отличие от шейдера, гонки с автостартом waybar тут нет:
# сигнал шлётся только по явным действиям пользователя, когда waybar уже жив.
signal_waybar() {
  [[ -n "${WAYBAR_NOTIF_SIGNAL:-}" ]] || return 0
  pkill -RTMIN+"$WAYBAR_NOTIF_SIGNAL" waybar 2>/dev/null || true
}

dnd_active() {
  makoctl mode | grep -qx do-not-disturb
}

cmd_dnd() {
  case "${1:-}" in
    on)     makoctl mode -a do-not-disturb >/dev/null ;;
    off)    makoctl mode -r do-not-disturb >/dev/null ;;
    toggle) makoctl mode -t do-not-disturb >/dev/null ;;
    status)
      if dnd_active; then printf 'on\n'; else printf 'off\n'; fi
      return
      ;;
    *) notify_error "Usage: dnd toggle|on|off|status"; exit 1 ;;
  esac
  signal_waybar
}

# JSON для waybar: колокольчик + счётчик ЛЕНТЫ (видимые попапы + история —
# иначе висящее на экране уведомление «не существует» для счётчика), класс dnd
# при "не беспокоить". Тултип: обычно последние 5 записей ленты; при живом
# курсоре листания — страница вокруг курсора с маркером ▶. Текст экранируем
# (@html): тултип — Pango-разметка.
cmd_status() {
  local dnd=0
  dnd_active && dnd=1
  load_nav
  feed_json | jq -c --argjson dnd "$dnd" --argjson idx "$idx" '
    . as $all
    | ($all | length) as $n
    | ($all | map(
        ("\(.app_name // "?"): \(.summary // "")"
         + (if (.body // "") != "" then
              " — " + (.body | gsub("\\s+"; " ") | .[0:80])
            else "" end))
        | @html)) as $lines
    | (if $n == 0 then "Уведомлений нет ( ´ ▽ ` )"
       elif $idx >= 0 then
         ([$idx, $n - 1] | min) as $cur
         | ([$cur - 2, 0] | max) as $from
         | ([$from + 9, $n] | min) as $to
         | ("📜 \($cur + 1)/\($n)\n"
            + ([range($from; $to)
                | if . == $cur then "<b>▶ \($lines[.])</b>" else "   \($lines[.])" end]
               | join("\n")))
       else $lines[:5] | join("\n") end) as $feed
    | ($feed + "\nЛКМ: история · ПКМ: не беспокоить · СКМ: закрыть попапы · колесо: листать") as $tt
    | if $dnd == 1 then
        {text: (if $n > 0 then "🔕 \($n)" else "🔕" end),
         tooltip: ("Не беспокоить (－ω－) zzZ\n" + $tt), class: "dnd"}
      elif $n > 0 then
        {text: "🔔 \($n)", tooltip: $tt, class: "history"}
      else
        {text: "🔔", tooltip: $tt, class: "empty"}
      end'
}

# Строки ленты для rofi-пикера (rofi-notify.sh), новые сверху:
#   id<TAB>icon<TAB>label
# Табы и переводы строк внутри текста заменяем пробелами — TAB здесь разделитель.
# Номер в label соответствует 📜 n/N листания в тултипе и делает различимыми
# одинаковые уведомления (их часто несколько подряд).
cmd_menu() {
  feed_json | jq -r '
    to_entries[] | .key as $i | .value | [
      (.id | tostring),
      (.app_icon // ""),
      ("\($i + 1) · "
       + (if .urgency == "critical" then "🔴" elif .urgency == "low" then "🟢" else "🟡" end)
       + " \(.app_name // "?"): \((.summary // "") | gsub("[\\t\\n]"; " "))"
       + (if (.body // "") != "" then
            " — " + (.body | gsub("[\\t\\n]"; " ") | .[0:70])
          else "" end))
    ] | join("\t")'
}

cmd_text() {
  local id="${1:?id required}"
  feed_json | jq -r --argjson id "$id" '
    .[] | select(.id == $id)
    | [(.summary // ""), (.body // "")] | map(select(. != "")) | join("\n")'
}

# Действия записи: "key<TAB>label". Пустой label (бывает, шлют " ") заменяем ключом.
cmd_actions() {
  local id="${1:?id required}"
  feed_json | jq -r --argjson id "$id" '
    .[] | select(.id == $id) | .actions // {} | to_entries[]
    | "\(.key)\t\(if (.value | gsub("\\s"; "")) == "" then .key else .value end)"'
}

# Листание истории в тултипе waybar-модуля (как календарь у часов): колесо
# двигает курсор (nav up|down), сигнал заставляет waybar перечитать status, а
# status при живом курсоре рисует в тултипе страницу ленты вокруг него. GTK
# обновляет уже открытый тултип на лету: set_tooltip_markup дёргает re-query.
# Курсор эфемерный: живёт в рантайме и протухает через NAV_TTL секунд без
# скролла — тултип возвращается к обычной сводке.
NAV_STATE="${XDG_RUNTIME_DIR:-/tmp}/huix-notify-nav"
NAV_TTL=20

# Лента модуля = видимые попапы + история (новые сверху) — по ней считается
# счётчик, листает курсор и строится rofi-список.
feed_json() {
  { makoctl list -j; makoctl history -j; } | jq -s '.[0] + .[1]'
}

feed_len() {
  feed_json | jq length
}

is_displayed() {
  makoctl list -j | jq -e --argjson id "$1" 'any(.[]; .id == $id)' >/dev/null
}

in_history() {
  makoctl history -j | jq -e --argjson id "$1" 'any(.[]; .id == $id)' >/dev/null
}

load_nav() { # -> глобальный idx: позиция курсора в ленте, -1 = неактивен
  idx=-1
  local ts=0 now
  now=$(date +%s)
  if [[ -f "$NAV_STATE" ]]; then
    # shellcheck disable=SC1090
    source "$NAV_STATE"
    [[ "$idx" =~ ^-?[0-9]+$ ]] || idx=-1
    # NB: не сворачивать в `(( )) && ...` — ложное (( )) последней командой
    # функции вернёт 1, и set -e убьёт скрипт.
    if ((now - ts > NAV_TTL)); then idx=-1; fi
  fi
}

cmd_nav() {
  local dir="${1:?up|down required}" n
  load_nav
  n=$(feed_len)
  # down — глубже (старее), up — к свежим. Первый скролл в любую сторону
  # встаёт на самую свежую запись (idx = -1 -> 0).
  case "$dir" in
    down) idx=$((idx + 1)); ((idx > n - 1)) && idx=$((n - 1)) ;;
    up)   idx=$((idx - 1)); ((idx < 0)) && idx=0 ;;
    *) notify_error "Usage: nav up|down"; exit 1 ;;
  esac
  ((n == 0)) && idx=-1
  printf 'idx=%s\nts=%s\n' "$idx" "$(date +%s)" >"$NAV_STATE"
  signal_waybar
}

silent_on()  { makoctl mode -a silent >/dev/null; }
silent_off() { makoctl mode -r silent >/dev/null 2>&1 || true; }

# Достаёт уведомление <id> из истории на экран (невидимо, под mode=silent):
# restore снимает записи с верхушки истории, пока не снимет целевую. Снятые ДО
# целевой складывает в RESTORED_ABOVE (от новых к старым). 1 — если id не нашёлся.
RESTORED_ABOVE=()
pluck() {
  local target="$1" id
  silent_on
  while read -r id; do
    makoctl restore
    [[ "$id" == "$target" ]] && return 0
    RESTORED_ABOVE+=("$id")
  done < <(makoctl history -j | jq -r '.[].id')
  return 1
}

# Возвращает снятые pluck-ом записи обратно в историю. dismiss кладёт в историю
# сверху, поэтому идём от старых к новым — исходный порядок сохраняется.
restack() {
  local i
  for ((i = ${#RESTORED_ABOVE[@]} - 1; i >= 0; i--)); do
    makoctl dismiss -n "${RESTORED_ABOVE[$i]}"
  done
}

cmd_delete() {
  local id="${1:?id required}"
  # Запись прямо на экране — обычный dismiss мимо истории, цепочка не нужна.
  if is_displayed "$id"; then
    makoctl dismiss -n "$id" -h
    signal_waybar
    return
  fi
  trap silent_off EXIT
  if ! pluck "$id"; then
    restack
    notify_error "Уведомление $id не найдено (・_・;)"
    exit 1
  fi
  makoctl dismiss -n "$id" -h
  restack
  silent_off
  signal_waybar
}

cmd_invoke() {
  local id="${1:?id required}" key="${2:?action key required}"
  trap silent_off EXIT
  if is_displayed "$id"; then
    makoctl invoke -n "$id" "$key"
  else
    # Историческая запись: invoke по истории — no-op, поэтому сначала тихо
    # достаём её на экран (silent) и вызываем действие уже по показанной.
    if ! pluck "$id"; then
      restack
      notify_error "Уведомление $id не найдено (・_・;)"
      exit 1
    fi
    makoctl invoke -n "$id" "$key"
    restack
    silent_off
  fi
  # Действие "потреблено" — убираем уведомление без следа. Живой отправитель
  # часто сам закрывает его по ActionInvoked (CloseNotification), успевая
  # раньше нас и роняя запись в историю, — поэтому ждём мгновение и подчищаем,
  # где бы она ни оказалась.
  sleep 0.2
  if is_displayed "$id"; then
    makoctl dismiss -n "$id" -h
  elif in_history "$id"; then
    if pluck "$id"; then
      makoctl dismiss -n "$id" -h
    fi
    restack
    silent_off
  fi
  signal_waybar
}

cmd_clear() {
  trap silent_off EXIT
  local id
  silent_on
  # restore всегда снимает верхушку истории — идём по снимку ids сверху вниз.
  while read -r id; do
    makoctl restore
    makoctl dismiss -n "$id" -h
  done < <(makoctl history -j | jq -r '.[].id')
  silent_off
  signal_waybar
}

case "${1:-}" in
  status)  cmd_status ;;
  dnd)     shift; cmd_dnd "$@" ;;
  clear)   cmd_clear ;;
  delete)  shift; cmd_delete "$@" ;;
  invoke)  shift; cmd_invoke "$@" ;;
  actions) shift; cmd_actions "$@" ;;
  menu)    cmd_menu ;;
  text)    shift; cmd_text "$@" ;;
  nav)     shift; cmd_nav "$@" ;;
  *) notify_error "Usage: notify-center.sh status|dnd|clear|delete|invoke|actions|menu|text|nav ..."; exit 1 ;;
esac
