#!/usr/bin/env bash

# Claude Code status line: the path to this script is set in statusLine.command
# of the shared settings.json (~/.local/share/claude-shared). It receives the
# session JSON on stdin and emits a single line

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_hour_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Collapse the home directory to ~ (via case, no ambiguous substitutions)
case "$cwd" in
"$HOME") dir="~" ;;
"$HOME"/*) dir="~${cwd#"$HOME"}" ;;
*) dir="$cwd" ;;
esac

user=$(whoami)

# NixOS glyph () + user in bold blue (like os+username in Starship), then the
# path, a separator, the model and the context-window fill level
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

# Show limits as the remainder rather than the spend — clearer how much is left
if [ -n "$five_hour_used" ]; then
  remaining=$(LC_ALL=C awk "BEGIN {printf \"%.0f\", 100 - $five_hour_used}")
  printf ' · 5h:%s%%' "$remaining"
fi

if [ -n "$seven_day_used" ]; then
  remaining_week=$(LC_ALL=C awk "BEGIN {printf \"%.0f\", 100 - $seven_day_used}")
  printf ' · 7d:%s%%' "$remaining_week"
fi

printf '\n'
