{ pkgs, huixDir, ... }:

let
  # Shared across both accounts; the profiles themselves sit next to it, in claude-profiles/
  sharedDir = ".local/share/claude-shared";

  # Thin wrapper around scripts/claude-account.sh: the logic is in the script, Nix only
  # assembles PATH
  claude-account = pkgs.writeShellApplication {
    name = "claude-account";
    # gnused/gnugrep/procps are for `init`: sed rewrites legacy plugin paths, grep is the
    # leftover-path control check, pgrep -x claude guards against a live session
    runtimeInputs = with pkgs; [
      coreutils
      jq
      gnused
      gnugrep
      procps
    ];
    text = ''
      exec bash "${huixDir}/scripts/claude-account.sh" "$@"
    '';
  };

  # Wrapper around claude-code: injects the active profile's CLAUDE_CONFIG_DIR
  claude = pkgs.writeShellApplication {
    name = "claude";
    text = ''
      # If the variable is already set, we were launched by Claude Code itself (a subagent,
      # claude -p): the subprocess profile must match the parent's, otherwise
      # transcript mirroring breaks
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

  # commands/ only — settings.json/CLAUDE.md/plugins/ are writable by Claude Code (store symlink = read-only)
  # recursive = true: HM creates a real dir + per-file symlinks, so Claude Code can add its own files alongside
  home.file."${sharedDir}/commands" = {
    source = ./commands;
    recursive = true;
  };

  home.file."${sharedDir}/agents" = {
    source = ./agents;
    recursive = true;
  };
}
