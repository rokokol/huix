{ config, lib, ... }:

# Web services of this host, published to the tailnet with one port each. nginx is the one
# listener: a backend binds to loopback or a socket, and a site here forwards a port to it. The
# firewall opens none of the ports, because tailscale.nix beside this file trusts the tailnet
# interface. nginx also refuses every address outside the tailnet ranges, so a port that the
# firewall opens by mistake still serves nothing to the LAN. There is no enable option: a
# service that declares a site is published, and the service's own option gates it
let
  cfg = config.rokokol.tailnet-web;
  ports = lib.mapAttrsToList (_: site: site.port) cfg.sites;

  # Every address of the host, so the tailnet address need not be known before tailscaled is up
  listenAddresses = [
    "0.0.0.0"
    "[::]"
  ];

  # The ranges Tailscale assigns its nodes addresses from
  tailnetRanges = [
    "100.64.0.0/10"
    "fd7a:115c:a1e0::/48"
  ];
in
{
  options.rokokol.tailnet-web.sites = lib.mkOption {
    default = { };
    description = "Sites published to the tailnet, by name";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          port = lib.mkOption {
            type = lib.types.port;
            description = "TCP port of the site, on every address of the host";
          };

          backend = lib.mkOption {
            type = lib.types.str;
            example = "http://127.0.0.1:3000";
            description = "URL that nginx forwards the requests of the site to";
          };

          extraConfig = lib.mkOption {
            type = lib.types.lines;
            default = "";
            example = "client_max_body_size 512m;";
            description = "nginx directives for the location of the site";
          };
        };
      }
    );
  };

  config = lib.mkIf (cfg.sites != { }) {
    assertions = [
      {
        assertion = lib.allUnique ports;
        message = "rokokol.tailnet-web.sites share a port: ${toString ports}";
      }
    ];

    services.nginx = {
      enable = true;
      virtualHosts = lib.mapAttrs' (
        name: site:
        lib.nameValuePair "tailnet-${name}" {
          listen = map (addr: {
            inherit addr;
            inherit (site) port;
          }) listenAddresses;
          extraConfig = lib.concatMapStrings (range: "allow ${range};\n") tailnetRanges + "deny all;\n";
          locations."/" = {
            proxyPass = site.backend;
            recommendedProxySettings = true;
            # Harmless for a backend that never upgrades, and Grafana Live needs it
            proxyWebsockets = true;
            inherit (site) extraConfig;
          };
        }
      ) cfg.sites;
    };
  };
}
