#!/usr/bin/env bash
# The second half of the station's installer image. Nix builds the first half with no secret in
# it, because everything Nix builds lies world-readable in /nix/store. This script adds the
# secrets to a copy outside the store, and install-station.sh takes them out on the station.
# The names inside the image and the checks of the files are in lib/station-secrets.sh
# Needs bash 3.2, POSIX tools and xorriso
set -euo pipefail

usage() {
  cat <<'EOF'
make-station-iso.sh — copy the station's installer image with its secrets added inside

  make-station-iso.sh write [-s DIR] ISO OUTPUT   write OUTPUT: ISO with the secrets of DIR inside
  make-station-iso.sh help                        this text

  -s DIR   the directory with age-key.txt (the station's age key) and tailscale-state.tar (a
           tar whose one top-level directory ts-state/ holds a tailscaled state directory);
           default: $XDG_STATE_HOME/huix/station-bootstrap, with ~/.local/state in place of an
           unset XDG_STATE_HOME

ISO is the image `nix build .#station-installer` makes, in result/iso/. The copy keeps its boot
records and gains /station-secrets, readable by root alone. OUTPUT must not exist yet and must
not be inside a git work tree or the Nix store (NIX_STORE_DIR, default /nix/store); it is
created readable by its owner alone. The secrets are read from DIR and written into OUTPUT,
and nowhere else. OUTPUT is a secret itself: delete it once the station is installed
Nothing here reaches the network
Exit 0 when OUTPUT is written, 1 when a secret, the image or the write is wrong, 2 on a usage
error or a refused OUTPUT
EOF
}

fail() { # the thing asked about is wrong
  printf 'make-station-iso.sh: %s\n' "$1" >&2
  exit 1
}

die() { # the request itself is wrong
  printf 'make-station-iso.sh: %s\n' "$1" >&2
  exit 2
}

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/lib/station-secrets.sh"

# The volume ID is how the booted installer finds its own medium, so the copy must keep it
volume_id() {
  xorriso -indev "$1" -pvd_info 2>/dev/null | sed -n 's/^Volume Id *: //p'
}

boot_images() {
  xorriso -indev "$1" -report_el_torito plain 2>/dev/null | grep -c '^El Torito boot img' || true
}

# refuse_location OUTPUT — exits 2 when OUTPUT would land where others can read it or where it
# could be committed; prints the absolute path otherwise
refuse_location() {
  local out=$1 dir real store
  dir=$(dirname -- "$out")
  [ -d "$dir" ] || die "$dir is not a directory"
  real=$(cd -P -- "$dir" && pwd -P)
  store=${NIX_STORE_DIR:-/nix/store}
  case "$real/" in
    "$store"/*) die "$out is in the Nix store, which every user can read" ;;
  esac
  dir=$real
  while :; do
    [ ! -e "$dir/.git" ] || die "$out is inside the git work tree $dir, where it could be committed"
    [ "$dir" != / ] || break
    dir=$(dirname -- "$dir")
  done
  out=$real/$(basename -- "$out")
  [ ! -e "$out" ] && [ ! -L "$out" ] || die "$out exists already; delete it or name another file"
  printf '%s\n' "$out"
}

cmd_write() {
  local src=${XDG_STATE_HOME:-$HOME/.local/state}/huix/station-bootstrap iso out problem
  local dest=/$secrets_dir_name
  while (($#)); do
    case "$1" in
      -s)
        (($# >= 2)) || die "-s needs a directory"
        src=$2
        shift 2
        ;;
      -*) die "no such flag: $1" ;;
      *) break ;;
    esac
  done
  (($# == 2)) || die "write needs ISO and OUTPUT; see make-station-iso.sh help"
  iso=$1
  out=$(refuse_location "$2")
  [ -f "$iso" ] && [ -r "$iso" ] || fail "$iso is not a readable image"
  if ! problem=$(station_secrets_problem "$src"); then
    fail "$problem"
  fi

  # From here on a partial file may hold the secrets, so every way out but success removes it
  umask 077
  trap 'rm -f -- "$out"' EXIT
  # The two replays carry over what xorriso would otherwise drop: the Joliet tree and the
  # other write options of the image, and its boot records with the partition tables
  xorriso -indev "$iso" -outdev "$out" \
    -assess_indev_features replay \
    -map "$src/$age_key_name" "$dest/$age_key_name" \
    -map "$src/$tailscale_tar_name" "$dest/$tailscale_tar_name" \
    -chown_r 0 "$dest" -- \
    -chgrp_r 0 "$dest" -- \
    -chmod 0700 "$dest" -- \
    -chmod 0600 "$dest/$age_key_name" "$dest/$tailscale_tar_name" -- \
    -boot_image any replay \
    -commit ||
    fail "xorriso could not write $out"
  chmod 600 "$out"
  [ "$(volume_id "$out")" = "$(volume_id "$iso")" ] ||
    fail "the copy lost the volume ID of $iso, and the installer would not find its medium"
  [ "$(boot_images "$out")" = "$(boot_images "$iso")" ] ||
    fail "the copy lost a boot image of $iso"
  trap - EXIT

  printf 'make-station-iso.sh: wrote %s\n' "$out" >&2
  printf '%s holds the age key and the Tailscale state of the station, so it is a secret itself.\n' \
    "$out" >&2
  printf 'Delete it from this computer and from the stick once the station is installed\n' >&2
}

cmd=${1:-}
(($# == 0)) || shift
case "$cmd" in
  write) cmd_write "$@" ;;
  -h | --help | help) usage ;;
  '')
    usage >&2
    exit 2
    ;;
  *)
    printf 'make-station-iso.sh: no such subcommand: %s\n\n' "$cmd" >&2
    usage >&2
    exit 2
    ;;
esac
