{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.rokokol.kdenlive.enable = lib.mkEnableOption "Kdenlive with its MCP server and video skills";

  config = lib.mkIf config.rokokol.kdenlive.enable {
    home.packages = with pkgs; [ kdePackages.kdenlive ];

    programs.mcp.servers.kdenlive = {
      command = lib.getExe pkgs.kdenlive-mcp;
      args = [ "mcp" ];
    };

    rokokol.agents.mcpGroups.kdenlive = "creative";
  };
}
