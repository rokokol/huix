#!/usr/bin/env bash

# Статусная строка Claude Code: путь к скрипту прописан в statusLine.command
# общего settings.json (~/.local/share/claude-shared). На вход прилетает JSON
# сессии в stdin, на выход — одна строка.

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_hour_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Домашний каталог схлопываем в ~ (через case, без неоднозначных подстановок)
case "$cwd" in
"$HOME") dir="~" ;;
"$HOME"/*) dir="~${cwd#"$HOME"}" ;;
*) dir="$cwd" ;;
esac

user=$(whoami)

# Глиф NixOS () + юзер жирным синим (как os+username в Starship), дальше путь,
# разделитель, модель и заполненность контекстного окна.
printf '\033[1;34m %s\033[0m || %s' "$user" "$dir"

if [ -n "$model" ] || [ -n "$used" ]; then
  printf '   ·  '
fi

[ -n "$model" ] && printf '%s' "$model"

if [ -n "$used" ]; then
  ctx=$(LC_ALL=C printf "%.0f" "$used")
  [ -n "$model" ] && printf ' · '
  printf 'ctx:%s%%' "$ctx"
fi

# Лимиты показываем как остаток, а не как расход — так понятнее, сколько ещё есть.
if [ -n "$five_hour_used" ]; then
  remaining=$(LC_ALL=C awk "BEGIN {printf \"%.0f\", 100 - $five_hour_used}")
  printf ' · 5h:%s%%' "$remaining"
fi

if [ -n "$seven_day_used" ]; then
  remaining_week=$(LC_ALL=C awk "BEGIN {printf \"%.0f\", 100 - $seven_day_used}")
  printf ' · 7d:%s%%' "$remaining_week"
fi

printf '\n'
