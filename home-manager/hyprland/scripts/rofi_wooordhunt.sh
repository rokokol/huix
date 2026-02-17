#!/usr/bin/env bash

INPUT="$*"
MARKER=$'\u200b'

if [[ "$INPUT" == *"$MARKER" ]]; then
  echo -n "${INPUT%"$MARKER"}" | wl-copy
  exit 0
fi

if [ -z "$INPUT" ]; then
  echo -en "\0message\x1fWooordhunt ultra parser\n"
  exit 0
fi

LINK="https://wooordhunt.ru/word/${INPUT,,}"
HTML=$(curl -s "$LINK")
TRANSCRIPTION=$(echo "$HTML" | pup '#us_tr_sound > .transcription text{}' | xargs)
MEANINGS_LIST=$(echo "$HTML" | pup '.t_inline_en text{}' | sed 's/, /\n/g' | grep .)

if [ -z "$MEANINGS_LIST" ]; then
  echo -en "\0message\x1f (,,#ﾟДﾟ)\n"
  echo "$LINK$MARKER"
  exit 0
else
  echo -en "\0message\x1f${TRANSCRIPTION}\n"
fi

while read -r line; do
  echo "$line$MARKER"
done <<<"$MEANINGS_LIST"
