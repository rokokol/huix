#!/usr/bin/env bash
# Run from a store copy by nixos/services/system/monitoring/backup-heartbeat.nix and
# pushgateway.nix, as users that can only read what they check. Each finding goes to stderr
# when it is found. The summary goes last, so the last line of the unit's journal carries the
# whole verdict
# Needs bash 3.2 and GNU findutils for find -printf: the server it watches runs Linux
set -euo pipefail

usage() {
  cat <<'EOF'
backup-heartbeat.sh — fail when a node behind this server went quiet

  backup-heartbeat.sh check [-m FILE] [-p FILE] DATA HTPASSWD MAX_AGE MIN_FREE
  backup-heartbeat.sh push [-p FILE] [-l USER]... HTPASSWD MAX_SILENCE < PAGE

  -m FILE   also write the newest snapshot time of each repository, and the free space,
            to FILE as Prometheus text metrics (a missing repository is time 0)
  -p FILE   write each problem to FILE as a cause, one a line: a key, a tab, a subject.
            The run then passes with problems found, and FILE carries them; an empty FILE
            means none
  -l USER   push: a user of HTPASSWD that backs up from this host and pushes nowhere;
            give it once for each such user

DATA is the rest-server data directory. Every user in the HTPASSWD file is one expected
repository at DATA/<user>/, so a user that never pushed is reported as well. The user named
metrics is the exception: rest-server gives that name the metrics page and nothing else. A repository
is stale when the newest file under DATA/<user>/snapshots/ is older than MAX_AGE, written
as a number with s, m, h or d (36h). MIN_FREE is the space the filesystem of DATA must keep
free, a number of bytes with K, M, G or T in powers of 1024 (10G). A repository one level
deeper, at DATA/<user>/<name>/, is not the expected layout: it is reported as missing, with
a note that names the nested path

push reads a Pushgateway metrics page on stdin. Every user in HTPASSWD is one expected node,
which pushes with its own name as the instance label, except each user given with -l: that
one backs up from the server's own host and pushes nowhere. A node fails when its newest
push_time_seconds, over every job, is older than MAX_SILENCE (1h), or when it never pushed.
A node that pushes on time also fails for each problem it reports of itself: a series
node_problem{key="…",summary="…"} with a value above zero, one a problem

Every problem is reported, one line each, and a summary line comes last
Nothing here reaches the network
Exit 0 when nothing is wrong or -p took the problems, 1 when something is wrong, 2 on a
usage error or an HTPASSWD with no user in it
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

# The list that -p writes, and the host that names the subjects in it
causes_file=""
local_users=()
causes=""
host=$(uname -n)

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
      -p)
        (($# >= 2)) || die "-p needs a file"
        causes_file=$2
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
  local users=() user
  read_users "$htpasswd"

  local now problems=() series=() newest snapdir nested
  now=$(date +%s)
  for user in "${users[@]}"; do
    # The name becomes a path and a metric label, so only a plain one is accepted
    case "$user" in
      '' | .* | *[![:alnum:]._-]*)
        printf 'backup-heartbeat.sh: %s: not a usable repository name\n' "$user" >&2
        problem bad-name "bad name" "the restic server has a user that is no usable repository name"
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
      problem "$user-missing" "$user missing" "the backup of $user has no snapshot"
    elif ((now - newest > max_age)); then
      printf 'backup-heartbeat.sh: %s: newest snapshot is %d h old\n' \
        "$user" $(((now - newest) / 3600)) >&2
      problem "$user-stale" "$user stale" "the backup of $user is older than $3"
    fi
  done

  # df -P prints one line per filesystem whatever the length of its name; column 4 is KiB free
  local free_kib free=-1
  if free_kib=$(df -P -k -- "$data" 2>/dev/null | awk 'NR == 2 { print $4 }') && [ -n "$free_kib" ]; then
    free=$((free_kib << 10))
    if ((free < min_free)); then
      human "$free"
      printf 'backup-heartbeat.sh: only %s free on %s\n' "$human" "$data" >&2
      problem low-space "low space" "only $human free for the backups"
    fi
  else
    printf 'backup-heartbeat.sh: cannot read the free space of %s\n' "$data" >&2
    problem no-data "no data directory" "the backup directory cannot be read"
  fi

  if [ -n "$metrics" ]; then
    write_metrics "$metrics" "$free" "${series[@]+"${series[@]}"}"
  fi

  summarise "backups"
  human "$free"
  printf 'backup-heartbeat.sh: everything holds: %d repositories fresh, %s free\n' \
    "${#users[@]}" "$human"
}

cmd_push() {
  while (($#)); do
    case "$1" in
      -p)
        (($# >= 2)) || die "-p needs a file"
        causes_file=$2
        shift 2
        ;;
      -l)
        (($# >= 2)) || die "-l needs a user"
        local_users+=("$2")
        shift 2
        ;;
      -*) die "no such flag: $1" ;;
      *) break ;;
    esac
  done
  (($# == 2)) || die "push takes HTPASSWD MAX_SILENCE"
  local htpasswd=$1 seconds
  parse_age "$2"
  local max_silence=$seconds
  local users=() user
  read_users "$htpasswd"

  # The newest push_time_seconds of each instance, over every job it pushed under, as
  # "time <instance> <seconds>", and each node_problem series, one a problem the node reports
  # of itself, as "problem <instance> <key> <summary>". A label value is the text between the
  # quotes after its name, wherever the label stands, and a summary may hold an escaped quote
  local page
  page=$(awk '
    function label(name,    v) {
      if (!match($0, name "=\"([^\"\\\\]|\\\\.)*\"")) return ""
      v = substr($0, RSTART + length(name) + 2, RLENGTH - length(name) - 3)
      gsub(/\\"/, "\"", v)
      gsub(/\\\\/, "\\", v)
      return v
    }
    /^push_time_seconds\{/ {
      name = label("instance")
      t = int($NF + 0)
      if (name != "" && t > newest[name]) newest[name] = t
    }
    /^node_problem\{/ && $NF + 0 > 0 {
      print "problem", label("instance"), label("key"), label("summary")
    }
    END { for (name in newest) print "time", name, newest[name] }
  ')

  local now problems=() pushed key summary
  now=$(date +%s)
  for user in "${users[@]}"; do
    case " ${local_users[*]-} " in *" $user "*) continue ;; esac
    pushed=$(awk -v u="$user" '$1 == "time" && $2 == u { print $3 }' <<<"$page")
    if [ -z "$pushed" ]; then
      printf 'backup-heartbeat.sh: %s: never pushed\n' "$user" >&2
      # Never and not lately are one fault to the owner: the station does not hear the node
      problem "$user-silent" "$user never pushed" "$user does not push to the station"
    elif ((now - pushed > max_silence)); then
      printf 'backup-heartbeat.sh: %s: silent for %d min\n' "$user" $(((now - pushed) / 60)) >&2
      problem "$user-silent" "$user silent" "$user does not push to the station"
    else
      # What a node that pushes on time reports of itself; a silent node's last word is stale
      while read -r _ _ key summary; do
        case "$key" in
          '' | .* | *[!A-Za-z0-9._-]*) key=unnamed ;;
        esac
        printf 'backup-heartbeat.sh: %s: %s\n' "$user" "$summary" >&2
        problem "$user-$key" "$user: $summary" "$user: $summary"
      done < <(awk -v u="$user" '$1 == "problem" && $2 == u' <<<"$page")
    fi
  done

  summarise "pushes"
  printf 'backup-heartbeat.sh: everything holds: %d nodes pushed\n' "${#users[@]}"
}

# read_users HTPASSWD — sets $users to the expected nodes. A user is the text before the first
# colon of a line; blank lines and comments are skipped. rest-server admits the user "metrics"
# to /metrics only, so that name is never a node
read_users() {
  local line
  [ -r "$1" ] || die "cannot read $1"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'* | metrics:*) continue ;; esac
    users+=("${line%%:*}")
  done <"$1"
  ((${#users[@]})) || die "$1 names no user, so there is nothing to check"
}

# problem KEY SHORT SUBJECT — one problem: SHORT for the summary line, KEY and SUBJECT for the
# list of causes that -p writes
problem() {
  problems+=("$2")
  causes+="$1"$'\t'"[$host] $3"$'\n'
}

# summarise WHAT — writes the list of causes when -p asked for one, then puts every problem on
# the last line. Without -p a problem fails the run; with it the list carries them, and the run
# passes
summarise() {
  if [ -n "$causes_file" ]; then
    local tmp=$causes_file.tmp.$$
    mkdir -p -- "$(dirname -- "$causes_file")"
    printf '%s' "$causes" >"$tmp"
    mv -f -- "$tmp" "$causes_file"
  fi
  ((${#problems[@]})) || return 0
  local summary="" p
  for p in "${problems[@]}"; do
    summary="${summary:+$summary, }$p"
  done
  if [ -n "$causes_file" ]; then
    printf 'backup-heartbeat.sh: %d problem(s) in %s: %s\n' "${#problems[@]}" "$1" "$summary" >&2
    exit 0
  fi
  fail "${#problems[@]} problem(s) in $1: $summary"
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
  push) cmd_push "$@" ;;
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
