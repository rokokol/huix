{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# Hindsight runs every model on a key of its own, and that key's counter is what the provider
# billed — so the dashboard reads the spend instead of inferring it from tokens, which Hindsight
# records for neither an embedding nor a rerank (DEVIATIONS.md, "Hindsight spends an OpenRouter
# key of its own"). The same unit counts the recalls that paid for a rerank: the trace table has
# the number and the only call counter omits the rerank scope (PITFALLS.md, "Hindsight's call
# counter records chat alone"). Both reach Grafana through the textfile directory that the
# station's node_exporter serves. It is not part of the Hermes monitor: Hindsight spends whether
# or not the agent runs
let
  cfg = config.rokokol.hindsight;
  metrics = "/run/hindsight-monitor/metrics.prom";
  script = builtins.path {
    name = "hindsight-monitor.py";
    path = "${inputs.self}/scripts/hindsight-monitor.py";
  };
in
{
  config = lib.mkIf cfg.enable {
    # The station's node_exporter serves a directory in RAM, and a link keeps the file's owner
    # the unit's while the exporter, which runs as root, only reads it
    systemd.tmpfiles.rules = [
      "L+ ${config.rokokol.node-exporter.textfileDir}/hindsight.prom - - - - ${metrics}"
    ];
    systemd.services.hindsight-monitor = {
      description = "Export Hindsight's spend and its paid rerank calls";
      wants = [ "network-online.target" ];
      after = [
        "hindsight.service"
        "network-online.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "hindsight-monitor";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "hindsight-monitor";
        RuntimeDirectoryPreserve = true;
        LoadCredential = [
          "key:${config.sops.secrets.openrouter-hindsight-api-key.path}"
          "token:${config.sops.secrets.hindsight-api-token.path}"
        ];
        ExecStart = lib.escapeShellArgs [
          (lib.getExe pkgs.python3)
          script
          "--metrics"
          metrics
          "--key-file"
          "%d/key"
          "--token-file"
          "%d/token"
          "--state-dir"
          "/var/lib/hindsight-monitor"
          "--bank"
          cfg.bank
          "--api-hindsight"
          "http://127.0.0.1:${toString cfg.port}"
        ];
        TimeoutStartSec = 60;
        ProtectHome = "tmpfs";
        ProtectSystem = "strict";
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
      };
    };
    systemd.timers.hindsight-monitor = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3m";
        # A minute is the finest the counters need, and it is what keeps the last day of a trace
        # bucket in the state file before the trace table prunes it
        OnUnitInactiveSec = "1m";
      };
    };
  };
}
