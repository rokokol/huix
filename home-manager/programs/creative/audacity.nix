{
  config,
  lib,
  pkgs,
  ...
}:

# Audacity 4 has no script pipe module, so the MCP needs the stable Audacity 3 package
let
  audacity = pkgs.symlinkJoin {
    name = "audacity-with-mcp-${pkgs.stable.audacity.version}";
    paths = with pkgs; [ stable.audacity ];
    nativeBuildInputs = with pkgs; [ makeWrapper ];
    # Audacity resets a module to New when its saved modification time differs
    # The startup plugin scan forks a plugin host, which re-creates the script pipes and
    # leaves the originals without a reader: https://github.com/audacity/audacity/issues/8671
    postBuild = ''
      wrapProgram $out/bin/audacity \
        --run 'config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/audacity"' \
        --run '${lib.getExe' pkgs.coreutils "mkdir"} -p "$config_dir" || exit $?' \
        --run 'module_datetime="$(${lib.getExe' pkgs.coreutils "date"} -r ${pkgs.stable.audacity}/lib/audacity/modules/mod-script-pipe.so +%Y-%m-%dT%H:%M:%S)" || exit $?' \
        --run '${lib.getExe pkgs.crudini} --set "$config_dir/audacity.cfg" ModuleDateTime mod-script-pipe "$module_datetime" || exit $?' \
        --run '${lib.getExe pkgs.crudini} --set "$config_dir/audacity.cfg" Module mod-script-pipe 1 || exit $?' \
        --run '${lib.getExe pkgs.crudini} --set "$config_dir/audacity.cfg" Effects SkipEffectsScanAtStartup 1 || exit $?'
    '';
    meta = pkgs.stable.audacity.meta // {
      mainProgram = "audacity";
    };
  };
in
{
  options.rokokol.audacity.enable = lib.mkEnableOption "Audacity with its MCP server";

  config = lib.mkIf config.rokokol.audacity.enable {
    home.packages = [ audacity ];

    programs.mcp.servers.audacity.command = lib.getExe pkgs.audacity-mcp;
    rokokol.agents.mcpGroups.audacity = "creative";
  };
}
