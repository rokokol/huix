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
evals() { grep '^hyprctl eval' "$STUB_LOG" | sed 's/^hyprctl eval //'; }

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
is "set 1 rewrites the focused monitor's rule with its mode, position and scale" \
  'hl.monitor({ output = "DP-1", mode = "2560x1440@143.99900", position = "1440x0", scale = 1.0, transform = 1 })
hl.config({ input = { touchdevice = { transform = 1 }, tablet = { transform = 1 } } })' "$(evals)"

reset_log
bash "$rotate" -m eDP-1 next >/dev/null 2>&1
is "next wraps 3 to 0 on the named monitor" \
  'hl.monitor({ output = "eDP-1", mode = "1920x1080@59.98400", position = "0x0", scale = 1.3333334, transform = 0 })
hl.config({ input = { touchdevice = { transform = 0 }, tablet = { transform = 0 } } })' "$(evals)"

reset_log
bash "$rotate" prev >/dev/null 2>&1
is "prev wraps 0 to 3" \
  'hl.monitor({ output = "DP-1", mode = "2560x1440@143.99900", position = "1440x0", scale = 1.0, transform = 3 })
hl.config({ input = { touchdevice = { transform = 3 }, tablet = { transform = 3 } } })' "$(evals)"

is "status prints the named monitor's transform" "3" "$(bash "$rotate" -m eDP-1 status 2>/dev/null)"

bash "$rotate" set 4 >/dev/null 2>&1
is "set refuses a transform outside 0..3 with a usage error" 2 "$?"

bash "$rotate" -m DP-9 status >/dev/null 2>&1
is "an unknown monitor is a failure, not a usage error" 1 "$?"

reset_log
export STUB_SENSOR='=== Has accelerometer (orientation: normal)\n    Accelerometer orientation changed: left-up\n    Accelerometer orientation changed: undefined\n    Accelerometer orientation changed: right-up'
bash "$rotate" auto >/dev/null 2>&1
is "auto follows the sensor on the built-in panel and skips undefined" \
  'hl.monitor({ output = "eDP-1", mode = "1920x1080@59.98400", position = "0x0", scale = 1.3333334, transform = 0 })
hl.monitor({ output = "eDP-1", mode = "1920x1080@59.98400", position = "0x0", scale = 1.3333334, transform = 1 })
hl.monitor({ output = "eDP-1", mode = "1920x1080@59.98400", position = "0x0", scale = 1.3333334, transform = 3 })' "$(evals | grep '^hl.monitor')"

bash "$rotate" >/dev/null 2>&1
is "no subcommand is a usage error" 2 "$?"

# tablet-mode.sh
export STUB_MONITORS='[{"name":"eDP-1","width":1920,"height":1080,"refreshRate":59.98400,"x":0,"y":0,"scale":1.3333334,"transform":1,"focused":true}]'

reset_log
STUB_ACTIVE=0 HUIX_TABLET_SIGNAL=10 bash "$tablet" on >/dev/null 2>&1
is "on starts both units, shows the titlebars, hides the cursor and pokes the bar" \
  'systemctl --user start huix-auto-rotate.service huix-virt-keyboard.service
hyprctl eval hl.config({ plugin = { hyprbars = { enabled = true } } })
hyprctl eval hl.config({ cursor = { invisible = true } })
pkill -RTMIN+10 waybar' "$(grep -E '^(systemctl --user start|hyprctl eval hl.config\(\{ (plugin|cursor)|pkill)' "$STUB_LOG")"

reset_log
# Explicitly empty: the shell running the tests may carry the session's own signal number
STUB_ACTIVE=0 HUIX_TABLET_SIGNAL= bash "$tablet" on >/dev/null 2>&1
is "without a bar signal declared nothing is poked" "" "$(grep '^pkill' "$STUB_LOG")"

reset_log
STUB_ACTIVE=1 bash "$tablet" off >/dev/null 2>&1
is "off stops both units, hides the titlebars, shows the cursor and puts the screen upright" \
  'systemctl --user stop huix-auto-rotate.service huix-virt-keyboard.service
hyprctl eval hl.config({ plugin = { hyprbars = { enabled = false } } })
hyprctl eval hl.config({ cursor = { invisible = false } })
hyprctl eval hl.monitor({ output = "eDP-1", mode = "1920x1080@59.98400", position = "0x0", scale = 1.3333334, transform = 0 })' "$(grep -E '^(systemctl --user stop|hyprctl eval hl\.(config\(\{ (plugin|cursor)|monitor))' "$STUB_LOG")"

is "the bar button is the keyboard glyph in the mode and nothing outside it" \
  '{"text":"⌨️","class":"on"} {"text":"","class":"off"}' \
  "$(STUB_ACTIVE=1 bash "$tablet" virt-keyboard status 2>/dev/null) $(STUB_ACTIVE=0 bash "$tablet" virt-keyboard status 2>/dev/null)"

is "status reads the auto-rotate unit" "on off" "$(STUB_ACTIVE=1 bash "$tablet" status 2>/dev/null) $(STUB_ACTIVE=0 bash "$tablet" status 2>/dev/null)"

reset_log
STUB_ACTIVE=0 STUB_EVTEST=10 bash "$tablet" sync >/dev/null 2>&1
is "sync enters the mode when the switch is on and asks the device evtest named" \
  "evtest --query /dev/input/event7 EV_SW SW_TABLET_MODE
systemctl --user start huix-auto-rotate.service huix-virt-keyboard.service" "$(grep -E '^(evtest|systemctl --user start)' "$STUB_LOG")"

reset_log
STUB_ACTIVE=1 STUB_EVTEST=0 bash "$tablet" sync >/dev/null 2>&1
is "sync leaves the mode when the switch is off" \
  "systemctl --user stop huix-auto-rotate.service huix-virt-keyboard.service" "$(grep '^systemctl --user stop' "$STUB_LOG")"

reset_log
STUB_ACTIVE=1 STUB_EVTEST=10 bash "$tablet" sync >/dev/null 2>&1
is "sync in the mode restarts auto-rotate so the sensor speaks again after a reload" \
  "systemctl --user restart huix-auto-rotate.service" "$(grep '^systemctl --user restart' "$STUB_LOG")"

reset_log
STUB_ACTIVE=1 bash "$tablet" virt-keyboard toggle >/dev/null 2>&1
is "virt-keyboard toggle with the keyboard running sends SIGRTMIN" "pkill -RTMIN -x wvkbd-mobintl" "$(grep '^pkill' "$STUB_LOG")"

reset_log
STUB_ACTIVE=0 bash "$tablet" virt-keyboard toggle >/dev/null 2>&1
is "virt-keyboard toggle without the keyboard starts its unit and shows it" \
  "systemctl --user start huix-virt-keyboard.service
pkill -USR2 -x wvkbd-mobintl" "$(grep -E '^(systemctl --user start|pkill)' "$STUB_LOG")"

reset_log
STUB_ACTIVE=1 bash "$tablet" virt-keyboard hide >/dev/null 2>&1
is "virt-keyboard hide sends SIGUSR1" "pkill -USR1 -x wvkbd-mobintl" "$(grep '^pkill' "$STUB_LOG")"

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
is "status shows used RAM and used swap, red above the threshold" \
  '{"text":"6.0/0.8Gb 🧠","tooltip":"RAM 6.0 of 8.0 Gb, swap 0.8 of 4.0 Gb","class":"swap"}' "$(bash "$memory" status)"
is "a higher threshold keeps the class ok" '"class":"ok"' "$(bash "$memory" status -w 1024 | grep -o '"class":"[a-z]*"')"
is "the environment sets the threshold too" '"class":"ok"' "$(HUIX_SWAP_WARN_MB=1024 bash "$memory" status | grep -o '"class":"[a-z]*"')"
cat >"$HUIX_MEMINFO" <<'EOF'
MemTotal:        8388608 kB
MemAvailable:    2097152 kB
SwapTotal:             0 kB
SwapFree:              0 kB
EOF
is "without a swap device only the RAM is shown" \
  '{"text":"6.0Gb 🧠","tooltip":"RAM 6.0 of 8.0 Gb, no swap","class":"ok"}' "$(bash "$memory" status)"
bash "$memory" status -w many >/dev/null 2>&1
is "a threshold that is not a number is a usage error" 2 "$?"
HUIX_MEMINFO=$work/missing bash "$memory" status >/dev/null 2>&1
is "an unreadable memory file is a failure" 1 "$?"

if ((failures)); then
  printf 'run.sh: %d test(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'run.sh: everything holds\n'
