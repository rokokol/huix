{
  roles,
  panels,
  maxDiskUsed,
  maxConntrackUsed,
  maxStuckSockets,
  maxPushSilence,
  resources,
}:

# The nodes sample every ten minutes. Use an hour for rates from those samples
let
  inherit (panels)
    bars
    query
    panel
    row
    stat
    states
    table
    variable
    ;

  node = ''job="vpn", instance=~"$instance"'';
  pushAge = "time() - push_time_seconds{${node}}";
  fresh = "${pushAge} < ${toString maxPushSilence}";
  panelUp = "x_ui_panel_up{${node}} * on (instance) (${pushAge} < bool ${toString maxPushSilence})";
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
    (row "VPN now" null 0)
    (stat {
      title = "Xray";
      x = 0;
      y = 1;
      w = 6;
      unit = "none";
      expr = current "x_ui_xray_up";
      legend = "{{instance}}";
      mappings = upDown;
      description = "Local Xray state, not an end-to-end check. No data means that the state is unknown or the push is stale";
    })
    (stat {
      title = "Panel API";
      x = 6;
      y = 1;
      w = 6;
      unit = "none";
      expr = panelUp;
      legend = "{{instance}}";
      mappings = upDown;
      description = "A push past the silence limit also counts as down";
    })
    (stat {
      title = "Clients online";
      x = 12;
      y = 1;
      w = 6;
      unit = "short";
      expr = current "x_ui_online_clients";
      legend = "{{instance}}";
      decimals = 0;
      description = "Each panel includes its child nodes without duplicates. Do not add master and child counts. Unknown or stale values show no data";
    })
    (stat {
      title = "Time since last metrics push";
      x = 18;
      y = 1;
      w = 6;
      unit = "s";
      expr = pushAge;
      legend = "{{instance}}";
      thresholds = maxPushSilence;
    })
    (stat {
      title = "Reboot";
      x = 0;
      y = 5;
      w = 6;
      unit = "none";
      expr = current "vpn_reboot_required";
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
    (stat {
      title = "Disk used";
      x = 6;
      y = 5;
      w = 6;
      unit = "percentunit";
      expr = resources.freshDisk "vpn" node;
      legend = "{{instance}}";
      thresholds = maxDiskUsed;
    })
    (stat {
      title = "Pending updates";
      x = 12;
      y = 5;
      w = 6;
      unit = "short";
      expr = current "vpn_pending_updates";
      legend = "{{instance}}";
      decimals = 0;
    })
    (stat {
      title = "Uptime";
      x = 18;
      y = 5;
      w = 6;
      unit = "s";
      expr = current "vpn_uptime_seconds";
      legend = "{{instance}}";
    })
    (table {
      title = "Reported problems";
      x = 0;
      y = 9;
      w = 24;
      expr = current "node_problem";
      unit = "none";
      thresholds = 1;
      labels = [
        "instance"
        "key"
        "summary"
      ];
      valueName = "Reported";
    })
    (row "VPN state history" null 17)
    (states {
      title = "Xray history";
      x = 0;
      y = 18;
      w = 8;
      expr = current "x_ui_xray_up";
      legend = "{{instance}}";
      mappings = upDown;
    })
    (states {
      title = "Panel API history";
      x = 8;
      y = 18;
      w = 8;
      expr = panelUp;
      legend = "{{instance}}";
      mappings = upDown;
    })
    (panel {
      title = "Clients online history";
      x = 16;
      y = 18;
      w = 8;
      unit = "short";
      min = 0;
      decimals = 0;
      shaded = true;
      description = "Each panel includes its child nodes without duplicates. Do not add master and child counts. Unknown or stale values leave gaps";
      queries = [ (query "A" roles.series-1 (current "x_ui_online_clients") "{{instance}}") ];
    })
    (row "Resource history" null 26)
    (panel {
      title = "Load";
      x = 0;
      y = 27;
      w = 8;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [ (query "A" roles.series-1 "vpn_load1{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Memory used";
      x = 8;
      y = 27;
      w = 8;
      unit = "percentunit";
      min = 0;
      max = 1;
      shaded = true;
      queries = [ (query "A" roles.series-1 "vpn_memory_used_ratio{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Unit restarts per hour";
      x = 16;
      y = 27;
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
      title = "Connection tracking table used";
      x = 0;
      y = 35;
      w = 12;
      unit = "percentunit";
      min = 0;
      max = 1;
      shaded = true;
      thresholds = maxConntrackUsed;
      queries = [ (query "A" roles.series-1 "vpn_conntrack_used_ratio{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Established sockets without a timer";
      x = 12;
      y = 35;
      w = 12;
      unit = "short";
      min = 0;
      shaded = true;
      thresholds = maxStuckSockets;
      queries = [
        (query "A" roles.series-1 "vpn_established_sockets_without_timer{${node}}" "{{instance}}")
      ];
    })
    (row "Attacks" null 43)
    (panel {
      title = "fail2ban failed attempts per hour";
      x = 0;
      y = 44;
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
      title = "fail2ban bans per hour";
      x = 8;
      y = 44;
      w = 8;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (hourly "vpn_fail2ban_banned_total{${node}}" "instance, jail")
          "{{instance}} {{jail}}"
        )
      ];
    })
    (panel {
      title = "Packets the firewall dropped per hour";
      x = 16;
      y = 44;
      w = 8;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (hourly "vpn_ufw_drops_total{${node}}" "instance") "{{instance}}")
      ];
    })
  ]
  ++ panels.attackers "vpn" node 52
  ++ [
    (table {
      title = "Active bans";
      x = 0;
      y = 60;
      w = 24;
      expr = current "vpn_fail2ban_banned";
      unit = "short";
      labels = [
        "instance"
        "jail"
      ];
      valueName = "Banned";
      sortDesc = true;
      coloured = false;
    })
    (row "Traffic now" null 68)
    (bars {
      title = "Inbounds now, down";
      x = 0;
      y = 69;
      w = 12;
      expr = inbounds ''direction="down"'';
      legend = "{{node}} {{inbound}}";
      unit = "Bps";
    })
    (bars {
      title = "Inbounds now, up";
      x = 12;
      y = 69;
      w = 12;
      expr = inbounds ''direction="up"'';
      legend = "{{node}} {{inbound}}";
      unit = "Bps";
    })
    # One row a node, whichever node of the fleet the master's panel says an inbound runs on
    (row "Inbounds of $vpn_node" "vpn_node" 77)
    (panel {
      title = "Down, by inbound";
      x = 0;
      y = 78;
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
      y = 78;
      w = 12;
      unit = "Bps";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (inbounds ''node=~"$vpn_node", direction="up"'') "{{inbound}}")
      ];
    })

    (row "Clients" null 86)
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
          y = 87;
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
      ]
  ++ [
    (row "Capacity" null 95)
    (panel {
      title = "Disk use in seven days";
      description = "Linear forecast from seven days of measurements the node actually made. The red line marks a full disk, and a gap a history too short to forecast";
      x = 0;
      y = 96;
      w = 24;
      unit = "percentunit";
      thresholds = 1;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (resources.forecast (resources.freshDisk "vpn" node)) "{{instance}}")
      ];
    })
  ];
}
