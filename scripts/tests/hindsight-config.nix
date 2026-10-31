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
  fixture = (pkgs.formats.json { }).generate "hindsight-config.json" {
    environment = station.systemd.services.hindsight.environment;
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
    backupPaths = station.services.restic.backups.hermes.paths;
    backupRequires = station.systemd.services.restic-backups-hermes.requires;
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
