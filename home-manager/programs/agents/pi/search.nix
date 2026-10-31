{ config, lib, pkgs, osConfig, ... }:

{
  config = lib.mkIf config.rokokol.pi.enable {
    programs.mcp.servers.searxng = {
      command = lib.getExe pkgs.mcp-searxng;
      env = {
        SEARXNG_URL =
          if osConfig.rokokol.searxng.enable or false then
            "http://127.0.0.1:${toString (osConfig.rokokol.searxng.port or 9000)}"
          else
            "http://nixos-station:${toString (osConfig.rokokol.searxng.publicPort or 9001)}";
      };
    };
  };
}