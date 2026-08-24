{
  lib,
  pkgs,
  inputs,
  ...
}:

# The VPN client: `sing-box -C base.d -c profiles/<name>.json`. The base below is shared, a
# profile is one outbound tagged `proxy`, switching is the upstream `sing-box@<name>` unit
let
  ruZones = [
    ".ru"
    ".su"
    ".xn--p1ai"
  ];

  # Taken from the store, not fetched at startup: a remote rule-set would have to come through
  # the tunnel, so the client would refuse to start exactly when the node is down. `nix flake
  # update` refreshes them; builtins.path keeps one file out of the whole input tree
  geositeRu = builtins.path {
    name = "geosite-category-ru.srs";
    path = "${inputs.sing-geosite}/geosite-category-ru.srs";
  };

  geoipRu = builtins.path {
    name = "geoip-ru.srs";
    path = "${inputs.sing-geoip}/geoip-ru.srs";
  };

  baseConfig = {
    log = {
      level = "warn";
      timestamp = true;
    };

    # Without a bootstrap the first query waits on the tunnel that waits on the query
    dns = {
      servers = [
        {
          tag = "bootstrap";
          type = "local";
        }
        {
          tag = "remote";
          type = "tls";
          server = "8.8.8.8";
          detour = "proxy";
          domain_resolver = "bootstrap";
        }
      ];
      # Russian names resolve outside the tunnel too, or the answer is geo-wrong and the query
      # travels to a node that refuses to carry it
      rules = [
        {
          domain_suffix = ruZones;
          server = "bootstrap";
        }
        {
          rule_set = "geosite-ru";
          server = "bootstrap";
        }
      ];
      final = "remote";
      strategy = "ipv4_only";
    };

    inbounds = [
      {
        type = "tun";
        tag = "tun-in";
        interface_name = "skvpn-tun";
        address = [
          "172.19.0.1/30"
          "fdfe:dcba:9876::1/126"
        ];
        auto_route = true;

        # auto_route alone puts its table behind main, so locally-originated TCP never reaches it
        auto_redirect = true;
        strict_route = false;

        # A tailnet address pulled into the TUN answers over lo, and Tailscale's antispoof drops
        # any tailnet source that did not arrive on tailscale0
        route_exclude_address = [
          "100.64.0.0/10"
          "fd7a:115c:a1e0::/48"
        ];
        stack = "system";
      }
    ];

    outbounds = [
      {
        type = "direct";
        tag = "direct";
      }
    ];

    route = {
      auto_detect_interface = true;
      default_domain_resolver = "bootstrap";

      # hijack-dns before ip_is_private: the TUN's own DNS address is private and would be lost
      rules = [
        { action = "sniff"; }
        {
          protocol = "dns";
          action = "hijack-dns";
        }
        {
          ip_is_private = true;
          outbound = "direct";
        }

        # The exit refuses Russian destinations fail-closed, so they have to leave here instead.
        # The zone suffixes carry it: geosite-category-ru misses plenty, wooordhunt.ru included
        {
          domain_suffix = ruZones;
          outbound = "direct";
        }
        {
          rule_set = [
            "geosite-ru"
            "geoip-ru"
          ];
          outbound = "direct";
        }
      ];

      rule_set = [
        {
          tag = "geosite-ru";
          type = "local";
          format = "binary";
          path = "${geositeRu}";
        }
        {
          tag = "geoip-ru";
          type = "local";
          format = "binary";
          path = "${geoipRu}";
        }
      ];

      final = "proxy";
    };
  };

  skvpn = pkgs.writers.writePython3Bin "skvpn" { flakeIgnore = [ "E501" ]; } (
    builtins.readFile "${inputs.self}/scripts/skvpn.py"
  );
in
{
  environment.systemPackages = [
    pkgs.sing-box
    skvpn
  ];

  environment.etc."sing-box/base.d/00-base.json".text = builtins.toJSON baseConfig;

  # setgid: profiles are written by root, read by the service user
  systemd.tmpfiles.rules = [ "d /etc/sing-box/profiles 2750 root sing-box -" ];

  systemd.services."sing-box@" = {
    description = "sing-box, profile %i";

    after = [
      "network-online.target"
      "nss-lookup.target"
    ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      User = "sing-box";
      StateDirectory = "sing-box-%i";
      CapabilityBoundingSet = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
        "CAP_NET_BIND_SERVICE"
      ];
      AmbientCapabilities = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
        "CAP_NET_BIND_SERVICE"
      ];
      ExecStart = "${lib.getExe pkgs.sing-box} -D /var/lib/sing-box-%i -C /etc/sing-box/base.d -c /etc/sing-box/profiles/%i.json run";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      Restart = "on-failure";
      RestartSec = "10s";
      LimitNOFILE = "infinity";
    };
  };

  # Also runs on every `skvpn up`, so a rotated node is picked up without being asked for
  systemd.services.skvpn-sync = {
    description = "Refresh sing-box profiles from the stored subscription";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${skvpn}/bin/skvpn sub sync --if-stale";
    };
  };

  systemd.timers.skvpn-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  users.users.sing-box = {
    isSystemUser = true;
    group = "sing-box";
    home = "/var/lib/sing-box";
  };
  users.groups.sing-box = { };

  # TUN replies arrive on skvpn-tun but route via the LAN link, so strict rpfilter drops every
  # UDP answer (Discord voice)
  networking.firewall.checkReversePath = "loose";
}
