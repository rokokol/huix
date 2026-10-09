{
  lib,
  roles,
  criticalTemperature,
  datasource,
}:

# The dashboard of the hosts, as Grafana's JSON model: a row of each host with its CPU, memory,
# swap traffic, CPU temperature and disks, and a row of each host that has a GPU. Every colour is
# a role of ddlc-themes, and the temperature turns to danger where waybar does. Grafana keeps one
# colour per series whatever its theme, so the colours are the dark roles and the UI is dark too
let
  ds = {
    type = "prometheus";
    uid = datasource;
  };

  fixed = color: {
    mode = "fixed";
    fixedColor = color;
  };

  # One series of a query; its colour stays fixed, so a host looks the same on every visit
  query = refId: color: expr: legend: {
    target = {
      inherit refId expr;
      datasource = ds;
      legendFormat = legend;
    };
    override = {
      matcher = {
        id = "byFrameRefID";
        options = refId;
      };
      properties = [
        {
          id = "color";
          value = fixed color;
        }
      ];
    };
  };

  panel =
    {
      title,
      x,
      y,
      w,
      unit,
      queries,
      min ? null,
      max ? null,
      # A query of several series takes shades of its colour instead of one fixed colour
      shaded ? false,
      thresholds ? null,
    }:
    {
      type = "timeseries";
      inherit title;
      datasource = ds;
      gridPos = {
        inherit x y w;
        h = 8;
      };
      targets = map (q: q.target) queries;
      fieldConfig = {
        defaults = {
          inherit unit;
          color =
            if shaded then
              {
                mode = "shades";
                fixedColor = roles.series-1;
              }
            else
              fixed roles.series-1;
          custom = {
            lineWidth = 2;
            fillOpacity = 10;
            spanNulls = false;
            thresholdsStyle.mode = if thresholds == null then "off" else "dashed";
          };
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = roles.ok;
                value = null;
              }
            ]
            ++ lib.optional (thresholds != null) {
              color = roles.danger;
              value = thresholds;
            };
          };
        }
        // lib.optionalAttrs (min != null) { inherit min; }
        // lib.optionalAttrs (max != null) { inherit max; };
        overrides = lib.optionals (!shaded) (map (q: q.override) queries);
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
        tooltip.mode = "multi";
      };
    };

  row = title: repeat: y: {
    type = "row";
    inherit title repeat;
    collapsed = false;
    gridPos = {
      inherit y;
      x = 0;
      w = 24;
      h = 1;
    };
    panels = [ ];
  };

  on = selector: ''host="''$${selector}"'';
  host = on "host";
  gpu = on "gpu_host";

  # The CPU's chips, by driver: k10temp on AMD, coretemp on Intel. Their highest sensor stands
  # for the CPU, since one host labels a package sensor and another only its cores
  cpuTemperature = ''
    max by (host) (
      node_hwmon_temp_celsius{${host}}
      * on (host, chip) group_left ()
      node_hwmon_chip_names{${host}, chip_name=~"coretemp|k10temp"}
    )'';

  # Disk file systems once each: btrfs mounts one volume at several points
  disks = metric: ''max by (host, device) (${metric}{${host}, fstype=~"btrfs|ext4|xfs|vfat"})'';

  variable = name: job: {
    inherit name;
    type = "query";
    datasource = ds;
    query = {
      query = "label_values(up{job=\"${job}\"}, host)";
      refId = name;
    };
    definition = "label_values(up{job=\"${job}\"}, host)";
    refresh = 2;
    multi = true;
    includeAll = true;
    current = {
      text = [ "All" ];
      value = [ "$__all" ];
    };
    sort = 1;
  };
in
{
  uid = "hosts";
  title = "Hosts";
  editable = false;
  schemaVersion = 39;
  time = {
    from = "now-24h";
    to = "now";
  };
  refresh = "30s";
  templating.list = [
    (variable "host" "node")
    # The hosts with a GPU; their rows follow the hosts row, and the selector stays hidden
    ((variable "gpu_host" "nvidia-gpu") // { hide = 2; })
  ];
  panels = [
    (row "$host" "host" 0)
    (panel {
      title = "CPU";
      x = 0;
      y = 1;
      w = 8;
      unit = "percent";
      min = 0;
      max = 100;
      queries = [
        (query "A" roles.series-1
          "100 * (1 - avg by (host) (rate(node_cpu_seconds_total{${host}, mode=\"idle\"}[$__rate_interval])))"
          "load"
        )
      ];
    })
    (panel {
      title = "Memory";
      x = 8;
      y = 1;
      w = 8;
      unit = "bytes";
      min = 0;
      queries = [
        (query "A" roles.series-1
          "node_memory_MemTotal_bytes{${host}} - node_memory_MemAvailable_bytes{${host}}"
          "RAM used"
        )
        (query "B" roles.series-2
          "node_memory_SwapTotal_bytes{${host}} - node_memory_SwapFree_bytes{${host}}"
          "swap used"
        )
        # Swap counts zram's pages at their full size; this is the RAM they take
        (query "C" roles.series-3 "sum by (host) (zram_memory_used_bytes{${host}})" "RAM of zram")
      ];
    })
    (panel {
      title = "Swap traffic";
      x = 16;
      y = 1;
      w = 8;
      unit = "suffix: pages/s";
      min = 0;
      queries = [
        (query "A" roles.series-1 "rate(node_vmstat_pswpin{${host}}[$__rate_interval])" "in")
        (query "B" roles.series-2 "rate(node_vmstat_pswpout{${host}}[$__rate_interval])" "out")
      ];
    })
    (panel {
      title = "CPU temperature";
      x = 0;
      y = 9;
      w = 12;
      unit = "celsius";
      thresholds = criticalTemperature;
      queries = [ (query "A" roles.series-1 cpuTemperature "CPU") ];
    })
    (panel {
      title = "Disks";
      x = 12;
      y = 9;
      w = 12;
      unit = "percent";
      min = 0;
      max = 100;
      shaded = true;
      queries = [
        (query "A" roles.series-1
          "100 * (1 - ${disks "node_filesystem_avail_bytes"} / ${disks "node_filesystem_size_bytes"})"
          "{{device}}"
        )
      ];
    })
    (row "GPU of $gpu_host" "gpu_host" 17)
    (panel {
      title = "GPU load";
      x = 0;
      y = 18;
      w = 8;
      unit = "percentunit";
      min = 0;
      max = 1;
      queries = [ (query "A" roles.series-1 "nvidia_smi_utilization_gpu_ratio{${gpu}}" "load") ];
    })
    (panel {
      title = "GPU memory";
      x = 8;
      y = 18;
      w = 8;
      unit = "bytes";
      min = 0;
      queries = [
        (query "A" roles.series-1 "nvidia_smi_memory_used_bytes{${gpu}}" "used")
        (query "B" roles.series-3 "nvidia_smi_memory_total_bytes{${gpu}}" "total")
      ];
    })
    (panel {
      title = "GPU temperature and power";
      x = 16;
      y = 18;
      w = 8;
      unit = "short";
      min = 0;
      queries = [
        (query "A" roles.series-1 "nvidia_smi_temperature_gpu{${gpu}}" "°C")
        (query "B" roles.series-2 "nvidia_smi_power_draw_watts{${gpu}}" "W")
      ];
    })
  ];
}
