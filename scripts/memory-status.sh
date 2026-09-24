#!/usr/bin/env bash
# waybar's own memory module has thresholds on the RAM percentage only and no class that
# follows the swap, so the number the bar shows and the colour it turns come from here
# Needs awk beside bash
set -euo pipefail

usage() {
  cat <<'EOF'
memory-status.sh — used RAM, and used swap when there is any, as one waybar JSON line

  memory-status.sh status [-w MB]   print {"text":…,"tooltip":…,"class":…}
  memory-status.sh help             this text

  -w MB   swap in use above which the class is "swap" (default: $HUIX_SWAP_WARN_MB, else 500)

The text is "<ram>Gb 🧠" with no swap device, and "<ram>/<swap>Gb 🧠" with one; the
class is "swap" above the threshold and "ok" otherwise
Environment: HUIX_SWAP_WARN_MB is the threshold when -w is not given; HUIX_MEMINFO is
the file read (default /proc/meminfo)
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
  local warn="${HUIX_SWAP_WARN_MB:-500}" meminfo="${HUIX_MEMINFO:-/proc/meminfo}"
  while (($#)); do
    case "$1" in
      -w)
        (($# >= 2)) || die "-w needs a number of megabytes"
        warn=$2
        shift 2
        ;;
      -*) die "no such flag: $1" ;;
      *) die "status takes no argument: $1" ;;
    esac
  done
  [[ "$warn" =~ ^[0-9]+$ ]] || die "the threshold is a whole number of megabytes, not $warn"
  [ -r "$meminfo" ] || fail "cannot read $meminfo"
  # Used RAM is what the kernel could not hand out on request; used swap is total minus free
  awk -v warn="$warn" '
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
      class = (swap_used * 1024 > warn) ? "swap" : "ok"
      printf "{\"text\":\"%s\",\"tooltip\":\"%s\",\"class\":\"%s\"}\n", text, tooltip, class
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
