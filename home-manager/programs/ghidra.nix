{
  config,
  lib,
  pkgs,
  ...
}:

# Reverse engineering: Ghidra with its extensions, and Detect It Easy, which names a file's
# compiler and packer and plots its entropy. ReVa, one of the extensions, is itself an MCP server
# inside the running Ghidra, so the agents reach it over HTTP and no bridge is packaged
let
  cfg = config.rokokol.ghidra;
  # ReVa's own default, which it keeps in Ghidra's tool options and reads from no file
  revaDefaultPort = 8080;
  reva =
    if cfg.port == revaDefaultPort then
      pkgs.ghidra-extensions.reva
    else
      pkgs.ghidra-extensions.reva.overrideAttrs (previous: {
        postPatch = (previous.postPatch or "") + ''
          substituteInPlace src/main/java/reva/plugin/ConfigManager.java \
            --replace-fail "DEFAULT_PORT = ${toString revaDefaultPort};" "DEFAULT_PORT = ${toString cfg.port};"
        '';
      });
  # ReVa's source carries the skills that drive it, so they come at the revision of the extension
  revaSkills = "${reva.src}/ReVa/skills";
in
{
  options.rokokol.ghidra = {
    enable = lib.mkEnableOption "Ghidra with ReVa and its MCP server, and Detect It Easy" // {
      default = config.rokokol.workstation.enable;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = revaDefaultPort;
      description = ''
        Loopback port of ReVa's MCP server. Ghidra keeps a port set in its own options over
        this one, so leave that option at its default
      '';
    };

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs.ghidra-extensions; [
        findcrypt
        ghidra-golanganalyzerextension
        ghidraninja-ghidra-scripts
      ];
      defaultText = lib.literalExpression "with pkgs.ghidra-extensions; [ findcrypt ghidra-golanganalyzerextension ghidraninja-ghidra-scripts ]";
      description = "Ghidra extensions beside ReVa, from `pkgs.ghidra-extensions`";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      (ghidra.withExtensions (_: [ reva ] ++ cfg.extensions))
      detect-it-easy
    ];

    home.sessionVariables.REVA_PORT = cfg.port;

    # It answers only while Ghidra runs
    programs.mcp.servers.ghidra.url = "http://localhost:${toString cfg.port}/mcp/message";

    rokokol.agents.skills = lib.mapAttrs (name: _: "${revaSkills}/${name}") (
      lib.filterAttrs (_: type: type == "directory") (builtins.readDir revaSkills)
    );
  };
}
