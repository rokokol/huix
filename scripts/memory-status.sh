#!/usr/bin/env bash
# waybar's own memory module shows the RAM alone, so the number with the swap beside it
# comes from here. No class follows the swap: the amount in use says nothing about whether
# the machine pages right now
# Needs awk beside bash
set -euo pipefail

usage() {
  cat <<'EOF'
memory-status.sh — used RAM, and used swap when there is any, as one waybar JSON line

  memory-status.sh status   print {"text":…,"tooltip":…}
  memory-status.sh help     this text

The text is "<ram>Gb 🧠" with no swap device, and "<ram>/<swap>Gb 🧠" with one
Environment: HUIX_MEMINFO is the file read (default /proc/meminfo)
Nothing here reaches the network
Exit 0 done, 1 when the memory file cannot be read, 2 on a usage error
EOF
}

fail() { # the thing asked about is wrong
  printf 'memory-status.sh: %s\n' "$1" >&2
  exit 1
}

die() { # the request itself is wrong
  printf 'memory-status.sh: %s\n' "$1" >&2
  exit 2
}

cmd_status() {
  local meminfo="${HUIX_MEMINFO:-/proc/meminfo}"
  (($# == 0)) || die "status takes no argument: $1"
  [ -r "$meminfo" ] || fail "cannot read $meminfo"
  # Used RAM is what the kernel could not hand out on request; used swap is total minus free
  awk '
    /^MemTotal:/ { total = $2 }
    /^MemAvailable:/ { available = $2 }
    /^SwapTotal:/ { swap_total = $2 }
    /^SwapFree:/ { swap_free = $2 }
    END {
      used = (total - available) / 1048576
      swap_used = (swap_total - swap_free) / 1048576
      if (swap_total > 0) {
        text = sprintf("%.1f/%.1fGb 🧠", used, swap_used)
        tooltip = sprintf("RAM %.1f of %.1f Gb, swap %.1f of %.1f Gb", used, total / 1048576, swap_used, swap_total / 1048576)
      } else {
        text = sprintf("%.1fGb 🧠", used)
        tooltip = sprintf("RAM %.1f of %.1f Gb, no swap", used, total / 1048576)
      }
      printf "{\"text\":\"%s\",\"tooltip\":\"%s\"}\n", text, tooltip
    }
  ' "$meminfo"
}

cmd="${1:-}"
(($# == 0)) || shift
case "$cmd" in
  status) cmd_status "$@" ;;
  -h | --help | help) usage ;;
  '')
    usage >&2
    exit 2
    ;;
  *)
    printf 'memory-status.sh: no such subcommand: %s\n\n' "$cmd" >&2
    usage >&2
    exit 2
    ;;
esac
