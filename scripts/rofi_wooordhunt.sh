#!/usr/bin/env bash

set -euo pipefail

INPUT="$*"
SENTINEL_NOOP="__wooordhunt_noop__"
# Wrap widths (in chars) tuned to the 720px window: WRAP_WIDTH for indented
# explanation rows, HEAD_MAX for the word+gloss row before it gets wrapped below.
WRAP_WIDTH=54
HEAD_MAX=58

print_message() {
  printf '\0message\x1f%s\n' "$1"
}

print_entry() {
  local display="$1"
  local copy_value="${2:-$1}"
  printf '%s\0info\x1f%s\n' "$display" "$copy_value"
}

print_fallback_entry() {
  printf '%s\0info\x1f%s\n' "---" "$SENTINEL_NOOP"
}

# Print a long explanation beneath its translation. rofi rows are single-line,
# so we wrap by hand and emit one row per line. The rows are nonselectable
# (skipped while navigating) and carry the english word as copy value, so an
# accidental activation still copies something sensible.
print_hint_lines() {
  local text="$1" copy_value="$2" line
  while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf '   %s\0info\x1f%s\x1fnonselectable\x1ftrue\n' "$line" "$copy_value"
  done < <(printf '%s\n' "$text" | fold -s -w "$WRAP_WIDTH")
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

# US transcription for a single english word, e.g. "house" -> |haʊs|.
# Used to annotate RU->EN results, which carry no transcription themselves.
fetch_transcription() {
  local slug="${1// /_}"
  curl -fsSL --max-time 4 "https://wooordhunt.ru/word/${slug}" 2>/dev/null |
    pup '#us_tr_sound > .transcription text{}' 2>/dev/null | xargs || true
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
  print_message "🇷🇺: ${ORIGINAL_INPUT} （´ω｀♡%）"
fi

if printf '%s' "$HTML" | grep -q 'class="sub_entry"'; then
  # Each sub_entry is one meaning group: one or more synonym words (e.g.
  # "exam / examination") sharing a "— glosses" list and one explanation.
  # Parse per section via JSON so words, glosses and meanings stay aligned —
  # a flat text dump misaligns whenever a section has several words or no meaning.
  SECTIONS=$(printf '%s' "$HTML" | pup 'section.sub_entry json{}' 2>/dev/null | jq -r '
    .[] |
      (.children[]? | select(.tag=="h3")) as $h3 |
      ([$h3.children[]? | select(.tag=="a") | .text] | join(" / ")) as $words |
      (($h3.text // "") | (capture("—\\s*(?<g>.*)")?.g) // "") as $gloss |
      ((.children[]? | select(.tag=="p" and ((.class // "") | test("meaning"))) | .text) // "") as $meaning |
      [$words, $gloss, $meaning] | @tsv
  ' 2>/dev/null || true)

  if [[ -z "$SECTIONS" ]]; then
    print_message "Не удалось разобрать ответ Wooordhunt (T＿T)"
    print_fallback_entry
    exit 0
  fi

  trans_key() {
    local s="${1// /_}"
    printf '%s' "${s//[^a-zA-Z0-9_]/_}"
  }

  # Fetch every english word's transcription in parallel (RU->EN pages have none).
  TMPD=$(mktemp -d)
  trap 'rm -rf "$TMPD"' EXIT
  while IFS= read -r word; do
    word=$(printf '%s' "$word" | xargs)
    [[ -z "$word" ]] && continue
    (fetch_transcription "$word" >"$TMPD/$(trans_key "$word")" 2>/dev/null || true) &
  done < <(printf '%s' "$HTML" | pup 'section.sub_entry h3 a text{}' 2>/dev/null | sort -u)
  wait

  while IFS=$'\t' read -r words gloss meaning; do
    [[ -z "$words" ]] && continue
    gloss=$(printf '%s' "$gloss" | xargs)
    meaning=$(printf '%s' "$meaning" | xargs)

    # First word is what we copy; build the head with each word's transcription.
    mapfile -t wlist < <(printf '%s\n' "$words" | sed 's@ / @\n@g')
    copy_word=$(printf '%s' "${wlist[0]}" | xargs)
    head=""
    for w in "${wlist[@]}"; do
      w=$(printf '%s' "$w" | xargs)
      [[ -z "$w" ]] && continue
      tr=$(cat "$TMPD/$(trans_key "$w")" 2>/dev/null || true)
      part="$w"
      [[ -n "$tr" ]] && part+=" ${tr}"
      [[ -z "$head" ]] && head="$part" || head+=" / ${part}"
    done

    # Keep short gloss lists inline with the word; wrap long ones onto indented
    # rows below so the selectable row never overflows the window.
    gloss_below=""
    if [[ -n "$gloss" ]]; then
      if ((${#head} + ${#gloss} + 3 <= HEAD_MAX)); then
        head+=" — ${gloss}"
      else
        gloss_below="$gloss"
      fi
    fi
    print_entry "$head" "$copy_word"
    [[ -n "$gloss_below" ]] && print_hint_lines "$gloss_below" "$copy_word"
    [[ -n "$meaning" ]] && print_hint_lines "$meaning" "$copy_word"
  done < <(printf '%s\n' "$SECTIONS")
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
