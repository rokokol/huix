#!/usr/bin/env bash

set -euo pipefail

INPUT="$*"
MARKER=$'\u200b'

print_message() {
  printf '\0message\x1f%s\n' "$1"
}

if [[ "$INPUT" == *"$MARKER" ]]; then
  printf '%s' "${INPUT%"$MARKER"}" | wl-copy
  exit 0
fi

if [[ -z "$INPUT" ]]; then
  print_message "Wooordhunt ultra parser"
  exit 0
fi

PARSED_INPUT=$(printf '%s\n' "${INPUT,,}" | xargs)
LINK="https://wooordhunt.ru/word/${PARSED_INPUT}"

if HTML=$(curl -fsSL --max-time 5 "$LINK" 2>/dev/null); then
  :
else
  curl_status=$?

  case "$curl_status" in
    22) print_message "Ничего не найдено: ${PARSED_INPUT}" ;;
    28) print_message "Wooordhunt не ответил вовремя" ;;
    *) print_message "Не удалось получить ответ от Wooordhunt" ;;
  esac

  exit 0
fi

TRANSCRIPTION_US=$(printf '%s' "$HTML" | pup '#us_tr_sound > .transcription text{}' 2>/dev/null | xargs || true)
TRANSCRIPTION_UK=$(printf '%s' "$HTML" | pup '#uk_tr_sound > .transcription text{}' 2>/dev/null | xargs || true)
MEANINGS_LIST=$(printf '%s' "$HTML" | pup '.t_inline_en text{}' 2>/dev/null | sed 's/, /\n/g' | grep . || true)

if [[ -z "$MEANINGS_LIST" ]]; then
  print_message "Не удалось разобрать ответ Wooordhunt"
  exit 0
fi

if [[ -n "$TRANSCRIPTION_US" || -n "$TRANSCRIPTION_UK" ]]; then
  print_message "🇺🇸: ${TRANSCRIPTION_US} // 🇬🇧: ${TRANSCRIPTION_UK}"
fi

while IFS= read -r line; do
  printf '%s%s\n' "$line" "$MARKER"
done <<<"$MEANINGS_LIST"
