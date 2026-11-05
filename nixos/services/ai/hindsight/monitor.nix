{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# Hindsight runs every model on a key of its own, and that key's counter is what the provider
# billed — so the dashboard reads the spend instead of inferring it from tokens, which Hindsight
# does not record for embeddings or rerank at all (DEVIATIONS.md, "Hindsight spends an OpenRouter
# key of its own"). A timer exports the counter into the host's Prometheus, through the same
# textfile directory as the other collected metrics. It is not part of the Hermes monitor:
# Hindsight spends whether or not the agent runs
let
  cfg = config.rokokol.hindsight;
  metrics = "/run/hindsight-spend-monitor/metrics.prom";
  script = builtins.path {
    name = "hindsight-spend-monitor.py";
    path = "${inputs.self}/scripts/hindsight-spend-monitor.py";
  };
in
{
  config = lib.mkIf cfg.enable {
    # The station's node_exporter serves a directory in RAM, and a link keeps the file's owner
    # the unit's while the exporter, which runs as root, only reads it
    systemd.tmpfiles.rules = [
      "L+ ${config.rokokol.node-exporter.textfileDir}/hindsight-spend.prom - - - - ${metrics}"
    ];
    systemd.services.hindsight-spend-monitor = {
      description = "Export the OpenRouter spend of Hindsight's key";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RuntimeDirectory = "hindsight-spend-monitor";
        RuntimeDirectoryPreserve = true;
        LoadCredential = "key:${config.sops.secrets.openrouter-hindsight-api-key.path}";
        ExecStart = lib.escapeShellArgs [
          (lib.getExe pkgs.python3)
          script
          "--metrics"
          metrics
          "--key-file"
          "%d/key"
        ];
        TimeoutStartSec = 60;
        ProtectHome = "tmpfs";
        ProtectSystem = "strict";
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
      };
    };
    systemd.timers.hindsight-spend-monitor = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3m";
        # The counter moves with the key, so a minute is the finest the dashboard needs, and the
        # unit reads one endpoint of an API that rate limits per key
        OnUnitInactiveSec = "1m";
      };
    };
  };
}
