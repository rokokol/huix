{
  roles,
  panels,
  resources,
}:

# A separate GPU row keeps its charts off hosts that do not run the exporter
let
  inherit (panels)
    query
    panel
    row
    stat
    table
    variable
    ;

  on = selector: ''host="''$${selector}"'';
  host = on "host";
  gpu = on "gpu_host";

  cpuLoad = ''100 * (1 - avg by (host) (rate(node_cpu_seconds_total{${host}, mode="idle"}[$__rate_interval])))'';
  memoryUsed = "node_memory_MemTotal_bytes{${host}} - node_memory_MemAvailable_bytes{${host}}";
in
panels.dashboard {
  uid = "hosts";
  title = "Hosts";
  templating.list = [
    (variable "host" ''up{job="node"}'' "host")
    # The hosts with a GPU; their rows follow the hosts row, and the selector stays hidden
    ((variable "gpu_host" ''up{job="nvidia-gpu"}'' "host") // { hide = 2; })
  ];
  panels = [
    (row "$host" "host" 0)
    (stat {
      title = "Node exporter";
      x = 0;
      y = 1;
      w = 6;
      unit = "none";
      expr = ''up{job="node", ${host}}'';
      mappings = {
        "0" = {
          text = "Down";
          color = roles.danger;
        };
        "1" = {
          text = "Up";
          color = roles.ok;
        };
      };
    })
    (stat {
      title = "CPU now";
      x = 6;
      y = 1;
      w = 6;
      unit = "percent";
      expr = cpuLoad;
      decimals = 1;
    })
    (stat {
      title = "RAM used now";
      x = 12;
      y = 1;
      w = 6;
      unit = "percentunit";
      expr = "(${memoryUsed}) / node_memory_MemTotal_bytes{${host}}";
      decimals = 1;
    })
    (stat {
      title = "CPU temperature now";
      x = 18;
      y = 1;
      w = 6;
      unit = "celsius";
      expr = resources.cpuTemperature host;
      thresholds = resources.limits.cpuTemperature;
    })
    (table {
      title = "Disks";
      x = 0;
      y = 5;
      w = 12;
      unit = "percentunit";
      expr = resources.diskUsed host;
      thresholds = resources.limits.diskUsed;
      labels = [ "device" ];
      valueName = "Used";
      sortDesc = true;
    })
    (panel {
      title = "Disk use in seven days";
      description = "Linear forecast from the last seven days. The red line marks a full disk, and a gap a history too short to forecast";
      x = 12;
      y = 5;
      w = 12;
      unit = "percentunit";
      thresholds = 1;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (resources.forecast (resources.diskUsed host)) "{{device}}")
      ];
    })
    (panel {
      title = "CPU";
      x = 0;
      y = 13;
      w = 12;
      unit = "percent";
      min = 0;
      max = 100;
      queries = [
        (query "A" roles.series-1 cpuLoad "load")
      ];
    })
    (panel {
      title = "CPU temperature";
      x = 12;
      y = 13;
      w = 12;
      unit = "celsius";
      thresholds = resources.limits.cpuTemperature;
      queries = [ (query "A" roles.series-1 (resources.cpuTemperature host) "CPU") ];
    })
    (panel {
      title = "Memory";
      x = 0;
      y = 21;
      w = 12;
      unit = "bytes";
      min = 0;
      queries = [
        (query "A" roles.series-1 memoryUsed "RAM used")
        (query "B" roles.series-3
          "node_memory_SwapTotal_bytes{${host}} - node_memory_SwapFree_bytes{${host}}"
          "swap used"
        )
      ];
    })
    (panel {
      title = "Swap traffic";
      x = 12;
      y = 21;
      w = 12;
      unit = "suffix: pages/s";
      min = 0;
      queries = [
        (query "A" roles.series-1 "rate(node_vmstat_pswpin{${host}}[$__rate_interval])" "in")
        (query "B" roles.series-3 "rate(node_vmstat_pswpout{${host}}[$__rate_interval])" "out")
      ];
    })
    (row "GPU of $gpu_host" "gpu_host" 29)
    (panel {
      title = "GPU load";
      x = 0;
      y = 30;
      w = 12;
      unit = "percentunit";
      min = 0;
      max = 1;
      queries = [ (query "A" roles.series-1 "nvidia_smi_utilization_gpu_ratio{${gpu}}" "load") ];
    })
    (stat {
      title = "GPU memory used now";
      x = 12;
      y = 30;
      w = 12;
      h = 8;
      unit = "percentunit";
      expr = "nvidia_smi_memory_used_bytes{${gpu}} / nvidia_smi_memory_total_bytes{${gpu}}";
      decimals = 1;
    })
    (panel {
      title = "GPU temperature";
      x = 0;
      y = 38;
      w = 12;
      unit = "celsius";
      queries = [ (query "A" roles.series-1 "nvidia_smi_temperature_gpu{${gpu}}" "") ];
    })
    (panel {
      title = "GPU power";
      x = 12;
      y = 38;
      w = 12;
      unit = "watt";
      min = 0;
      queries = [ (query "A" roles.series-1 "nvidia_smi_power_draw_watts{${gpu}}" "") ];
    })
  ];
}
