{
  config,
  lib,
  pkgs,
  ...
}:

# Enable the addon at launch without a binary preferences file or a change to user preferences
let
  addon = pkgs.runCommandLocal "blender-mcp-addon" { } ''
    mkdir -p $out
    cp ${pkgs.blender-mcp.src}/addon.py $out/blender_mcp.py
  '';
  startup = pkgs.writeText "blender-mcp-startup.py" ''
    import sys
    import addon_utils

    sys.path.insert(0, "${addon}")
    addon_utils.enable("blender_mcp", default_set=False, persistent=True)
  '';
  package = pkgs.symlinkJoin {
    name = "blender-with-mcp-${pkgs.blender.version}";
    paths = with pkgs; [ blender ];
    nativeBuildInputs = with pkgs; [ makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/blender --add-flags "--python ${startup}"
    '';
    meta = pkgs.blender.meta // {
      mainProgram = "blender";
    };
  };
in
{
  options.rokokol.blender.enable = lib.mkEnableOption "Blender with its MCP addon and server";

  config = lib.mkIf config.rokokol.blender.enable {
    home.packages = [ package ];

    programs.mcp.servers.blender = {
      command = lib.getExe pkgs.blender-mcp;
      env.DISABLE_TELEMETRY = "true";
    };
    rokokol.agents.mcpGroups.blender = "creative";
  };
}
