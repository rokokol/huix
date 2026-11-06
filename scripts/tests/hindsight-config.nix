{
  pkgs,
  inputs,
  rokokolName,
}:
let
  station = inputs.self.nixosConfigurations.nixos-station.config;
  pc = inputs.self.nixosConfigurations.nixos-pc.config;
  laptop = inputs.self.nixosConfigurations.nixos-laptop.config;
  cfg = station.rokokol.hindsight;
  dashboard = import "${inputs.self}/nixos/services/system/grafana/dashboards/hindsight.nix" {
    roles = (pkgs.lib.importJSON inputs.ddlc-themes.lib.roles).dark;
    panels = import "${inputs.self}/nixos/services/system/grafana/panels.nix" {
      inherit (pkgs) lib;
      roles = (pkgs.lib.importJSON inputs.ddlc-themes.lib.roles).dark;
      datasource = "prometheus";
    };
    memoryModel = (import "${inputs.self}/lib/ai-models.nix").memory.model;
    inherit (cfg) poolMax;
  };
  fixture = (pkgs.formats.json { }).generate "hindsight-config.json" {
    # What the dashboard asks Prometheus, so a query of a series that never exists is caught here
    # rather than on a panel that stays empty without saying so
    dashboardExpressions = pkgs.lib.concatMap (
      panel: map (target: target.expr) (panel.targets or [ ])
    ) dashboard.panels;
    keyBalancePanel = builtins.head (
      builtins.filter (panel: (panel.title or null) == "OpenRouter key balance") dashboard.panels
    );
    latencyPanel = builtins.head (
      builtins.filter (panel: (panel.title or null) == "Average model and phase latency") dashboard.panels
    );
    environment = station.systemd.services.hindsight.environment;
    envTemplate = station.sops.templates."hindsight.env".content;
    placeholders = {
      agents = station.sops.placeholder."openrouter-api-key";
      hindsight = station.sops.placeholder."openrouter-hindsight-api-key";
    };
    monitor = station.systemd.services.hindsight-monitor.serviceConfig;
    textfileRules = station.systemd.tmpfiles.rules;
    initdbArgs = station.services.postgresql.initdbArgs;
    enableTCPIP = station.services.postgresql.enableTCPIP;
    api = station.systemd.services.hindsight.serviceConfig;
    databaseSetup = station.systemd.services.hindsight-database.serviceConfig;
    databaseAfter = station.systemd.services.hindsight-database.after;
    databaseRequires = station.systemd.services.hindsight-database.requires;
    dump = station.systemd.services.postgresqlBackup-hindsight.unitConfig;
    inherit (station.services.postgresqlBackup) location pgdumpOptions;
    dumpDir = cfg.backup.dumpDir;
    mountPoint = cfg.backup.mountPoint;
    backupPaths = station.services.restic.backups.station.paths;
    backupRequires = station.systemd.services.restic-backups-station.requires;
    folders = station.services.syncthing.settings.folders;
    pcFolders = pc.services.syncthing.settings.folders;
    laptopFolders = laptop.services.syncthing.settings.folders;
    piMemory =
      builtins.readFile
        pc.home-manager.users.${rokokolName}.home.file."${
          pc.home-manager.users.${rokokolName}.programs.pi-coding-agent.configDir
        }/extensions/memory.ts".source;
    hermesMemoryProvider = station.services.hermes-agent.settings.memory.provider;
    hermesMcpServers = builtins.attrNames station.services.hermes-agent.settings.mcp_servers;
    hermesPythonPackages = map (
      package: package.name
    ) station.services.hermes-agent.extraPythonPackages;
    hermesEnv = station.sops.templates."hermes.env".content;
    inherit (cfg) bank port;
  };
in
pkgs.runCommand "hindsight-config-tests" { nativeBuildInputs = with pkgs; [ python3 ]; } ''
  python3 ${./test-hindsight-config.py} ${fixture}
  touch "$out"
''
