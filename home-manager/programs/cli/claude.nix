{
  config,
  lib,
  pkgs,
  ...
}:

# Profile switching and shared OpenCode config live in rokokol/claude-account
let
  sharedDir = "${config.xdg.dataHome}/claude-shared";
in
{
  # desktop/sync.nix reads SKILLS_DIR, so it needs this module on as well
  options.rokokol.claude.enable = lib.mkEnableOption "Claude Code and its shared profile" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.claude.enable {
    home.packages = with pkgs; [ claude-code ];
    home.shellAliases.c = "claude";

    programs.claude-account = {
      enable = true;
      opencode.enable = true;
      # The module leaves this null and its script picks the same path on its own, where Nix
      # cannot read it back. Naming it here is what lets SKILLS_DIR follow the directory
      inherit sharedDir;
    };

    # Each shared skill is a checkout of its own repository, so sync.sh sweeps this directory
    home.sessionVariables.SKILLS_DIR = "${sharedDir}/skills";

    # The DDLC Claude Code themes sit outside ~/.claude/themes, which lists every file in it as
    # a theme; toggle-theme.sh links the current one in as ddlc.json
    home.sessionVariables.CLAUDE_DDLC_THEMES = "${sharedDir}/ddlc-themes/themes";
  };
}
