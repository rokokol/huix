#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
claude-account.sh — переключалка профилей Claude Code (один системный юзер, разные аккаунты)

Использование:
  claude-account list          список профилей с email, активный помечен звёздочкой
  claude-account current       имя активного профиля
  claude-account use <имя>     сделать профиль активным
  claude-account add <имя>     завести новый профиль (дальше /login внутри claude)
  claude-account init [имя [почта]]
                               мигрировать старый ~/.claude в профиль (имя по умолчанию
                               — хостнейм; почта берётся из .claude.json). Если ~/.claude
                               нет — ничего не делает. Запускать из чистого терминала,
                               без открытых сессий claude
  claude-account path          CLAUDE_CONFIG_DIR активного профиля (для обёртки)
  claude-account --help        эта справка

Профиль изолирует только аккаунт: .credentials.json (OAuth-токен) и .claude.json
(в нём oauthAccount и userID — привязка токена к аккаунту). Всё остальное общее и
симлинчится из ~/.local/share/claude-shared: settings.json, CLAUDE.md, plugins/,
skills/, commands/, agents/, а также вся работа на двоих — чаты и память (projects/),
история команд (history.jsonl), планы (plans/), задачи (tasks/, todos/) и история
правок файлов (file-history/). Claude Code пишет сквозь симлинк, поэтому /config,
/memory и /resume связь не рвут.

.claude.json держим на профиль осознанно: там oauthAccount, и держать его вместе с
токеном обязательно, иначе две параллельные сессии перетирали бы личность друг друга.
Побочный эффект: MCP/интеграции user-scope и trust-флаги папок в нём не расшариваются
(это про .claude.json, а не про проекты) — общий MCP заводи через .mcp.json в проекте.

Выбор durable, в ~/.local/state/huix/claude-account — как тема и шейдер. Уже
запущенные сессии он не трогает: CLAUDE_CONFIG_DIR фиксируется на старте claude.
EOF
}

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/huix/claude-account"
SHARED_DIR="$DATA_HOME/claude-shared"
PROFILES_DIR="$DATA_HOME/claude-profiles"
DEFAULT_PROFILE="rokokol"

# Что общее на оба аккаунта. commands/ и agents/ раскладывает home-manager,
# поэтому до первого rebuild их может не быть — это не ошибка, а ещё рано.
# projects/, history.jsonl, plans/, todos/, tasks/, file-history/ — общая работа на
# двоих: чаты и память, история команд, планы, задачи и история правок файлов.
SHARED_ENTRIES=(
  settings.json CLAUDE.md plugins skills commands agents
  projects history.jsonl plans todos tasks file-history
)

die() {
  printf 'claude-account: %s\n' "$1" >&2
  exit 1
}

# Имя профиля уходит в путь, так что фильтруем жёстко.
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

# Общий каталог должен существовать раньше, чем на него делают симлинки.
ensure_shared() {
  mkdir -p "$SHARED_DIR" \
    "$SHARED_DIR/plugins" "$SHARED_DIR/skills" "$SHARED_DIR/projects" \
    "$SHARED_DIR/plans" "$SHARED_DIR/todos" "$SHARED_DIR/tasks" "$SHARED_DIR/file-history"

  # Пустой settings.json обязан быть валидным JSON, иначе Claude Code падает на парсе.
  [[ -e "$SHARED_DIR/settings.json" ]] || printf '{}\n' >"$SHARED_DIR/settings.json"
  [[ -e "$SHARED_DIR/CLAUDE.md" ]] || : >"$SHARED_DIR/CLAUDE.md"
  [[ -e "$SHARED_DIR/history.jsonl" ]] || : >"$SHARED_DIR/history.jsonl"
}

# Идемпотентно: каталог профиля + симлинки на общее. Ничего не перезаписывает —
# если на месте симлинка лежит обычный файл, только предупреждает (иначе однажды
# молча съедим чьи-то настройки).
ensure_profile() {
  local name="$1"
  local dir="$PROFILES_DIR/$name"
  local entry link

  ensure_shared
  mkdir -p "$dir"
  chmod 700 "$dir" # внутри .credentials.json с OAuth-токенами

  for entry in "${SHARED_ENTRIES[@]}"; do
    link="$dir/$entry"

    if [[ ! -e "$SHARED_DIR/$entry" ]]; then
      continue
    fi

    if [[ -L "$link" ]]; then
      # Симлинк уже наш — перенацеливаем на всякий случай (битый/переехавший).
      ln -sfn "../../claude-shared/$entry" "$link"
    elif [[ -e "$link" ]]; then
      printf 'claude-account: %s — обычный файл, не трогаю (ожидался симлинк на общее)\n' \
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

    printf '%s %-12s %s\n' "$mark" "$name" "${email:-не залогинен}"
  done

  ((found)) || die "профилей нет, заведи: claude-account add <имя>"
}

cmd_use() {
  local name="${1:-}"

  [[ -n "$name" ]] || die "укажи имя профиля: claude-account use <имя>"
  valid_name "$name" || die "имя профиля только из [a-zA-Z0-9_-]: $name"
  [[ -d "$PROFILES_DIR/$name" ]] || die "профиля $name нет, заведи: claude-account add $name"

  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$name" >"$STATE_FILE"
  printf 'активный профиль: %s\n' "$name"
}

cmd_add() {
  local name="${1:-}"

  [[ -n "$name" ]] || die "укажи имя профиля: claude-account add <имя>"
  valid_name "$name" || die "имя профиля только из [a-zA-Z0-9_-]: $name"
  [[ ! -d "$PROFILES_DIR/$name" ]] || die "профиль $name уже есть"

  ensure_profile "$name"
  printf 'профиль %s создан: %s\n' "$name" "$PROFILES_DIR/$name"
  printf 'дальше: claude-account use %s, потом claude → /login\n' "$name"
}

# Обёртка claude дёргает это на каждый запуск — заодно чинятся симлинки профиля
# (например, commands/ и agents/, появившиеся после очередного rebuild).
cmd_path() {
  local name
  name=$(read_state)

  valid_name "$name" || die "битое имя профиля в $STATE_FILE: $name"
  ensure_profile "$name"
  printf '%s\n' "$PROFILES_DIR/$name"
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
path)
  shift
  cmd_path "$@"
  ;;
help | -h | --help | "")
  usage
  ;;
*)
  die "неизвестная команда: $1 (см. --help)"
  ;;
esac
