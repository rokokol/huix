{
  lib,
  roles,
  panels,
  maxBackupAge,
  minBackupFree,
  maxPushSilence,
  syncthingHosts,
  resources,
}:

# The panels use the limits of the monitors so their warnings agree
let
  inherit (panels)
    query
    panel
    row
    stat
    states
    table
    variable
    ;

  host = ''host=~"$host"'';

  # A failed unit is 2, an active one 1, any other state 0
  unitStates = ''
    max by (host, name) (node_systemd_unit_state{${host}, name=~".*\\.service", state="failed"}) * 2
    + max by (host, name) (node_systemd_unit_state{${host}, name=~".*\\.service", state="active"})'';

  # The name of each device beside its ID, and each device of the configuration even while it
  # is not connected. A device of a host that runs the Syncthing scraped here is that host
  # itself, which has no connection to itself
  peers = ''
    (
      syncthing_connections_active
      or on (device) (0 * syncthing_config_device_info)
    )
    * on (device) group_left (name) syncthing_config_device_info{name!~"${lib.concatStringsSep "|" syncthingHosts}"}'';

  folders = metric: "${metric} * on (folder) group_left (label) syncthing_config_folder_info";
in
panels.dashboard {
  uid = "guards";
  title = "Guards";
  templating.list = [ (variable "host" ''up{job="node"}'' "host") ];
  panels = [
    (row "Problems" null 0)
    (table {
      title = "Open problems";
      x = 0;
      y = 1;
      w = 12;
      expr = "time() - alert_open_since_seconds";
      unit = "s";
      valueName = "open for";
      # Every open problem is one to look at, however young
      thresholds = 0;
      labels = [
        "host"
        "key"
      ];
    })
    (states {
      title = "Watched units";
      x = 12;
      y = 1;
      w = 12;
      expr = unitStates;
      legend = "{{host}} {{name}}";
      mappings = {
        "0" = {
          text = "inactive";
          color = roles.series-3;
        };
        "1" = {
          text = "active";
          color = roles.ok;
        };
        "2" = {
          text = "failed";
          color = roles.danger;
        };
      };
    })
    (row "Backups and nodes" null 9)
    (table {
      title = "Age of the newest backup";
      x = 0;
      y = 10;
      w = 9;
      expr = "time() - backup_last_snapshot_timestamp_seconds";
      unit = "s";
      thresholds = maxBackupAge;
      labels = [ "repository" ];
      valueName = "Age";
      sortDesc = true;
    })
    (stat {
      title = "Free space for backups";
      x = 9;
      y = 10;
      w = 6;
      h = 8;
      expr = "backup_free_bytes";
      unit = "bytes";
      thresholds = minBackupFree;
      dangerBelow = true;
    })
    (table {
      title = "Time since the last push";
      x = 15;
      y = 10;
      w = 9;
      expr = "time() - push_time_seconds";
      unit = "s";
      thresholds = maxPushSilence;
      labels = [
        "job"
        "instance"
      ];
      valueName = "Age";
      sortDesc = true;
    })
    (row "Disks" null 18)
    (table {
      title = "SMART health";
      x = 0;
      y = 19;
      w = 8;
      expr = "smartctl_device_smart_status{${host}}";
      unit = "bool_yes_no";
      valueName = "passed";
      thresholds = 1;
      dangerBelow = true;
      labels = [
        "host"
        "device"
      ];
    })
    (panel {
      title = "Disk temperature";
      thresholds = resources.limits.diskTemperature;
      x = 8;
      y = 19;
      w = 16;
      unit = "celsius";
      shaded = true;
      queries = [
        (query "A" roles.series-1 (resources.diskTemperature host) "{{host}} {{device}}")
      ];
    })
    (table {
      title = "Sectors reallocated, pending or uncorrectable";
      x = 0;
      y = 27;
      w = 12;
      expr = ''smartctl_device_attribute{${host}, attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable", attribute_value_type="raw"}'';
      unit = "short";
      thresholds = 1;
      labels = [
        "host"
        "device"
        "attribute_name"
      ];
      valueName = "Sectors";
      sortDesc = true;
    })
    (table {
      title = "NVMe wear";
      x = 12;
      y = 27;
      w = 6;
      expr = "smartctl_device_percentage_used{${host}}";
      unit = "percent";
      labels = [
        "host"
        "device"
      ];
      valueName = "Used";
      coloured = false;
      sortDesc = true;
    })
    (table {
      title = "NVMe media errors";
      x = 18;
      y = 27;
      w = 6;
      expr = "smartctl_device_media_errors{${host}}";
      unit = "short";
      labels = [
        "host"
        "device"
      ];
      valueName = "Errors";
      coloured = false;
      sortDesc = true;
    })
    (row "btrfs" null 35)
    (table {
      title = "Time since the last scrub and snapshot run";
      x = 0;
      y = 36;
      w = 12;
      expr = ''time() - node_systemd_timer_last_trigger_seconds{${host}, name=~"btrfs-scrub@.*|btrbk-.*"}'';
      unit = "s";
      labels = [
        "host"
        "name"
      ];
      valueName = "Age";
      coloured = false;
      sortDesc = true;
    })
    (panel {
      title = "Device errors";
      x = 12;
      y = 36;
      w = 12;
      unit = "short";
      min = 0;
      shaded = true;
      thresholds = 1;
      queries = [
        (query "A" roles.series-1 "sum by (host, device, type) (node_btrfs_device_errors_total{${host}})"
          "{{host}} {{device}} {{type}}"
        )
      ];
    })
    (table {
      title = "Snapshots of each archived folder";
      x = 0;
      y = 44;
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
      y = 44;
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
    (row "Syncthing" null 52)
    (states {
      title = "Peers";
      x = 0;
      y = 53;
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
      x = 12;
      y = 53;
      w = 12;
      unit = "bytes";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (folders ''syncthing_model_folder_summary{scope="need", type="bytes"}'')
          "{{host}} {{label}}"
        )
      ];
    })
    (row "Memory" null 61)
    (stat {
      title = "RAM that zram takes";
      x = 0;
      y = 62;
      w = 12;
      unit = "bytes";
      expr = "sum by (host) (zram_memory_used_bytes{${host}})";
      legend = "{{host}}";
    })
    (stat {
      title = "zram compression";
      x = 12;
      y = 62;
      w = 12;
      unit = "suffix:×";
      expr = "sum by (host) (zram_original_bytes{${host}}) / (sum by (host) (zram_compressed_bytes{${host}}) > 0)";
      legend = "{{host}}";
      decimals = 1;
    })
  ];
}
