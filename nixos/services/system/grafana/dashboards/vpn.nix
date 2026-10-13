{
  roles,
  panels,
  maxDiskUsed,
  maxConntrackUsed,
  maxStuckSockets,
}:

# The dashboard of the VPN nodes, from what they push to the Pushgateway: their health, then the
# attacks on them and the traffic through them. A node pushes at least every quarter hour, so a
# rate is taken over an hour, which always holds several pushes
let
  inherit (panels)
    query
    panel
    row
    states
    variable
    ;

  node = ''job="vpn", instance=~"$instance"'';

  # The clients with the most traffic, because a panel of every client is unreadable
  topClients = 10;

  hourly = metric: by: "sum by (${by}) (increase(${metric}[1h]))";
  traffic = metric: by: "sum by (${by}) (rate(${metric}[1h]))";
in
panels.dashboard {
  uid = "vpn";
  title = "VPN";
  templating.list = [ (variable "instance" ''push_time_seconds{job="vpn"}'' "instance") ];
  panels = [
    (row "Health" null 0)
    (panel {
      title = "Load";
      x = 0;
      y = 1;
      w = 8;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [ (query "A" roles.series-1 "vpn_load1{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Memory used";
      x = 8;
      y = 1;
      w = 8;
      unit = "percentunit";
      min = 0;
      max = 1;
      shaded = true;
      queries = [ (query "A" roles.series-1 "vpn_memory_used_ratio{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Disk used";
      x = 16;
      y = 1;
      w = 8;
      unit = "percentunit";
      min = 0;
      max = 1;
      shaded = true;
      thresholds = maxDiskUsed;
      queries = [ (query "A" roles.series-1 "vpn_disk_used_ratio{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Connection tracking table used";
      x = 0;
      y = 9;
      w = 8;
      unit = "percentunit";
      min = 0;
      max = 1;
      shaded = true;
      thresholds = maxConntrackUsed;
      queries = [ (query "A" roles.series-1 "vpn_conntrack_used_ratio{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Established sockets without a timer";
      x = 8;
      y = 9;
      w = 8;
      unit = "short";
      min = 0;
      shaded = true;
      thresholds = maxStuckSockets;
      queries = [
        (query "A" roles.series-1 "vpn_established_sockets_without_timer{${node}}" "{{instance}}")
      ];
    })
    (panel {
      title = "Unit restarts per hour";
      x = 16;
      y = 9;
      w = 8;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (hourly "vpn_unit_restarts_total{${node}}" "instance, unit")
          "{{instance}} {{unit}}"
        )
      ];
    })
    (panel {
      title = "Pending updates";
      x = 0;
      y = 17;
      w = 8;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [ (query "A" roles.series-1 "vpn_pending_updates{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Uptime";
      x = 8;
      y = 17;
      w = 8;
      unit = "s";
      min = 0;
      shaded = true;
      queries = [ (query "A" roles.series-1 "vpn_uptime_seconds{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Problems the node reports";
      x = 16;
      y = 17;
      w = 8;
      unit = "short";
      min = 0;
      shaded = true;
      # The station alerts while this is above zero
      thresholds = 1;
      queries = [
        (query "A" roles.series-1 "count by (instance) (node_problem{${node}})" "{{instance}}")
      ];
    })
    (states {
      title = "Reboot";
      x = 0;
      y = 25;
      w = 24;
      expr = "vpn_reboot_required{${node}}";
      legend = "{{instance}}";
      mappings = {
        "0" = {
          text = "current";
          color = roles.ok;
        };
        "1" = {
          text = "required";
          color = roles.kind-warning;
        };
      };
    })

    (row "Attacks and traffic" null 33)
    (panel {
      title = "fail2ban failed attempts per hour";
      x = 0;
      y = 34;
      w = 8;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (hourly "vpn_fail2ban_failed_total{${node}}" "instance, jail")
          "{{instance}} {{jail}}"
        )
      ];
    })
    (panel {
      title = "fail2ban bans";
      x = 8;
      y = 34;
      w = 8;
      unit = "short";
      min = 0;
      queries = [
        (query "A" roles.series-1 (hourly "vpn_fail2ban_banned_total{${node}}" "instance, jail")
          "{{instance}} {{jail}} per hour"
        )
        (query "B" roles.series-3 "vpn_fail2ban_banned{${node}}" "{{instance}} {{jail}} banned now")
      ];
    })
    (panel {
      title = "Packets the firewall dropped";
      x = 16;
      y = 34;
      w = 8;
      unit = "pps";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 "rate(vpn_ufw_drops_total{${node}}[1h])" "{{instance}}")
      ];
    })
    (panel {
      title = "Traffic by inbound";
      x = 0;
      y = 42;
      w = 12;
      unit = "Bps";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1
          (traffic "vpn_inbound_traffic_bytes_total{${node}}" "instance, inbound, direction")
          "{{instance}} {{inbound}} {{direction}}"
        )
      ];
    })
    (panel {
      title = "Traffic of the ${toString topClients} busiest clients";
      x = 12;
      y = 42;
      w = 12;
      unit = "Bps";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1
          ''
            ${traffic "vpn_client_traffic_bytes_total{${node}}" "instance, client, direction"}
            and on (instance, client)
            topk(${toString topClients}, ${traffic "vpn_client_traffic_bytes_total{${node}}" "instance, client"})''
          "{{instance}} {{client}} {{direction}}"
        )
      ];
    })
  ];
}
