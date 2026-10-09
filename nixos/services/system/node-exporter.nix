{ config, lib, ... }:

# The host's own metrics for the station's Prometheus: CPU, memory, swap, disks, network and the
# hwmon sensors. The exporter listens on every address, and tailscale.nix trusts the tailnet
# interface, so the tailnet reaches it while the closed firewall keeps every other network out.
# A module that measures a thing node_exporter cannot see writes a file into the textfile
# directory, and that module enables itself only where the thing exists
let
  dir = config.rokokol.node-exporter.textfileDir;
in
{
  options.rokokol.node-exporter.textfileDir = lib.mkOption {
    type = lib.types.str;
    # In RAM: a writer rewrites its file every few seconds, and nothing there must outlive a boot.
    # Not the exporter's own runtime directory, which systemd removes when the exporter stops
    default = "/run/node-exporter-textfile";
    readOnly = true;
    description = "Directory whose *.prom files node_exporter serves beside its own metrics";
  };

  config = {
    services.prometheus.exporters.node = {
      enable = true;
      extraFlags = [ "--collector.textfile.directory=${dir}" ];
    };

    systemd.tmpfiles.rules = [ "d ${dir} 0755 root root -" ];
  };
}
