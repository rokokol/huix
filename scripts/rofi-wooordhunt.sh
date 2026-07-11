#!/usr/bin/env bash

set -euo pipefail

INPUT="$*"
SENTINEL_NOOP="__wooordhunt_noop__"
# Ширины переноса (в символах) под окно 720px: WRAP_WIDTH — для строк-пояснений
# с отступом, HEAD_MAX — для строки «слово+глосса» до её переноса ниже.
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

# Печатаем длинное пояснение под переводом. Строки rofi однострочные, поэтому
# переносим вручную и выдаём по строке на элемент. Строки невыбираемые
# (пропускаются при навигации) и несут английское слово как значение для копии,
# так что случайная активация всё равно скопирует что-то осмысленное.
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
# wooordhunt использует подчёркивания для фраз из нескольких слов (например
# give_up); голый пробел в URL валит curl, поэтому схлопываем пробелы в «_».
URL_SLUG="${PARSED_INPUT// /_}"

fetch_html() {
  curl -fsSL --max-time 5 "$1" 2>/dev/null
}

# Разбираем блок произношения страницы слова в строки по одной на каждую
# произносимую форму: "<us-транскрипция>\t<uk-транскрипция>\t<часть речи>".
# Омографы (например transfer как сущ. и глагол) идут несколькими us/uk-блоками с
# общим id внутри <div class="trans_sound">, каждый предваряется меткой вроде
# "глагол произносится"; идём по блоку по порядку, сохраняя каждую форму и
# помечая её словом части речи с самого сайта (первый токен метки, пусто для
# слов с единственной формой).
# Аргументы: $1 = HTML.
parse_transcriptions() {
  printf '%s' "$1" | pup '.trans_sound json{}' 2>/dev/null | jq -r '
    .[].children
    | reduce .[] as $c ({forms: [], cur: null};
        if (($c.class // "") | startswith("es_div")) then
          (if .cur then .forms += [.cur] else . end)
          | .cur = {us: "", uk: "", pos:
              ([$c.children[]? | select((.class // "") == "es_i") | .text]
               | first // "" | gsub("^\\s+|\\s+$"; "") | split(" ")[0])}
        elif ($c.id // "") == "us_tr_sound" then
          (.cur //= {us: "", uk: "", pos: ""})
          | .cur.us = ([$c.children[]? | select((.class // "") == "transcription") | .text]
                        | first // "" | gsub("^\\s+|\\s+$"; ""))
        elif ($c.id // "") == "uk_tr_sound" then
          (.cur //= {us: "", uk: "", pos: ""})
          | .cur.uk = ([$c.children[]? | select((.class // "") == "transcription") | .text]
                        | first // "" | gsub("^\\s+|\\s+$"; ""))
        else . end)
    | (if .cur then .forms + [.cur] else .forms end)
    | .[] | select((.us | length > 0) or (.uk | length > 0))
    | [.us, .uk, .pos] | @tsv
  ' 2>/dev/null || true
}

# Рендерим разобранные строки транскрипций для показа. При нескольких формах
# (омографы) каждая транскрипция помечается частью речи, чтобы произношения
# различались, а не слипались молча; единственная форма показывается голой.
#   mode=head  -> американское, британское как фолбэк (аннотации RU->EN)
#   mode=us|uk -> только этот акцент (строка заголовка EN->RU)
format_transcriptions() {
  local rows="$1" mode="$2" us uk pos val part result="" count
  count=$(printf '%s\n' "$rows" | grep -c . || true)
  while IFS=$'\t' read -r us uk pos; do
    case "$mode" in
    head) val="${us:-$uk}" ;;
    us) val="$us" ;;
    uk) val="$uk" ;;
    esac
    val=$(printf '%s' "$val" | xargs)
    [[ -z "$val" ]] && continue
    part="$val"
    [[ "$count" -gt 1 && -n "$pos" ]] && part="${val} (${pos})"
    [[ -z "$result" ]] && result="$part" || result+=", ${part}"
  done < <(printf '%s\n' "$rows")
  printf '%s' "$result"
}

# US-транскрипция(и) для одного английского слова, напр. "house" -> |haʊs|, с
# британской как фолбэк. Аннотирует результаты RU->EN, у которых её нет.
fetch_transcription() {
  local slug="${1// /_}" html
  html=$(curl -fsSL --max-time 4 "https://wooordhunt.ru/word/${slug}" 2>/dev/null || true)
  format_transcriptions "$(parse_transcriptions "$html")" head
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

TR_ROWS=$(parse_transcriptions "$HTML")
TRANSCRIPTION_US=$(format_transcriptions "$TR_ROWS" us)
TRANSCRIPTION_UK=$(format_transcriptions "$TR_ROWS" uk)

if [[ -n "$TRANSCRIPTION_US" || -n "$TRANSCRIPTION_UK" ]]; then
  print_message "🇺🇸: ${TRANSCRIPTION_US} // 🇬🇧: ${TRANSCRIPTION_UK}"
elif [[ "$PARSED_INPUT" =~ [а-яА-ЯёЁ] ]]; then
  print_message "🇷🇺: ${ORIGINAL_INPUT} （´ω｀♡%）"
fi

if printf '%s' "$HTML" | grep -q 'class="sub_entry"'; then
  # Каждый sub_entry — одна группа значений: одно или несколько слов-синонимов
  # (например "exam / examination") с общим списком «— глоссы» и одним пояснением.
  # Разбираем посекционно через JSON, чтобы слова, глоссы и значения не съезжали —
  # плоский текст съезжает, когда в секции несколько слов или нет значения.
  SECTIONS=$(printf '%s' "$HTML" | pup 'section.sub_entry json{}' 2>/dev/null | jq -r '
    .[] |
      (.children[]? | select(.tag=="h3")) as $h3 |
      # Большинство слов лежит в ссылках <a>, но неслинкованные фразы (например
      # "baking oven") приходят голым <span>; берём и то, и то. Слово может быть
      # собственным текстом ссылки (transfer) или вложено на уровень в <span>
      # (risk -> <a><span>risk</span>), поэтому фолбэчимся на текст детей.
      # (Транскрипции лежат в отдельном блоке и тянутся по-словно ниже, никогда
      # внутри этих h3.)
      ([$h3.children[]?
         | select(.tag == "a" or .tag == "span")
         | (([.text] + [.children[]?.text]) | map(select(. != null and (. | test("\\S")))) | first // "")
         | select(. != "")
       ] | join(" / ")) as $words |
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

  # Тянем транскрипцию каждого английского слова параллельно (у страниц RU->EN их нет).
  TMPD=$(mktemp -d)
  trap 'rm -rf "$TMPD"' EXIT
  while IFS= read -r word; do
    word=$(printf '%s' "$word" | xargs)
    [[ -z "$word" ]] && continue
    (fetch_transcription "$word" >"$TMPD/$(trans_key "$word")" 2>/dev/null || true) &
  done < <(cut -f1 <<<"$SECTIONS" | sed 's@ / @\n@g' | sort -u)
  wait

  while IFS=$'\t' read -r words gloss meaning; do
    [[ -z "$words" ]] && continue
    gloss=$(printf '%s' "$gloss" | xargs)
    meaning=$(printf '%s' "$meaning" | xargs)

    # Первое слово — то, что копируем; собираем head с транскрипцией каждого слова.
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

    # Короткие списки глосс держим в строке со словом; длинные переносим на
    # строки с отступом ниже, чтобы выбираемая строка не вылезала за окно.
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
  # По одному переводу на span-ребёнок. HTML каждого span схлопываем вручную, а
  # не через `text{}`, потому что span может обернуть вводное слово в свой тег
  # (например "<i>(чрезмерно)</i> подчёркивать"); text{} выдал бы это двумя
  # строками и разбил одно значение на два элемента.
  TR_SPANS=$(printf '%s' "$HTML" | pup '.tr > span' 2>/dev/null | awk '
    /^<span/ { buf = ""; next }
    /^<\/span>/ {
      gsub(/<[^>]*>/, "", buf)
      gsub(/[[:space:]]+/, " ", buf)
      sub(/^ /, "", buf); sub(/ $/, "", buf)
      if (buf != "") print buf
      next
    }
    { buf = buf " " $0 }
  ' || true)
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

# Страницы фраз (например "эй там") несут перевод в .light_tr, а не в одном из
# структурированных селекторов выше.
if [[ -z "$MEANINGS_LIST" ]]; then
  MEANINGS_LIST=$(printf '%s' "$HTML" | pup '.light_tr text{}' 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep . || true)
fi

if [[ -z "$MEANINGS_LIST" ]]; then
  print_message "Не удалось разобрать ответ Wooordhunt ヽ(；▽；)ノ"
  print_fallback_entry
  exit 0
fi

printf '%s\n' "$MEANINGS_LIST" | sed 's/, /\n/g' | while IFS= read -r piece; do
  piece=$(printf '%s' "$piece" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -z "$piece" ]] && continue
  print_entry "$piece"
done
