{
  config,
  lib,
  pkgs,
  ...
}:

# The managed layer supplements, rather than replaces, OpenCode's mutable global config
let
  configDir = "${config.xdg.configHome}/opencode";
  usageMonitorConfig = pkgs.writeText "usage-monitor.json" (
    builtins.toJSON {
      version = 2;
      providers.openai = { };
    }
  );
in
{
  home.sessionVariables.OPENCODE_CONFIG = "${configDir}/huix.json";

  xdg.configFile."opencode/huix.json".text = builtins.toJSON {
    lsp = true;
    plugin = [ "opencode-usage-monitor@2.0.1" ];
  };

  home.activation.createOpenCodeUsageMonitorConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${configDir}/usage-monitor.json" ]; then
      $DRY_RUN_CMD install -Dm600 "${usageMonitorConfig}" "${configDir}/usage-monitor.json"
    fi
  '';
}
