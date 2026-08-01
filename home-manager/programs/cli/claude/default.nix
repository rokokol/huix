{ pkgs, huixDir, ... }:

let
  # Общее на оба аккаунта; сами профили лежат рядом, в claude-profiles/.
  sharedDir = ".local/share/claude-shared";

  # Тонкая обёртка над scripts/claude-account.sh: логика в скрипте, Nix только
  # собирает PATH.
  claude-account = pkgs.writeShellApplication {
    name = "claude-account";
    runtimeInputs = with pkgs; [
      coreutils
      jq
    ];
    text = ''
      exec bash "${huixDir}/scripts/claude-account.sh" "$@"
    '';
  };

  # Обёртка над claude-code: подставляет CLAUDE_CONFIG_DIR активного профиля.
  claude = pkgs.writeShellApplication {
    name = "claude";
    text = ''
      # Если переменная уже выставлена, нас запустил сам Claude Code (сабагент,
      # claude -p): профиль подпроцесса обязан совпадать с родительским, иначе
      # ломается зеркалирование транскриптов.
      if [ -z "''${CLAUDE_CONFIG_DIR:-}" ]; then
        CLAUDE_CONFIG_DIR="$(${claude-account}/bin/claude-account path)"
        export CLAUDE_CONFIG_DIR
      fi

      exec ${pkgs.claude-code}/bin/claude "$@"
    '';
  };
in
{
  home.packages = [
    claude
    claude-account
  ];

  # Декларативная часть общего конфига. settings.json, CLAUDE.md, plugins/ и
  # skills/ сюда сознательно не заводятся: в них пишет сам Claude Code (/config,
  # /memory, маркетплейсы плагинов), а store-симлинк был бы read-only.
  #
  # recursive = true важен: home-manager создаёт настоящий каталог и симлинчит
  # файлы по одному, поэтому плагины и TUI могут доложить туда своё.
  home.file."${sharedDir}/commands" = {
    source = ./commands;
    recursive = true;
  };

  home.file."${sharedDir}/agents" = {
    source = ./agents;
    recursive = true;
  };
}
