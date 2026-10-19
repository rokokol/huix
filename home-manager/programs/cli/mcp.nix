{
  config,
  lib,
  pkgs,
  ...
}:

# Every MCP server is declared once, in Home Manager's shared list programs.mcp.servers, by the
# module of the tool it belongs to. This module turns the list into the config file of each agent,
# and the agent's own seam passes that file on. Home Manager's programs.claude-code and
# programs.opencode read the list too, but they write into ~/.claude and ~/.config/opencode, which
# claude-account shares between hosts through Syncthing, and a store path of one host would reach
# the others there. A secret reaches a server only as a file, through `env.<NAME>.file`
let
  cfg = config.rokokol.mcp;
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
in
{
  options.rokokol.mcp = {
    opencode.exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "opencode" ];
      description = "Servers that OpenCode leaves out: the one that reaches OpenCode itself";
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
      default = json.generate "opencode-mcp.json" {
        "$schema" = "https://opencode.ai/config.json";
        mcp = lib.mapAttrs forOpencode (removeAttrs servers cfg.opencode.exclude);
      };
      defaultText = lib.literalMD "the servers of `programs.mcp.servers`, as OpenCode's `OPENCODE_CONFIG` reads them";
      description = "Config file of OpenCode with the MCP servers alone, merged over its own";
    };
  };
}
