{
  config,
  lib,
  osConfig,
  rokokolName,
  ...
}:

# The home of the Claude Code agent on the archive host, which nixos/services/tools/claude-agent.nix
# runs. It shares the workstations' Claude Code state through the archive's copy of it
{
  home.stateVersion = osConfig.system.stateVersion;

  # Each archived folder where a workstation keeps it, so the paths in the shared state resolve
  home.file = lib.mapAttrs' (
    path: dir:
    lib.nameValuePair (lib.removePrefix "/home/${rokokolName}/" path) {
      source = config.lib.file.mkOutOfStoreSymlink dir;
    }
  ) osConfig.rokokol.syncthing.archive.folders;

  programs.claude-account = {
    enable = true;
    # Spelled out, as the session runs with HOME set to the owner's home and the defaults would
    # follow it
    claudeDir = "${config.home.homeDirectory}/.claude";
    profilesDir = "${config.xdg.dataHome}/claude-profiles";
    sharedDir = "${config.xdg.dataHome}/claude-shared";
    # No OpenCode runs here
    opencode.share = false;
  };
}
