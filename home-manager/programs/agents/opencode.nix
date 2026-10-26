{
  config,
  lib,
  pkgs,
  ...
}:

# Headless OpenCode server for local tools and Claude Code MCP integration. Its only client is
# the opencode MCP server, which this module declares, so a host without the server has neither
let
  port = config.rokokol.opencode.port;
in
{
  options.rokokol.opencode = {
    server = lib.mkEnableOption "the headless OpenCode API server on 127.0.0.1:${toString port}";
    port = lib.mkOption {
      type = lib.types.port;
      default = 4096;
      description = "Loopback port of the OpenCode API server";
    };
  };

  config = lib.mkIf config.rokokol.opencode.server {
    systemd.user.services.opencode-server = {
      Unit = {
        Description = "OpenCode headless API server";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname 127.0.0.1 --port ${toString port}";
        # A user unit inherits no session variable, and this one carries the MCP servers
        Environment = [
          "OPENCODE_CONFIG=${config.rokokol.agents.opencodeConfig}"
          "OPENCODE_DISABLE_LSP_DOWNLOAD=true"
        ];
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "default.target" ];
    };

  };
}
