{ config, lib, ... }:

# Web services of this host, published to the tailnet with one port each. nginx is the one
# listener: a backend binds to loopback or a socket, and a site here forwards a port to it. The
# firewall opens none of the ports, because tailscale.nix beside this file trusts the tailnet
# interface. nginx also refuses every address outside the tailnet ranges, so a port that the
# firewall opens by mistake still serves nothing to the LAN. A site that sets `lan` is the
# exception: the firewall opens its port on the LAN link, and nginx admits the LAN network. There is
# no enable option: a service that declares a site is published, and its own option gates it
let
  cfg = config.rokokol.tailnet-web;
  ports = lib.mapAttrsToList (_: site: site.port) cfg.sites;
  lanSites = lib.filterAttrs (_: site: site.lan) cfg.sites;

  # The network of an IPv4 address in CIDR form, so 192.168.0.104/24 gives 192.168.0.0/24. The
  # lib of nixpkgs has this for IPv6 only
  networkOf =
    cidr:
    let
      parts = lib.splitString "/" cidr;
      prefix = lib.toInt (lib.last parts);
      pow2 = n: lib.foldl' (product: _: product * 2) 1 (lib.range 1 n);
      octet =
        i: value:
        let
          kept = lib.min 8 (lib.max 0 (prefix - 8 * i));
        in
        builtins.bitAnd value (256 - pow2 (8 - kept));
      octets = lib.imap0 octet (map lib.toInt (lib.splitString "." (lib.head parts)));
    in
    "${lib.concatMapStringsSep "." toString octets}/${toString prefix}";

  lanNetwork = networkOf cfg.lan.address;

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
  options.rokokol.tailnet-web.lan = lib.mkOption {
    default = null;
    description = "The LAN link of the host, which sites with `lan` are open to";
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          interface = lib.mkOption {
            type = lib.types.str;
            example = "lan";
            description = "Name of the LAN link, which the firewall opens the ports on";
          };

          address = lib.mkOption {
            type = lib.types.strMatching "[0-9]+(\\.[0-9]+){3}/[0-9]+";
            example = "192.168.0.104/24";
            description = "IPv4 address of the host on the link, in CIDR form; nginx admits its network";
          };
        };
      }
    );
  };

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

          # Only for a service with a login of its own: every device on the LAN reaches it
          lan = lib.mkEnableOption "access from the LAN network of `rokokol.tailnet-web.lan`";
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
      {
        assertion = lanSites == { } || cfg.lan != null;
        message = "rokokol.tailnet-web.sites.${lib.head (lib.attrNames lanSites)}.lan needs rokokol.tailnet-web.lan";
      }
    ];

    # Not mkIf: it reads the attribute names even when false, and a null lan has none to give.
    # The assertion above reports a null lan instead
    networking.firewall.interfaces = lib.optionalAttrs (lanSites != { } && cfg.lan != null) {
      ${cfg.lan.interface}.allowedTCPPorts = lib.mapAttrsToList (_: site: site.port) lanSites;
    };

    services.nginx = {
      enable = true;
      virtualHosts = lib.mapAttrs' (
        name: site:
        lib.nameValuePair "tailnet-${name}" {
          listen = map (addr: {
            inherit addr;
            inherit (site) port;
          }) listenAddresses;
          extraConfig =
            lib.concatMapStrings (range: "allow ${range};\n") (
              tailnetRanges ++ lib.optional site.lan lanNetwork
            )
            + "deny all;\n";
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
