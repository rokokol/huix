{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

# The agent keeps its own state and receives only the shared tool registry
let
  agent = osConfig.rokokol.mya-agent;
in
{
  # Of the research directory, the research group alone: ex-USSR kinship is deep-research
  imports = [
    ./programs/agents/agents.nix
    ./programs/agents/remote/default.nix
    ./programs/agents/research/group.nix
    ./programs/agents/research/docs-mcp.nix
    ./programs/agents/research/papers.nix
    ./programs/agents/skills.nix
    ./programs/cli/matplotlib.nix
  ];
  rokokol.matplotlib.enable = true;

  # Hermes puts its own ffmpeg, Node and ripgrep only on its process's PATH, so a shell or a unit
  # of the agent outside it lacks them
  home.packages = with pkgs; [
    ffmpeg
    nodejs
    ripgrep
  ];

  # The huix group without close-session, which keeps Claude Code's memory, and headless-gui,
  # which needs a GUI the station does not run
  rokokol.skills.include = [
    "ai-commit-trailers"
    "bash-best-practices"
    "ci"
    "code-comments"
    "contributing"
    "create-readme"
    "huix-standard"
    "maintainer-docs"
    "nix-best-practices"
    "phone-alert"
    "termux-api"
    "tests"
    "versioning"
  ];
  rokokol.docs-mcp.enable = true;
  rokokol.papers.enable = true;
  # PaperQA's preset runs on Ollama, which the station lacks
  programs.papers.corpus.enable = false;

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

}
