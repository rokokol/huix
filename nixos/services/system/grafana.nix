{
  config,
  lib,
  pkgs,
  criticalTemperature,
  inputs,
  ...
}:

# Grafana over the Prometheus of this host, through its tailnet-web site, which the LAN reaches
# too. Whoever reaches the site sees the dashboards without a login, as a viewer; the admin signs
# in from either network. Grafana binds to loopback.
#
# Grafana sets the admin password from sops only when it makes its database. To change it later,
# run `grafana cli admin reset-admin-password` as the grafana user, then change the secret
let
  hostName = config.networking.hostName;
  port = 3200;
  backendPort = 3201;
  secrets = [
    "grafana-admin-password"
    "grafana-secret-key"
  ];
  fromFile = name: "$__file{${config.sops.secrets.${name}.path}}";
  datasource = "prometheus";

  dashboard = import ./grafana-dashboard.nix {
    inherit lib criticalTemperature datasource;
    roles = (lib.importJSON inputs.ddlc-themes.lib.roles).dark;
  };
in
{
  options.rokokol.grafana.enable = lib.mkEnableOption "Grafana over the Prometheus of this host";

  config = lib.mkIf config.rokokol.grafana.enable {
    assertions = [
      {
        assertion = config.rokokol.prometheus.enable;
        message = "rokokol.grafana shows the Prometheus of this host, which is not enabled";
      }
    ];

    sops.secrets = lib.genAttrs secrets (_: {
      owner = "grafana";
      restartUnits = [ "grafana.service" ];
    });

    services.grafana = {
      enable = true;
      # Even the Prometheus data source is a plugin, which Grafana would download from grafana.com
      # on each start, unpinned. Plugins from the store turn that installer off
      declarativePlugins = with pkgs.grafanaPlugins; [ prometheus ];
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = backendPort;
          domain = hostName;
          root_url = "http://${hostName}:${toString port}/";
        };

        security = {
          admin_user = "admin";
          admin_password = fromFile "grafana-admin-password";
          secret_key = fromFile "grafana-secret-key";
          # Plain HTTP inside the tailnet and the LAN, so a secure cookie would never come back
          cookie_secure = false;
        };

        "auth.anonymous" = {
          enabled = true;
          org_role = "Viewer";
        };
        users = {
          allow_sign_up = false;
          # The dashboard's colours are the dark roles, which a light page would wash out
          default_theme = "dark";
        };

        # Nothing leaves the station on its own
        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
          check_for_plugin_updates = false;
          feedback_links_enabled = false;
        };
        news.news_feed_enabled = false;
      };

      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            uid = datasource;
            type = "prometheus";
            url = "http://127.0.0.1:${toString config.services.prometheus.port}";
            isDefault = true;
            # The step of a graph never falls below the scrape interval, or it shows gaps
            jsonData.timeInterval = config.services.prometheus.globalConfig.scrape_interval;
          }
        ];
        # From the store, so a change made in the UI cannot be saved over it
        dashboards.settings.providers = [
          {
            name = "huix";
            options.path = pkgs.writeTextDir "${dashboard.uid}.json" (builtins.toJSON dashboard);
          }
        ];
      };
    };

    rokokol.tailnet-web.sites.grafana = {
      inherit port;
      backend = "http://127.0.0.1:${toString backendPort}";
      lan = true;
    };
  };
}
