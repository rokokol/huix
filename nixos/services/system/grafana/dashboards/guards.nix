{
  lib,
  roles,
  panels,
  maxBackupAge,
  minBackupFree,
  maxPushSilence,
  syncthingHosts,
}:

# The dashboard of the watchers: what is open and which watched unit failed, how fresh the
# backups and the pushes of the nodes are, the disks by SMART, zram, btrfs with its scrubs and
# snapshots, and Syncthing. The thresholds are the ones the watchers alert at, in seconds and
# bytes, so a value turns red where its alert fires
let
  inherit (panels)
    query
    panel
    row
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
      w = 10;
      expr = "time() - alert_open_since_seconds";
      unit = "s";
      labels = [
        "host"
        "key"
      ];
    })
    (states {
      title = "Watched units";
      x = 10;
      y = 1;
      w = 14;
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
    (panel {
      title = "Age of the newest backup";
      x = 0;
      y = 10;
      w = 8;
      unit = "s";
      min = 0;
      shaded = true;
      thresholds = maxBackupAge;
      queries = [
        (query "A" roles.series-1 "time() - backup_last_snapshot_timestamp_seconds" "{{repository}}")
      ];
    })
    (panel {
      title = "Free space for backups";
      x = 8;
      y = 10;
      w = 8;
      unit = "bytes";
      min = 0;
      thresholds = minBackupFree;
      dangerBelow = true;
      queries = [ (query "A" roles.series-1 "backup_free_bytes" "free") ];
    })
    (panel {
      title = "Time since the last push of each node";
      x = 16;
      y = 10;
      w = 8;
      unit = "s";
      min = 0;
      shaded = true;
      thresholds = maxPushSilence;
      queries = [
        (query "A" roles.series-1 "time() - max by (instance) (push_time_seconds)" "{{instance}}")
      ];
    })
    (row "Disks" null 18)
    (table {
      title = "SMART health";
      x = 0;
      y = 19;
      w = 6;
      expr = "smartctl_device_smart_status{${host}}";
      unit = "bool_yes_no";
      thresholds = 1;
      dangerBelow = true;
      labels = [
        "host"
        "device"
      ];
    })
    (panel {
      title = "Disk temperature";
      x = 6;
      y = 19;
      w = 6;
      unit = "celsius";
      shaded = true;
      queries = [
        (query "A" roles.series-1 ''smartctl_device_temperature{${host}, temperature_type="current"}''
          "{{host}} {{device}}"
        )
      ];
    })
    (panel {
      title = "Sectors reallocated or pending";
      x = 12;
      y = 19;
      w = 6;
      unit = "short";
      min = 0;
      shaded = true;
      thresholds = 1;
      queries = [
        (query "A" roles.series-1
          ''smartctl_device_attribute{${host}, attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable", attribute_value_type="raw"}''
          "{{host}} {{device}} {{attribute_name}}"
        )
      ];
    })
    (panel {
      title = "Wear and media errors";
      x = 18;
      y = 19;
      w = 6;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 "smartctl_device_percentage_used{${host}}" "{{host}} {{device}} % used")
        (query "B" roles.series-3 "smartctl_device_media_errors{${host}}"
          "{{host}} {{device}} media errors"
        )
      ];
    })

    (row "Memory" null 27)
    (panel {
      title = "zram compression";
      x = 0;
      y = 28;
      w = 8;
      unit = "none";
      min = 1;
      queries = [
        (query "A" roles.series-1
          "sum by (host) (zram_original_bytes{${host}}) / sum by (host) (zram_compressed_bytes{${host}})"
          "{{host}}"
        )
      ];
      shaded = true;
    })
    (panel {
      title = "RAM that zram takes";
      x = 8;
      y = 28;
      w = 8;
      unit = "bytes";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 "sum by (host) (zram_memory_used_bytes{${host}})" "{{host}}")
      ];
    })
    (panel {
      title = "Swap traffic";
      x = 16;
      y = 28;
      w = 8;
      unit = "suffix: pages/s";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1
          "rate(node_vmstat_pswpin{${host}}[$__rate_interval]) + rate(node_vmstat_pswpout{${host}}[$__rate_interval])"
          "{{host}}"
        )
      ];
    })

    (row "btrfs" null 36)
    (panel {
      title = "Time since the last scrub and snapshot run";
      x = 0;
      y = 37;
      w = 12;
      unit = "s";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1
          ''time() - node_systemd_timer_last_trigger_seconds{${host}, name=~"btrfs-scrub@.*|btrbk-.*"}''
          "{{host}} {{name}}"
        )
      ];
    })
    (panel {
      title = "Device errors";
      x = 12;
      y = 37;
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
    (panel {
      title = "Snapshots of each archived folder";
      x = 0;
      y = 45;
      w = 12;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [ (query "A" roles.series-1 "btrbk_snapshots{${host}}" "{{host}} {{folder}}") ];
    })
    # A folder gets a snapshot only when it changed, so an old newest snapshot of a quiet folder
    # is no fault, and the panel has no threshold
    (panel {
      title = "Age of each folder's newest snapshot";
      x = 12;
      y = 45;
      w = 12;
      unit = "s";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 "time() - btrbk_newest_snapshot_timestamp_seconds{${host}}"
          "{{host}} {{folder}}"
        )
      ];
    })

    (row "Syncthing" null 53)
    (states {
      title = "Peers";
      x = 0;
      y = 54;
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
      y = 54;
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
  ];
}
