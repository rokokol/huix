#!/usr/bin/env bash

SRC="$1"
TGT="$2"
shift 2
USER_INPUT="$*"

print_message() {
  printf '\0message\x1f%s\n' "$1"
}

# Первый запуск
if [[ -z "$USER_INPUT" ]]; then
  print_message "$SRC -> $TGT ⊂(‘ω’⊂ )))Σ≡=─༄༅༄༅༄༅༄༅༄༅"
  exit 0
fi

# Нажат Enter на готовом переводе
if [[ "$USER_INPUT" == "✔ "* ]]; then
  # Убираем префикс "✔ " и копируем чистый текст
  echo -n "${USER_INPUT#✔ }" | wl-copy
  exit 0
fi

# Введен новый текст (нужен перевод)
translation=$(curl -s -L -X POST "http://localhost:$LIBRE_TRANSLATE_PORT/translate" \
  -H "Content-Type: application/json" \
  -d "{\"q\": \"$USER_INPUT\", \"source\": \"$SRC\", \"target\": \"$TGT\", \"format\": \"text\"}" | jq -r '.translatedText')

if [[ -n "$translation" && "$translation" != "null" ]]; then
  # Выводим результат с префиксом, чтобы поймать его при следующем Enter
  print_message "From \"$USER_INPUT\" o(^▽^)o"
  echo "✔ $translation"
else
  echo "✖ Ошибка перевода ┬┴┬┴┤(･_├┬┴┬┴"
fi
