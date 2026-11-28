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

  roles = (lib.importJSON inputs.ddlc-themes.lib.roles).dark;
  panels = import ./panels.nix { inherit lib roles datasource; };
  models = import ../../../../lib/ai-models.nix;
  inherit (models) memory;
  modelPricesScript = builtins.path {
    name = "model-prices.py";
    path = "${inputs.self}/scripts/model-prices.py";
  };
  modelPricesList = pkgs.writeText "model-prices.json" (builtins.toJSON models.chat);
  modelPricesMetrics = "/run/model-prices/metrics.prom";
  modelPricesInterval = 60 * 60;

  # An age such as 36h and a size such as 10G, as the watchers' options write them, in seconds
  # and bytes, so the dashboard turns red where the watcher alerts
  scaled =
    units: text:
    let
      unit = lib.substring (lib.stringLength text - 1) 1 text;
    in
    if units ? ${unit} then lib.toInt (lib.removeSuffix unit text) * units.${unit} else lib.toInt text;
  seconds = scaled {
    s = 1;
    m = 60;
    h = 3600;
    d = 86400;
  };
  bytes = scaled {
    K = 1024;
    M = 1024 * 1024;
    G = 1024 * 1024 * 1024;
    T = 1024 * 1024 * 1024 * 1024;
  };

  maxBackupAge = seconds config.rokokol.backup-heartbeat.maxAge;
  resources = import ./resources.nix {
    inherit lib criticalTemperature modelPricesInterval;
    stationHost = hostName;
    maxPushSilence = seconds config.rokokol.pushgateway.maxSilence;
  };

  hermes = config.rokokol.mya-agent.hermes.monitor.enable;
  hindsight = config.rokokol.hindsight.enable or false;
  obsidianThing = config.rokokol.obsidian-thing.enable;
  hostDashboard = import ./dashboards/hosts.nix {
    inherit
      lib
      roles
      panels
      resources
      ;
  };
  hostDashboards = map (
    host:
    hostDashboard {
      hostName = host;
      withGpu =
        inputs.self.nixosConfigurations.${host}.config.services.prometheus.exporters.nvidia-gpu.enable;
      withInfrastructure = host == hostName;
      inherit maxBackupAge;
      minBackupFree = bytes config.rokokol.backup-heartbeat.minFree;
      syncthingHosts = lib.optional config.services.syncthing.enable hostName;
    }
  ) (builtins.attrNames inputs.self.nixosConfigurations);
  aiDashboards =
    lib.optional (hermes || hindsight || obsidianThing) (
      import ./dashboards/spend.nix {
        inherit
          lib
          panels
          hermes
          hindsight
          obsidianThing
          ;
        lowBalance = builtins.fromJSON config.rokokol.mya-agent.hermes.monitor.lowBalance;
        modelRoutes = models.chat;
        modelPricesMaxAge = 2 * modelPricesInterval;
      }
    )
    ++ lib.optional hermes (import ./dashboards/hermes.nix { inherit roles panels; })
    ++ lib.optional hindsight (
      import ./dashboards/hindsight.nix {
        inherit roles panels;
        memoryModel = memory.model;
        poolMax = config.rokokol.hindsight.poolMax;
      }
    );
  serviceDashboards = [
    # The mail node owns these numbers and its report names a problem at each of them. They
    # are written here once, since that node's configuration is not part of this flake
    (import ./dashboards/mail.nix {
      inherit
        roles
        panels
        maxBackupAge
        resources
        ;
      minCertificateLife = seconds "14d";
      maxQuotaUsed = 0.9;
    })
    # The same for the VPN nodes: the disk and the sockets come from their list of open
    # problems, the connection tracking table from their self-check
    (import ./dashboards/vpn.nix {
      inherit roles panels resources;
      maxConntrackUsed = 0.8;
      maxStuckSockets = 200;
      maxPushSilence = seconds config.rokokol.pushgateway.maxSilence;
    })
  ]
  ++ lib.optional config.rokokol.obsidian-thing.enable (
    import ./dashboards/obsidian-thing.nix { inherit panels roles; }
  );
  otherDashboards = [ ];
  dashboardDirectory =
    name: items:
    pkgs.runCommand "grafana-${name}-dashboards" { } ''
      mkdir $out
      ${lib.concatMapStrings (dashboard: ''
        cp ${pkgs.writeText "${dashboard.uid}.json" (builtins.toJSON dashboard)} $out/${dashboard.uid}.json
      '') items}
    '';
in
{
  imports = [ (import ./alerting.nix { inherit resources datasource; }) ];

  options.rokokol.grafana = {
    enable = lib.mkEnableOption "Grafana over the Prometheus of this host";

    resourcePolicy = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      internal = true;
      default = resources;
      description = "Resource thresholds, queries and rules for dashboards and checks";
    };

    dashboardTitles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = map (dashboard: dashboard.title) (
        aiDashboards ++ serviceDashboards ++ hostDashboards ++ otherDashboards
      );
      defaultText = lib.literalMD "the titles of the dashboards this module provisions";
      description = "Titles of the provisioned dashboards, for what points a reader at them";
    };
  };

  config = lib.mkIf config.rokokol.grafana.enable {
    systemd.tmpfiles.rules = [
      "L+ ${config.rokokol.node-exporter.textfileDir}/model-prices.prom - - - - ${modelPricesMetrics}"
    ];
    systemd.services.model-prices = {
      description = "Collect OpenRouter endpoint prices";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RuntimeDirectory = "model-prices";
        RuntimeDirectoryPreserve = true;
        ExecStart = lib.escapeShellArgs [
          (lib.getExe pkgs.python3)
          modelPricesScript
          "--models"
          modelPricesList
          "--metrics"
          modelPricesMetrics
        ];
        TimeoutStartSec = 120;
        ProtectHome = "tmpfs";
        ProtectSystem = "strict";
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
      };
    };
    systemd.timers.model-prices = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitInactiveSec = "${toString modelPricesInterval}s";
      };
    };

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
      declarativePlugins = with pkgs.grafanaPlugins; [
        prometheus
        grafana-metricsdrilldown-app
      ];
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
            options.path = dashboardDirectory "other" otherDashboards;
          }
          {
            name = "ai";
            folder = "AI";
            folderUid = "ai-folder";
            options.path = dashboardDirectory "ai" aiDashboards;
          }
          {
            name = "hosts";
            folder = "Hosts";
            folderUid = "hosts-folder";
            options.path = dashboardDirectory "hosts" hostDashboards;
          }
          {
            name = "services";
            folder = "Services";
            folderUid = "services-folder";
            options.path = dashboardDirectory "services" serviceDashboards;
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
