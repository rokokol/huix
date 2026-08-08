{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Stock claude-code: ~/.claude is a symlink to the active profile, so no launch wrapper.
  # The claude-account wrapper itself comes from scripts/scripts.nix
  home.packages = [ pkgs.claude-code ];

  # Pinned to the default config dir, same value for every account. Its only effect is moving
  # .claude.json inside the profile: the binary looks for it beside the dir and rewrites it with
  # rename(2), which would turn a symlink at that path into a regular file
  home.sessionVariables.CLAUDE_CONFIG_DIR = "$HOME/.claude";

  # Repairs the active profile's symlinks after a rebuild adds a new shared entry. Must come after
  # linkGeneration, not just writeBoundary — that is where home-manager removes the previous
  # generation's files, and it would undo the repair
  home.activation.claudeProfileLinks = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${config.custom.scripts.packages.claude-account}/bin/claude-account ensure || true
  '';
}
