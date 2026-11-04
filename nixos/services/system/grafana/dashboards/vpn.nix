{
  roles,
  panels,
  maxDiskUsed,
  maxConntrackUsed,
  maxStuckSockets,
  maxPushSilence,
}:

# The dashboard of the VPN nodes, from what they push to the Pushgateway: their health, then the
# attacks on them and the traffic through them. A node samples every ten minutes, so a rate of
# its own numbers is taken over an hour, which always holds several samples
let
  inherit (panels)
    bars
    query
    panel
    row
    states
    variable
    ;

  node = ''job="vpn", instance=~"$instance"'';
  fresh = "time() - push_time_seconds{${node}} < ${toString maxPushSilence}";
  current = metric: "${metric}{${node}} and on (instance) (${fresh})";
  upDown = {
    "0" = {
      text = "down";
      color = roles.danger;
    };
    "1" = {
      text = "up";
      color = roles.ok;
    };
  };

  # The master pushes the panel's traffic every minute and the station scrapes every half minute,
  # so three minutes is the shortest window that always holds two different values. The master
  # reports for the whole fleet, so an inbound is chosen by its node label, not by the instance
  nowWindow = "3m";
  inbounds =
    labels:
    ''sum by (node, inbound) (rate(vpn_inbound_traffic_bytes_total{job="vpn", ${labels}}[${nowWindow}]))'';

  # The clients with the most traffic, because a panel of every client is unreadable
  topClients = 10;

  hourly = metric: by: "sum by (${by}) (increase(${metric}[1h]))";
  traffic = metric: by: "sum by (${by}) (rate(${metric}[1h]))";
in
panels.dashboard {
  uid = "vpn";
  title = "VPN";
  templating.list = [
    (variable "instance" ''push_time_seconds{job="vpn"}'' "instance")
    (variable "vpn_node" "vpn_inbound_traffic_bytes_total" "node")
  ];
  panels = [
    (row "VPN state" null 0)
    (
      (states {
        title = "Xray";
        x = 0;
        y = 1;
        w = 8;
        expr = current "x_ui_xray_up";
        legend = "{{instance}}";
        mappings = upDown;
      })
      // {
        description = "Local Xray state as the panel reports it, not an end-to-end connection check. Unknown state or a stale push leaves a gap";
      }
    )
    (
      (states {
        title = "Panel API";
        x = 8;
        y = 1;
        w = 8;
        expr = "x_ui_panel_up{${node}} * on (instance) (time() - push_time_seconds{${node}} < bool ${toString maxPushSilence})";
        legend = "{{instance}}";
        mappings = upDown;
      })
      // {
        description = "Whether the node can read its panel API. A push past the node alert silence limit also counts as down";
      }
    )
    (panel {
      title = "Clients online";
      x = 16;
      y = 1;
      w = 8;
      unit = "short";
      min = 0;
      decimals = 0;
      shaded = true;
      description = "Each panel includes its child nodes without duplicates. Do not add master and child counts. Unknown or stale values leave gaps";
      queries = [ (query "A" roles.series-1 (current "x_ui_online_clients") "{{instance}}") ];
    })

    (row "Health" null 9)
    (panel {
      title = "Load";
      x = 0;
      y = 10;
      w = 8;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [ (query "A" roles.series-1 "vpn_load1{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Memory used";
      x = 8;
      y = 10;
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
      y = 10;
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
      y = 18;
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
      y = 18;
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
      y = 18;
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
      y = 26;
      w = 8;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [ (query "A" roles.series-1 "vpn_pending_updates{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Uptime";
      x = 8;
      y = 26;
      w = 8;
      unit = "s";
      min = 0;
      shaded = true;
      queries = [ (query "A" roles.series-1 "vpn_uptime_seconds{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Problems the node reports";
      x = 16;
      y = 26;
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
      y = 34;
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

    (row "Attacks" null 42)
    (panel {
      title = "fail2ban failed attempts per hour";
      x = 0;
      y = 43;
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
      y = 43;
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
      title = "Packets the firewall dropped per hour";
      x = 16;
      y = 43;
      w = 8;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (hourly "vpn_ufw_drops_total{${node}}" "instance") "{{instance}}")
      ];
    })
  ]
  ++ panels.attackers "vpn" node 51
  ++ [
    (row "Traffic now" null 59)
    (bars {
      title = "Inbounds now, down";
      x = 0;
      y = 60;
      w = 12;
      expr = inbounds ''direction="down"'';
      legend = "{{node}} {{inbound}}";
      unit = "Bps";
    })
    (bars {
      title = "Inbounds now, up";
      x = 12;
      y = 60;
      w = 12;
      expr = inbounds ''direction="up"'';
      legend = "{{node}} {{inbound}}";
      unit = "Bps";
    })

    # One row a node, whichever node of the fleet the master's panel says an inbound runs on
    (row "Inbounds of $vpn_node" "vpn_node" 68)
    (panel {
      title = "Down, by inbound";
      x = 0;
      y = 69;
      w = 12;
      unit = "Bps";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (inbounds ''node=~"$vpn_node", direction="down"'') "{{inbound}}")
      ];
    })
    (panel {
      title = "Up, by inbound";
      x = 12;
      y = 69;
      w = 12;
      unit = "Bps";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (inbounds ''node=~"$vpn_node", direction="up"'') "{{inbound}}")
      ];
    })

    (row "Clients" null 77)
  ]
  # Both panels show the same clients, the busiest by up and down together, so a client does not
  # drop out of one panel while it stays in the other
  ++
    map
      (
        side:
        panel {
          title = "${side.title}, the ${toString topClients} busiest clients";
          inherit (side) x;
          y = 78;
          w = 12;
          unit = "Bps";
          min = 0;
          shaded = true;
          queries = [
            (query "A" roles.series-1
              ''
                ${traffic ''vpn_client_traffic_bytes_total{${node}, direction="${side.direction}"}'' "instance, client"}
                and on (instance, client)
                topk(${toString topClients}, ${traffic "vpn_client_traffic_bytes_total{${node}}" "instance, client"})''
              "{{instance}} {{client}}"
            )
          ];
        }
      )
      [
        {
          direction = "down";
          title = "Down";
          x = 0;
        }
        {
          direction = "up";
          title = "Up";
          x = 12;
        }
      ];
}
