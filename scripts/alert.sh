#!/usr/bin/env bash
# Run from a store copy by nixos/services/system/monitoring/alert-mail.nix, as root, from
# alert-mail@, the sync, reconcile and digest units and each delivery. The open problems are one
# directory each under $ALERT_STATE/open, so a raise from two units at once cannot merge them; a
# lock keeps the check and the write of one key together. Delivery happens outside the lock, as
# a mail can wait a day for its relay
# Needs bash 3.2 and GNU coreutils: the host it runs on is NixOS
set -euo pipefail

usage() {
  cat <<'EOF'
alert.sh — keep the open problems of this host, and tell the owner when one opens or closes

  alert.sh raise [-q] KEY SUBJECT < BODY   open a problem, or update the one open under KEY
  alert.sh clear KEY                       close the problem open under KEY
  alert.sh sync SOURCE FILE                make the problems under SOURCE:… the causes in FILE
  alert.sh deliver FILE                    send a message that waits in the outbox
  alert.sh reconcile                       close each unit problem whose unit recovered, and
                                           open or close the reboot problem
  alert.sh digest                          mail every open problem, when there is one
  alert.sh list                            print the open problems, one line each

  -q   open the problem in silence: it waits for the digest, and its close is silent too

A problem that opens or closes is mailed to root, sent to the owner's Telegram and handed to
the agent. A problem raised again while open only updates its body. KEY names one problem and
is a file name: letters, digits and . _ : @ - only. A KEY of the form unit:NAME is closed by
reconcile once systemd reports NAME active, or inactive with the result success. The reboot
problem is open while the kernel, initrd or modules of the current system differ from the
booted one

sync reads FILE, one cause a line: a CAUSE made of the same characters as a KEY, a tab, and
its SUBJECT. Each cause is a problem under SOURCE:CAUSE, opened and sent once; each problem
under SOURCE that FILE no longer lists is closed. An empty FILE closes them all; a FILE that
cannot be read, or a cause that is not a key, changes nothing and fails

list prints KEY, the time it opened, and SUBJECT, separated by tabs. Every change is also a
line in $ALERT_STATE/journal: time, OPEN, UPDATE or RESOLVED, KEY, SUBJECT, by tabs

Environment:
  ALERT_STATE          the state directory (required)
  ALERT_MAIL           the command that sends a mail read on stdin (required)
  ALERT_TELEGRAM_API   the Bot API base URL; empty means no Telegram
  ALERT_TELEGRAM_TOKEN, ALERT_TELEGRAM_CHAT  files with the bot's token and the owner's chat id;
                       while either cannot be read, only the mail goes
  ALERT_NOTIFY         the command that hands one line of text to the agent; empty means none
  ALERT_METRICS        a file for the open problems as Prometheus text; empty means none
  ALERT_SPAWN          the command that starts "deliver FILE" apart, given FILE; empty means
                       each message is sent in place. With it, a message waits in
                       $ALERT_STATE/outbox until its delivery ends, and reconcile hands on one
                       that a reboot left there
  ALERT_BOOTED, ALERT_CURRENT  the booted and current system (default /run/booted-system and
                       /run/current-system)
Exit 0 done, 1 when the state cannot be written, 2 on a usage error
EOF
}

fail() { # the thing asked about is wrong
  printf 'alert.sh: %s\n' "$1" >&2
  exit 1
}

die() { # the request itself is wrong
  printf 'alert.sh: %s\n' "$1" >&2
  exit 2
}

state=${ALERT_STATE:-}
host=$(uname -n)

setup() {
  [ -n "$state" ] || die "ALERT_STATE is not set"
  [ -n "${ALERT_MAIL:-}" ] || die "ALERT_MAIL is not set"
  mkdir -p -- "$state/open" || fail "cannot write $state"
}

check_key() {
  case "$1" in
    '' | .* | *[!A-Za-z0-9._:@-]*) die "not a usable key: $1" ;;
  esac
}

# journal WHAT KEY SUBJECT
journal() {
  printf '%s\t%s\t%s\t%s\n' "$(date -Iseconds)" "$1" "$2" "$3" >>"$state/journal"
}

# with_lock COMMAND... — runs the command while no other alert.sh changes the state, then
# rewrites the metrics from the state it left
with_lock() {
  exec 9>>"$state/lock"
  flock 9
  "$@"
  write_metrics
  flock -u 9
}

# write_metrics — written beside $ALERT_METRICS and renamed over it, so a collector never reads
# half a file
write_metrics() {
  [ -n "${ALERT_METRICS:-}" ] || return 0
  local tmp=$ALERT_METRICS.tmp.$$ dir
  mkdir -p -- "$(dirname -- "$ALERT_METRICS")"
  {
    printf '# HELP alert_open_since_seconds Time the open problem under the key opened\n'
    printf '# TYPE alert_open_since_seconds gauge\n'
    for dir in "$state/open"/*; do
      [ -d "$dir" ] || continue
      printf 'alert_open_since_seconds{key="%s"} %s\n' "${dir##*/}" "$(cat -- "$dir/since")"
    done
  } >"$tmp"
  mv -f -- "$tmp" "$ALERT_METRICS"
}

# send SUBJECT BODY [ASK] — with a spawner, the message goes to the outbox as a file and the
# spawner starts its delivery apart, so a mail that waits a day for its relay holds up no other
# alert; without one it is delivered here. ASK 1 asks the agent to look into the problem
send() {
  if [ -z "${ALERT_SPAWN:-}" ]; then
    deliver_now "$1" "$2" "${3:-0}"
    return
  fi
  local file
  mkdir -p -- "$state/outbox"
  file=$(mktemp "$state/outbox/XXXXXXXX")
  printf '%s\n%s\n%s\n' "$1" "${3:-0}" "$2" >"$file"
  $ALERT_SPAWN "$file" || printf 'alert.sh: the delivery did not start: %s\n' "$1" >&2
}

# deliver_now SUBJECT BODY ASK — Telegram, the agent and the mail. A channel that fails is
# reported and the others still go. Telegram retries for ten minutes beside the mail, which may
# retry for a day, so neither one waits for the other
deliver_now() {
  local subject=$1 body=$2 ask=$3 note
  telegram "$subject" "$body" &
  if [ -n "${ALERT_NOTIFY:-}" ]; then
    note=$subject
    if [ "$ask" = 1 ]; then
      note+=" — look into it with the station-health skill and tell the owner what you found"
    fi
    "$ALERT_NOTIFY" "$note" || printf 'alert.sh: the agent did not take: %s\n' "$subject" >&2
  fi
  {
    printf 'To: root\n'
    printf 'Subject: %s\n' "$subject"
    printf 'MIME-Version: 1.0\n'
    printf 'Content-Type: text/plain; charset=UTF-8\n'
    printf 'Content-Transfer-Encoding: 8bit\n'
    printf '\n'
    printf '%s\n' "$body"
  } | $ALERT_MAIL
  wait
}

# telegram SUBJECT BODY
telegram() {
  local subject=$1 body=$2 token chat answer
  if [ -n "${ALERT_TELEGRAM_API:-}" ]; then
    if token=$(cat -- "${ALERT_TELEGRAM_TOKEN:-}" 2>/dev/null) &&
      chat=$(cat -- "${ALERT_TELEGRAM_CHAT:-}" 2>/dev/null); then
      # Telegram refuses a text over 4096 characters. Its answer to a refusal says why, as in
      # a chat that never started the bot, and holds no token
      answer=$(mktemp)
      curl --silent --show-error --fail-with-body --max-time 30 \
        --retry 5 --retry-all-errors --retry-max-time 600 -o "$answer" \
        --data-urlencode "chat_id=$chat" \
        --data-urlencode "text=$(printf '%s%s' "$subject" "${body:+$'\n\n'$body}" | head -c 4000)" \
        "$ALERT_TELEGRAM_API/bot$token/sendMessage" ||
        printf 'alert.sh: Telegram did not take: %s (%s)\n' "$subject" "$(cat -- "$answer")" >&2
      rm -f -- "$answer"
    else
      printf 'alert.sh: no Telegram credentials, so only the mail goes\n' >&2
    fi
  fi
}

# open_key QUIET KEY SUBJECT BODY — sets $opened to 1 when the problem is new
open_key() {
  local dir=$state/open/$2
  opened=0
  if [ -d "$dir" ]; then
    journal UPDATE "$2" "$3"
  else
    mkdir -- "$dir"
    date +%s >"$dir/since"
    [ "$1" = 1 ] && : >"$dir/quiet"
    opened=1
    journal OPEN "$2" "$3"
  fi
  printf '%s\n' "$3" >"$dir/subject"
  printf '%s\n' "$4" >"$dir/body"
}

# close_key KEY — sets $closed to 1 and $subject, $quiet when a problem was open
close_key() {
  local dir=$state/open/$1
  closed=0
  [ -d "$dir" ] || return 0
  subject=$(cat -- "$dir/subject")
  quiet=0
  [ -e "$dir/quiet" ] && quiet=1
  rm -r -- "$dir"
  closed=1
  journal RESOLVED "$1" "$subject"
}

raise() {
  local q=0 opened
  if [ "${1:-}" = -q ]; then
    q=1
    shift
  fi
  (($# == 2)) || die "raise takes [-q] KEY SUBJECT"
  check_key "$1"
  local body
  body=$(cat)
  with_lock open_key "$q" "$1" "$2" "$body"
  if ((opened && !q)); then
    send "$2" "$body" 1
  fi
}

clear_key() {
  local closed subject quiet
  with_lock close_key "$1"
  if ((closed && !quiet)); then
    # The subject is a raw header, so it stays ASCII beside what the caller wrote
    send "$subject (resolved)" "The problem under $1 is gone."
  fi
}

cmd_raise() {
  setup
  raise "$@"
}

cmd_clear() {
  (($# == 1)) || die "clear takes KEY"
  check_key "$1"
  setup
  clear_key "$1"
}

# The list is read whole and checked before anything changes, so a list cut short or broken
# never closes a problem that is still there
cmd_sync() {
  (($# == 2)) || die "sync takes SOURCE FILE"
  check_key "$1"
  setup
  local source=$1 file=$2 line cause subject keys="" dir key
  [ -r "$file" ] || fail "cannot read $file"
  local causes
  causes=$(cat -- "$file") || fail "cannot read $file"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    cause=${line%%$'\t'*}
    case "$cause" in
      '' | .* | *[!A-Za-z0-9._:@-]*) fail "$file: not a usable cause: $cause" ;;
    esac
    keys+=" $source:$cause "
  done <<<"$causes"

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    cause=${line%%$'\t'*}
    subject=${line#*$'\t'}
    [ "$subject" != "$line" ] || subject=$cause
    # A cause already open stays as it is, or each run of the check would add to the journal
    [ ! -d "$state/open/$source:$cause" ] || continue
    # The subject is all a cause says, so the body stays empty rather than saying it twice
    raise "$source:$cause" "$subject" </dev/null
  done <<<"$causes"

  for dir in "$state/open/$source":*; do
    [ -d "$dir" ] || continue
    key=${dir##*/}
    case "$keys" in *" $key "*) continue ;; esac
    clear_key "$key"
  done
}

cmd_reconcile() {
  (($# == 0)) || die "reconcile takes nothing"
  setup
  local dir key unit active result file
  # A message whose delivery a reboot cut short is handed on again
  if [ -n "${ALERT_SPAWN:-}" ]; then
    for file in "$state/outbox"/*; do
      [ -f "$file" ] || continue
      $ALERT_SPAWN "$file" || printf 'alert.sh: the delivery did not start: %s\n' "$file" >&2
    done
  fi
  for dir in "$state/open"/unit:*; do
    [ -d "$dir" ] || continue
    key=${dir##*/}
    unit=${key#unit:}
    active=$(systemctl show -P ActiveState "$unit" || true)
    result=$(systemctl show -P Result "$unit" || true)
    if [ "$active" = active ] || { [ "$active" = inactive ] && [ "$result" = success ]; }; then
      clear_key "$key"
    fi
  done

  local booted=${ALERT_BOOTED:-/run/booted-system} current=${ALERT_CURRENT:-/run/current-system}
  local part due=0 seen=0
  for part in kernel initrd kernel-modules; do
    [ -e "$booted/$part" ] && [ -e "$current/$part" ] || continue
    seen=1
    [ "$(readlink -f -- "$booted/$part")" = "$(readlink -f -- "$current/$part")" ] || due=1
  done
  # The metrics live in RAM, so the first reconcile after a boot writes them even with no change
  with_lock :
  ((seen)) || return 0
  if ((due)); then
    printf 'The current system has a kernel, initrd or modules that %s did not boot.\n' "$host" |
      raise -q reboot "[$host] a reboot is due"
  else
    clear_key reboot
  fi
}

cmd_digest() {
  (($# == 0)) || die "digest takes nothing"
  setup
  local dir count=0 report="" since
  for dir in "$state/open"/*; do
    [ -d "$dir" ] || continue
    count=$((count + 1))
    since=$(date -d "@$(cat -- "$dir/since")" '+%Y-%m-%d %H:%M')
    report+="== $(cat -- "$dir/subject") (open since $since)"$'\n'"$(cat -- "$dir/body")"$'\n\n'
  done
  ((count)) || return 0
  {
    printf 'To: root\n'
    printf 'Subject: [%s] %d unresolved\n' "$host" "$count"
    printf 'MIME-Version: 1.0\n'
    printf 'Content-Type: text/plain; charset=UTF-8\n'
    printf 'Content-Transfer-Encoding: 8bit\n'
    printf '\n'
    printf '%s' "$report"
  } | $ALERT_MAIL
}

# A delivery holds a lock on its file, so a message that a reconcile hands on again while it is
# still on its way is not sent twice
cmd_deliver() {
  (($# == 1)) || die "deliver takes FILE"
  setup
  local file=$1 subject ask body
  [ -r "$file" ] || fail "cannot read $file"
  exec 8<"$file"
  flock -n 8 || return 0
  {
    IFS= read -r subject
    IFS= read -r ask
    body=$(cat)
  } <&8
  deliver_now "$subject" "$body" "$ask"
  rm -f -- "$file"
}

cmd_list() {
  (($# == 0)) || die "list takes nothing"
  [ -n "$state" ] || die "ALERT_STATE is not set"
  local dir
  for dir in "$state/open"/*; do
    [ -d "$dir" ] || continue
    printf '%s\t%s\t%s\n' "${dir##*/}" "$(date -d "@$(cat -- "$dir/since")" -Iseconds)" \
      "$(cat -- "$dir/subject")"
  done
}

cmd="${1:-}"
(($# == 0)) || shift
case "$cmd" in
  raise) cmd_raise "$@" ;;
  clear) cmd_clear "$@" ;;
  sync) cmd_sync "$@" ;;
  deliver) cmd_deliver "$@" ;;
  reconcile) cmd_reconcile "$@" ;;
  digest) cmd_digest "$@" ;;
  list) cmd_list "$@" ;;
  -h | --help | help) usage ;;
  '')
    usage >&2
    exit 2
    ;;
  *)
    printf 'alert.sh: no such subcommand: %s\n\n' "$cmd" >&2
    usage >&2
    exit 2
    ;;
esac
