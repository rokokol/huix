#!/usr/bin/env bash

# === НАСТРОЙКИ ===
MODE="$1"
ENGINE="google" # Самый быстрый. Можно менять на 'yandex' или 'libre'
shift 

if [ "$MODE" == "ru" ]; then
    LANGS="ru:en"
    PROMPT="🇷🇺 RU ➜ EN"
else
    LANGS="en:ru"
    PROMPT="🇺🇸 EN ➜ RU"
fi

# === КОПИРОВАНИЕ ===
if [ "$ROFI_RETV" = 1 ]; then
    echo -n "$@" | sed 's/^[ \t]*//;s/[ \t]*$//' | wl-copy
    exit 0
fi

# === ИНТЕРФЕЙС ===
if [ -z "$@" ]; then
    echo -en "\0prompt\x1f$PROMPT\n"
    exit 0
fi

# === ПОЛУЧЕНИЕ ПЕРЕВОДА (ОДИН ЗАПРОС) ===
# Мы передаем "$@" в конце, потому что это и есть текст для перевода.
# Флаги подобраны из твоей справки (help), чтобы отключить всё лишнее сразу.

trans -no-ansi \
    -e "$ENGINE" \
    -show-original n \
    -show-languages n \
    -show-prompt-message y \
    -show-original-phonetics y \
    -show-original-dictionary n \
    -show-translation y \
    -show-dictionary y \
    -show-alternatives y \
    "$LANGS" "$@" 
# | \
#     sed -r '
#         # Удаляем заголовки разделов, которые trans все равно любит писать
#         /^(Definitions|Translations|Synonyms|See also)/d;
#
#         # Удаляем названия частей речи (Noun, Verb и т.д.), если они мешают
#         # /^[[:space:]]*(Noun|Verb|Adjective|Adverb)/d;
#     ' | \
#     awk '
#     {
#         # Удаляем пробелы в начале и конце строки
#         gsub(/^[ \t]+|[ \t]+$/, "");
#     }
#     # Печатаем строку только если она не пустая и мы её еще не видели (убираем дубли)
#     length($0) > 0 && !seen[$0]++ { print }
#     '
