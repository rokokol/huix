{
  config,
  lib,
  osConfig,
  ...
}:

# The home of the Claude Code agent that nixos/services/ai/mya-agent runs. It shares
# the workstations' Claude Code state through the copy of it the host keeps
let
  agent = osConfig.rokokol.mya-agent;
in
{
  home.stateVersion = osConfig.system.stateVersion;

  # Each directory the session edits, linked where the host says
  home.file = lib.mapAttrs (_: dir: {
    source = config.lib.file.mkOutOfStoreSymlink dir;
  }) agent.directories;

  # The agent logs in to the workstations as its guest user. No one answers a prompt in its
  # session, and a workstation's host key changes only when it is installed again
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."nixos-pc nixos-laptop" = {
      BatchMode = "yes";
      StrictHostKeyChecking = "accept-new";
    };
  };

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
