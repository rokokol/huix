#!/usr/bin/env bash
# Run from a store copy as the wake-pc command of nixos/station/wake-pc.nix, which sets the
# variables and puts wakeonlan and tailscale on PATH. The host has no checkout of this repository
# Needs bash 3.2 and POSIX tools only
set -euo pipefail

usage() {
  cat <<'EOF'
wake-pc.sh — wake the PC with a Wake-on-LAN magic packet

  wake-pc.sh        wake the PC and wait until it answers on the tailnet
  wake-pc.sh send   only send the packet
  wake-pc.sh help   this text

The host sets the variables. WAKE_PC_MAC_FILE names a file whose first line is the PC's
MAC address. WAKE_PC_BROADCAST is the broadcast address of the LAN, such as 192.168.0.255:
the packet goes there and leaves on the wired link, past any VPN route. WAKE_PC_HOST is
the PC's name on the tailnet, and WAKE_PC_WAIT the seconds to wait for it, 300 by default
Exit 0 when the PC is on, or the packet is sent for send; 1 when the MAC file cannot be read
or holds no MAC address; 2 on a usage error or a missing variable; 3 when the PC gave no
answer in the wait: it may have no power, or its boot stopped before the network came up
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

answers() {
  tailscale ping -c 1 --timeout 3s "$1" >/dev/null 2>&1
}

wake() {
  local host=${WAKE_PC_HOST:-} wait=${WAKE_PC_WAIT:-300} waited=0 step=10
  [ -n "$host" ] || die "WAKE_PC_HOST is not set"
  grep -Eqx '[0-9]+' <<<"$wait" || die "WAKE_PC_WAIT is not a number of seconds: $wait"
  if answers "$host"; then
    echo "$host is already on"
    return
  fi
  send >/dev/null
  until answers "$host"; do
    if ((waited >= wait)); then
      printf 'wake-pc.sh: %s gave no answer in %ss after the packet\n' "$host" "$wait" >&2
      exit 3
    fi
    sleep "$step"
    waited=$((waited + step))
  done
  echo "$host is on after about ${waited}s"
}

cmd=${1:-}
case "$cmd" in
  '')
    wake
    ;;
  send)
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
