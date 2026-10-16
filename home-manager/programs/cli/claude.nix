{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

# Claude Code for every user who runs it, the station's agent among them. Profile switching and
# shared OpenCode config live in rokokol/claude-account
let
  cfg = config.rokokol.claude;
  sharedDir = "${config.xdg.dataHome}/claude-shared";
in
{
  # desktop/sync.nix reads SKILLS_DIR, so it needs this module on as well. The defaults read the
  # host, as a home without the desktop's modules, like the agent's, has no workstation option
  options.rokokol.claude = {
    enable = lib.mkEnableOption "Claude Code and its shared profile" // {
      default = osConfig.rokokol.workstation.enable;
      defaultText = lib.literalExpression "osConfig.rokokol.workstation.enable";
    };
    desktop.enable =
      lib.mkEnableOption "OpenCode beside Claude Code, the DDLC themes and the `c` alias"
      // {
        default = osConfig.rokokol.workstation.enable;
        defaultText = lib.literalExpression "osConfig.rokokol.workstation.enable";
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
