{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.rokokol.opencode.server {
    programs.mcp.servers.opencode = {
      command = lib.getExe' pkgs.nodejs "npx";
      args = [
        "-y"
        "opencode-mcp"
      ];
      env.OPENCODE_BASE_URL = "http://127.0.0.1:${toString config.rokokol.opencode.port}";
    };
  };
}
