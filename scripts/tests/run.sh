#!/usr/bin/env bash
# Runs the scripts against stubs of hyprctl, monitor-sensor, systemctl, evtest, pkill and
# notify-send that record what they were asked and answer from environment variables, so
# every keyword a script emits is asserted without a compositor. Wired as the script-tests
# flake check; run by hand from anywhere
# No -e: every failing assertion is printed and counted, and the run exits on the counter
# Needs jq beside bash
set -uo pipefail

usage() {
  cat <<'EOF'
run.sh — the tests of the scripts beside this directory, against stubbed commands

  run.sh          run every test, one "ok"/"not ok" line each on stdout
  run.sh help     this text

Nothing here reaches the network or touches the session: hyprctl, monitor-sensor,
systemctl, evtest, pkill and notify-send are stubs for the duration of the run
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
STUB_ACTIVE=0 HUIX_TABLET_SIGNAL= bash "$tablet" on >/dev/null 2>&1
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

# memory-status.sh, over a copy of /proc/meminfo: 8 GiB of RAM with 2 GiB available,
# 4 GiB of swap with 0.75 GiB in use
memory=$SCRIPTS/memory-status.sh
export HUIX_MEMINFO=$work/meminfo
cat >"$HUIX_MEMINFO" <<'EOF'
MemTotal:        8388608 kB
MemFree:          524288 kB
MemAvailable:    2097152 kB
SwapTotal:       4194304 kB
SwapFree:        3407872 kB
EOF
text=$(bash "$memory" status | jq -r .text)
is "status shows used RAM, not free RAM" "yes" "$(grep -q '6\.0' <<<"$text" && ! grep -q '2\.0' <<<"$text" && echo yes)"
is "status shows used swap beside it" "yes" "$(grep -q '0\.8' <<<"$text" && echo yes)"
cat >"$HUIX_MEMINFO" <<'EOF'
MemTotal:        8388608 kB
MemAvailable:    2097152 kB
SwapTotal:             0 kB
SwapFree:              0 kB
EOF
text=$(bash "$memory" status | jq -r .text)
is "without a swap device the RAM is still shown" "yes" "$(grep -q '6\.0' <<<"$text" && echo yes)"
is "without a swap device no swap figure is shown" "" "$(grep -o '/' <<<"$text")"
bash "$memory" status extra >/dev/null 2>&1
is "status takes no argument" 2 "$?"
HUIX_MEMINFO=$work/missing bash "$memory" status >/dev/null 2>&1
is "an unreadable memory file is a failure" 1 "$?"

if ((failures)); then
  printf 'run.sh: %d test(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'run.sh: everything holds\n'
