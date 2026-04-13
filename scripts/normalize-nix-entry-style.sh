#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

while IFS= read -r -d '' file; do
  perl -0pi -e '
    s/^(\{[^\n]*\}:) \{$/$1\n\n{/mg;
    s/^(\{[^\n]*\}:)\n+\{/$1\n\n{/mg;
    s/^(\{[^\n]*\}:)\n+(?=let\b)/$1\n\n/mg;
    s/^(\s*in) \{$/$1\n{/mg;
    s/^(\s*in)\n+\{/$1\n{/mg;
  ' "$file"
done < <(find . -type f -name '*.nix' -print0)
