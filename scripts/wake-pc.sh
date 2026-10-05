#!/usr/bin/env bash
# Run from a store copy as the wake-pc command of nixos/station/wake-pc.nix, which sets both
# variables and puts wakeonlan on PATH. The host has no checkout of this repository
# Needs bash 3.2 and POSIX tools only
set -euo pipefail

usage() {
  cat <<'EOF'
wake-pc.sh — wake the PC with a Wake-on-LAN magic packet

  wake-pc.sh        send the packet
  wake-pc.sh help   this text

The host sets two variables. WAKE_PC_MAC_FILE names a file whose first line is the PC's
MAC address. WAKE_PC_BROADCAST is the broadcast address of the LAN, such as 192.168.0.255:
the packet goes there and leaves on the wired link, past any VPN route
Exit 0 when the packet is sent, 1 when the MAC file cannot be read or holds no MAC address,
2 on a usage error or a missing variable
EOF
}

fail() { # the thing asked about is wrong
  printf 'wake-pc.sh: %s\n' "$1" >&2
  exit 1
}

die() { # the request itself is wrong
  printf 'wake-pc.sh: %s\n' "$1" >&2
  exit 2
}

send() {
  local mac_file=${WAKE_PC_MAC_FILE:-} broadcast=${WAKE_PC_BROADCAST:-} mac
  [ -n "$mac_file" ] || die "WAKE_PC_MAC_FILE is not set"
  [ -n "$broadcast" ] || die "WAKE_PC_BROADCAST is not set"
  [ -r "$mac_file" ] || fail "cannot read $mac_file"
  IFS= read -r mac <"$mac_file" || [ -n "${mac:-}" ] || fail "$mac_file is empty"
  grep -Eqx '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' <<<"$mac" ||
    fail "$mac_file holds no MAC address"
  wakeonlan -i "$broadcast" "$mac"
}

cmd=${1:-}
case "$cmd" in
  '')
    send
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
