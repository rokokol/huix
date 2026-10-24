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
  imports = [
    ./programs/agents/claude.nix
    ./programs/agents/dav-mcp.nix
    ./programs/agents/mail-skill.nix
    ./programs/agents/skills.nix
    ./programs/agents/telegram-skill.nix
  ];

  # It talks to a Super Productivity that runs on a workstation, which the station cannot reach
  rokokol.skills.exclude = [ "super-productivity" ];

  home.stateVersion = osConfig.system.stateVersion;

  # Each directory the session edits, linked where the host says
  home.file = lib.mapAttrs (_: dir: {
    source = config.lib.file.mkOutOfStoreSymlink dir;
  }) agent.directories;

  # The agent logs in to the workstations as its guest user and to the nodes as their observer. No
  # one answers a prompt in its session, and a host key changes only when the host is installed
  # again. Every host rather than a list: the nodes are the ones that push to the station, and a
  # second list of them would drift
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        BatchMode = "yes";
        StrictHostKeyChecking = "accept-new";
      };
      # Termux sshd on the phone; Termux has one user, so the login name does not matter
      mobile-1.Port = 8022;
    };
  };

  # The identity of every commit the session makes, in any repository of the user. The package
  # is the one the user already has, and nothing here pushes: the session holds no write token
  programs.git = {
    enable = true;
    package = null;
    settings.user = {
      inherit (agent.git) name email;
    };
  };

  rokokol.claude.enable = true;

  programs.claude-account = {
    # Spelled out, as the session may run with HOME set to an alias of the home, and the defaults
    # would follow it
    claudeDir = "${config.home.homeDirectory}/.claude";
    profilesDir = "${config.xdg.dataHome}/claude-profiles";
    # No OpenCode runs here
    opencode.share = false;
  };
}
