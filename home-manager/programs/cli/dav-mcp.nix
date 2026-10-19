{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

# The calendar MCP server for the user whose Radicale login the host keeps, which
# nixos/services/tools/dav-mcp.nix declares
let
  login = osConfig.rokokol.dav-mcp;
in
{
  config = lib.mkIf (login.enable && login.user == config.home.username) {
    programs.mcp.servers.dav = {
      command = lib.getExe pkgs.dav-mcp;
      env = {
        CALDAV_SERVER_URL = login.url;
        CALDAV_USERNAME = login.user;
        CALDAV_PASSWORD.file = login.passwordFile;
        AUTH_METHOD = "Basic";
        # An event without a zone is read in the zone of the host
        TZ = osConfig.time.timeZone;
      };
    };
  };
}
