# Sourced by make-station-iso.sh, which puts the station's secrets into its installer image, and
# by install-station.sh, which takes them out on the station; nothing here runs on its own
# Needs bash 3.2 and POSIX tools only

# The directory inside the image and the names of the files in it. Lowercase, because they are
# names the two scripts share and not variables either one reads from the environment
secrets_dir_name=station-secrets
age_key_name=age-key.txt
tailscale_tar_name=tailscale-state.tar
# The single top-level directory of the tar. Its contents are a tailscaled state directory
tailscale_top_name=ts-state

# station_secrets_problem DIR — prints why DIR is not a usable set of secrets and returns 1, or
# prints nothing and returns 0. It reads the files and copies nothing
station_secrets_problem() {
  local dir=$1 key tar entries entry
  key=$dir/$age_key_name
  tar=$dir/$tailscale_tar_name
  for entry in "$key" "$tar"; do
    if [ ! -f "$entry" ] || [ ! -r "$entry" ]; then
      printf '%s is missing or unreadable\n' "$entry"
      return 1
    fi
  done
  if ! grep -q '^AGE-SECRET-KEY-1' "$key"; then
    printf '%s holds no age secret key\n' "$key"
    return 1
  fi
  if ! entries=$(tar -tf "$tar" 2>/dev/null); then
    printf '%s is not a tar archive\n' "$tar"
    return 1
  fi
  if [ -z "$entries" ]; then
    printf '%s is empty\n' "$tar"
    return 1
  fi
  while IFS= read -r entry; do
    case "$entry" in
      "$tailscale_top_name" | "$tailscale_top_name"/*) ;;
      *)
        printf '%s holds %s, outside its one directory %s/\n' "$tar" "$entry" "$tailscale_top_name"
        return 1
        ;;
    esac
    case "/$entry/" in
      */../*)
        printf '%s holds %s, which climbs out of its directory\n' "$tar" "$entry"
        return 1
        ;;
    esac
  done <<<"$entries"
  if ! grep -qx "$tailscale_top_name/tailscaled.state" <<<"$entries"; then
    printf '%s has no %s/tailscaled.state\n' "$tar" "$tailscale_top_name"
    return 1
  fi
}
