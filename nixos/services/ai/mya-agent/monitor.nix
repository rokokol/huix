{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# A timer collects local usage without a permanent exporter process
let
  agent = config.rokokol.mya-agent;
  cfg = agent.hermes.monitor;
  home = "${config.services.hermes-agent.stateDir}/.hermes";
  script = builtins.path {
    name = "hermes-monitor.py";
    path = "${inputs.self}/scripts/hermes-monitor.py";
  };
in
{
  options.rokokol.mya-agent.hermes.monitor = {
    enable = lib.mkEnableOption "Hermes metrics and session spend notifications" // {
      default = agent.enable;
      defaultText = lib.literalExpression "config.rokokol.mya-agent.enable";
    };
    spendStep = lib.mkOption {
      type = lib.types.strMatching "[0-9]+(\\.[0-9]+)?";
      default = "0.50";
      description = "USD step between session spend notifications";
    };
    lowBalance = lib.mkOption {
      type = lib.types.strMatching "[0-9]+(\\.[0-9]+)?";
      default = "5.00";
      description = "Account balance in USD below which a notification is sent";
    };
    api = lib.mkOption {
      type = lib.types.str;
      default = "https://openrouter.ai/api/v1";
      description = "OpenRouter API endpoint";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.extraFlags = [ "--web.enable-otlp-receiver" ];
    services.hermes-agent.settings.monitoring = {
      gateway_health_export = {
        enabled = true;
        metrics_enabled = true;
        diagnostic_events_enabled = false;
      };
      export.otlp = {
        enabled = true;
        endpoint = "http://127.0.0.1:${toString config.services.prometheus.port}/api/v1/otlp/v1/traces";
      };
    };

    systemd.tmpfiles.rules = [
      "L+ ${config.rokokol.node-exporter.textfileDir}/hermes.prom - - - - /run/hermes-monitor/metrics.prom"
    ];
    systemd.services.hermes-monitor = {
      description = "Collect Hermes usage and report spend thresholds";
      wants = [ "network-online.target" ];
      after = [
        "hermes-agent.service"
        "network-online.target"
      ];
      unitConfig.ConditionPathExists = "${home}/state.db";
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "hermes-monitor";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "hermes-monitor";
        RuntimeDirectoryPreserve = true;
        LoadCredential = [
          "key:${config.sops.secrets.openrouter-api-key.path}"
          "bot:${config.sops.secrets.telegram-bot-token.path}"
          "chat:${config.sops.secrets.telegram-owner-chat-id.path}"
        ];
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe pkgs.python3)
            script
            "--home"
            home
            "--state-dir"
            "/var/lib/hermes-monitor"
            "--metrics"
            "/run/hermes-monitor/metrics.prom"
            "--key-file"
            "%d/key"
            "--bot-token-file"
            "%d/bot"
            "--chat-id-file"
            "%d/chat"
            "--spend-step"
            cfg.spendStep
            "--low-balance"
            cfg.lowBalance
            "--api"
            cfg.api
            "--telegram-api"
            config.rokokol.alert-mail.telegram.api
          ]
          ++ lib.optionals (agent.hermes.reportsTopic != null) [
            "--telegram-thread-id"
            (toString agent.hermes.reportsTopic)
          ]
        );
        TimeoutStartSec = 90;
        ProtectHome = "tmpfs";
        BindReadOnlyPaths = [ home ];
        ProtectSystem = "strict";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
      };
    };
    systemd.timers.hermes-monitor = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitInactiveSec = "1m";
      };
    };
  };
}
