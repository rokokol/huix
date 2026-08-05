#!/usr/bin/env bash

SRC="$1"
TGT="$2"
shift 2
USER_INPUT="$*"

print_message() {
  printf '\0message\x1f%s\n' "$1"
}

# Errors are entries too, so Enter on one copies the text — keep the kaomoji out of it, in the message line
fail() {
  print_message "Translation failed ┬┴┬┴┤(･_├┬┴┬┴"
  echo "✖ $1"
  exit 0
}

# First run
if [[ -z "$USER_INPUT" ]]; then
  print_message "$SRC -> $TGT ⊂(‘ω’⊂ )))Σ≡=─༄༅༄༅༄༅༄༅༄༅"
  exit 0
fi

# Enter pressed on a ready translation or on an error — copy the text without the status prefix
case "$USER_INPUT" in
  "✔ "*)
    echo -n "${USER_INPUT#✔ }" | wl-copy
    exit 0
    ;;
  "✖ "*)
    echo -n "${USER_INPUT#✖ }" | wl-copy
    exit 0
    ;;
esac

# Set by nixos/services/tools/libre-translate.nix; a session started before that rebuild lacks it
if [[ -z "${LIBRE_TRANSLATE_PORT:-}" ]]; then
  fail "LIBRE_TRANSLATE_PORT is unset — re-login to pick up the session variable"
fi

# New text entered (translation needed)
# jq builds the payload: raw interpolation breaks on quotes, backslashes and newlines in the input
payload=$(jq -nc --arg q "$USER_INPUT" --arg source "$SRC" --arg target "$TGT" \
  '{ q: $q, source: $source, target: $target, format: "text" }')

# no -f: an HTTP error still carries a JSON .error worth showing, so only connect/timeout failures land here
if ! response=$(curl -s -L -m 15 -X POST "http://localhost:$LIBRE_TRANSLATE_PORT/translate" \
  -H "Content-Type: application/json" -d "$payload"); then
  fail "No answer on :$LIBRE_TRANSLATE_PORT — check systemctl status libretranslate"
fi

translation=$(jq -r '.translatedText // empty' <<<"$response")

if [[ -z "$translation" ]]; then
  fail "$(jq -r '.error // "Translation error"' <<<"$response")"
fi

# Print the result with a prefix so we can catch it on the next Enter
print_message "From \"$USER_INPUT\" o(^▽^)o"
echo "✔ $translation"
