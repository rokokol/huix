{
  lib,
  pkgs,
  huixDir,
  ...
}:

let
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
in
{
  # Stock claude-code: ~/.claude is a symlink to the active profile, so no launch wrapper
  home.packages = [
    pkgs.claude-code
    claude-account
  ];

  # Pinned to the default config dir, same value for every account. Its only effect is moving
  # .claude.json inside the profile: the binary looks for it beside the dir and rewrites it with
  # rename(2), which would turn a symlink at that path into a regular file
  home.sessionVariables.CLAUDE_CONFIG_DIR = "$HOME/.claude";

  # Repairs the active profile's symlinks after a rebuild adds a new shared entry
  home.activation.claudeProfileLinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${claude-account}/bin/claude-account ensure || true
  '';
}
