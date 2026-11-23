{
  lib,
  criticalTemperature,
  stationHost,
  maxPushSilence,
  modelPricesInterval,
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
    cpuUsed = 0.9;
    memoryUsed = 0.9;
    forecastSeconds = 7 * 24 * 3600;
    history = "7d";
    forecastHold = "1h";
    diskHold = "30m";
    loadHold = "15m";
    temperatureHold = "15m";
  };
  percent = share: toString (builtins.floor (share * 100));
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
  freshMemory =
    prefix: selector: "${prefix}_memory_used_ratio{${selector}} and on (instance) (${fresh prefix})";
  # Both counters grow by the same number of seconds, so their ratio is utilization. The window is
  # an hour because Mail pushes every quarter hour: a shorter one would divide by a rate of zero
  freshCpu =
    prefix: selector:
    let
      busy = "rate(${prefix}_cpu_busy_seconds_total{${selector}}[1h])";
      total = "rate(${prefix}_cpu_seconds_total{${selector}}[1h])";
    in
    "clamp_max(${busy} / (${total} > 0), 1) and on (instance) (${fresh prefix})";
  prediction =
    series: "predict_linear((${series})[${limits.history}:10m], ${toString limits.forecastSeconds})";
  # A line through two points is not a trend, so the forecast waits for about two days of samples,
  # which a node that pushes every quarter hour reaches with 190 of them. The window ends an hour
  # back: a workstation that sleeps every night loses a quarter of a week to that, and pinning the
  # depth to one clock hour would blank its forecast for the same hours every morning
  readySamples = 190;
  historyReady =
    series: "count_over_time((${series})[${limits.history}:10m] offset 1h) >= ${toString readySamples}";
  forecast = series: "(${prediction series}) and (${historyReady series})";
  # A displayed estimate weights recent daily slopes more heavily; alert rules keep their fit
  visualForecast =
    series:
    let
      samples =
        weighted:
        lib.concatStringsSep " or " (
          lib.genList (
            age:
            let
              slope = "deriv((${series})[1d:1h] offset ${toString age}d)";
              sample = if weighted then slope else "0 * ${slope} + 1";
            in
            ''label_replace((${sample}) * 0.8 ^ ${toString age}, "forecast_age", "${toString age}", "__name__", ".*")''
          ) 7
        );
      weighted = samples true;
      weights = samples false;
      slope = "(sum without (forecast_age) (${weighted}) / sum without (forecast_age) (${weights}))";
      available = "count without (forecast_age) (${weights}) >= 3";
    in
    "((${series}) + (${slope}) * ${toString limits.forecastSeconds}) and (${available}) and (${historyReady series})";
  priceAge = "time() - max(model_price_collection_timestamp_seconds)";
  priceMaxAge = toString (2 * modelPricesInterval);
  priceFresh = "and on () (${priceAge} < ${priceMaxAge})";
  station = ''host="${stationHost}"'';
  # The station needs no push and no freshness guard; a node behind the Pushgateway reports the
  # same two shares itself, and its rule waits for a fresh push
  stationCpu = ''1 - avg by (host) (rate(node_cpu_seconds_total{${station}, mode="idle"}[5m]))'';
  stationMemory = "1 - node_memory_MemAvailable_bytes{${station}} / node_memory_MemTotal_bytes{${station}}";
  hostDashboard = "{{ $labels.host }}";
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
  # A node reports its own share, so the alert compares that share to the limit directly, and the
  # freshness guard keeps a node that stopped pushing from raising one
  usageAlerts =
    prefix:
    let
      selector = ''job="${prefix}"'';
    in
    [
      (
        (rule "${prefix}-cpu-high" "CPU use is high"
          "(${freshCpu prefix selector}) >= bool ${builtins.toJSON limits.cpuUsed}"
          limits.loadHold
          prefix
        )
        // {
          summary = "CPU use stayed above ${percent limits.cpuUsed}%";
        }
      )
      (
        (rule "${prefix}-memory-high" "Memory use is high"
          "(${freshMemory prefix selector}) >= bool ${builtins.toJSON limits.memoryUsed}"
          limits.loadHold
          prefix
        )
        // {
          summary = "Memory use stayed above ${percent limits.memoryUsed}%";
        }
      )
    ];
  # A node that reports its own disk reports it at its own ratio, so here it gets the forecast
  # alone, and the host names itself in the labels of the alert
  diskForecast = uidPrefix: series: dashboard: [
    (
      (rule "${uidPrefix}-disk-forecast" "Disk will fill within seven days"
        "(${forecast series}) >= bool 1"
        limits.forecastHold
        dashboard
      )
      // {
        summary = "Disk forecast: the current trend can exhaust free space within seven days";
      }
    )
  ];
in
{
  # Alert thresholds and their linear forecast are independent of the displayed estimate
  inherit
    limits
    diskUsed
    freshDisk
    freshCpu
    freshMemory
    forecast
    visualForecast
    cpuTemperature
    diskTemperature
    ;
  rules = [
    (rule "model-provider-missing" "A configured model endpoint is absent from OpenRouter"
      "(last_over_time(model_price_endpoint_available[48h]) == bool 0) and on (model, provider) (model_price_route_configured == 1) ${priceFresh}"
      "1h"
      "ai-spend"
    )
    (rule "model-price-fetch-failed" "OpenRouter endpoint catalogue request failed"
      "(model_price_fetch_success == bool 0) ${priceFresh}"
      "2h"
      "ai-spend"
    )
    (rule "model-price-collector-stale" "OpenRouter endpoint collector is stale"
      "(${priceAge} >= bool ${priceMaxAge}) or absent(model_price_collection_timestamp_seconds)"
      "2h"
      "ai-spend"
    )
    (rule "station-cpu-hot" "CPU temperature is high"
      "(${cpuTemperature station}) >= bool ${toString limits.cpuTemperature}"
      limits.temperatureHold
      stationHost
    )
    (
      (rule "station-cpu-high" "CPU use is high"
        "(${stationCpu}) >= bool ${builtins.toJSON limits.cpuUsed}"
        limits.loadHold
        stationHost
      )
      // {
        summary = "CPU use stayed above ${percent limits.cpuUsed}%";
      }
    )
    (
      (rule "station-memory-high" "Memory use is high"
        "(${stationMemory}) >= bool ${builtins.toJSON limits.memoryUsed}"
        limits.loadHold
        stationHost
      )
      // {
        summary = "Memory use stayed above ${percent limits.memoryUsed}%";
      }
    )
    (rule "station-disk-hot" "Disk temperature is high"
      "${diskTemperature station} >= bool ${toString limits.diskTemperature}"
      limits.temperatureHold
      stationHost
    )
    (rule "smart-health" "SMART health check failed" "smartctl_device_smart_status == bool 0" "15m"
      hostDashboard
    )
    (rule "smart-sectors-new" "SMART sector error count increased" (growth ata) "15m" hostDashboard)
    (rule "smart-sectors-pending" "SMART has pending or uncorrectable sectors"
      ''smartctl_device_attribute{attribute_name=~"Current_Pending_Sector|Offline_Uncorrectable", attribute_value_type="raw"} > bool 0''
      "15m"
      hostDashboard
    )
    (rule "nvme-media-new" "NVMe media error count increased" (growth media) "15m" hostDashboard)
    (rule "nvme-critical" "NVMe reports a critical warning" "smartctl_device_critical_warning > bool 0"
      "15m"
      hostDashboard
    )
    (rule "btrfs-errors-new" "Btrfs device errors increased" "increase(${btrfs}[24h]) > bool 0" "15m"
      hostDashboard
    )
  ]
  ++ diskForecast "station" (diskUsed station) stationHost
  ++ [
    (
      (rule "station-disk-full" "Disk use is high"
        "(${diskUsed station}) >= bool ${builtins.toJSON limits.diskUsed}"
        limits.diskHold
        stationHost
      )
      // {
        summary = "Disk use reached ${percent limits.diskUsed}%";
      }
    )
  ]
  ++ lib.concatMap usageAlerts [
    "mail"
    "vpn"
  ]
  ++ lib.concatMap (prefix: diskForecast prefix (freshDisk prefix ''job="${prefix}"'') prefix) [
    "mail"
    "vpn"
  ];
}
