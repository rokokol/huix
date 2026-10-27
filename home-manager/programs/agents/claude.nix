{
  config,
  lib,
  pkgs,
  ...
}:

# Profile selection and shared OpenCode config live in rokokol/claude-account
let
  cfg = config.rokokol.claude;
  sharedDir = "${config.xdg.dataHome}/claude-shared";
in
{
  imports = [ ./agents.nix ];

  options.rokokol.claude = {
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = pkgs.symlinkJoin {
        name = "claude-code-${lib.getVersion pkgs.claude-code}";
        paths = with pkgs; [ claude-code ];
        nativeBuildInputs = with pkgs; [ makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/claude --add-flags ${
            lib.escapeShellArg (
              lib.concatStringsSep " " (map (plugin: "--plugin-dir ${plugin}") config.rokokol.claude.plugins)
            )
          }
        '';
        inherit (pkgs.claude-code) meta;
      };
      defaultText = lib.literalMD "Claude Code with the MCP servers and the skills of `rokokol.agents`, and the `plugins`";
      description = "Claude Code as every session of this user runs it";
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Claude Code plugin directories that every session of this user loads";
    };

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
        rokokol.claude.plugins = lib.attrValues config.rokokol.agents.claudePlugins;
        home.packages = [ cfg.package ];

        programs.claude-account = {
          enable = true;
          # The module leaves this null and its script picks the same path on its own, where Nix
          # cannot read it back. Naming it here is what lets skills.nix keep the skills' state there
          inherit sharedDir;
        };
      }

      (lib.mkIf cfg.desktop.enable {
        home.shellAliases.c = "claude";
        programs.claude-account.opencode.enable = true;
        # OpenCode merges this file over its own config
        home.sessionVariables.OPENCODE_CONFIG = config.rokokol.agents.opencodeConfig;
        # Its own language servers would otherwise be downloaded past Nix, next to the ones above
        home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";

        # The DDLC Claude Code themes sit outside ~/.claude/themes, which lists every file in it
        # as a theme; toggle-theme.sh links the current one in as ddlc.json
        home.sessionVariables.CLAUDE_DDLC_THEMES = "${sharedDir}/ddlc-themes/themes";
      })
    ]
  );
}
