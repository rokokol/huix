{
  config,
  lib,
  pkgs,
  ...
}:

# MCP servers that answer from documentation rather than from the user's own data: mcp-nixos,
# over the NixOS, Home Manager and nixpkgs indexes of a channel rather than this flake's pin, and
# DeepWiki, which answers about a public GitHub repository from an index Cognition hosts
{
  options.rokokol.docs-mcp.enable = lib.mkEnableOption "the mcp-nixos and DeepWiki MCP servers" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.docs-mcp.enable {
    programs.mcp.servers = {
      nixos.command = lib.getExe pkgs.mcp-nixos;
      deepwiki.url = "https://mcp.deepwiki.com/mcp";
    };
  };
}
