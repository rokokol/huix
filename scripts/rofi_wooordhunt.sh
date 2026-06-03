#!/usr/bin/env bash

set -euo pipefail

INPUT="$*"
SENTINEL_NOOP="__wooordhunt_noop__"

print_message() {
  printf '\0message\x1f%s\n' "$1"
}

print_entry() {
  local display="$1"
  local copy_value="${2:-$1}"
  printf '%s\0info\x1f%s\n' "$display" "$copy_value"
}

print_hint() {
  printf '   %s\0info\x1f%s\n' "$1" "$1"
}

print_fallback_entry() {
  printf '%s\0info\x1f%s\n' "---" "$SENTINEL_NOOP"
}

if [[ -n "${ROFI_INFO:-}" ]]; then
  if [[ "$ROFI_INFO" != "$SENTINEL_NOOP" ]]; then
    printf '%s' "$ROFI_INFO" | wl-copy
  fi
  exit 0
fi

if [[ -z "$INPUT" ]]; then
  print_message "Wooordhunt ultra parser （´ω｀♡%）"
  exit 0
fi

ORIGINAL_INPUT=$(printf '%s\n' "$INPUT" | xargs)
PARSED_INPUT="${ORIGINAL_INPUT,,}"
# wooordhunt uses underscores for multi-word phrases (e.g. give_up); a raw
# space in the URL makes curl fail outright, so collapse spaces to underscores.
URL_SLUG="${PARSED_INPUT// /_}"

fetch_html() {
  curl -fsSL --max-time 5 "$1" 2>/dev/null
}

HTML=""
if HTML=$(fetch_html "https://wooordhunt.ru/переводы/${URL_SLUG}"); then
  :
else
  if HTML=$(fetch_html "https://wooordhunt.ru/word/${URL_SLUG}"); then
    :
  else
    last_status=$?
    case "$last_status" in
    22) print_message "Ничего не найдено: ${PARSED_INPUT} (╯°□°）╯︵ ┻━┻" ;;
    28) print_message "Wooordhunt не ответил вовремя ٩(ó｡ò۶ ♡)))♬" ;;
    *) print_message "Не удалось получить ответ от Wooordhunt |_・)" ;;
    esac
    print_fallback_entry
    exit 0
  fi
fi

TRANSCRIPTION_US=$(printf '%s' "$HTML" | pup '#us_tr_sound > .transcription text{}' 2>/dev/null | xargs || true)
TRANSCRIPTION_UK=$(printf '%s' "$HTML" | pup '#uk_tr_sound > .transcription text{}' 2>/dev/null | xargs || true)

if [[ -n "$TRANSCRIPTION_US" || -n "$TRANSCRIPTION_UK" ]]; then
  print_message "🇺🇸: ${TRANSCRIPTION_US} // 🇬🇧: ${TRANSCRIPTION_UK}"
elif [[ "$PARSED_INPUT" =~ [а-яА-ЯёЁ] ]]; then
  print_message "🇷🇺: ${ORIGINAL_INPUT}"
fi

if printf '%s' "$HTML" | grep -q 'class="sub_entry"'; then
  H3_RAW=$(printf '%s' "$HTML" | pup 'section.sub_entry h3 text{}' 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep . || true)
  MEANINGS=$(printf '%s' "$HTML" | pup 'section.sub_entry p.meaning text{}' 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep . || true)

  if [[ -z "$H3_RAW" ]]; then
    print_message "Не удалось разобрать ответ Wooordhunt (T＿T)"
    print_fallback_entry
    exit 0
  fi

  H3_PAIRS=$(printf '%s\n' "$H3_RAW" | paste -d'|' - -)

  paste -d$'\t' <(printf '%s\n' "$H3_PAIRS") <(printf '%s\n' "$MEANINGS") | while IFS=$'\t' read -r pair meaning; do
    engword="${pair%%|*}"
    rest="${pair#*|}"
    rest="${rest# }"
    rest="${rest#— }"
    rest="${rest#— }"
    if [[ -n "$rest" && "$rest" != "$engword" ]]; then
      print_entry "${engword} — ${rest}" "$engword"
    else
      print_entry "$engword" "$engword"
    fi
    if [[ -n "$meaning" ]]; then
      print_hint "$meaning"
    fi
  done
  exit 0
fi

MEANINGS_LIST=""
if printf '%s' "$HTML" | grep -q 'class="t_inline_en"'; then
  MEANINGS_LIST=$(printf '%s' "$HTML" | pup '.t_inline_en text{}' 2>/dev/null | xargs)
else
  TR_SPANS=$(printf '%s' "$HTML" | pup '.tr > span text{}' 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep . || true)
  if [[ -n "$TR_SPANS" ]]; then
    MEANINGS_LIST="$TR_SPANS"
  elif printf '%s' "$HTML" | grep -q 'class="t_inline"'; then
    MEANINGS_LIST=$(printf '%s' "$HTML" | pup 'p.t_inline:first-of-type text{}' 2>/dev/null | xargs)
  else
    TR_TEXT=$(printf '%s' "$HTML" | pup '.tr text{}' 2>/dev/null | sed -n 's/^[[:space:]]*-[[:space:]]*//p' || true)
    if [[ -n "$TR_TEXT" ]]; then
      MEANINGS_LIST="$TR_TEXT"
    fi
  fi
fi

# Phrase pages (e.g. "эй там") carry the translation in .light_tr instead of
# any of the structured selectors above.
if [[ -z "$MEANINGS_LIST" ]]; then
  MEANINGS_LIST=$(printf '%s' "$HTML" | pup '.light_tr text{}' 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep . || true)
fi

if [[ -z "$MEANINGS_LIST" ]]; then
  print_message "Не удалось разобрать ответ Wooordhunt (T＿T)"
  print_fallback_entry
  exit 0
fi

printf '%s\n' "$MEANINGS_LIST" | sed 's/, /\n/g' | while IFS= read -r piece; do
  piece=$(printf '%s' "$piece" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -z "$piece" ]] && continue
  print_entry "$piece"
done
