{
  config,
  lib,
  pkgs,
  ...
}:

# Claude Code for every user who runs it, the station's agent among them. Profile switching and
# shared OpenCode config live in rokokol/claude-account
let
  cfg = config.rokokol.claude;
  sharedDir = "${config.xdg.dataHome}/claude-shared";
in
{
  # desktop/sync.nix reads SKILLS_DIR, so it needs this module on as well
  options.rokokol.claude = {
    enable = lib.mkEnableOption "Claude Code and its shared profile" // {
      default = config.rokokol.workstation.enable;
    };
    desktop.enable = lib.mkEnableOption "OpenCode, the DDLC themes and the `c` alias" // {
      default = config.rokokol.workstation.enable;
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = with pkgs; [ claude-code ];

        programs.claude-account = {
          enable = true;
          # The module leaves this null and its script picks the same path on its own, where Nix
          # cannot read it back. Naming it here is what lets SKILLS_DIR follow the directory
          inherit sharedDir;
        };

        # Each shared skill is a checkout of its own repository, so sync.sh sweeps this directory
        home.sessionVariables.SKILLS_DIR = "${sharedDir}/skills";
      }

      (lib.mkIf cfg.desktop.enable {
        home.shellAliases.c = "claude";
        programs.claude-account.opencode.enable = true;

        # The DDLC Claude Code themes sit outside ~/.claude/themes, which lists every file in it
        # as a theme; toggle-theme.sh links the current one in as ddlc.json
        home.sessionVariables.CLAUDE_DDLC_THEMES = "${sharedDir}/ddlc-themes/themes";
      })
    ]
  );
}
