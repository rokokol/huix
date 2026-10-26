{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.rokokol.rea.enable = lib.mkEnableOption "REA with its MCP server and investigation skill";

  config = lib.mkIf config.rokokol.rea.enable {
    home.packages = with pkgs; [ rea ];
    programs.mcp.servers.rea = {
      command = lib.getExe pkgs.rea;
      args = [ "mcp" ];
      env = {
        GHIDRA_INSTALL_DIR = "${pkgs.ghidra}/lib/ghidra";
        JAVA_HOME = "${pkgs.jdk}";
      };
    };
    rokokol.agents = {
      skills.reverse-engineer-anything = "${pkgs.rea}/lib/node_modules/rea-agents/skills/reverse-engineer-anything";
      skillGroups.reverse-engineer-anything = "reversing";
      mcpGroups.rea = "reversing";
    };
  };
}
