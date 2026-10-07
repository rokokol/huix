#!/usr/bin/env bash
# waybar's own memory module shows the RAM alone, so the number with the swap beside it
# comes from here. Each swap device is its own figure, in the order the kernel fills them: a
# zram device in front of a partition says how much of the swap still sits in RAM. No class
# follows the swap: the amount in use says nothing about whether the machine pages right now
# Needs awk, sort and tail beside bash
set -euo pipefail

usage() {
  cat <<'EOF'
memory-status.sh — used RAM, and used swap when there is any, as one waybar JSON line

  memory-status.sh status   print {"text":…,"tooltip":…}
  memory-status.sh help     this text

The text is "<ram>Gb 🧠" with no swap device, "<ram>/<swap>Gb 🧠" with one, and
"<ram>/<swap>+<swap>Gb 🧠" with more, the swap in use on each device from the highest priority
down; the kernel fills them in that order. The tooltip names each device
Environment: HUIX_MEMINFO and HUIX_SWAPS are the files read (default /proc/meminfo and
/proc/swaps)
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
  local meminfo="${HUIX_MEMINFO:-/proc/meminfo}" swaps="${HUIX_SWAPS:-/proc/swaps}"
  (($# == 0)) || die "status takes no argument: $1"
  [ -r "$meminfo" ] || fail "cannot read $meminfo"
  [ -r "$swaps" ] || fail "cannot read $swaps"
  # Used RAM is what the kernel could not hand out on request. /proc/swaps gives each device
  # as name, type, size, used and priority in KiB, under a header line; the devices go in
  # sorted by priority, highest first
  awk '
    FNR == NR {
      if ($1 == "MemTotal:") total = $2
      if ($1 == "MemAvailable:") available = $2
      next
    }
    {
      n = split($1, path, "/")
      count++
      text_swap = text_swap (count > 1 ? "+" : "") sprintf("%.1f", $4 / 1048576)
      tooltip_swap = tooltip_swap sprintf("\\n%s %.1f of %.1f Gb, priority %d", path[n], $4 / 1048576, $3 / 1048576, $5)
    }
    END {
      used = (total - available) / 1048576
      ram = sprintf("RAM %.1f of %.1f Gb", used, total / 1048576)
      if (count > 0) {
        text = sprintf("%.1f/%sGb 🧠", used, text_swap)
        tooltip = ram tooltip_swap
      } else {
        text = sprintf("%.1fGb 🧠", used)
        tooltip = ram ", no swap"
      }
      printf "{\"text\":\"%s\",\"tooltip\":\"%s\"}\n", text, tooltip
    }
  ' "$meminfo" <(tail -n +2 "$swaps" | sort -k5,5nr)
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
