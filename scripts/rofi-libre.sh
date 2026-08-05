#!/usr/bin/env bash

SRC="$1"
TGT="$2"
shift 2
USER_INPUT="$*"

print_message() {
  printf '\0message\x1f%s\n' "$1"
}

# First run
if [[ -z "$USER_INPUT" ]]; then
  print_message "$SRC -> $TGT ⊂(‘ω’⊂ )))Σ≡=─༄༅༄༅༄༅༄༅༄༅"
  exit 0
fi

# Enter pressed on a ready translation
if [[ "$USER_INPUT" == "✔ "* ]]; then
  # Strip the "✔ " prefix and copy the clean text
  echo -n "${USER_INPUT#✔ }" | wl-copy
  exit 0
fi

# New text entered (translation needed)
translation=$(curl -s -L -m 15 -X POST "http://localhost:$LIBRE_TRANSLATE_PORT/translate" \
  -H "Content-Type: application/json" \
  -d "{\"q\": \"$USER_INPUT\", \"source\": \"$SRC\", \"target\": \"$TGT\", \"format\": \"text\"}" | jq -r '.translatedText')

if [[ -n "$translation" && "$translation" != "null" ]]; then
  # Print the result with a prefix so we can catch it on the next Enter
  print_message "From \"$USER_INPUT\" o(^▽^)o"
  echo "✔ $translation"
else
  echo "✖ Translation error ┬┴┬┴┤(･_├┬┴┬┴"
fi
