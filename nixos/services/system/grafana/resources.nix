{
  lib,
  criticalTemperature,
  stationHost,
  maxPushSilence,
}:

# The thresholds, the queries and the rules of the resource alerts, in one place: a panel turns
# red at the value a rule alerts at, and a check proves each rule fires where it should. The
# station is the host of this Grafana, so its own metrics need no push and no freshness guard;
# the nodes behind the Pushgateway report their disk themselves at their own ratio, so Grafana
# adds only the forecast there, and guards it against a group that stopped being pushed
let
  limits = {
    cpuTemperature = criticalTemperature;
    diskTemperature = 55;
    diskUsed = 0.9;
    forecastSeconds = 7 * 24 * 3600;
    history = "7d";
    forecastHold = "1h";
    diskHold = "30m";
    temperatureHold = "15m";
  };
  fileSystems = ''fstype=~"btrfs|ext4|xfs|vfat"'';
  diskUsed = selector: ''
    max by (host, device) (
      (1 - node_filesystem_avail_bytes{${selector}, ${fileSystems}}
        / node_filesystem_size_bytes{${selector}, ${fileSystems}})
      and (node_filesystem_readonly{${selector}, ${fileSystems}} == 0)
    )'';
  pushedDisk = prefix: selector: "${prefix}_disk_used_ratio{${selector}}";
  fresh = job: ''time() - push_time_seconds{job="${job}"} < ${toString maxPushSilence}'';
  freshDisk = prefix: selector: "(${pushedDisk prefix selector}) and on (instance) (${fresh prefix})";
  prediction =
    series: "predict_linear((${series})[${limits.history}:10m], ${toString limits.forecastSeconds})";
  # A line through two points is not a trend, so the forecast waits for about two days of samples,
  # which a node that pushes every quarter hour reaches with 190 of them. The second window opens
  # a week back and is three hours wide, because a range selector leaves out a sample on its start
  readySamples = 190;
  historyReady = series: ''
    (count_over_time((${series})[${limits.history}:10m]) >= ${toString readySamples})
    and present_over_time((${series})[3h:10m] offset 165h)'';
  forecast = series: "(${prediction series}) and (${historyReady series})";
  station = ''host="${stationHost}"'';
  cpuTemperature = selector: ''
    max by (host) (
      node_hwmon_temp_celsius{${selector}}
      * on (host, chip) group_left ()
      node_hwmon_chip_names{${selector}, chip_name=~"coretemp|k10temp"}
    )'';
  diskTemperature =
    selector: ''smartctl_device_temperature{${selector}, temperature_type="current"}'';
  ata = ''smartctl_device_attribute{attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable", attribute_value_type="raw"}'';
  media = "smartctl_device_media_errors";
  btrfs = "node_btrfs_device_errors_total";
  growth = series: "(${series} - min_over_time(${series}[24h])) > bool 0";
  # Grafana names the pending period `for`, and the field carries that name so that the
  # provisioning reads as Grafana's own file
  rule = uid: title: expr: for: dashboard: {
    inherit
      uid
      title
      expr
      for
      dashboard
      ;
  };
  # A node that reports its own disk reports it at its own ratio, so here it gets the forecast
  # alone, and the host names itself in the labels of the alert
  diskForecast = uidPrefix: series: dashboard: [
    (rule "${uidPrefix}-disk-forecast" "Disk will fill within seven days"
      "(${forecast series}) >= bool 1"
      limits.forecastHold
      dashboard
    )
  ];
in
{
  # Dashboards draw the same queries the rules evaluate, so a panel turns red where an alert fires
  inherit
    limits
    diskUsed
    freshDisk
    forecast
    cpuTemperature
    diskTemperature
    ;
  rules = [
    (rule "station-cpu-hot" "CPU temperature is high"
      "(${cpuTemperature station}) >= bool ${toString limits.cpuTemperature}"
      limits.temperatureHold
      "hosts"
    )
    (rule "station-disk-hot" "Disk temperature is high"
      "${diskTemperature station} >= bool ${toString limits.diskTemperature}"
      limits.temperatureHold
      "guards"
    )
    (rule "smart-health" "SMART health check failed" "smartctl_device_smart_status == bool 0" "15m"
      "guards"
    )
    (rule "smart-sectors-new" "SMART sector error count increased" (growth ata) "15m" "guards")
    (rule "smart-sectors-pending" "SMART has pending or uncorrectable sectors"
      ''smartctl_device_attribute{attribute_name=~"Current_Pending_Sector|Offline_Uncorrectable", attribute_value_type="raw"} > bool 0''
      "15m"
      "guards"
    )
    (rule "nvme-media-new" "NVMe media error count increased" (growth media) "15m" "guards")
    (rule "nvme-critical" "NVMe reports a critical warning" "smartctl_device_critical_warning > bool 0"
      "15m"
      "guards"
    )
    (rule "btrfs-errors-new" "Btrfs device errors increased" "increase(${btrfs}[24h]) > bool 0" "15m"
      "guards"
    )
  ]
  ++ diskForecast "station" (diskUsed station) "hosts"
  ++ [
    (rule "station-disk-full" "Disk use is high"
      "(${diskUsed station}) >= bool ${builtins.toJSON limits.diskUsed}"
      limits.diskHold
      "hosts"
    )
  ]
  ++ lib.concatMap (prefix: diskForecast prefix (freshDisk prefix ''job="${prefix}"'') prefix) [
    "mail"
    "vpn"
  ];
}
