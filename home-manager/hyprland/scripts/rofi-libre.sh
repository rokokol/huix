#!/usr/bin/env bash

SRC="$1"
TGT="$2"
shift 2
USER_INPUT="$*"

# 1. Сценарий: Первый запуск (отрисовка)
if [[ -z "$USER_INPUT" ]]; then
  exit 0
fi

# 2. Сценарий: Нажат Enter на готовом переводе
if [[ "$USER_INPUT" == "✔ "* ]]; then
  # Убираем префикс "✔ " и копируем чистый текст
  echo -n "${USER_INPUT#✔ }" | wl-copy
  exit 0
fi

# 3. Сценарий: Введен новый текст (нужен перевод)
translation=$(curl -s -L -X POST "http://localhost:5000/translate" \
  -H "Content-Type: application/json" \
  -d "{\"q\": \"$USER_INPUT\", \"source\": \"$SRC\", \"target\": \"$TGT\", \"format\": \"text\"}" | jq -r '.translatedText')

if [[ -n "$translation" && "$translation" != "null" ]]; then
  # Выводим результат с префиксом, чтобы поймать его при следующем Enter
  echo "✔ $translation"
else
  echo "✖ Ошибка перевода ┬┴┬┴┤(･_├┬┴┬┴"
fi
