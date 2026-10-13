#!/usr/bin/env bash
# Run from a store copy by nixos/services/tools/syncthing.nix after each btrbk run, as root,
# since the snapshots are root's. btrbk names a snapshot <subvolume>.<YYYYMMDDTHHMM> in local
# time when its timestamp_format is long, and that name is all this reads
# Needs bash 3.2 and GNU coreutils for date -d: the host it runs on is NixOS
set -euo pipefail

usage() {
  cat <<'EOF'
btrbk-metrics.sh — the snapshots of each folder as Prometheus text metrics

  btrbk-metrics.sh write SNAPSHOTS FILE

SNAPSHOTS is btrbk's snapshot directory. Each entry named <folder>.<YYYYMMDDTHHMM>, the
timestamp in local time, is one snapshot of that folder; any other entry is left out.
FILE gets btrbk_snapshots{folder} and btrbk_newest_snapshot_timestamp_seconds{folder},
written beside FILE and renamed over it
Nothing here reaches the network
Exit 0 when FILE is written, 1 when SNAPSHOTS cannot be read, 2 on a usage error
EOF
}

fail() { # the thing asked about is wrong
  printf 'btrbk-metrics.sh: %s\n' "$1" >&2
  exit 1
}

die() { # the request itself is wrong
  printf 'btrbk-metrics.sh: %s\n' "$1" >&2
  exit 2
}

cmd_write() {
  (($# == 2)) || die "write takes SNAPSHOTS FILE"
  local dir=$1 file=$2 entry name stamp folder seconds
  [ -d "$dir" ] && [ -r "$dir" ] || fail "cannot read $dir"

  # One line of "folder seconds" for each snapshot
  local lines=""
  for entry in "$dir"/*; do
    name=${entry##*/}
    case "$name" in .*) continue ;; esac
    stamp=${name##*.}
    folder=${name%.*}
    case "$stamp" in
      [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9]) ;;
      *) continue ;;
    esac
    [ "$folder" != "$name" ] && [ -n "$folder" ] || continue
    seconds=$(date -d "${stamp:0:8} ${stamp:9:2}:${stamp:11:2}" +%s)
    lines+="$folder $seconds"$'\n'
  done

  local tmp=$file.tmp.$$
  mkdir -p -- "$(dirname -- "$file")"
  {
    printf '# HELP btrbk_snapshots Snapshots btrbk keeps of the folder\n'
    printf '# TYPE btrbk_snapshots gauge\n'
    printf '%s' "$lines" | awk 'NF { n[$1]++ } END { for (f in n) printf "btrbk_snapshots{folder=\"%s\"} %d\n", f, n[f] }'
    printf '# HELP btrbk_newest_snapshot_timestamp_seconds Time of the newest snapshot of the folder\n'
    printf '# TYPE btrbk_newest_snapshot_timestamp_seconds gauge\n'
    printf '%s' "$lines" | awk 'NF { if ($2 > m[$1]) m[$1] = $2 } END { for (f in m) printf "btrbk_newest_snapshot_timestamp_seconds{folder=\"%s\"} %d\n", f, m[f] }'
  } >"$tmp"
  mv -f -- "$tmp" "$file"
}

cmd="${1:-}"
(($# == 0)) || shift
case "$cmd" in
  write) cmd_write "$@" ;;
  -h | --help | help) usage ;;
  '')
    usage >&2
    exit 2
    ;;
  *)
    printf 'btrbk-metrics.sh: no such subcommand: %s\n\n' "$cmd" >&2
    usage >&2
    exit 2
    ;;
esac
