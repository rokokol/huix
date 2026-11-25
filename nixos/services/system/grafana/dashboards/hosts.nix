{
  lib,
  roles,
  panels,
  resources,
}:
{
  hostName,
  withGpu ? false,
  withInfrastructure ? false,
  maxBackupAge ? null,
  minBackupFree ? null,
  syncthingHosts ? [ ],
}:

let
  inherit (panels)
    diskForecastStat
    panel
    query
    row
    stat
    states
    table
    ;

  host = ''host="${hostName}"'';
  gpu = host;
  serviceHost = ''host="${hostName}", name=~".*\\.service"'';
  failedUnitState = ''node_systemd_unit_state{${serviceHost}, state="failed"}'';
  failedUnits = "${failedUnitState} == 1";
  failedInRange = "max_over_time(${failedUnitState}[$__range] @ end()) > 0";
  noFailuresState = "3";
  unitStates = ''
    max by (host, name) (${failedUnitState}) * 2
    + max by (host, name) (node_systemd_unit_state{${serviceHost}, state="active"})'';
  peers = ''
    (
      syncthing_connections_active
      or on (device) (0 * syncthing_config_device_info)
    )
    * on (device) group_left (name) syncthing_config_device_info{name!~"${lib.concatStringsSep "|" syncthingHosts}"}'';
  folders = metric: "${metric} * on (folder) group_left (label) syncthing_config_folder_info";
  memoryUsed = "node_memory_MemTotal_bytes{${host}} - node_memory_MemAvailable_bytes{${host}}";
  cpuLoad = ''100 * (1 - avg by (host) (rate(node_cpu_seconds_total{${host}, mode="idle"}[$__rate_interval])))'';
  infrastructurePanels = lib.optionals withInfrastructure [
    (row "Backups and nodes" null 71)
    (table {
      title = "Age of the newest backup";
      description = "Time since the newest snapshot in each backup repository";
      x = 0;
      y = 72;
      w = 12;
      expr = "time() - backup_last_snapshot_timestamp_seconds";
      unit = "s";
      thresholds = maxBackupAge;
      labels = [ "repository" ];
      valueName = "Age";
      sortDesc = true;
    })
    (stat {
      title = "Free space for backups";
      description = "Free space on the volume that stores backups";
      x = 12;
      y = 72;
      w = 12;
      h = 8;
      expr = "backup_free_bytes";
      unit = "bytes";
      thresholds = minBackupFree;
      dangerBelow = true;
    })
    (row "Syncthing" null 80)
    (states {
      title = "Peers";
      description = "Connection state of each configured Syncthing peer over the selected range";
      x = 0;
      y = 81;
      w = 12;
      expr = "clamp_max(${peers}, 1)";
      legend = "{{host}} {{name}}";
      mappings = {
        "0" = {
          text = "disconnected";
          color = roles.danger;
        };
        "1" = {
          text = "connected";
          color = roles.ok;
        };
      };
    })
    (panel {
      title = "What each folder still needs";
      description = "Bytes each Syncthing folder still needs to download";
      x = 12;
      y = 81;
      w = 12;
      unit = "bytes";
      min = 0;
      queries = [
        (query "A" (folders ''syncthing_model_folder_summary{scope="need", type="bytes"}'')
          "{{host}} {{label}}"
        )
      ];
    })
    (table {
      title = "Snapshots of each archived folder";
      description = "Number of btrbk snapshots retained for each archived folder";
      x = 0;
      y = 89;
      w = 12;
      expr = "btrbk_snapshots{${host}}";
      unit = "short";
      labels = [
        "host"
        "folder"
      ];
      valueName = "Snapshots";
      coloured = false;
    })
    (table {
      title = "Age of each folder's newest snapshot";
      x = 12;
      y = 89;
      w = 12;
      expr = "time() - btrbk_newest_snapshot_timestamp_seconds{${host}}";
      unit = "s";
      labels = [
        "host"
        "folder"
      ];
      valueName = "Age";
      coloured = false;
      description = "A folder gets a snapshot only when it changes. An old snapshot of a quiet folder is not a fault";
    })
  ];
in
panels.dashboard {
  uid = hostName;
  title = hostName;
  tags = [
    "host"
    hostName
  ]
  ++ lib.optionals withInfrastructure [
    "server"
    "storage"
    "monitoring"
    "ai"
  ]
  ++ lib.optional (!withInfrastructure) "workstation"
  ++ lib.optional withGpu "gpu";
  panels = [
    (row hostName null 0)
    (stat {
      title = "Node exporter";
      description = "Whether Prometheus can scrape the host's node exporter";
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
      description = "Share of CPU time spent outside the idle state";
      x = 6;
      y = 1;
      w = 6;
      unit = "percent";
      expr = cpuLoad;
      thresholds = resources.limits.cpuUsed * 100;
      decimals = 1;
    })
    (stat {
      title = "RAM used now";
      description = "Share of RAM not available for applications";
      x = 12;
      y = 1;
      w = 6;
      unit = "percentunit";
      expr = "(${memoryUsed}) / node_memory_MemTotal_bytes{${host}}";
      thresholds = resources.limits.memoryUsed;
      decimals = 1;
    })
    (stat {
      title = "CPU temperature now";
      description = "Highest reported CPU temperature from supported hardware sensors";
      x = 18;
      y = 1;
      w = 6;
      unit = "celsius";
      expr = resources.cpuTemperature host;
      thresholds = resources.limits.cpuTemperature;
    })
    (table {
      title = "Disk use now";
      description = "Current used share of each device, for the latest sample";
      x = 0;
      y = 5;
      w = 6;
      unit = "percentunit";
      expr = resources.diskUsed host;
      thresholds = resources.limits.diskUsed;
      labels = [ "device" ];
      valueName = "Used";
      sortDesc = true;
    })
    (panel {
      title = "Disks";
      description = "Each bar shows the highest used share among writable filesystems on a device at that time";
      x = 6;
      y = 5;
      w = 12;
      unit = "percentunit";
      min = 0;
      max = 1;
      bars = true;
      interval = "15m";
      thresholds = resources.limits.diskUsed;
      queries = [ (query "A" (resources.diskUsed host) "{{device}}") ];
    })
    (diskForecastStat {
      x = 18;
      y = 5;
      w = 6;
      h = 8;
      thresholds = resources.limits.forecastFull;
      expr = resources.forecast (resources.diskUsed host);
      legend = "{{device}}";
    })
    (panel {
      title = "CPU";
      description = "Share of CPU time spent outside the idle state over time";
      x = 0;
      y = 13;
      w = 12;
      unit = "percent";
      min = 0;
      max = 100;
      thresholds = resources.limits.cpuUsed * 100;
      queries = [ (query "A" cpuLoad "load") ];
    })
    (panel {
      title = "CPU temperature";
      description = "Highest reported CPU temperature from supported hardware sensors";
      x = 12;
      y = 13;
      w = 12;
      unit = "celsius";
      thresholds = resources.limits.cpuTemperature;
      queries = [ (query "A" (resources.cpuTemperature host) "CPU") ];
    })
    (panel {
      title = "Memory";
      description = "RAM unavailable to applications and swap space in use";
      x = 0;
      y = 21;
      w = 12;
      unit = "bytes";
      min = 0;
      queries = [
        (query "A" memoryUsed "RAM used")
        (query "B" "node_memory_SwapTotal_bytes{${host}} - node_memory_SwapFree_bytes{${host}}" "swap used")
      ];
    })
    (panel {
      title = "Swap traffic";
      description = "Memory pages read from and written to swap per second";
      x = 12;
      y = 21;
      w = 12;
      unit = "suffix: pages/s";
      min = 0;
      queries = [
        (query "A" "rate(node_vmstat_pswpin{${host}}[$__rate_interval])" "in")
        (query "B" "rate(node_vmstat_pswpout{${host}}[$__rate_interval])" "out")
      ];
    })
    (row "Services" null 29)
    (table {
      title = "Failed units";
      description = "Systemd services currently in the failed state";
      x = 0;
      y = 30;
      w = 8;
      expr = failedUnits;
      unit = "bool_on_off";
      thresholds = 1;
      labels = [ "name" ];
      valueName = "Failed";
    })
    (states {
      title = "Unit state history";
      description = "State history for services that failed in the selected range. When none failed, the summary marks periods with systemd samples";
      x = 8;
      y = 30;
      w = 16;
      expr = ''
        ((${unitStates}) and on (host, name) (${failedInRange}))
        or label_replace(
          (max by (host) (${failedUnitState}) == 0) + ${noFailuresState}
          unless on (host) (${failedInRange}),
          "name", "Observed services", "__name__", ".*"
        )
      '';
      legend = "{{name}}";
      mappings = {
        "0" = {
          text = "inactive";
          color = roles.muted;
        };
        "1" = {
          text = "active";
          color = roles.ok;
        };
        "2" = {
          text = "failed";
          color = roles.danger;
        };
        ${noFailuresState} = {
          text = "no failures observed";
          color = roles.ok;
        };
      };
    })
    (row "Disk health" null 38)
    (table {
      title = "SMART health";
      description = "SMART health result reported by each disk";
      x = 0;
      y = 39;
      w = 8;
      expr = "smartctl_device_smart_status{${host}}";
      unit = "bool_yes_no";
      valueName = "passed";
      thresholds = 1;
      dangerBelow = true;
      labels = [ "device" ];
    })
    (panel {
      title = "Disk temperature";
      description = "Current temperature reported by each SMART device";
      thresholds = resources.limits.diskTemperature;
      x = 8;
      y = 39;
      w = 16;
      unit = "celsius";
      queries = [
        (query "A" (resources.diskTemperature host) "{{device}}")
      ];
    })
    (table {
      title = "Sectors reallocated, pending or uncorrectable";
      description = "Raw SMART sector counts by device and attribute";
      x = 0;
      y = 47;
      w = 12;
      expr = ''smartctl_device_attribute{${host}, attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable", attribute_value_type="raw"}'';
      unit = "short";
      thresholds = 1;
      labels = [
        "device"
        "attribute_name"
      ];
      valueName = "Sectors";
      sortDesc = true;
    })
    (table {
      title = "NVMe wear";
      description = "Percentage of estimated NVMe endurance used, as reported by the device";
      x = 12;
      y = 47;
      w = 6;
      expr = "smartctl_device_percentage_used{${host}}";
      unit = "percent";
      labels = [ "device" ];
      valueName = "Used";
      coloured = false;
      sortDesc = true;
    })
    (table {
      title = "NVMe media errors";
      description = "Cumulative media and data integrity errors reported by each NVMe device";
      x = 18;
      y = 47;
      w = 6;
      expr = "smartctl_device_media_errors{${host}}";
      unit = "short";
      labels = [ "device" ];
      valueName = "Errors";
      coloured = false;
      sortDesc = true;
    })
    (row "Btrfs" null 55)
    (table {
      title = "Time since the last scrub and snapshot run";
      description = "Time since each Btrfs scrub or btrbk timer last triggered";
      x = 0;
      y = 56;
      w = 12;
      expr = ''time() - node_systemd_timer_last_trigger_seconds{${host}, name=~"btrfs-scrub@.*|btrbk-.*"}'';
      unit = "s";
      labels = [ "name" ];
      valueName = "Age";
      coloured = false;
      sortDesc = true;
    })
    (panel {
      title = "Btrfs device errors";
      description = "Cumulative Btrfs device errors by device and error type";
      x = 12;
      y = 56;
      w = 12;
      unit = "short";
      min = 0;
      thresholds = 1;
      bars = true;
      interval = "1d";
      queries = [
        (query "A" "sum by (device, type) (node_btrfs_device_errors_total{${host}})" "{{device}} {{type}}")
      ];
    })
    (row "Memory compression" null 64)
    (stat {
      title = "RAM that zram takes";
      description = "Physical memory occupied by compressed zram data and its overhead";
      x = 0;
      y = 65;
      w = 12;
      unit = "bytes";
      expr = "sum by (host) (zram_memory_used_bytes{${host}})";
      legend = "";
    })
    (stat {
      title = "zram compression";
      description = "Original zram data size divided by its compressed size";
      x = 12;
      y = 65;
      w = 12;
      unit = "suffix:×";
      expr = "sum by (host) (zram_original_bytes{${host}}) / (sum by (host) (zram_compressed_bytes{${host}}) > 0)";
      decimals = 1;
    })
    (row "Reported problems" null 73)
    (table {
      title = "Open problems";
      description = "Time since each reported problem opened. The station includes all reported hosts";
      x = 0;
      y = 74;
      w = 24;
      expr =
        if withInfrastructure then
          "time() - alert_open_since_seconds"
        else
          "time() - alert_open_since_seconds{${host}}";
      unit = "s";
      valueName = "Open for";
      thresholds = 0;
      labels = [
        "host"
        "key"
      ];
    })
  ]
  ++ map (
    item:
    item
    // {
      gridPos = item.gridPos // {
        y = item.gridPos.y + 12;
      };
    }
  ) infrastructurePanels
  ++ lib.optionals withGpu [
    (row "GPU" null 83)
    (panel {
      title = "GPU load";
      description = "Share of time the GPU reports work in progress";
      x = 0;
      y = 84;
      w = 12;
      unit = "percentunit";
      min = 0;
      max = 1;
      queries = [ (query "A" "nvidia_smi_utilization_gpu_ratio{${gpu}}" "load") ];
    })
    (panel {
      title = "GPU memory used";
      description = "Share of GPU memory in use over the selected time range";
      x = 12;
      y = 84;
      w = 12;
      unit = "percentunit";
      min = 0;
      max = 1;
      decimals = 1;
      queries = [
        (query "A" "nvidia_smi_memory_used_bytes{${gpu}} / nvidia_smi_memory_total_bytes{${gpu}}"
          "{{uuid}}"
        )
      ];
    })
    (panel {
      title = "GPU temperature";
      description = "Temperature reported by the GPU";
      x = 0;
      y = 92;
      w = 12;
      unit = "celsius";
      queries = [ (query "A" "nvidia_smi_temperature_gpu{${gpu}}" "") ];
    })
    (panel {
      title = "GPU power";
      description = "Power draw reported by the GPU";
      x = 12;
      y = 92;
      w = 12;
      unit = "watt";
      min = 0;
      queries = [ (query "A" "nvidia_smi_power_draw_watts{${gpu}}" "") ];
    })
  ];
}
