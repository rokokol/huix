{
  config,
  lib,
  pkgs,
  ...
}:

# FreeCAD with the addon of freecad-mcp, an XML-RPC server inside the running FreeCAD on
# 127.0.0.1:9875, a port both halves hard-code. The agents reach it through the freecad-mcp
# bridge, which also runs scripts in a headless freecadcmd of the same FreeCAD
let
  inherit (pkgs) freecad freecad-mcp;
  # FreeCAD keeps user data, its Mod directory among it, per minor version
  dataDir = ".local/share/FreeCAD/v${lib.versions.major freecad.version}-${lib.versions.minor freecad.version}";
  # The addon keeps its settings in a file it writes itself, so the default it starts from is
  # patched instead, and its menu still turns the start off
  addon = pkgs.runCommandLocal "freecad-mcp-addon-${freecad-mcp.version}" { } ''
    cp -r ${freecad-mcp.src}/addon/FreeCADMCP $out
    chmod -R u+w $out
    substituteInPlace $out/rpc_server/settings.py \
      --replace-fail '"auto_start_rpc": False' '"auto_start_rpc": True'
  '';
in
{
  options.rokokol.freecad.enable =
    lib.mkEnableOption "FreeCAD with the freecad-mcp addon and its MCP server"
    // {
      default = config.rokokol.workstation.enable;
    };

  config = lib.mkIf config.rokokol.freecad.enable {
    home.packages = [ freecad ];

    home.file."${dataDir}/Mod/FreeCADMCP".source = addon;

    # It answers only while FreeCAD runs, apart from the headless scripts
    programs.mcp.servers.freecad = {
      command = lib.getExe freecad-mcp;
      args = [
        "--host"
        "127.0.0.1"
        "--freecadcmd"
        "${freecad}/bin/freecadcmd"
      ];
    };
  };
}
