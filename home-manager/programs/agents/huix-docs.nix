{
  config,
  lib,
  pkgs,
  huixDir,
  ...
}:

# The documentation of this configuration, answered from the checkout rather than from the store:
# an agent that asks about the tree it is editing gets the tree it is editing, and a page rendered
# a minute ago is already in the answer. See `lib/docs/build.nix` for the rendered copy
{
  options.rokokol.huix-docs.enable =
    lib.mkEnableOption "the MCP server over this repository's own documentation"
    // {
      default = config.rokokol.workstation.enable;
    };

  config = lib.mkIf config.rokokol.huix-docs.enable {
    rokokol.agents.mcpGroups.huix-docs = "huix";
    programs.mcp.servers.huix-docs = {
      command = lib.getExe pkgs.python3;
      args = [
        "-B"
        "${huixDir}/scripts/docs-mcp.py"
      ];
    };
  };
}
