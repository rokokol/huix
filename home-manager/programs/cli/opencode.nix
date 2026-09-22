{
  pkgs,
  ...
}:

# Headless OpenCode server for local tools and Claude Code MCP integration
{
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
}
