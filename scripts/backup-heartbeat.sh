#!/usr/bin/env bash
# Run from a store copy by nixos/services/system/backup-heartbeat.nix, as a user that can only
# read the repositories. Each finding goes to stderr when it is found. The summary goes last,
# so the last line of the unit's journal carries the whole verdict
# Needs bash 3.2 and GNU findutils for find -printf: the server it watches runs Linux
set -euo pipefail

usage() {
  cat <<'EOF'
backup-heartbeat.sh — fail when a restic repository on this server got no recent snapshot

  backup-heartbeat.sh check [-m FILE] DATA HTPASSWD MAX_AGE MIN_FREE

  -m FILE   also write the newest snapshot time of each repository, and the free space,
            to FILE as Prometheus text metrics (a missing repository is time 0)

DATA is the rest-server data directory. Every user in the HTPASSWD file is one expected
repository at DATA/<user>/, so a user that never pushed is reported as well. The user named
metrics is the exception: rest-server gives that name the metrics page and nothing else. A repository
is stale when the newest file under DATA/<user>/snapshots/ is older than MAX_AGE, written
as a number with s, m, h or d (36h). MIN_FREE is the space the filesystem of DATA must keep
free, a number of bytes with K, M, G or T in powers of 1024 (10G). A repository one level
deeper, at DATA/<user>/<name>/, is not the expected layout: it is reported as missing, with
a note that names the nested path

Every problem is reported, one line each, and a summary line comes last
Nothing here reaches the network
Exit 0 when every repository is fresh and the space is above the floor, 1 when one is not or
DATA cannot be read, 2 on a usage error or an HTPASSWD with no user in it
EOF
}

fail() { # the thing asked about is wrong
  printf 'backup-heartbeat.sh: %s\n' "$1" >&2
  exit 1
}

die() { # the request itself is wrong
  printf 'backup-heartbeat.sh: %s\n' "$1" >&2
  exit 2
}

# parse_age TEXT — sets $seconds from 36h, 90m, 2d or 600s
parse_age() {
  local n=${1%[smhd]} unit=${1##*[0-9]}
  case "$n" in '' | *[!0-9]*) die "not an age: $1" ;; esac
  case "$unit" in
    s) seconds=$n ;;
    m) seconds=$((n * 60)) ;;
    h) seconds=$((n * 3600)) ;;
    d) seconds=$((n * 86400)) ;;
    *) die "not an age: $1" ;;
  esac
}

# parse_size TEXT — sets $bytes from 10G, 512M or a bare number of bytes
parse_size() {
  local n=${1%[KMGT]} unit=${1##*[0-9]}
  case "$n" in '' | *[!0-9]*) die "not a size: $1" ;; esac
  case "$unit" in
    '') bytes=$n ;;
    K) bytes=$((n << 10)) ;;
    M) bytes=$((n << 20)) ;;
    G) bytes=$((n << 30)) ;;
    T) bytes=$((n << 40)) ;;
    *) die "not a size: $1" ;;
  esac
}

# human BYTES — sets $human to a size in GiB with one decimal
human() {
  human=$(awk -v b="$1" 'BEGIN { printf "%.1f GiB", b / 1073741824 }')
}

cmd_check() {
  local metrics=""
  while (($#)); do
    case "$1" in
      -m)
        (($# >= 2)) || die "-m needs a file"
        metrics=$2
        shift 2
        ;;
      -*) die "no such flag: $1" ;;
      *) break ;;
    esac
  done
  (($# == 4)) || die "check takes DATA HTPASSWD MAX_AGE MIN_FREE"
  local data=$1 htpasswd=$2 seconds bytes
  parse_age "$3"
  local max_age=$seconds
  parse_size "$4"
  local min_free=$bytes
  [ -r "$htpasswd" ] || die "cannot read $htpasswd"

  # A user is the text before the first colon of a line; blank lines and comments are skipped.
  # rest-server admits the user "metrics" to /metrics only, so that name never has a repository
  local users=() user line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'* | metrics:*) continue ;; esac
    users+=("${line%%:*}")
  done <"$htpasswd"
  ((${#users[@]})) || die "$htpasswd names no user, so there is nothing to check"

  local now problems=() series=() newest snapdir nested
  now=$(date +%s)
  for user in "${users[@]}"; do
    # The name becomes a path and a metric label, so only a plain one is accepted
    case "$user" in
      '' | .* | *[![:alnum:]._-]*)
        printf 'backup-heartbeat.sh: %s: not a usable repository name\n' "$user" >&2
        problems+=("bad name")
        continue
        ;;
    esac
    snapdir=$data/$user/snapshots
    newest=0
    if [ -d "$snapdir" ]; then
      # awk reads every line, so find never meets a closed pipe
      newest=$(find "$snapdir" -type f -printf '%T@\n' |
        awk 'BEGIN { m = 0 } { t = int($1); if (t > m) m = t } END { print m }')
    fi
    series+=("$user $newest")
    if ((newest == 0)); then
      nested=$(find "$data/$user" -mindepth 2 -maxdepth 2 -name config -type f -print 2>/dev/null || true)
      if [ -n "$nested" ]; then
        nested=${nested%%$'\n'*}
        printf 'backup-heartbeat.sh: %s: no snapshot at %s/, but a nested repository at %s\n' \
          "$user" "$user" "${nested%/config}" >&2
      else
        printf 'backup-heartbeat.sh: %s: no snapshot at all\n' "$user" >&2
      fi
      problems+=("$user missing")
    elif ((now - newest > max_age)); then
      printf 'backup-heartbeat.sh: %s: newest snapshot is %d h old\n' \
        "$user" $(((now - newest) / 3600)) >&2
      problems+=("$user stale")
    fi
  done

  # df -P prints one line per filesystem whatever the length of its name; column 4 is KiB free
  local free_kib free=-1
  if free_kib=$(df -P -k -- "$data" 2>/dev/null | awk 'NR == 2 { print $4 }') && [ -n "$free_kib" ]; then
    free=$((free_kib << 10))
    if ((free < min_free)); then
      human "$free"
      printf 'backup-heartbeat.sh: only %s free on %s\n' "$human" "$data" >&2
      problems+=("low space")
    fi
  else
    printf 'backup-heartbeat.sh: cannot read the free space of %s\n' "$data" >&2
    problems+=("no data directory")
  fi

  if [ -n "$metrics" ]; then
    write_metrics "$metrics" "$free" "${series[@]+"${series[@]}"}"
  fi

  if ((${#problems[@]})); then
    local summary="" p
    for p in "${problems[@]}"; do
      summary="${summary:+$summary, }$p"
    done
    fail "${#problems[@]} problem(s) in backups: $summary"
  fi
  human "$free"
  printf 'backup-heartbeat.sh: everything holds: %d repositories fresh, %s free\n' \
    "${#users[@]}" "$human"
}

# write_metrics FILE FREE "USER TIME"... — written beside FILE and renamed over it, so a
# collector never reads half a file
write_metrics() {
  local file=$1 free=$2 tmp entry
  shift 2
  tmp=$file.tmp.$$
  mkdir -p -- "$(dirname -- "$file")"
  {
    printf '# HELP backup_last_snapshot_timestamp_seconds Newest snapshot file of the repository, 0 when none\n'
    printf '# TYPE backup_last_snapshot_timestamp_seconds gauge\n'
    for entry in "$@"; do
      printf 'backup_last_snapshot_timestamp_seconds{repository="%s"} %s\n' "${entry% *}" "${entry##* }"
    done
    if ((free >= 0)); then
      printf '# HELP backup_free_bytes Free space on the filesystem of the backup data\n'
      printf '# TYPE backup_free_bytes gauge\n'
      printf 'backup_free_bytes %s\n' "$free"
    fi
  } >"$tmp"
  mv -f -- "$tmp" "$file"
}

cmd="${1:-}"
(($# == 0)) || shift
case "$cmd" in
  check) cmd_check "$@" ;;
  -h | --help | help) usage ;;
  '')
    usage >&2
    exit 2
    ;;
  *)
    printf 'backup-heartbeat.sh: no such subcommand: %s\n\n' "$cmd" >&2
    usage >&2
    exit 2
    ;;
esac
