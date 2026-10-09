{
  config,
  lib,
  inputs,
  ...
}:

# Prometheus on loopback, for the Grafana beside it. It scrapes every host of this flake over the
# tailnet, by the host's name, and takes from each host's own configuration which exporters run
# there and on which port: a host that turns an exporter off drops out of its job. A host that is
# off gives a gap, not an alert
let
  cfg = config.rokokol.prometheus;

  # This host from its own configuration, so that whatever extends it, as a test does, is seen
  hosts = lib.mapAttrs (_: host: host.config) inputs.self.nixosConfigurations // {
    ${config.networking.hostName} = config;
  };

  exporters = [
    "node"
    "smartctl"
    "nvidia-gpu"
  ];

  job = exporter: {
    job_name = exporter;
    static_configs = lib.mapAttrsToList (name: host: {
      targets = [ "${name}:${toString host.services.prometheus.exporters.${exporter}.port}" ];
      labels.host = name;
    }) (lib.filterAttrs (_: host: host.services.prometheus.exporters.${exporter}.enable) hosts);
  };
in
{
  options.rokokol.prometheus = {
    enable = lib.mkEnableOption "Prometheus that scrapes the hosts of this flake";

    retention = lib.mkOption {
      type = lib.types.strMatching "[0-9]+[smhdwy]";
      default = "1y";
      example = "90d";
      description = "How long Prometheus keeps the metrics it scraped";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      retentionTime = cfg.retention;
      globalConfig.scrape_interval = "30s";
      scrapeConfigs = lib.filter (job: job.static_configs != [ ]) (map job exporters);
    };
  };
}
