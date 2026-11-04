{ resources, datasource }:
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# The resource rules of resources.nix as Grafana's own alerting, and their way out: a webhook to
# the bridge beside this file, which writes the causes file that the host's alert registry reads.
# So a firing rule arrives by the same mail, Telegram message and morning digest as a failed unit,
# with one place that holds the relay and the bot, and the registry closes a problem when Grafana
# sends its resolution. The bridge accepts only the alerts labelled huix_resource, so a rule added
# by hand in the UI cannot mail through the registry
let
  grafanaUrl = "http://${config.networking.hostName}:${toString config.rokokol.tailnet-web.sites.grafana.port}";
  port = 3210;
  directory = "/var/lib/grafana-alerts";
  script = builtins.path {
    name = "grafana-alerts.py";
    path = "${inputs.self}/scripts/grafana-alerts.py";
  };
  rule = definition: {
    inherit (definition)
      uid
      title
      hold
      ;
    condition = "B";
    # A host that went away is not a hot disk: the push watch names a silent node, and the rule
    # closes with the data
    noDataState = "OK";
    execErrState = "KeepLast";
    labels.huix_resource = "true";
    annotations = {
      summary = definition.title;
      description =
        "${grafanaUrl}/d/${definition.dashboard} shows the value that raised this alert, and the"
        + " rule evaluates ${definition.expr}";
    };
    data = [
      {
        refId = "A";
        datasourceUid = datasource;
        relativeTimeRange = {
          from = 600;
          to = 0;
        };
        model = {
          refId = "A";
          inherit (definition) expr;
          instant = true;
          range = false;
          intervalMs = 60000;
          maxDataPoints = 43200;
          datasource = {
            type = "prometheus";
            uid = datasource;
          };
        };
      }
      {
        refId = "B";
        datasourceUid = "__expr__";
        relativeTimeRange = {
          from = 0;
          to = 0;
        };
        model = {
          refId = "B";
          type = "threshold";
          expression = "A";
          conditions = [
            {
              evaluator = {
                type = "gt";
                params = [ 0 ];
              };
              operator.type = "and";
              query.params = [ "B" ];
              reducer = {
                type = "last";
                params = [ ];
              };
              type = "query";
            }
          ];
        };
      }
    ];
  };
in
{
  config = lib.mkIf config.rokokol.grafana.enable {
    assertions = [
      {
        assertion = config.rokokol.alert-mail.enable;
        message = "Grafana resource alerts require the host alert registry";
      }
    ];
    services.grafana.provision.alerting = {
      rules.settings = {
        apiVersion = 1;
        groups = [
          {
            orgId = 1;
            name = "Resources";
            folder = "Infrastructure";
            interval = "1m";
            rules = map rule resources.rules;
          }
        ];
      };
      contactPoints.settings = {
        apiVersion = 1;
        contactPoints = [
          {
            orgId = 1;
            name = "Host alert registry";
            receivers = [
              {
                uid = "host-alert-registry";
                type = "webhook";
                disableResolveMessage = false;
                settings = {
                  url = "http://127.0.0.1:${toString port}/alerts";
                  httpMethod = "POST";
                  maxAlerts = 0;
                };
              }
            ];
          }
        ];
      };
      policies.settings = {
        apiVersion = 1;
        policies = [
          {
            orgId = 1;
            receiver = "Host alert registry";
            group_by = [
              "alertname"
              "host"
              "instance"
            ];
            group_wait = "10s";
            group_interval = "1m";
            repeat_interval = "4h";
          }
        ];
      };
    };
    rokokol.alert-mail.sources.grafana = "${directory}/causes";
    systemd.services.grafana-alerts = {
      description = "Pass Grafana alerts to the host alert registry";
      wantedBy = [ "multi-user.target" ];
      before = [ "grafana.service" ];
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.python3} ${script} --address 127.0.0.1 --port ${toString port} --state-dir ${directory}";
        DynamicUser = true;
        StateDirectory = "grafana-alerts";
        StateDirectoryMode = "0755";
        Restart = "on-failure";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" ];
        IPAddressAllow = "localhost";
        IPAddressDeny = "any";
        UMask = "0022";
      };
      unitConfig.OnFailure = "alert-mail@%n.service";
    };
  };
}
