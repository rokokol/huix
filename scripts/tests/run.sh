#!/usr/bin/env bash
# Runs the scripts against stubs of hyprctl, monitor-sensor, systemctl, evtest, pkill,
# notify-send, df and wakeonlan that record what they were asked and answer from environment
# variables, so every keyword a script emits is asserted without a compositor. Wired as the
# script-tests flake check; run by hand from anywhere, through `nix develop -c` for the tools
# No -e: every failing assertion is printed and counted, and the run exits on the counter
# Needs jq, flock and xorriso beside bash, which the flake's default dev shell takes from the check
set -uo pipefail

usage() {
  cat <<'EOF'
run.sh — the tests of the scripts beside this directory, against stubbed commands

  run.sh          run every test, one "ok"/"not ok" line each on stdout
  run.sh help     this text

Nothing here reaches the network or touches the session: hyprctl, monitor-sensor,
systemctl, evtest, pkill, notify-send, df and wakeonlan are stubs for the duration of the run.
make-station-iso.sh runs the real xorriso on a small image in a temporary directory
Exit 0 when every test passes, 1 when one fails, 2 on a usage error
EOF
}

cmd="${1:-}"
case "$cmd" in
  '') ;;
  -h | --help | help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SCRIPTS=$HERE/..
work=$(mktemp -d "${TMPDIR:-/tmp}/huix-script-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT

failures=0
ok() { printf 'ok - %s\n' "$1"; }
not_ok() {
  printf 'not ok - %s\n' "$1"
  failures=$((failures + 1))
}
# is NAME EXPECTED ACTUAL
is() {
  if [ "$2" = "$3" ]; then
    ok "$1"
  else
    not_ok "$1"
    printf '  expected: %s\n  actual:   %s\n' "$2" "$3" >&2
  fi
}

# The checks below ask what a script did, not how it spelled it: a call is found by the
# facts it must carry, so a change of wording or order in the output fails no test

# logged NAME ERE... — the stub log has one line matching every pattern
logged() {
  local name=$1 line
  shift
  while IFS= read -r line; do
    local pattern hit=1
    for pattern in "$@"; do
      grep -Eq -- "$pattern" <<<"$line" || hit=0
    done
    if ((hit)); then
      ok "$name"
      return
    fi
  done <"$STUB_LOG"
  not_ok "$name"
  printf '  no logged line matches all of: %s\n' "$*" >&2
  sed 's/^/  log: /' "$STUB_LOG" >&2
}

# not_logged NAME ERE — no line of the stub log matches
not_logged() {
  if grep -Eq -- "$2" "$STUB_LOG"; then
    not_ok "$1"
    grep -E -- "$2" "$STUB_LOG" | sed 's/^/  unexpected: /' >&2
  else
    ok "$1"
  fi
}

# transforms MONITOR — the transform of every monitor rule sent for MONITOR, in order
transforms() {
  grep '^hyprctl eval hl.monitor' "$STUB_LOG" | grep -F "\"$1\"" |
    sed -E 's/.*transform = ([0-9]+).*/\1/' | paste -sd' ' -
}

# The stubs record every call as one line of "NAME ARGS" in $STUB_LOG
mkdir -p "$work/bin"
export STUB_LOG=$work/log
export PATH=$work/bin:$PATH

cat >"$work/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf 'hyprctl %s\n' "$*" >>"$STUB_LOG"
case "$1 $2" in
  "monitors -j") printf '%s\n' "$STUB_MONITORS" ;;
  "eval "*) printf 'ok\n' ;;
esac
EOF
cat >"$work/bin/monitor-sensor" <<'EOF'
#!/usr/bin/env bash
printf 'monitor-sensor %s\n' "$*" >>"$STUB_LOG"
printf '%b\n' "$STUB_SENSOR"
EOF
cat >"$work/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$STUB_LOG"
case "$*" in
  *is-active*) [ "${STUB_ACTIVE:-}" = 1 ] ;;
  "show -P ActiveState "*) printf '%s\n' "${STUB_ACTIVE_STATE:-inactive}" ;;
  "show -P Result "*) printf '%s\n' "${STUB_RESULT:-success}" ;;
esac
EOF
cat >"$work/bin/evtest" <<'EOF'
#!/usr/bin/env bash
printf 'evtest %s\n' "$*" >>"$STUB_LOG"
exit "${STUB_EVTEST:-0}"
EOF
for stub in pkill pgrep notify-send; do
  cat >"$work/bin/$stub" <<EOF
#!/usr/bin/env bash
printf '$stub %s\n' "\$*" >>"\$STUB_LOG"
EOF
done
# stdbuf is only a prefix in the real script: the stub runs what follows its flag
cat >"$work/bin/stdbuf" <<'EOF'
#!/usr/bin/env bash
shift
exec "$@"
EOF
# A build sandbox has no /usr/bin/env: the stubs run under the bash running this file, and
# the scripts are started through it below for the same reason
sed -i "1s|.*|#!$BASH|" "$work/bin"/*
chmod +x "$work/bin"/*

# The switch device is found by name in the kernel's input list; a copy of that list stands
# in for /proc here
export HUIX_INPUT_DEVICES=$work/devices
cat >"$HUIX_INPUT_DEVICES" <<'EOF'
I: Bus=0019 Vendor=0000 Product=0000 Version=0000
N: Name="Intel Virtual Buttons"
H: Handlers=kbd event6
B: EV=13

I: Bus=0019 Vendor=0000 Product=0000 Version=0000
N: Name="Intel Virtual Switches"
P: Phys=INT33D6/input0
H: Handlers=event7
B: EV=21

I: Bus=0000 Vendor=0000 Product=0005 Version=0000
N: Name="Lid Switch"
H: Handlers=event9
B: EV=21
EOF

reset_log() { : >"$STUB_LOG"; }

# A laptop panel plus an external monitor, the external one focused
export STUB_MONITORS='[
  {"name":"DP-1","width":2560,"height":1440,"refreshRate":143.99900,"x":1440,"y":0,"scale":1.0,"transform":0,"focused":true},
  {"name":"eDP-1","width":1920,"height":1080,"refreshRate":59.98400,"x":0,"y":0,"scale":1.3333334,"transform":3,"focused":false}
]'
export HUIX_TABLET_SWITCH="Intel Virtual Switches"

rotate=$SCRIPTS/rotate-screen.sh
tablet=$SCRIPTS/tablet-mode.sh

# rotate-screen.sh
reset_log
bash "$rotate" set 1 >/dev/null 2>&1
is "set turns the focused monitor" "1" "$(transforms DP-1)"
logged "the rule keeps the monitor's own mode, position and scale" \
  'hl\.monitor' '"DP-1"' '2560x1440' '1440x0' 'scale = 1(\.0)?[ ,]'
logged "touch and pen turn with the monitor" \
  'touchdevice = \{ transform = 1 \}' 'tablet = \{ transform = 1 \}'

reset_log
bash "$rotate" -m eDP-1 next >/dev/null 2>&1
is "next wraps the last transform round to upright, on the named monitor" "0" "$(transforms eDP-1)"
is "a named monitor leaves the focused one alone" "" "$(transforms DP-1)"

reset_log
bash "$rotate" prev >/dev/null 2>&1
is "prev wraps upright round to the last transform" "3" "$(transforms DP-1)"

is "status prints the named monitor's transform" "3" "$(bash "$rotate" -m eDP-1 status 2>/dev/null)"

bash "$rotate" set 4 >/dev/null 2>&1
is "set refuses a transform outside 0..3 with a usage error" 2 "$?"

bash "$rotate" -m DP-9 status >/dev/null 2>&1
is "an unknown monitor is a failure, not a usage error" 1 "$?"

reset_log
export STUB_SENSOR='=== Has accelerometer (orientation: normal)\n    Accelerometer orientation changed: left-up\n    Accelerometer orientation changed: undefined\n    Accelerometer orientation changed: right-up'
bash "$rotate" auto >/dev/null 2>&1
is "auto follows the sensor on the built-in panel and skips undefined" "0 1 3" "$(transforms eDP-1)"
is "auto leaves the external monitor alone" "" "$(transforms DP-1)"

bash "$rotate" >/dev/null 2>&1
is "no subcommand is a usage error" 2 "$?"

# tablet-mode.sh
export STUB_MONITORS='[{"name":"eDP-1","width":1920,"height":1080,"refreshRate":59.98400,"x":0,"y":0,"scale":1.3333334,"transform":1,"focused":true}]'

reset_log
STUB_ACTIVE=0 HUIX_TABLET_SIGNAL=10 bash "$tablet" on >/dev/null 2>&1
logged "on starts auto-rotation" '^systemctl --user start' 'huix-auto-rotate'
logged "on starts the on-screen keyboard" '^systemctl --user start' 'huix-virt-keyboard'
logged "on shows the titlebars" 'hyprbars' 'enabled = true'
logged "on hides the cursor" 'cursor' 'invisible = true'
logged "on pokes the bar on the signal it declared" '^pkill' 'RTMIN\+10' 'waybar'

reset_log
# Explicitly empty: the shell running the tests may carry the session's own signal number
STUB_ACTIVE=0 HUIX_TABLET_SIGNAL='' bash "$tablet" on >/dev/null 2>&1
not_logged "without a bar signal declared nothing is poked" '^pkill'

reset_log
STUB_ACTIVE=1 bash "$tablet" off >/dev/null 2>&1
logged "off stops auto-rotation" '^systemctl --user stop' 'huix-auto-rotate'
logged "off stops the on-screen keyboard" '^systemctl --user stop' 'huix-virt-keyboard'
logged "off hides the titlebars" 'hyprbars' 'enabled = false'
logged "off shows the cursor" 'cursor' 'invisible = false'
is "off puts the screen upright" "0" "$(transforms eDP-1)"

on_text=$(STUB_ACTIVE=1 bash "$tablet" virt-keyboard status 2>/dev/null | jq -r .text)
off_text=$(STUB_ACTIVE=0 bash "$tablet" virt-keyboard status 2>/dev/null | jq -r .text)
is "the bar button has something to show in the mode" "yes" "$([ -n "$on_text" ] && echo yes)"
is "the bar button is empty outside the mode, which hides it" "" "$off_text"

is "status reads the auto-rotate unit" "on off" "$(STUB_ACTIVE=1 bash "$tablet" status 2>/dev/null) $(STUB_ACTIVE=0 bash "$tablet" status 2>/dev/null)"

reset_log
STUB_ACTIVE=0 STUB_EVTEST=10 bash "$tablet" sync >/dev/null 2>&1
logged "sync asks the switch device found by its name" '^evtest --query' '/dev/input/event7' 'SW_TABLET_MODE'
logged "sync enters the mode when the switch is on" '^systemctl --user start' 'huix-auto-rotate'

reset_log
STUB_ACTIVE=1 STUB_EVTEST=0 bash "$tablet" sync >/dev/null 2>&1
logged "sync leaves the mode when the switch is off" '^systemctl --user stop' 'huix-auto-rotate'

reset_log
STUB_ACTIVE=1 STUB_EVTEST=10 bash "$tablet" sync >/dev/null 2>&1
logged "sync in the mode restarts auto-rotate so the sensor speaks again after a reload" \
  '^systemctl --user restart' 'huix-auto-rotate'
not_logged "sync in the mode does not enter it a second time" '^systemctl --user start'

# wvkbd's own signals: SIGRTMIN toggles, SIGUSR2 shows, SIGUSR1 hides
reset_log
STUB_ACTIVE=1 bash "$tablet" virt-keyboard toggle >/dev/null 2>&1
logged "virt-keyboard toggle flips a running keyboard" '^pkill' '-RTMIN ' 'wvkbd'

reset_log
STUB_ACTIVE=0 bash "$tablet" virt-keyboard toggle >/dev/null 2>&1
logged "virt-keyboard toggle starts a stopped keyboard" '^systemctl --user start' 'huix-virt-keyboard'
logged "virt-keyboard toggle then shows it" '^pkill' '-USR2' 'wvkbd'

reset_log
STUB_ACTIVE=1 bash "$tablet" virt-keyboard hide >/dev/null 2>&1
logged "virt-keyboard hide hides a running keyboard" '^pkill' '-USR1' 'wvkbd'

bash "$tablet" virt-keyboard >/dev/null 2>&1
is "virt-keyboard without an action is a usage error" 2 "$?"

# memory-status.sh, over copies of /proc/meminfo and /proc/swaps: 8 GiB of RAM with 2 GiB
# available; a partition at priority -2 with 0.25 GiB in use, listed before a zram device at
# priority 5 with 0.75 GiB in use, as the kernel lists devices in the order they were enabled
memory=$SCRIPTS/memory-status.sh
export HUIX_MEMINFO=$work/meminfo HUIX_SWAPS=$work/swaps
cat >"$HUIX_MEMINFO" <<'EOF'
MemTotal:        8388608 kB
MemFree:          524288 kB
MemAvailable:    2097152 kB
SwapTotal:       8388608 kB
SwapFree:        7340032 kB
EOF
cat >"$HUIX_SWAPS" <<'EOF'
Filename				Type		Size		Used		Priority
/dev/nvme0n1p3                          partition	4194304		262144		-2
/dev/zram0                              partition	4194304		786432		5
EOF
status=$(bash "$memory" status)
text=$(jq -r .text <<<"$status")
tooltip=$(jq -r .tooltip <<<"$status")
is "status shows used RAM, not free RAM" "yes" "$(grep -q '6\.0' <<<"$text" && ! grep -q '2\.0' <<<"$text" && echo yes)"
is "each swap device is shown on its own, the higher priority first" "yes" \
  "$(grep -q '0\.8+0\.2' <<<"$text" && echo yes)"
is "the tooltip names each swap device with its priority, the higher first" "yes" \
  "$(grep -n 'zram0' <<<"$tooltip" | grep -q '5' && grep -q 'nvme0n1p3.*-2' <<<"$tooltip" &&
    [ "$(grep -n zram0 <<<"$tooltip" | cut -d: -f1)" -lt "$(grep -n nvme0n1p3 <<<"$tooltip" | cut -d: -f1)" ] && echo yes)"
cat >"$HUIX_SWAPS" <<'EOF'
Filename				Type		Size		Used		Priority
/dev/zram0                              partition	4194304		786432		5
EOF
text=$(bash "$memory" status | jq -r .text)
is "a single swap device is shown alone" "yes" "$(grep -q '/0\.8Gb' <<<"$text" && echo yes)"
cat >"$HUIX_SWAPS" <<'EOF'
Filename				Type		Size		Used		Priority
EOF
text=$(bash "$memory" status | jq -r .text)
is "without a swap device the RAM is still shown" "yes" "$(grep -q '6\.0' <<<"$text" && echo yes)"
is "without a swap device no swap figure is shown" "" "$(grep -o '/' <<<"$text")"
bash "$memory" status extra >/dev/null 2>&1
is "status takes no argument" 2 "$?"
HUIX_MEMINFO=$work/missing bash "$memory" status >/dev/null 2>&1
is "an unreadable memory file is a failure" 1 "$?"
HUIX_SWAPS=$work/missing bash "$memory" status >/dev/null 2>&1
is "an unreadable swap list is a failure" 1 "$?"

# backup-heartbeat.sh, over repositories laid out here the way rest-server writes them:
# <data>/<user>/snapshots/<id>. alpha pushed an hour ago, beta three days ago, gamma never
heartbeat=$SCRIPTS/backup-heartbeat.sh
backup=$work/backup
now=$(date +%s)
mkdir -p "$backup/alpha/snapshots" "$backup/beta/snapshots"
touch -d "@$((now - 3600))" "$backup/alpha/snapshots/a1"
touch -d "@$((now - 3 * 86400))" "$backup/alpha/snapshots/a0" "$backup/beta/snapshots/b0"
# The hashes are never read: the expected repositories are the names before the colon
printf 'alpha:hash\n' >"$work/htpasswd-alpha"
printf '# nodes\nalpha:hash\n\nbeta:hash\n' >"$work/htpasswd-beta"
printf 'alpha:hash\ngamma:hash\n' >"$work/htpasswd-gamma"
printf 'alpha:hash\nbeta:hash\ngamma:hash\n' >"$work/htpasswd-all"
printf '# nobody yet\n\n' >"$work/htpasswd-empty"
# rest-server reserves the name: this user reads /metrics and never pushes
printf 'alpha:hash\nmetrics:hash\n' >"$work/htpasswd-metrics"
printf 'metrics:hash\n' >"$work/htpasswd-only-metrics"
# The df stub answers in KiB, as df -P -k does: 50 GiB free unless a case says otherwise
cat >"$work/bin/df" <<'EOF'
#!/usr/bin/env bash
printf 'df %s\n' "$*" >>"$STUB_LOG"
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
printf '/dev/stub 104857600 0 %s 50%% /srv\n' "${STUB_DF_AVAIL:-52428800}"
EOF
sed -i "1s|.*|#!$BASH|" "$work/bin/df"
chmod +x "$work/bin/df"

# beat HTPASSWD [ARG]... — run a check with a 36h limit and a 10G floor, the output in $beat_out
beat() {
  local htpasswd=$1
  shift
  beat_out=$(bash "$heartbeat" check "$@" "$backup" "$work/$htpasswd" 36h 10G 2>&1)
}
# last_line — the line a mail subject is taken from
last_line() { tail -n 1 <<<"$beat_out"; }

beat htpasswd-alpha
is "a repository with a fresh snapshot passes" 0 "$?"

beat htpasswd-beta
is "a stale repository fails" 1 "$?"
is "the stale repository is named in the last line" yes "$(grep -q beta <<<"$(last_line)" && echo yes)"
is "the fresh repository is not reported" "" "$(grep -v '^backup-heartbeat.sh: everything' <<<"$beat_out" | grep -o alpha)"

beat htpasswd-gamma
is "a repository that never pushed fails" 1 "$?"
bash "$heartbeat" check -p "$work/backup.causes" "$backup" "$work/htpasswd-all" 36h 10G >/dev/null 2>&1
is "a check that lists its causes passes" 0 "$?"
is "each stale or missing repository is a cause" "beta-stale|gamma-missing" \
  "$(cut -f1 "$work/backup.causes" | sort | paste -sd'|' -)"
STUB_DF_AVAIL=1048576 bash "$heartbeat" check -p "$work/backup.causes" "$backup" "$work/htpasswd-alpha" 36h 10G >/dev/null 2>&1
is "low space is a cause of its own" "low-space" "$(cut -f1 "$work/backup.causes")"
is "the missing repository is named in the last line" yes "$(grep -q gamma <<<"$(last_line)" && echo yes)"

beat htpasswd-all
is "two failures fail" 1 "$?"
is "both failures are named in the last line" yes \
  "$(grep -q beta <<<"$(last_line)" && grep -q gamma <<<"$(last_line)" && echo yes)"

STUB_DF_AVAIL=1048576 beat htpasswd-alpha
is "free space under the floor fails with every repository fresh" 1 "$?"

beat htpasswd-empty
is "an htpasswd with no user is a usage error, not a pass" 2 "$?"

beat htpasswd-metrics
is "the metrics reader is not an expected repository" 0 "$?"

beat htpasswd-only-metrics
is "an htpasswd with only the metrics reader is a usage error" 2 "$?"

beat htpasswd-alpha -m "$work/metrics/backup.prom"
is "a metrics file is written beside a passing check" 0 "$?"
is "the metrics carry the repository's newest snapshot time" yes \
  "$(grep -Eq "^[a-z_]+\{repository=\"alpha\"\} $((now - 3600))$" "$work/metrics/backup.prom" && echo yes)"

beat htpasswd-gamma -m "$work/metrics/backup.prom"
is "a missing repository is in the metrics as time zero" yes \
  "$(grep -Eq '^[a-z_]+\{repository="gamma"\} 0$' "$work/metrics/backup.prom" && echo yes)"

# A repository one level deeper than the contract is missing, and the nested path is named
mkdir -p "$backup/gamma/laptop/snapshots"
touch "$backup/gamma/laptop/config" "$backup/gamma/laptop/snapshots/g0"
beat htpasswd-gamma
is "a nested repository does not count as the user's repository" 1 "$?"
is "the nested repository is named" yes "$(grep -q 'gamma/laptop' <<<"$beat_out" && echo yes)"
rm -r "$backup/gamma"

bash "$heartbeat" check "$work/no-such-dir" "$work/htpasswd-alpha" 36h 10G >/dev/null 2>&1
is "a missing data directory fails" 1 "$?"

bash "$heartbeat" check "$backup" "$work/htpasswd-alpha" 36x 10G >/dev/null 2>&1
is "an age without a unit it knows is a usage error" 2 "$?"

# backup-heartbeat.sh push, over a Pushgateway page in the format Prometheus writes floats in.
# alpha pushed ten minutes ago under one job and a day ago under another, beta two hours ago
# with its labels in the other order, gamma never
cat >"$work/pushgateway.prom" <<EOF
# HELP push_time_seconds Last Unix time when changing this group in the Pushgateway succeeded.
# TYPE push_time_seconds gauge
push_time_seconds{instance="alpha",job="node"} $(awk -v t=$((now - 600)) 'BEGIN { printf "%.10e", t }')
push_time_seconds{instance="alpha",job="mail"} $((now - 86400))
push_time_seconds{job="node",instance="beta"} $((now - 7200)).5
push_failure_time_seconds{instance="gamma",job="node"} $now
EOF

# push HTPASSWD [PAGE] — run the push check with a 1h limit, the output in $beat_out
push() {
  beat_out=$(bash "$heartbeat" push "$work/$1" 1h <"${2:-$work/pushgateway.prom}" 2>&1)
}

push htpasswd-alpha
is "a node that pushed recently passes" 0 "$?"

push htpasswd-beta
is "a node silent past the limit fails" 1 "$?"
is "the silent node is named in the last line" yes "$(grep -q beta <<<"$(last_line)" && echo yes)"
is "a push with its labels in another order is still found" "" "$(grep 'beta' <<<"$beat_out" | grep -o never)"
is "the node that pushed is not reported" "" "$(grep -v '^backup-heartbeat.sh: everything' <<<"$beat_out" | grep -o alpha)"

push htpasswd-gamma
is "a node that never pushed fails" 1 "$?"
is "the node that never pushed is named in the last line" yes "$(grep -q gamma <<<"$(last_line)" && echo yes)"

push htpasswd-metrics
is "the metrics reader is not an expected node" 0 "$?"

push htpasswd-alpha /dev/null
is "an empty page fails every node" 1 "$?"

# A node that pushes on time but reports problems of its own, one series a cause; the label
# order and an escaped quote in the summary are as Pushgateway may write them
cp "$work/pushgateway.prom" "$work/pushgateway-problems.prom"
cat >>"$work/pushgateway-problems.prom" <<'EOF'
node_problem{instance="alpha",job="mail",key="postfix",summary="postfix.service failed"} 1
node_problem{job="vpn",summary="disk is \"91%\" full",key="disk-full",instance="alpha"} 1
EOF
push htpasswd-alpha "$work/pushgateway-problems.prom"
is "a node that reports problems fails" 1 "$?"
is "each problem of the node is named" yes \
  "$(grep -q 'postfix.service failed' <<<"$beat_out" && grep -q 'disk is "91%" full' <<<"$beat_out" && echo yes)"

# With -p the causes go to a file, one a line, and the check passes so that its unit stays up
pushp() {
  beat_out=$(bash "$heartbeat" push -p "$work/push.causes" "$work/$1" 1h <"$2" 2>&1)
}
pushp htpasswd-alpha "$work/pushgateway-problems.prom"
is "a push check that lists its causes passes" 0 "$?"
is "each cause is a key and a subject" \
  "alpha-disk-full|alpha-postfix" \
  "$(cut -f1 "$work/push.causes" | sort | paste -sd'|' -)"
is "a node's cause keeps the node's own words" yes \
  "$(grep -q "$(printf 'alpha-postfix\t.*alpha.*postfix.service failed')" "$work/push.causes" && echo yes)"
pushp htpasswd-gamma "$work/pushgateway.prom"
is "a node that never pushed is a cause" yes \
  "$(grep -q "$(printf '^gamma-never\t')" "$work/push.causes" && echo yes)"
pushp htpasswd-beta "$work/pushgateway.prom"
is "a silent node is a cause" yes "$(grep -q "$(printf '^beta-silent\t')" "$work/push.causes" && echo yes)"
pushp htpasswd-alpha "$work/pushgateway.prom"
is "a node with nothing to report leaves the list empty" "" "$(cat "$work/push.causes")"

bash "$heartbeat" push "$work/htpasswd-alpha" 1x <"$work/pushgateway.prom" >/dev/null 2>&1
is "a silence limit without a unit it knows is a usage error" 2 "$?"

bash "$heartbeat" push "$work/htpasswd-empty" 1h <"$work/pushgateway.prom" >/dev/null 2>&1
is "a push check with no node is a usage error" 2 "$?"

# btrbk-metrics.sh, over snapshot names as btrbk's long timestamp format writes them
btrbk_metrics=$SCRIPTS/btrbk-metrics.sh
snaps=$work/snapshots
mkdir -p "$snaps/myWiki.20261013T1815" "$snaps/myWiki.20261013T1830" "$snaps/claude-shared.20261013T1800"
mkdir -p "$snaps/.partial.20261013T1900"
touch "$snaps/notes"
TZ=UTC bash "$btrbk_metrics" write "$snaps" "$work/metrics/btrbk.prom" >/dev/null 2>&1
is "the snapshot metrics are written" 0 "$?"
is "each folder counts its own snapshots" "claude-shared 1|myWiki 2" \
  "$(sed -nE 's/^btrbk_snapshots\{folder="([^"]+)"\} ([0-9]+)$/\1 \2/p' "$work/metrics/btrbk.prom" | sort | paste -sd'|' -)"
is "the newest snapshot of a folder is its latest timestamp" "$(TZ=UTC date -d '2026-10-13 18:30' +%s)" \
  "$(sed -nE 's/^btrbk_newest_snapshot_timestamp_seconds\{folder="myWiki"\} ([0-9]+)$/\1/p' "$work/metrics/btrbk.prom")"
is "a name that is no snapshot is left out" "" "$(grep -E 'notes|partial' "$work/metrics/btrbk.prom")"
TZ=UTC bash "$btrbk_metrics" write "$work/no-such-snapshots" "$work/metrics/btrbk.prom" >/dev/null 2>&1
is "a missing snapshot directory is a failure" 1 "$?"
bash "$btrbk_metrics" write "$snaps" >/dev/null 2>&1
is "btrbk-metrics without a file is a usage error" 2 "$?"

# alert.sh, with its state in a temporary directory. The mailer stub keeps each message, the
# curl stub stands for the Telegram Bot API, and the notify stub for the agent
alert=$SCRIPTS/alert.sh
export ALERT_STATE=$work/alerts
export ALERT_MAIL=$work/bin/alert-mailer
export ALERT_NOTIFY=$work/bin/alert-notify
export ALERT_METRICS=$work/metrics/alerts.prom
export ALERT_TELEGRAM_API=http://telegram.test
# No system here, so reconcile has no kernel to compare unless a case gives it one
export ALERT_BOOTED=$work/no-system ALERT_CURRENT=$work/no-system
export ALERT_TELEGRAM_TOKEN=$work/telegram-bot-token ALERT_TELEGRAM_CHAT=$work/telegram-owner-chat-id
printf 'bot-token\n' >"$ALERT_TELEGRAM_TOKEN"
printf '42\n' >"$ALERT_TELEGRAM_CHAT"
cat >"$work/bin/alert-mailer" <<'EOF'
#!/usr/bin/env bash
printf 'mail %s %s\n' "$*" "$(grep -m1 '^Subject: ' | tr -d '\n')" >>"$STUB_LOG"
EOF
cat >"$work/bin/alert-notify" <<'EOF'
#!/usr/bin/env bash
printf 'notify %s\n' "$*" >>"$STUB_LOG"
exit "${STUB_NOTIFY:-0}"
EOF
# The text it sends spans lines, and the log keeps one line for each call
cat >"$work/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf 'curl %s\n' "$(tr '\n' ' ' <<<"$*")" >>"$STUB_LOG"
# The answer goes where -o says, as curl sends it
out=/dev/stdout
while (($#)); do
  if [ "$1" = -o ]; then out=$2; fi
  shift
done
if [ -n "${STUB_CURL_REFUSE:-}" ]; then
  printf '{"ok":false,"error_code":400,"description":"%s"}' "$STUB_CURL_REFUSE" >"$out"
  exit 22
fi
EOF
sed -i "1s|.*|#!$BASH|" "$work/bin/alert-mailer" "$work/bin/alert-notify" "$work/bin/curl"
chmod +x "$work/bin/alert-mailer" "$work/bin/alert-notify" "$work/bin/curl"

# raise ARG... — raise with a body on stdin; the status in $alert_status
raise() {
  alert_status=0
  printf 'the body of %s\n' "$*" | bash "$alert" raise "$@" >/dev/null 2>&1 || alert_status=$?
}
listed() { bash "$alert" list 2>/dev/null | cut -f1 | paste -sd' ' -; }

reset_log
raise unit:beat.service "beat.service failed"
is "a new problem is raised" 0 "$alert_status"
logged "a new problem is mailed" '^mail ' 'Subject: beat\.service failed'
logged "a new problem goes to Telegram" '^curl ' 'telegram\.test/botbot-token/sendMessage' 'chat_id=42' 'beat\.service failed'
logged "a new problem goes to the agent" '^notify ' 'beat\.service failed'
logged "the agent is asked to look into a new problem" '^notify ' 'beat\.service failed' 'station-health'
is "the problem is open" "unit:beat.service" "$(listed)"
is "the open problem is in the metrics with the time it opened" yes \
  "$(grep -Eq '^alert_open_since_seconds\{key="unit:beat.service"\} [0-9]+$' "$ALERT_METRICS" && echo yes)"

reset_log
raise unit:beat.service "beat.service failed"
not_logged "a problem raised again is not sent again" '^(mail|curl|notify) '
is "a problem raised again stays open once" "unit:beat.service" "$(listed)"

reset_log
raise -q reboot "a reboot is due"
not_logged "a quiet problem is not sent" '^(mail|curl|notify) '
is "a quiet problem is open beside the other" "reboot unit:beat.service" "$(listed)"

reset_log
bash "$alert" digest >/dev/null 2>&1
logged "the digest mails every open problem" '^mail ' 'Subject: .*2 unresolved'
not_logged "the digest goes to mail alone" '^(curl|notify) '

reset_log
bash "$alert" clear reboot >/dev/null 2>&1
not_logged "a quiet problem is cleared in silence" '^(mail|curl|notify) '
STUB_NOTIFY=1 bash "$alert" clear unit:beat.service >/dev/null 2>&1
is "a clear whose agent is down still succeeds" 0 "$?"
logged "a cleared problem is mailed as resolved" '^mail ' 'Subject: .*beat\.service failed.*resolved'
logged "a cleared problem goes to Telegram as resolved" '^curl ' 'resolved'
is "nothing is open after the clears" "" "$(listed)"
is "a cleared problem leaves the metrics" "" "$(grep '^alert_open_since_seconds{' "$ALERT_METRICS")"

reset_log
bash "$alert" clear unit:never.service >/dev/null 2>&1
is "clearing what is not open succeeds" 0 "$?"
not_logged "clearing what is not open sends nothing" '^(mail|curl|notify) '

reset_log
bash "$alert" digest >/dev/null 2>&1
not_logged "the digest of nothing sends nothing" '^mail '

journal=$(cut -f2,3 "$ALERT_STATE/journal")
is "the journal keeps each change of a problem" \
  "OPEN unit:beat.service|UPDATE unit:beat.service|OPEN reboot|RESOLVED reboot|RESOLVED unit:beat.service" \
  "$(tr '\t\n' ' |' <<<"$journal" | sed 's/|$//')"

# reconcile asks systemd about each open unit, through the systemctl stub
for case in "failed exit-code open" "active success resolved" "inactive success resolved" "inactive exit-code open"; do
  read -r state result verdict <<<"$case"
  raise unit:x.service "x.service failed"
  STUB_ACTIVE_STATE=$state STUB_RESULT=$result bash "$alert" reconcile >/dev/null 2>&1
  if [ -n "$(listed)" ]; then got=open; else got=resolved; fi
  is "reconcile: a unit $state with result $result is $verdict" "$verdict" "$got"
  bash "$alert" clear unit:x.service >/dev/null 2>&1
done

# The reboot is due when the booted kernel is not the current one
mkdir -p "$work/booted" "$work/current-old" "$work/current-new"
printf 'kernel-1\n' >"$work/k1"
printf 'kernel-2\n' >"$work/k2"
ln -sfn "$work/k1" "$work/booted/kernel"
ln -sfn "$work/k1" "$work/current-old/kernel"
ln -sfn "$work/k2" "$work/current-new/kernel"
reset_log
ALERT_BOOTED=$work/booted ALERT_CURRENT=$work/current-new bash "$alert" reconcile >/dev/null 2>&1
is "a new kernel opens a quiet reboot problem" "reboot" "$(listed)"
not_logged "the reboot problem is not sent" '^(mail|curl|notify) '
ALERT_BOOTED=$work/booted ALERT_CURRENT=$work/current-old bash "$alert" reconcile >/dev/null 2>&1
is "the booted kernel clears the reboot problem" "" "$(listed)"

reset_log
ALERT_TELEGRAM_API='' raise unit:y.service "y.service failed"
not_logged "no Telegram API means no Telegram" '^curl '
logged "without Telegram the mail still goes" '^mail ' 'y\.service failed'
bash "$alert" clear unit:y.service >/dev/null 2>&1

# Telegram refuses, as it does for a chat that never started the bot
reset_log
refused=$(printf 'body\n' | STUB_CURL_REFUSE='Bad Request: chat not found' bash "$alert" raise unit:r.service "r.service failed" 2>&1)
is "a refusal of Telegram names its reason" yes "$(grep -q 'chat not found' <<<"$refused" && echo yes)"
logged "a refusal of Telegram still lets the mail go" '^mail ' 'r\.service failed'
bash "$alert" clear unit:r.service >/dev/null 2>&1

# The secrets of Telegram missing, as before the owner puts them in sops
reset_log
ALERT_TELEGRAM_TOKEN=$work/no-such-token raise unit:z.service "z.service failed"
is "a missing Telegram secret does not fail the alert" 0 "$alert_status"
not_logged "a missing Telegram secret sends nothing to Telegram" '^curl '
logged "a missing Telegram secret still lets the mail go" '^mail ' 'z\.service failed'
bash "$alert" clear unit:z.service >/dev/null 2>&1

# With a spawner each message waits in the outbox for a delivery of its own, so a mail that
# waits for its relay holds up no other alert
cat >"$work/bin/alert-spawn" <<'EOF'
#!/usr/bin/env bash
printf 'spawn %s\n' "$*" >>"$STUB_LOG"
EOF
sed -i "1s|.*|#!$BASH|" "$work/bin/alert-spawn"
chmod +x "$work/bin/alert-spawn"
reset_log
ALERT_SPAWN=$work/bin/alert-spawn raise unit:s.service "s.service failed"
logged "a spawner takes the message" '^spawn ' 'outbox'
not_logged "a spawned message is not sent in place" '^(mail|curl|notify) '
outbox=$(ls "$ALERT_STATE"/outbox/*)
is "the outbox holds the subject on its first line" "s.service failed" "$(head -n 1 "$outbox")"
reset_log
STUB_ACTIVE_STATE=failed STUB_RESULT=exit-code ALERT_SPAWN=$work/bin/alert-spawn \
  bash "$alert" reconcile >/dev/null 2>&1
logged "a reconcile hands on a message left in the outbox" '^spawn ' "$outbox"
reset_log
flock "$outbox" bash "$alert" deliver "$outbox" >/dev/null 2>&1
not_logged "a message another delivery holds is not sent twice" '^(mail|curl|notify) '
bash "$alert" deliver "$outbox" >/dev/null 2>&1
logged "a delivery sends the message" '^mail ' 'Subject: s\.service failed'
logged "a delivery tells Telegram" '^curl ' 's\.service failed'
is "a delivered message leaves the outbox" "" "$(ls "$ALERT_STATE"/outbox/)"
bash "$alert" clear unit:s.service >/dev/null 2>&1

# sync opens a problem for each cause a check lists and closes each one it no longer lists
printf 'pc-silent\tpc is silent\nmail-missing\tmail has no snapshot\n' >"$work/causes"
reset_log
bash "$alert" sync beat "$work/causes" >/dev/null 2>&1
is "a sync of two causes succeeds" 0 "$?"
is "each listed cause is its own problem" "beat:mail-missing beat:pc-silent" "$(listed)"
logged "each new cause is sent on its own" '^mail ' 'Subject: pc is silent'
logged "the other new cause is sent too" '^mail ' 'Subject: mail has no snapshot'
reset_log
printf 'pc-silent\tpc is silent\nvpn-silent\tvpn is silent\n' >"$work/causes"
bash "$alert" sync beat "$work/causes" >/dev/null 2>&1
is "a sync keeps a cause still listed and opens a new one" "beat:pc-silent beat:vpn-silent" "$(listed)"
logged "the new cause is sent while the old one stays open" '^mail ' 'Subject: vpn is silent'
not_logged "a cause listed again is not sent again" 'Subject: pc is silent$'
is "a cause listed again leaves no line in the journal" 1 \
  "$(grep -c "$(printf '\tbeat:pc-silent\t')" "$ALERT_STATE/journal")"
logged "a cause no longer listed is closed" '^mail ' 'Subject: mail has no snapshot \(resolved\)'
raise unit:other.service "other failed"
: >"$work/causes"
bash "$alert" sync beat "$work/causes" >/dev/null 2>&1
is "an empty list closes every cause of its source and nothing else" "unit:other.service" "$(listed)"
bash "$alert" clear unit:other.service >/dev/null 2>&1
printf 'bad/cause\tx\n' >"$work/causes"
bash "$alert" sync beat "$work/causes" >/dev/null 2>&1
is "a cause that is not a key is a failure" 1 "$?"
bash "$alert" sync beat "$work/no-such-causes" >/dev/null 2>&1
is "a missing list is a failure, not an all clear" 1 "$?"

raise "bad/key" "bad"
is "a key that is not a file name is a usage error" 2 "$alert_status"

bash "$alert" >/dev/null 2>&1
is "alert without a subcommand is a usage error" 2 "$?"
unset ALERT_STATE ALERT_MAIL ALERT_NOTIFY ALERT_METRICS ALERT_TELEGRAM_API ALERT_BOOTED ALERT_CURRENT
unset ALERT_TELEGRAM_TOKEN ALERT_TELEGRAM_CHAT
rm "$work/bin/curl"

# wake-pc.sh, against a wakeonlan stub, with the MAC in a file as sops leaves it
wake=$SCRIPTS/wake-pc.sh
cat >"$work/bin/wakeonlan" <<'EOF'
#!/usr/bin/env bash
printf 'wakeonlan %s\n' "$*" >>"$STUB_LOG"
EOF
sed -i "1s|.*|#!$BASH|" "$work/bin/wakeonlan"
chmod +x "$work/bin/wakeonlan"
printf 'AA:BB:CC:DD:EE:0F\n' >"$work/pc-mac"
printf 'not a mac\n' >"$work/bad-mac"
export WAKE_PC_BROADCAST=192.168.0.255

reset_log
WAKE_PC_MAC_FILE=$work/pc-mac bash "$wake" >/dev/null 2>&1
is "wake-pc sends the packet" 0 "$?"
logged "the packet goes to the LAN broadcast, for the MAC in the file" \
  '^wakeonlan' '-i 192\.168\.0\.255' 'AA:BB:CC:DD:EE:0F'

reset_log
WAKE_PC_MAC_FILE=$work/bad-mac bash "$wake" >/dev/null 2>&1
is "a file that holds no MAC is a failure" 1 "$?"
not_logged "no packet goes out for a bad MAC" '^wakeonlan'

WAKE_PC_MAC_FILE=$work/missing bash "$wake" >/dev/null 2>&1
is "an unreadable MAC file is a failure" 1 "$?"

WAKE_PC_MAC_FILE=$work/pc-mac bash "$wake" now >/dev/null 2>&1
is "wake-pc takes no argument" 2 "$?"

WAKE_PC_MAC_FILE='' bash "$wake" >/dev/null 2>&1
is "without the host's settings it is a usage error" 2 "$?"

is "help answers without the host's settings" 0 "$(env -u WAKE_PC_BROADCAST bash "$wake" help >/dev/null 2>&1; echo $?)"

# make-station-iso.sh, with the real xorriso on a small image made here. Every run writes into
# $iso_work, so a file the script leaves anywhere else in it is found by a listing
make_iso=$SCRIPTS/make-station-iso.sh
iso_work=$work/iso
mkdir -p "$iso_work/content" "$iso_work/secrets/ts-state" "$iso_work/out"
printf 'not a boot image\n' >"$iso_work/content/version.txt"
xorriso -as mkisofs -quiet -r -J -V HUIX-TEST -o "$iso_work/in.iso" "$iso_work/content" 2>/dev/null
# Fixtures in the shape the owner's files have, never real secrets
printf '# public key: age1test\nAGE-SECRET-KEY-1TESTTESTTEST\n' >"$iso_work/secrets/age-key.txt"
printf '{}\n' >"$iso_work/secrets/ts-state/tailscaled.state"
printf 'marker\n' >"$iso_work/secrets/ts-state/marker"
tar -C "$iso_work/secrets" -cf "$iso_work/secrets/tailscale-state.tar" ts-state
rm -r "$iso_work/secrets/ts-state"
chmod 600 "$iso_work/secrets"/*

# make_iso_run OUTPUT [ARG]... — run with the fixtures, the status in $make_status and the
# messages in $make_out. HOME and TMPDIR point into $iso_work, so a stray file lands there
make_iso_run() {
  local out=$1
  shift
  make_out=$(HOME=$iso_work/home TMPDIR=$iso_work/tmp bash "$make_iso" write -s "$iso_work/secrets" "$@" \
    "$iso_work/in.iso" "$out" 2>&1)
  make_status=$?
}
# listing — every path under $iso_work, the outputs left out
listing() { find "$iso_work" -path "$iso_work/out" -prune -o -print | LC_ALL=C sort; }
mkdir -p "$iso_work/home" "$iso_work/tmp"
before=$(listing)

make_iso_run "$iso_work/out/station.iso"
is "make-station-iso writes the image" 0 "$make_status"
is "the image is readable by its owner alone" 600 "$(stat -c %a "$iso_work/out/station.iso")"
is "nothing is written outside the output" "$before" "$(listing)"
# xorriso prints one line per file: mode, links, owner, group, size, date, quoted path
in_image=$(xorriso -indev "$iso_work/out/station.iso" -lsdl '/station-secrets/*' 2>/dev/null)
is "both secrets are in the image" yes \
  "$(grep -q "/age-key.txt'$" <<<"$in_image" && grep -q "/tailscale-state.tar'$" <<<"$in_image" && echo yes)"
is "the secrets in the image belong to root and no one else may read them" yes \
  "$(awk '$3 != 0 || $4 != 0 || $1 != "-rw-------" { bad = 1 } END { if (NR == 2 && !bad) print "yes" }' <<<"$in_image")"
is "their directory in the image is closed to all but root" yes \
  "$(xorriso -indev "$iso_work/out/station.iso" -lsdl /station-secrets 2>/dev/null |
    awk '$1 == "drwx------" && $3 == 0 && $4 == 0 { print "yes" }')"
mkdir -p "$iso_work/check"
xorriso -osirrox on -indev "$iso_work/out/station.iso" \
  -extract /station-secrets "$iso_work/check/secrets" >/dev/null 2>&1
is "the age key in the image is the given one" yes \
  "$(cmp -s "$iso_work/secrets/age-key.txt" "$iso_work/check/secrets/age-key.txt" && echo yes)"
is "the tar in the image is the given one" yes \
  "$(cmp -s "$iso_work/secrets/tailscale-state.tar" "$iso_work/check/secrets/tailscale-state.tar" && echo yes)"
rm -rf "$iso_work/check"
is "the image keeps the volume ID the installer finds its medium by" yes \
  "$(xorriso -indev "$iso_work/out/station.iso" -pvd_info 2>/dev/null | grep -q "^Volume Id *: HUIX-TEST$" && echo yes)"
is "the image keeps the Joliet tree of the original" yes \
  "$(xorriso -indev "$iso_work/out/station.iso" -assess_indev_features plain 2>/dev/null |
    grep -qx 'Indev feature: joliet=1' && echo yes)"
is "the end says the output is a secret to delete" yes \
  "$(grep -qF "$iso_work/out/station.iso" <<<"$make_out" && grep -qi delete <<<"$make_out" && echo yes)"

before_out=$(stat -c '%s %Y' "$iso_work/out/station.iso")
make_iso_run "$iso_work/out/station.iso"
is "an existing output is a usage error" 2 "$make_status"
is "an existing output is left as it was" "$before_out" "$(stat -c '%s %Y' "$iso_work/out/station.iso")"
rm "$iso_work/out/station.iso"

mkdir -p "$iso_work/out/repo/.git" "$iso_work/out/repo/sub"
make_iso_run "$iso_work/out/repo/sub/station.iso"
is "an output inside a git work tree is a usage error" 2 "$make_status"
is "nothing is written inside the work tree" "" "$(find "$iso_work/out/repo" -name '*.iso')"
ln -s "$iso_work/out/repo/sub" "$iso_work/out/link"
make_iso_run "$iso_work/out/link/station.iso"
is "a symlink into a work tree is followed and refused" 2 "$make_status"

# The store is a path the build sandbox has as well, and the refusal comes before any write
make_iso_run /nix/store/huix-station-test.iso
is "an output in the Nix store is a usage error" 2 "$make_status"
is "the refusal names the store" yes "$(grep -qi store <<<"$make_out" && echo yes)"

# Each secret in turn is taken out of a copy of the fixtures
for name in age-key.txt tailscale-state.tar; do
  rm -rf "$iso_work/partial"
  cp -R "$iso_work/secrets" "$iso_work/partial"
  rm "$iso_work/partial/$name"
  make_out=$(bash "$make_iso" write -s "$iso_work/partial" "$iso_work/in.iso" "$iso_work/out/station.iso" 2>&1)
  is "a missing $name is a failure" 1 "$?"
  is "the missing $name is named" yes "$(grep -qF "$name" <<<"$make_out" && echo yes)"
  is "no image is written without $name" "" "$(find "$iso_work/out" -name '*.iso')"
done

rm -rf "$iso_work/partial"
cp -R "$iso_work/secrets" "$iso_work/partial"
mkdir -p "$iso_work/flat"
printf '{}\n' >"$iso_work/flat/tailscaled.state"
tar -C "$iso_work/flat" -cf "$iso_work/partial/tailscale-state.tar" tailscaled.state
bash "$make_iso" write -s "$iso_work/partial" "$iso_work/in.iso" "$iso_work/out/station.iso" >/dev/null 2>&1
is "a tar without its ts-state directory is a failure" 1 "$?"
printf 'not a key\n' >"$iso_work/partial/age-key.txt"
cp "$iso_work/secrets/tailscale-state.tar" "$iso_work/partial/"
bash "$make_iso" write -s "$iso_work/partial" "$iso_work/in.iso" "$iso_work/out/station.iso" >/dev/null 2>&1
is "a key file without an age key is a failure" 1 "$?"

# A writer that dies halfway: the part it wrote holds the secrets, so it must not stay
cat >"$work/bin/xorriso" <<'EOF'
#!/usr/bin/env bash
while (($#)); do
  if [ "$1" = -outdev ]; then printf 'partial' >"$2"; fi
  shift
done
exit 5
EOF
sed -i "1s|.*|#!$BASH|" "$work/bin/xorriso"
chmod +x "$work/bin/xorriso"
make_iso_run "$iso_work/out/station.iso"
is "a failed write is a failure" 1 "$make_status"
is "a failed write leaves no part of the image" "" "$(find "$iso_work/out" -name '*.iso')"
rm "$work/bin/xorriso"

bash "$make_iso" write "$iso_work/in.iso" >/dev/null 2>&1
is "make-station-iso without an output is a usage error" 2 "$?"

bash "$make_iso" >/dev/null 2>&1
is "make-station-iso without a subcommand is a usage error" 2 "$?"

if ((failures)); then
  printf 'run.sh: %d test(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'run.sh: everything holds\n'
