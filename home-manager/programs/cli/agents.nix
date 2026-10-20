{
  config,
  lib,
  pkgs,
  ...
}:

# What every AI agent of this user gets, declared once by the module of the tool it belongs to:
# the MCP servers, in Home Manager's shared list programs.mcp.servers, and the skills, in
# rokokol.agents.skills. This module turns both into what each agent reads, and the agent's own
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

  # One directory of every skill by its name, which OpenCode reads as it is and Claude Code reads
  # as the skills of one plugin
  skills = pkgs.linkFarm "agent-skills" cfg.skills;
  claudePlugin = pkgs.runCommandLocal "agent-skills-plugin" { } ''
    mkdir -p $out/.claude-plugin
    cp ${json.generate "plugin.json" { name = "huix"; }} $out/.claude-plugin/plugin.json
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
      );
      defaultText = lib.literalMD "the MCP servers and the skills, as OpenCode's `OPENCODE_CONFIG` reads them";
      description = "Config file of OpenCode with the MCP servers and the skills alone, merged over its own";
    };
  };

  config.rokokol.claude.plugins = lib.mkIf (cfg.skills != { }) [ claudePlugin ];
}
