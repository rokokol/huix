{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  options.rokokol.huix-docs.enable =
    lib.mkEnableOption "the MCP server over this repository's own documentation"
    // {
      default = config.rokokol.workstation.enable;
    };

  config = lib.mkIf config.rokokol.huix-docs.enable {
    rokokol.agents.mcpGroups.actual_system_docs = "huix";
    programs.mcp.servers.actual_system_docs.command =
      lib.getExe
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.huix-docs-mcp;
  };
}
