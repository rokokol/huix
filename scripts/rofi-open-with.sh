#!/usr/bin/env bash
# "Open with" in rofi, for yazi's Shift+Enter and for files of a type no app claims. Two
# script-modi share one rofi: the apps for the file's type, and every app that takes a file.
# The mode labels live in home-manager/programs/rofi.nix with the other modes' labels
# The type and the default come from xdg-mime, so the list agrees with what xdg-open would do
# Needs bash 3.2 and POSIX tools only, beside rofi, xdg-mime, gtk-launch and notify-send
set -euo pipefail

usage() {
  cat <<'EOF'
rofi-open-with.sh — pick the app that opens a file, in rofi

  rofi-open-with.sh open FILE...    show the apps for the type of the first FILE
  rofi-open-with.sh list MODE       the rofi side of a mode: suggested or all

In rofi, Ctrl+Tab switches between the apps for the type and all apps
The chosen app gets every FILE
Exit 0 done, 1 when a FILE does not exist, 2 on a usage error
EOF
}

fail() {
  printf 'rofi-open-with.sh: %s\n' "$1" >&2
  exit 1
}

die() {
  printf 'rofi-open-with.sh: %s\n' "$1" >&2
  exit 2
}

SELF=$(basename -- "${BASH_SOURCE[0]}")

cmd_open() {
  (($# >= 1)) || die "open needs at least one file"
  local file files=""
  for file; do
    [[ -e "$file" ]] || fail "no such file: $file"
    case "$file" in
      *$'\n'*) fail "a file name with a newline cannot be passed on: $file" ;;
    esac
    files+="$file"$'\n'
  done

  local type
  type=$(xdg-mime query filetype "$1")
  type=${type%%;*}
  export OPEN_WITH_FILES="$files" OPEN_WITH_TYPE="$type"
  OPEN_WITH_DEFAULT=$(xdg-mime query default "$type" || true)
  export OPEN_WITH_DEFAULT

  local subject
  if (($# == 1)); then
    subject=$(basename -- "$1")
  else
    subject="$# files"
  fi
  # The message is Pango markup, so a file name reaches it escaped. Not ${s//</&lt;}: since
  # bash 5.2 an & in the replacement stands for the matched text
  subject=$(printf '%s' "$subject" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

  exec rofi -show open-with -modi "open-with:$0 list suggested,open-with-all:$0 list all" \
    -show-icons -no-custom -mesg "$subject — $type"
}

# Every desktop entry as "id<TAB>path", the first of an id winning, in the order the XDG base
# directory spec gives the data directories
desktop_entries() {
  local dir dirs IFS=:
  dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  for dir in $dirs; do
    dir="$dir/applications"
    [[ -d "$dir" ]] || continue
    find -L "$dir" -name '*.desktop' -type f 2>/dev/null | while IFS= read -r path; do
      local id=${path#"$dir"/}
      printf '%s\t%s\n' "${id//\//-}" "$path"
    done
  done | awk -F '\t' '!seen[$1]++'
}

# The MIME databases' aliases and subclasses files, for the type's parents and other names
mime_files() {
  local dir dirs IFS=:
  dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  for dir in $dirs; do
    for kind in aliases subclasses; do
      [[ -f "$dir/mime/$kind" ]] && printf '%s %s\n' "$kind" "$dir/mime/$kind"
    done
  done
  return 0
}

# One line per app to show: rank, id, name, icon. Rank 0 is the default, which comes first
apps() {
  local mode=$1
  # The type's own name, its canonical name and their parents count as the type, and so does
  # every alias of those: an app that declares video/x-matroska opens video/matroska
  desktop_entries | awk -F '\t' \
    -v mode="$mode" -v type="$OPEN_WITH_TYPE" -v preferred="${OPEN_WITH_DEFAULT:-}" \
    -v self="$SELF" -v mimefiles="$(mime_files)" '
    function accept(t) { if (t != "" && !(t in ok)) { ok[t] = 1; queue[queued++] = t } }
    BEGIN {
      split(mimefiles, files, "\n")
      for (f in files) {
        split(files[f], pair, " ")
        while ((getline line < pair[2]) > 0) {
          split(line, w, " ")
          if (pair[1] == "aliases") { canonical[w[1]] = w[2]; others[w[2]] = others[w[2]] " " w[1] }
          else others[w[1]] = others[w[1]] " " w[2]
        }
      }
      accept(type in canonical ? canonical[type] : type)
      accept(type)
      for (q = 0; q < queued; q++) {
        n = split(others[queue[q]], more, " ")
        for (i = 1; i <= n; i++) accept(more[i])
      }
    }
    {
      id = $1; path = $2
      group = kind = name = icon = exec = mimes = hidden = nodisplay = terminal = ""
      while ((getline line < path) > 0) {
        if (line ~ /^\[/) { group = line; continue }
        if (group != "[Desktop Entry]") continue
        eq = index(line, "=")
        if (!eq) continue
        key = substr(line, 1, eq - 1); value = substr(line, eq + 1)
        if (key == "Type") kind = value
        else if (key == "Name") name = value
        else if (key == "Icon") icon = value
        else if (key == "Exec") exec = value
        else if (key == "MimeType") mimes = value
        else if (key == "Hidden") hidden = value
        else if (key == "NoDisplay") nodisplay = value
        else if (key == "Terminal") terminal = value
      }
      close(path)
      # gtk-launch finds no terminal for a Terminal=true entry here; the kitty wrappers of nvim
      # and yazi in home-manager stand in for those entries
      if (kind != "Application" || hidden == "true" || terminal == "true" || index(exec, self)) next
      declares = 0
      n = split(mimes, list, ";")
      for (i = 1; i <= n; i++) if (list[i] in ok) declares = 1
      if (id == preferred) rank = 0
      else if (declares) rank = 1
      else if (mode == "all" && exec ~ /%[fFuU]/ && nodisplay != "true") rank = 1
      else next
      printf "%d\t%s\t%s\t%s\n", rank, id, (name == "" ? id : name), icon
    }
  ' | sort -t "$(printf '\t')" -k1,1n -k3,3f
}

cmd_list() {
  (($# >= 1)) || die "list needs a mode"
  local mode=$1
  case "$mode" in
    suggested | all) ;;
    *) die "no such mode: $mode" ;;
  esac
  [[ -n "${OPEN_WITH_TYPE:-}" ]] || die "list runs inside rofi, started by open"

  # rofi puts the chosen row's id in ROFI_INFO; a run without it is the one that fills the list
  if [[ "${ROFI_RETV:-0}" == 1 && -n "${ROFI_INFO:-}" ]]; then
    local file files=()
    while IFS= read -r file; do
      [[ -n "$file" ]] && files+=("$file")
    done <<<"$OPEN_WITH_FILES"
    if ! gtk-launch "$ROFI_INFO" "${files[@]}" >/dev/null 2>&1; then
      notify-send "Open with" "Could not start $ROFI_INFO"
    fi
    return 0
  fi

  # A failure inside a process substitution would only leave the menu empty
  local rows rank id name icon
  rows=$(apps "$mode")
  [[ -n "$rows" ]] || return 0
  while IFS=$'\t' read -r rank id name icon; do
    if ((rank == 0)); then
      name="$name (default)"
    fi
    printf '%s\0icon\x1f%s\x1finfo\x1f%s\n' "$name" "$icon" "$id"
  done <<<"$rows"
}

cmd="${1:-}"
(($# == 0)) || shift
case "$cmd" in
  open) cmd_open "$@" ;;
  list) cmd_list "$@" ;;
  -h | --help | help) usage ;;
  '')
    usage >&2
    exit 2
    ;;
  *)
    printf 'rofi-open-with.sh: no such subcommand: %s\n\n' "$cmd" >&2
    usage >&2
    exit 2
    ;;
esac
