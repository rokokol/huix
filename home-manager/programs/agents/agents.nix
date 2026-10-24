{
  config,
  lib,
  pkgs,
  ...
}:

# What every AI agent of this user gets, declared once by the module of the tool it belongs to:
# the MCP servers, in Home Manager's shared list programs.mcp.servers, the skills, in
# rokokol.agents.skills, and the language servers, in rokokol.agents.lspServers. This module
# turns them into what each agent reads, and the agent's own
# seam passes that on. Home Manager's programs.claude-code and programs.opencode read the MCP
# list too, but they write into ~/.claude and ~/.config/opencode, which claude-account shares
# between hosts through Syncthing, and a store path of one host would reach the others there. A
# secret reaches a server only as a file, through `env.<NAME>.file`
let
  cfg = config.rokokol.agents;
  json = pkgs.formats.json { };
  servers = lib.filterAttrs (_: server: server.enabled or null != false) config.programs.mcp.servers;

  # Claude Code starts the server through a script that reads each file into its variable
  forClaude =
    name: server:
    lib.hm.mcp.transformMcpServer {
      inherit server;
      exclude = [ "enabled" ];
      extraTransforms = [
        lib.hm.mcp.addType
        (lib.hm.mcp.wrapEnvFilesCommand { inherit pkgs name; })
      ];
    };

  # OpenCode reads a file itself when a value says {file:PATH}. The shape is the one
  # programs.opencode writes, which Home Manager does not export
  forOpencode =
    _: server:
    let
      remote = server.url or null != null;
      env = lib.hm.mcp.renderEnv (path: "{file:${path}}") (server.env or { });
    in
    {
      type = if remote then "remote" else "local";
      enabled = true;
    }
    // (
      if remote then
        {
          inherit (server) url;
        }
        // lib.optionalAttrs (server.headers or { } != { }) { inherit (server) headers; }
      else
        {
          command = [ server.command ] ++ server.args or [ ];
        }
        // lib.optionalAttrs (env != { }) { environment = env; }
    );

  # Both agents take a language server as a command and the file extensions it serves, and each
  # spells the fields its own way
  lspForClaude = _: server: {
    inherit (server) command args;
    extensionToLanguage = server.extensions;
  };
  lspForOpencode = _: server: {
    command = [ server.command ] ++ server.args;
    extensions = lib.attrNames server.extensions;
  };

  # One directory of every skill by its name, which OpenCode reads as it is and Claude Code reads
  # as the skills of one plugin, which also carries the language servers
  skills = pkgs.linkFarm "agent-skills" cfg.skills;
  claudePlugin = pkgs.runCommandLocal "agent-skills-plugin" { } ''
    mkdir -p $out/.claude-plugin
    cp ${
      json.generate "plugin.json" (
        {
          name = "huix";
        }
        // lib.optionalAttrs (cfg.lspServers != { }) {
          lspServers = lib.mapAttrs lspForClaude cfg.lspServers;
        }
      )
    } $out/.claude-plugin/plugin.json
    ln -s ${skills} $out/skills
  '';
in
{
  options.rokokol.agents = {
    skills = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      example = lib.literalExpression "{ calendar = ./calendar-skill; }";
      description = "Skills every agent of this user loads, as directories with a SKILL.md, by name";
    };

    lspServers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            command = lib.mkOption {
              type = lib.types.str;
              description = "Executable of the server, by name, so that a devShell's own version wins over the one on the user's PATH";
            };
            args = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Arguments of the server";
            };
            extensions = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              example = {
                ".py" = "python";
              };
              description = "LSP language identifier of each file extension the server serves, the extension with its dot";
            };
          };
        }
      );
      default = { };
      description = "Language servers every agent of this user starts, by the name OpenCode gives its built-in one, so that the entry replaces it";
    };

    opencode.exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "opencode" ];
      description = "MCP servers that OpenCode leaves out: the one that reaches OpenCode itself";
    };

    claudeConfig = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      default = json.generate "claude-mcp.json" { mcpServers = lib.mapAttrs forClaude servers; };
      defaultText = lib.literalMD "the servers of `programs.mcp.servers`, as Claude Code's `--mcp-config` reads them";
      description = "MCP config file of Claude Code";
    };

    opencodeConfig = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      default = json.generate "opencode-agents.json" (
        {
          "$schema" = "https://opencode.ai/config.json";
          mcp = lib.mapAttrs forOpencode (removeAttrs servers cfg.opencode.exclude);
        }
        // lib.optionalAttrs (cfg.skills != { }) { skills.paths = [ "${skills}" ]; }
        // lib.optionalAttrs (cfg.lspServers != { }) { lsp = lib.mapAttrs lspForOpencode cfg.lspServers; }
      );
      defaultText = lib.literalMD "the MCP servers, the skills and the language servers, as OpenCode's `OPENCODE_CONFIG` reads them";
      description = "Config file of OpenCode with the MCP servers, the skills and the language servers alone, merged over its own";
    };
  };

  config.rokokol.claude.plugins = lib.mkIf (cfg.skills != { } || cfg.lspServers != { }) [
    claudePlugin
  ];
}
