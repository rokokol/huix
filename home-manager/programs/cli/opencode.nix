{
  config,
  lib,
  pkgs,
  ...
}:

# Headless OpenCode server for local tools and Claude Code MCP integration. Its only client is
# the opencode MCP server of Claude Code, so a host without that MCP needs no server
{
  options.rokokol.opencode.server = lib.mkEnableOption "the headless OpenCode API server on 127.0.0.1:4096";

  config = lib.mkIf config.rokokol.opencode.server {
    systemd.user.services.opencode-server = {
      Unit = {
        Description = "OpenCode headless API server";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname 127.0.0.1 --port 4096";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
