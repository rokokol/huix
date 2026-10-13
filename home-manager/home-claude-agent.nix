{
  config,
  lib,
  osConfig,
  ...
}:

# The home of the Claude Code agent that nixos/services/tools/claude-agent.nix runs. It shares
# the workstations' Claude Code state through the copy of it the host keeps
let
  agent = osConfig.rokokol.claude-agent;
in
{
  home.stateVersion = osConfig.system.stateVersion;

  # Each directory the session edits, linked where the host says
  home.file = lib.mapAttrs (_: dir: {
    source = config.lib.file.mkOutOfStoreSymlink dir;
  }) agent.directories;

  programs.claude-account = {
    enable = true;
    # Spelled out, as the session may run with HOME set to an alias of the home, and the defaults
    # would follow it
    claudeDir = "${config.home.homeDirectory}/.claude";
    profilesDir = "${config.xdg.dataHome}/claude-profiles";
    sharedDir = "${config.xdg.dataHome}/claude-shared";
    # No OpenCode runs here
    opencode.share = false;
  };
}
