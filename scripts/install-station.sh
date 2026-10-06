#!/usr/bin/env bash
# Run from a store copy by the station-install unit of nixos/station/installer/iso.nix, which
# sets every STATION_ variable from the configuration it installs and puts the tools on PATH.
# The secrets come from the image that make-station-iso.sh writes; the names inside it and
# their checks are in lib/station-secrets.sh. Each step either works or stops the run with a
# root shell on the terminal, and only the last step powers the machine off
# Needs bash 4.4 to wait for the tee of a process substitution, and runs only on the installer
# image
set -euo pipefail

usage() {
  cat <<'EOF'
install-station.sh — erase the station's disk and install its system there, then power off

  install-station.sh        install, asking nothing; any key in the countdown stops it
  install-station.sh help   this text

The configuration of the image sets the variables. STATION_DISK is the disk to erase, by its
/dev/disk/by-id path. STATION_DISKO is the disko program that erases, partitions and mounts it
under STATION_ROOT. STATION_SYSTEM is the system to install. STATION_KEY_PATH is where the
installed system reads its age key, and STATION_TAILSCALE_DIR is the state directory of its
tailscaled.

Nothing is touched unless the machine booted in UEFI mode, STATION_DISK exists, a mounted or
mountable ISO 9660 medium holds the directory station-secrets with valid secrets, and a 30 s
countdown on the terminal passes with no key pressed. A refusal or a failed step prints its
reason and leaves a root shell on the terminal; the machine stays on. Everything printed also
goes to /run/station-install.log
Nothing here reaches the network
Exit 0 when the system is installed and the power-off is asked for, 1 when it stops without a
terminal to leave a shell on, 2 on a usage error or a missing variable
EOF
}

die() { # the request itself is wrong
  printf 'install-station.sh: %s\n' "$1" >&2
  exit 2
}

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/lib/station-secrets.sh"

LOG=/run/station-install.log
COUNTDOWN=30
term=
secrets=
tee_pid=

# stop REASON — the end of every run that does not install: the reason, the log and a shell
stop() {
  printf '\n%s\n\n' "$1"
  printf 'The installer stopped. The machine stays on, and the log is %s\n' "$LOG"
  if [ -n "$term" ]; then
    printf 'This is a root shell; type poweroff to switch the machine off\n\n'
  fi
  # tee writes the log on its own; it gets its end of input here, and the log is whole once it
  # exits. The shell replaces this process, and the unit's end would kill a tee still writing
  if [ -n "$tee_pid" ]; then
    exec >/dev/null 2>&1
    wait "$tee_pid" || true
  fi
  if [ -z "$term" ]; then
    exit 1
  fi
  exec bash --login <"$term" >"$term" 2>&1
}

# step NAME COMMAND... — runs one step and stops the run when it fails
step() {
  local name=$1
  shift
  printf '\n==> %s\n' "$name"
  "$@" || stop "The step \"$name\" failed, so nothing after it was done"
}

# Prints the secrets directory of the medium. The image mounts its medium at boot, but a loader
# such as Ventoy may hand it over another way, so every mounted ISO 9660 file system is asked
# first, and then every ISO 9660 device that is not mounted, read-only
find_secrets() {
  local target dev probe=/run/station-medium
  while IFS= read -r target; do
    if [ -d "$target/$secrets_dir_name" ]; then
      printf '%s\n' "$target/$secrets_dir_name"
      return 0
    fi
  done < <(findmnt -rn -t iso9660 -o TARGET | sed 's/\\x20/ /g')
  mkdir -p "$probe"
  while IFS= read -r dev; do
    mount -o ro -t iso9660 "$dev" "$probe" 2>/dev/null || continue
    if [ -d "$probe/$secrets_dir_name" ]; then
      printf '%s\n' "$probe/$secrets_dir_name"
      return 0
    fi
    umount "$probe"
  done < <(blkid -o device -t TYPE=iso9660 || true)
  return 1
}

# Returns 0 when the countdown runs out and 1 when a key stops it
countdown() {
  local left=$COUNTDOWN key
  # A key pressed before the question is not an answer to it
  while read -r -s -n 1 -t 0.05 key <"$term"; do :; done
  while ((left > 0)); do
    printf '\rErasing it in %2d s. Press any key to stop. ' "$left"
    if read -r -s -n 1 -t 1 key <"$term"; then
      printf '\n'
      return 1
    fi
    left=$((left - 1))
  done
  printf '\n'
}

place_secrets() {
  local key=$STATION_ROOT$STATION_KEY_PATH state=$STATION_ROOT$STATION_TAILSCALE_DIR
  mkdir -p "$(dirname -- "$(dirname -- "$key")")" "$(dirname -- "$state")" &&
    install -d -m 0700 -o 0 -g 0 "$(dirname -- "$key")" &&
    install -m 0600 -o 0 -g 0 "$secrets/$age_key_name" "$key" &&
    install -d -m 0700 -o 0 -g 0 "$state" &&
    tar -x -f "$secrets/$tailscale_tar_name" -C "$state" --strip-components=1 \
      --no-same-owner "$tailscale_top_name" &&
    chown -R 0:0 "$state" &&
    chmod -R go-rwx "$state"
}

install_system() {
  nixos-install --root "$STATION_ROOT" --system "$STATION_SYSTEM" \
    --no-root-passwd --no-channel-copy </dev/null
}

unmount_all() {
  sync && umount -R "$STATION_ROOT"
}

install_station() {
  local name problem disk=${STATION_DISK:-}
  for name in STATION_DISK STATION_DISKO STATION_ROOT STATION_SYSTEM STATION_KEY_PATH \
    STATION_TAILSCALE_DIR; do
    [ -n "${!name:-}" ] || die "$name is not set"
  done

  if [ -t 0 ]; then
    term=$(tty)
  fi
  exec > >(tee -a "$LOG") 2>&1
  tee_pid=$!
  printf 'Station installer: %s onto %s\n' "$STATION_SYSTEM" "$disk"

  [ -n "$term" ] || stop "There is no terminal for the countdown, so nothing is erased."
  # systemd-boot, the station's loader, installs only into UEFI firmware
  [ -d /sys/firmware/efi ] ||
    stop "This machine booted the stick in legacy BIOS mode, and the station needs UEFI.
Nothing was touched. Boot the stick again in UEFI mode."

  udevadm settle --timeout=30 || true
  [ -b "$disk" ] ||
    stop "This machine has no disk $disk.
This stick installs the station onto that one disk only, and this is not that machine.
Nothing was touched."

  secrets=$(find_secrets) ||
    stop "The image holds no $secrets_dir_name directory: it is the plain image from Nix.
Add the secrets with make-station-iso.sh and boot the copy it writes. Nothing was touched."
  if ! problem=$(station_secrets_problem "$secrets"); then
    stop "The secrets on the stick are not usable: $problem. Nothing was touched."
  fi
  printf 'The secrets are in %s, on %s\n' "$secrets" "$(findmnt -no SOURCE --target "$secrets")"

  printf '\nThis erases every partition on\n  %s\n  %s\n\n' "$disk" \
    "$(lsblk -dno MODEL,SIZE "$disk" | tr -s ' ')"
  lsblk -o NAME,SIZE,FSTYPE,LABEL "$disk" || true
  printf '\n'
  countdown || stop "A key stopped the countdown. Nothing was touched."

  step "Erase, partition and mount $disk" "$STATION_DISKO" --yes-wipe-all-disks
  step "Place the age key and the Tailscale state" place_secrets
  step "Install the system" install_system
  step "Unmount the disk" unmount_all

  printf '\nThe station is installed. It powers off in 10 s: take the stick out, then switch\n'
  printf 'it on. Delete the image on the stick afterwards, as it holds the secrets\n'
  sleep 10
  systemctl poweroff
}

cmd=${1:-}
case "$cmd" in
  '')
    install_station
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
