#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
claude-account.sh — Claude Code profile switcher (one system user, several accounts)

Usage:
  claude-account list          list profiles with email, active one marked with a star
  claude-account current       name of the active profile
  claude-account use <name>    make a profile active
  claude-account add <name>    create a new profile (then /login inside claude)
  claude-account init [name [email]]
                               migrate an existing ~/.claude into a profile (name
                               defaults to the hostname; email is read from .claude.json).
                               Does nothing if ~/.claude is absent. Run from a clean
                               terminal with no claude sessions open
  claude-account path          CLAUDE_CONFIG_DIR of the active profile (for the wrapper)
  claude-account --help        this help

A profile isolates only the account: .credentials.json (OAuth token) and .claude.json
(it holds oauthAccount and userID — the token-to-account binding). Everything else is
shared and symlinked from ~/.local/share/claude-shared: settings.json, CLAUDE.md,
plugins/, skills/, commands/, agents/, plus all the shared work — chats and memory
(projects/), command history (history.jsonl), plans (plans/), tasks (tasks/, todos/) and
file-edit history (file-history/). Claude Code writes through symlinks, so /config,
/memory and /resume keep working

.claude.json is per-profile on purpose: it holds oauthAccount, which must live next to the
token, otherwise two parallel sessions would clobber each other's identity. Side effect:
user-scope MCP/integrations and folder trust flags from it are not shared — set up shared
MCP via .mcp.json inside the project

The choice is durable, in ~/.local/state/huix/claude-account — like theme and shader.
Already-running sessions are untouched: CLAUDE_CONFIG_DIR is fixed at claude startup
EOF
}

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/huix/claude-account"
SHARED_DIR="$DATA_HOME/claude-shared"
PROFILES_DIR="$DATA_HOME/claude-profiles"
DEFAULT_PROFILE="rokokol"

# What is shared across both accounts. commands/ and agents/ are laid out by home-manager,
# so before the first rebuild they may be missing — not an error, just too early
# projects/, history.jsonl, plans/, todos/, tasks/, file-history/ are the shared work: one
# job for two people — chats and memory, command history, plans, tasks and file-edit history
SHARED_ENTRIES=(
  settings.json CLAUDE.md plugins skills commands agents
  projects history.jsonl plans todos tasks file-history
)

die() {
  printf 'claude-account: %s\n' "$1" >&2
  exit 1
}

# The profile name goes into a path, so filter it hard
valid_name() {
  [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]
}

read_state() {
  local name=""

  if [[ -r "$STATE_FILE" ]]; then
    name=$(cat "$STATE_FILE")
  fi

  printf '%s' "${name:-$DEFAULT_PROFILE}"
}

# The shared dir must exist before anything symlinks into it
ensure_shared() {
  mkdir -p "$SHARED_DIR" \
    "$SHARED_DIR/plugins" "$SHARED_DIR/skills" "$SHARED_DIR/projects" \
    "$SHARED_DIR/plans" "$SHARED_DIR/todos" "$SHARED_DIR/tasks" "$SHARED_DIR/file-history"

  # An empty settings.json must still be valid JSON, otherwise Claude Code fails to parse it
  [[ -e "$SHARED_DIR/settings.json" ]] || printf '{}\n' >"$SHARED_DIR/settings.json"
  [[ -e "$SHARED_DIR/CLAUDE.md" ]] || : >"$SHARED_DIR/CLAUDE.md"
  [[ -e "$SHARED_DIR/history.jsonl" ]] || : >"$SHARED_DIR/history.jsonl"
}

# Idempotent: profile dir + symlinks to the shared parts. Overwrites nothing — if a real
# file sits where a symlink should be, it only warns (otherwise one day we'd silently eat
# someone's settings)
ensure_profile() {
  local name="$1"
  local dir="$PROFILES_DIR/$name"
  local entry link

  ensure_shared
  mkdir -p "$dir"
  chmod 700 "$dir" # holds .credentials.json with OAuth tokens

  for entry in "${SHARED_ENTRIES[@]}"; do
    link="$dir/$entry"

    if [[ ! -e "$SHARED_DIR/$entry" ]]; then
      continue
    fi

    if [[ -L "$link" ]]; then
      # Already our symlink — retarget just in case (broken/moved)
      ln -sfn "../../claude-shared/$entry" "$link"
    elif [[ -e "$link" ]]; then
      printf 'claude-account: %s — regular file, leaving it (expected a symlink to shared)\n' \
        "$link" >&2
    else
      ln -s "../../claude-shared/$entry" "$link"
    fi
  done
}

profile_email() {
  local cfg="$PROFILES_DIR/$1/.claude.json"

  if [[ -r "$cfg" ]]; then
    jq -r '.oauthAccount.emailAddress // empty' "$cfg" 2>/dev/null || true
  fi
}

cmd_list() {
  local active dir name email mark
  local found=0

  active=$(read_state)

  for dir in "$PROFILES_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    found=1

    name=$(basename "$dir")
    email=$(profile_email "$name")

    if [[ "$name" == "$active" ]]; then
      mark="*"
    else
      mark=" "
    fi

    printf '%s %-12s %s\n' "$mark" "$name" "${email:-not logged in}"
  done

  ((found)) || die "no profiles, create one: claude-account add <name>"
}

cmd_use() {
  local name="${1:-}"

  [[ -n "$name" ]] || die "give a profile name: claude-account use <name>"
  valid_name "$name" || die "profile name must match [a-zA-Z0-9_-]: $name"
  [[ -d "$PROFILES_DIR/$name" ]] || die "no profile $name, create it: claude-account add $name"

  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$name" >"$STATE_FILE"
  printf 'active profile: %s\n' "$name"
}

cmd_add() {
  local name="${1:-}"

  [[ -n "$name" ]] || die "give a profile name: claude-account add <name>"
  valid_name "$name" || die "profile name must match [a-zA-Z0-9_-]: $name"
  [[ ! -d "$PROFILES_DIR/$name" ]] || die "profile $name already exists"

  ensure_profile "$name"
  printf 'profile %s created: %s\n' "$name" "$PROFILES_DIR/$name"
  printf 'next: claude-account use %s, then claude → /login\n' "$name"
}

# The claude wrapper calls this on every launch — profile symlinks get repaired along the
# way (e.g. commands/ and agents/ that appeared after the latest rebuild)
cmd_path() {
  local name
  name=$(read_state)

  valid_name "$name" || die "broken profile name in $STATE_FILE: $name"
  ensure_profile "$name"
  printf '%s\n' "$PROFILES_DIR/$name"
}

# Leftover old-location paths in migrated shared files: plugins and statusline remember
# absolute paths from the previous layout
fix_legacy_paths() {
  local name="$1"
  local old="$HOME/.claude"
  local f

  for f in "$SHARED_DIR/plugins/installed_plugins.json" \
    "$SHARED_DIR/plugins/known_marketplaces.json"; do
    if [[ -f "$f" ]]; then
      sed -i "s#$old/plugins#$SHARED_DIR/plugins#g" "$f"
    fi
  done

  # Statusline moved into huix — if settings remembers the old path, point it at $HUIX
  local st="$SHARED_DIR/settings.json"
  if [[ -f "$st" ]] && grep -q "$old" "$st"; then
    local hx="${HUIX:-$HOME/huix}" tmp
    tmp=$(mktemp)
    if jq --arg cmd "$hx/scripts/claude-statusline.sh" \
      'if .statusLine.command? then .statusLine.command = $cmd else . end' \
      "$st" >"$tmp"; then
      mv "$tmp" "$st"
    else
      rm -f "$tmp"
    fi
  fi

  # Control check: maybe something still references the old path
  if grep -rl "$old" "$SHARED_DIR" "$PROFILES_DIR/$name" 2>/dev/null | grep -q .; then
    printf 'claude-account: references to %s remain, check by hand:\n' "$old" >&2
    grep -rl "$old" "$SHARED_DIR" "$PROFILES_DIR/$name" 2>/dev/null >&2
  fi
}

# One-time migration of an old ~/.claude into a profile. With no args the profile name is
# the hostname. Email is read from .claude.json (it can't be rewritten — the token is bound
# to its own identity); the email argument is optional and only feeds the confirmation line
cmd_init() {
  local force=0
  if [[ "${1:-}" == "--force" ]]; then
    force=1
    shift
  fi

  local name="${1:-$(uname -n)}"
  local email_arg="${2:-}"
  local legacy_dir="$HOME/.claude"
  local legacy_json="$HOME/.claude.json"

  # The trigger is the ~/.claude directory. No dir — nothing to migrate
  if [[ ! -d "$legacy_dir" ]]; then
    printf 'claude-account: no ~/.claude — nothing to migrate\n'
    return 0
  fi

  # Never move ~/.claude out from under a live session — it would break it. A claude-code
  # session shows up with comm "claude" or, when nixpkgs-wrapped, ".claude-wrapped"
  [[ -z "${CLAUDE_CONFIG_DIR:-}" ]] ||
    die "init ran from inside claude (CLAUDE_CONFIG_DIR is set) — exit and run from a clean terminal"
  if ((!force)) && { pgrep -x claude >/dev/null 2>&1 || pgrep -x .claude-wrapped >/dev/null 2>&1; }; then
    die "claude is running — close every session and run init from a clean terminal (or init --force if sure)"
  fi

  valid_name "$name" || die "profile name must match [a-zA-Z0-9_-]: $name"
  local dir="$PROFILES_DIR/$name"
  [[ ! -e "$dir" ]] || die "profile $name already exists — pick another name"

  # First move all of ~/.claude into the profile, .claude.json next to it
  mkdir -p "$PROFILES_DIR" "$SHARED_DIR"
  mv "$legacy_dir" "$dir"
  if [[ -e "$legacy_json" ]]; then
    mv "$legacy_json" "$dir/.claude.json"
  fi
  chmod 700 "$dir"
  rm -f "$dir/statusline-command.sh" # moved into huix

  local ts
  ts=$(date +%Y%m%d-%H%M%S)

  # CLAUDE.md special case: global memory is curated by hand, never auto-promoted to shared
  # A non-empty one is parked as .bak in the profile for a manual merge; an empty one is
  # dropped. The shared CLAUDE.md stays the (empty) stub ensure_shared makes
  local claude_md="$dir/CLAUDE.md"
  if [[ -f "$claude_md" && ! -L "$claude_md" ]]; then
    if [[ -s "$claude_md" ]]; then
      mv "$claude_md" "$claude_md.bak-init-$ts"
      printf 'claude-account: global CLAUDE.md parked at %s — merge wanted lines into %s\n' \
        "$claude_md.bak-init-$ts" "$SHARED_DIR/CLAUDE.md" >&2
    else
      rm -f "$claude_md"
    fi
  fi

  # Pull the shared entries out into claude-shared. On a fresh machine it is empty, so
  # everything moves as-is; if something is already there, the profile copy goes to .bak so
  # we don't clobber shared. Order matters: this loop runs before ensure_shared/ensure_profile,
  # otherwise those would create empty stubs and the real data would go to .bak instead
  local entry src
  for entry in "${SHARED_ENTRIES[@]}"; do
    [[ "$entry" == CLAUDE.md ]] && continue # handled above
    src="$dir/$entry"
    [[ -e "$src" && ! -L "$src" ]] || continue
    if [[ ! -e "$SHARED_DIR/$entry" ]]; then
      mv "$src" "$SHARED_DIR/$entry"
    else
      mv "$src" "$src.bak-init-$ts"
    fi
  done

  fix_legacy_paths "$name"

  # Profile symlinks to shared + fill in any missing shared dirs
  ensure_profile "$name"

  # Make it active
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$name" >"$STATE_FILE"

  local email
  email=$(profile_email "$name")
  printf 'profile %s created from ~/.claude (%s), active\n' \
    "$name" "${email:-${email_arg:-not logged in}}"
}

case "${1:-}" in
list)
  shift
  cmd_list "$@"
  ;;
current)
  read_state
  printf '\n'
  ;;
use)
  shift
  cmd_use "$@"
  ;;
add)
  shift
  cmd_add "$@"
  ;;
init)
  shift
  cmd_init "$@"
  ;;
path)
  shift
  cmd_path "$@"
  ;;
help | -h | --help | "")
  usage
  ;;
*)
  die "unknown command: $1 (see --help)"
  ;;
esac
