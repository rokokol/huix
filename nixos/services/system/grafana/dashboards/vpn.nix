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
  inboundMetric = "vpn_inbound_traffic_bytes_total";
  inboundSum = expr: "sum by (node, inbound) (${expr})";
  inbounds = labels: inboundSum ''rate(${inboundMetric}{job="vpn", ${labels}}[${nowWindow}])'';
  inboundCounter = ''${inboundMetric}{job="vpn"}'';
  inboundCurrent = ''${inboundCounter} and on (instance) (time() - push_time_seconds{job="vpn"} < ${toString maxPushSilence})'';
  inboundPeriod = window: ''
    increase(${inboundCounter}[${window}])
    and present_over_time(${inboundCounter}[10m] offset ${window})
    and (${inboundCurrent})
  '';
  inboundColumns = [
    {
      title = "Total";
      expr = inboundCurrent;
    }
    {
      title = "Last 30 days";
      expr = inboundPeriod "30d";
    }
    {
      title = "Last 7 days";
      expr = inboundPeriod "7d";
    }
    {
      title = "Last 24 hours";
      expr = inboundPeriod "1d";
    }
  ];
  inboundFields = [
    "node"
    "inbound"
  ]
  ++ map (column: column.title) inboundColumns;
  inboundTotals = builtins.concatStringsSep " or " (
    map (
      column: ''label_replace(${inboundSum column.expr}, "period", "${column.title}", "inbound", ".*")''
    ) inboundColumns
  );
  inboundTable = table {
    title = "Traffic totals by inbound";
    description = "Upload plus download for each inbound. Total is the panel counter since its last reset. Period estimates use Prometheus samples. No value means there are not enough samples";
    x = 0;
    y = 77;
    w = 24;
    unit = "bytes";
    expr = inboundTotals;
  };

  # The clients with the most traffic, because a panel of every client is unreadable
  topClients = 10;

  hourly = metric: by: "sum by (${by}) (increase(${metric}[1h]))";
  traffic = metric: by: "sum by (${by}) (rate(${metric}[1h]))";
in
panels.dashboard {
  uid = "vpn";
  title = "VPN";
  tags = [
    "service"
    "vpn"
    "network"
  ];
  templating.list = [
    (variable "instance" ''push_time_seconds{job="vpn"}'' "instance")
    (variable "vpn_node" inboundMetric "node")
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
      description = "Time since each VPN node last pushed its metrics";
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
      description = "Whether the VPN node reports that it needs a reboot";
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
          color = roles.danger;
        };
      };
    })
    (stat {
      title = "Disk used";
      description = "Share of disk capacity used, from the latest fresh node report";
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
      description = "Number of package updates reported by each VPN node";
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
      description = "Time since each VPN node last booted";
      x = 18;
      y = 5;
      w = 6;
      unit = "s";
      expr = current "vpn_uptime_seconds";
      legend = "{{instance}}";
    })
    (table {
      title = "Reported problems";
      description = "Problems reported by VPN nodes and their identifiers";
      x = 0;
      y = 9;
      w = 24;
      expr = current "node_problem";
      unit = "none";
      labels = [
        "instance"
        "key"
        "summary"
      ];
      valueName = null;
    })
    (row "VPN state history" null 17)
    (states {
      title = "Xray history";
      description = "Local Xray state reported by each VPN node over time";
      x = 0;
      y = 18;
      w = 8;
      expr = current "x_ui_xray_up";
      legend = "{{instance}}";
      mappings = upDown;
    })
    (states {
      title = "Panel API history";
      description = "Panel API state over time. A stale metrics push counts as down";
      x = 8;
      y = 18;
      w = 8;
      expr = panelUp;
      legend = "{{instance}}";
      mappings = upDown;
    })
    (panel {
      title = "Clients online history";
      description = "Connected clients at each reported sample. Each panel includes its child nodes without duplicates. Do not add master and child counts. Unknown or stale values leave gaps";
      bars = true;
      interval = "15m";
      x = 16;
      y = 18;
      w = 8;
      unit = "short";
      min = 0;
      decimals = 0;
      queries = [ (query "A" (current "x_ui_online_clients") "{{instance}}") ];
    })
    (row "Resource history" null 26)
    (panel {
      title = "Load";
      description = "One-minute system load reported by each VPN node";
      x = 0;
      y = 27;
      w = 8;
      unit = "short";
      min = 0;
      queries = [ (query "A" "vpn_load1{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Memory used";
      description = "Share of memory used on each VPN node";
      x = 8;
      y = 27;
      w = 8;
      unit = "percentunit";
      min = 0;
      max = 1;
      queries = [ (query "A" "vpn_memory_used_ratio{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Unit restarts per hour";
      description = "Service restarts during the hour before each bar";
      bars = true;
      interval = "1h";
      x = 16;
      y = 27;
      w = 8;
      unit = "short";
      min = 0;
      queries = [
        (query "A" (hourly "vpn_unit_restarts_total{${node}}" "instance, unit") "{{instance}} {{unit}}")
      ];
    })
    (panel {
      title = "Connection tracking table used";
      description = "Share of the connection tracking table occupied on each VPN node";
      x = 0;
      y = 35;
      w = 12;
      unit = "percentunit";
      min = 0;
      max = 1;
      thresholds = maxConntrackUsed;
      queries = [ (query "A" "vpn_conntrack_used_ratio{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Established sockets without a timer";
      description = "Established sockets without a timer at each reported sample";
      bars = true;
      interval = "15m";
      x = 12;
      y = 35;
      w = 12;
      unit = "short";
      min = 0;
      thresholds = maxStuckSockets;
      queries = [
        (query "A" "vpn_established_sockets_without_timer{${node}}" "{{instance}}")
      ];
    })
    (row "Attacks" null 43)
    (panel {
      title = "fail2ban failed attempts per hour";
      description = "Failed attempts by jail during the hour before each bar";
      bars = true;
      interval = "1h";
      x = 0;
      y = 44;
      w = 8;
      unit = "short";
      min = 0;
      queries = [
        (query "A" (hourly "vpn_fail2ban_failed_total{${node}}" "instance, jail") "{{instance}} {{jail}}")
      ];
    })
    (panel {
      title = "fail2ban bans per hour";
      description = "Bans by jail during the hour before each bar";
      bars = true;
      interval = "1h";
      x = 8;
      y = 44;
      w = 8;
      unit = "short";
      min = 0;
      queries = [
        (query "A" (hourly "vpn_fail2ban_banned_total{${node}}" "instance, jail") "{{instance}} {{jail}}")
      ];
    })
    (panel {
      title = "Packets the firewall dropped per hour";
      description = "Packets dropped during the hour before each bar";
      bars = true;
      interval = "1h";
      x = 16;
      y = 44;
      w = 8;
      unit = "short";
      min = 0;
      queries = [
        (query "A" (hourly "vpn_ufw_drops_total{${node}}" "instance") "{{instance}}")
      ];
    })
  ]
  ++ panels.attackers "vpn" node 52
  ++ [
    (table {
      title = "Active bans";
      description = "Currently banned addresses by VPN node and fail2ban jail";
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
      description = "Recent download throughput by node and inbound";
      x = 0;
      y = 69;
      w = 12;
      expr = inbounds ''direction="down"'';
      legend = "{{node}} {{inbound}}";
      unit = "Bps";
    })
    (bars {
      title = "Inbounds now, up";
      description = "Recent upload throughput by node and inbound";
      x = 12;
      y = 69;
      w = 12;
      expr = inbounds ''direction="up"'';
      legend = "{{node}} {{inbound}}";
      unit = "Bps";
    })
    (
      inboundTable
      // {
        targets = map (target: target // { format = "time_series"; }) inboundTable.targets;
        fieldConfig = inboundTable.fieldConfig // {
          defaults = inboundTable.fieldConfig.defaults // {
            unit = "bytes";
          };
        };
        transformations = [
          {
            id = "labelsToFields";
            options.valueLabel = "period";
          }
          {
            id = "merge";
            options = { };
          }
          {
            id = "organize";
            options = {
              excludeByName.Time = true;
              indexByName = builtins.listToAttrs (
                builtins.genList (index: {
                  name = builtins.elemAt inboundFields index;
                  value = index;
                }) (builtins.length inboundFields)
              );
              renameByName = {
                node = "Node";
                inbound = "Inbound";
              };
            };
          }
        ];
      }
    )
    # One row a node, whichever node of the fleet the master's panel says an inbound runs on
    (row "Inbounds of $vpn_node" "vpn_node" 85)
    (panel {
      title = "Down, by inbound";
      description = "Recent download throughput by inbound on the selected node";
      x = 0;
      y = 86;
      w = 12;
      unit = "Bps";
      min = 0;
      queries = [
        (query "A" (inbounds ''node=~"$vpn_node", direction="down"'') "{{inbound}}")
      ];
    })
    (panel {
      title = "Up, by inbound";
      description = "Recent upload throughput by inbound on the selected node";
      x = 12;
      y = 86;
      w = 12;
      unit = "Bps";
      min = 0;
      queries = [
        (query "A" (inbounds ''node=~"$vpn_node", direction="up"'') "{{inbound}}")
      ];
    })

    (row "Clients" null 94)
  ]
  # Both panels show the same clients, the busiest by up and down together, so a client does not
  # drop out of one panel while it stays in the other
  ++
    map
      (
        side:
        panel {
          title = "${side.title}, the ${toString topClients} busiest clients";
          description = "Hourly throughput for clients selected by their combined upload and download traffic";
          inherit (side) x;
          y = 95;
          w = 12;
          unit = "Bps";
          min = 0;
          queries = [
            (query "A"
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
    (row "Capacity" null 103)
    (stat {
      title = "Estimated disk use in seven days";
      description = "Estimate from exponentially weighted daily slopes. Missing history gives no estimate. Alerts use a separate linear forecast";
      x = 0;
      y = 104;
      w = 24;
      h = 8;
      unit = "percentunit";
      thresholds = 1;
      expr = resources.visualForecast (resources.freshDisk "vpn" node);
      legend = "{{instance}}";
    })
  ];
}
