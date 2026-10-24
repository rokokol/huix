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
  imports = [ ./agents.nix ];

  # desktop/sync.nix reads SKILLS_DIR, so it needs this module on as well
  options.rokokol.claude = {
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      # The flag is variadic: written apart from its value, it takes the next word for a second
      # file, so `claude --mcp-config FILE doctor` reads doctor as a file. With "=" it stops there
      default = pkgs.symlinkJoin {
        name = "claude-code-${lib.getVersion pkgs.claude-code}";
        paths = with pkgs; [ claude-code ];
        nativeBuildInputs = with pkgs; [ makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/claude --add-flags ${
            lib.escapeShellArg (
              lib.concatStringsSep " " (
                [ "--mcp-config=${config.rokokol.agents.claudeConfig}" ]
                ++ map (plugin: "--plugin-dir ${plugin}") config.rokokol.claude.plugins
              )
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
        home.packages = [ cfg.package ];

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
        # OpenCode merges this file over its own config
        home.sessionVariables.OPENCODE_CONFIG = config.rokokol.agents.opencodeConfig;

        # The DDLC Claude Code themes sit outside ~/.claude/themes, which lists every file in it
        # as a theme; toggle-theme.sh links the current one in as ddlc.json
        home.sessionVariables.CLAUDE_DDLC_THEMES = "${sharedDir}/ddlc-themes/themes";
      })
    ]
  );
}
