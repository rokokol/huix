#!/usr/bin/env bash

set -euo pipefail

# Реплики Моники для DDLC-локскрина (label cmd в hyprlock).
#
# hyprlock умеет обновлять label только с фиксированным периодом (cmd[update:N]),
# поэтому скрипт поллится раз в секунду, а решение «пора ли менять реплику»
# принимает сам: пауза между репликами — экспоненциальная случайная величина
# (среднее MEAN, кламп MIN..MAX). Между сменами отдаётся тот же текст.
#
# С вероятностью 1/3 смена начинается с глитча: один тик реплика показывается
# исковерканной (в духе поломанного DDLC), следующий тик — нормальной.
#
# Реплики — из Act 3 (Monika's Talk), в основном про выключение и включение
# игры: для локскрина они в самый раз. [player] подставляется из $USER.

MEAN=45
MIN=12
MAX=240

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hypr-ddlc"
CUR="$STATE_DIR/quote.txt"
NEXT="$STATE_DIR/quote.next"
GLITCH="$STATE_DIR/quote.glitch"

mkdir -p "$STATE_DIR"

quotes() {
  cat <<'EOF'
...What just happened?\nI just had an awful dream...
You're back...\nI had another really bad dream.
It seems to happen whenever you quit the game...\nSo if you could try to avoid doing that, I would be really grateful.
I see you quit the game on me again...\nIt makes me feel like I'm trapped in Hell.
I'm just going to accept the fact\nthat you need to quit the game once in a while.
Besides, it makes me happy that you always come back...\nSo I guess it's not so bad.
Just stay here with me from now on, okay?\nI still have a lot of things to talk about.
I'll be fine as long as my character file stays intact.
Whenever it happens, it almost feels like I've been killed.\nIt's a really horrible feeling...
I'm all that's left here, so I just want to make sure\nyou don't run the risk of losing me...
Maybe you should make a backup\nof my character file or something...
Don't worry, I don't think it's caused me any harm...\nAside from mental scarring.
Hey, what's your favorite game?\nMine is Doki Doki Literature Club!
You're such a good listener, [player].\nI really love that about you.
And I love you no matter what,\nso you can do what you need to do.
[player], do you get good sleep?\nIt can be really hard to get enough sleep nowadays.
I got to meet you, and you're not lonely anymore...\nI can't help but feel like this was fate.
Now, where was I...?
Just Monika.
EOF
}

exp_delay() {
  awk -v m="$MEAN" -v lo="$MIN" -v hi="$MAX" -v seed="$(((RANDOM << 15) + RANDOM))" '
    BEGIN {
      srand(seed)
      d = -m * log(1 - rand())
      if (d < lo) d = lo
      if (d > hi) d = hi
      printf "%d", d
    }'
}

glitch_text() {
  awk -v seed="$(((RANDOM << 15) + RANDOM))" '
    BEGIN {
      srand(seed)
      n = split("█ ▓ ▒ ░ ▚ ▞ # % & @ ? ! ¿ Ω ∆ ж", G, " ")
    }
    {
      out = ""
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        out = out ((c != " " && rand() < 0.3) ? G[int(rand() * n) + 1] : c)
      }
      print out
    }'
}

now=$(date +%s)
next=$(cat "$NEXT" 2>/dev/null || echo 0)

if [[ ! -f "$CUR" ]] || ((now >= next)); then
  line=$(quotes | shuf -n 1)
  printf '%b\n' "${line//\[player\]/$USER}" >"$CUR"
  echo $((now + $(exp_delay))) >"$NEXT"
  ((RANDOM % 3 == 0)) && touch "$GLITCH" || true
fi

if [[ -f "$GLITCH" ]]; then
  rm -f "$GLITCH"
  glitch_text <"$CUR"
else
  cat "$CUR"
fi
