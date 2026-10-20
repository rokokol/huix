#!/usr/bin/env bash
# Run from a store copy by the sync unit of nixos/services/ai/mya-agent/agent.nix, as the agent's
# user, with git on PATH. The host has no checkout of this repository. sync.sh on a workstation
# starts the unit before it takes the agent's commits and again after it pushes
# Needs bash 3.2 and POSIX tools only
set -euo pipefail

usage() {
  cat <<'EOF'
agent-sync.sh — commit what an agent left in its clones, then rebase them on their upstream

  agent-sync.sh REPO...   commit every change in each REPO, then pull --rebase it
  agent-sync.sh help      this text

The subject of the commit is "[USER] sync DATE", where USER runs this script: the agent wrote
the work, not the host it runs on. A clone with nothing to commit gets no commit. A rebase that
conflicts is wound back, so the clone keeps its own commits. The rebase drops a commit of the
clone when the upstream already holds the same patch
Exit 0 when every clone is committed and rebased, 1 when one is not, 2 on a usage error
EOF
}

die() { # the request itself is wrong
  printf 'agent-sync.sh: %s\n' "$1" >&2
  exit 2
}

sync_one() {
  local repo=$1
  git -C "$repo" add -A
  if ! git -C "$repo" diff --cached --quiet; then
    git -C "$repo" commit -q -m "[$(id -un)] sync $(date '+%Y-%m-%dT%H:%M:%S%z')"
  fi
  if ! git -C "$repo" pull -q --rebase; then
    git -C "$repo" rebase --abort 2>/dev/null || true
    printf 'agent-sync.sh: %s: the pull failed, the clone keeps its own commits\n' "$repo" >&2
    return 1
  fi
}

case "${1:-}" in
  -h | --help | help)
    usage
    exit 0
    ;;
  '')
    usage >&2
    exit 2
    ;;
esac

status=0
for repo in "$@"; do
  [ -d "$repo/.git" ] || die "not a git clone: $repo"
  sync_one "$repo" || status=1
done
exit "$status"
