{
  lib,
  roles,
  panels,
  hermes,
  hindsight,
  lowBalance,
}:

let
  inherit (panels)
    panel
    query
    row
    stat
    table
    ;
  usd =
    args:
    stat (
      {
        unit = "currencyUSD";
        decimals = 4;
      }
      // args
    );
  agentsFresh = "time() - hermes_collect_timestamp_seconds < 300";
  goFresh = "time() - mya_go_last_run < 1800";
  priceFresh = "time() - mya_price_last_run < 1800";
  withSample = expr: guard: "(${expr}) and on (job, instance, host) (${guard})";
  withPush = expr: guard: "(${expr}) and on (job) (${guard})";
  keyMetric = prefix: field: "${prefix}_${field}_usd";
  keys =
    lib.optional hermes {
      name = "Hermes";
      prefix = "openrouter_key";
      stamp = "hermes_collect_timestamp_seconds";
    }
    ++ lib.optional hindsight {
      name = "Hindsight";
      prefix = "hindsight_spend_key";
      stamp = "hindsight_spend_collect_timestamp_seconds";
    };
  # Prometheus aligns a one-day step to midnight UTC. Read the day before its gauge resets
  day =
    key:
    withSample "${keyMetric key.prefix "usage_daily"} offset 2m" "time() - 120 - (${key.stamp} offset 2m) < 300";
  # Fixed UTC steps exclude today and keep missing days out of the averages
  pace =
    key:
    let
      daily = "max(${day key})";
      mean =
        window: minimum:
        "(avg_over_time(${window}) and (count_over_time(${window}) >= ${toString minimum}))";
    in
    "(${mean "${daily}[7d:1d]" 5} + ${mean "${daily}[14d:1d] offset 7d" 7}) / 2";
  smoothing = {
    decay = "0.8";
    days = 14;
    minimum = 10;
  };
  smoothedPace =
    key:
    let
      daily = "max(${day key})";
      samples =
        weighted:
        lib.concatStringsSep "\n or " (
          lib.genList (
            age:
            let
              window = "${daily}[1d:1d]" + lib.optionalString (age > 0) " offset ${toString age}d";
              value = if weighted then "last_over_time(${window})" else "present_over_time(${window})";
            in
            ''label_replace(${value} * ${smoothing.decay} ^ ${toString age}, "day_age", "${toString age}", "__name__", ".*")''
          ) smoothing.days
        );
      # Divide by the weight of observed days only. A real zero still contributes weight
      available = samples false;
    in
    "(sum(${samples true}) / sum(${available})) and (count(${available}) >= ${toString smoothing.minimum}) and present_over_time(${daily}[3d:1d])";
  projected = rate: days: "(${rate}) * ${toString days}";
  horizons = {
    "1 week" = 7;
    "2 weeks" = 14;
    "30 days" = 30;
  };
  forecastWidth = 24 / (builtins.length keys + 1);
  today =
    key:
    withSample (keyMetric key.prefix "usage_daily") "(time() - ${key.stamp} < 300) and (${key.stamp} >= time() - time() % 86400)";
  keySummary =
    key:
    lib.concatStringsSep "\n or " (
      lib.mapAttrsToList
        (
          name: metric:
          ''label_replace((${withSample (keyMetric key.prefix metric) "time() - ${key.stamp} < 300"}), "item", "${name}", "job", ".*")''
        )
        {
          "Month to date" = "usage_monthly";
          "Lifetime spend" = "usage";
          "Key limit" = "limit";
          "Key limit left" = "limit_remaining";
        }
    );
in
panels.dashboard {
  uid = "ai-spend";
  title = "AI Spend";
  tags = [
    "cost"
    "ai"
  ];
  timezone = "utc";
  time.from = "now-14d/d";
  time.to = "now";
  refresh = "1m";
  panels =
    lib.optional hermes (usd {
      title = "OpenRouter credit balance";
      x = 0;
      y = 0;
      w = 8;
      h = 5;
      decimals = 2;
      expr = withSample "openrouter_balance_usd" agentsFresh;
      thresholds = lowBalance;
      dangerBelow = true;
      description = "Account credit, not the amount left on a key. Cards show values at the end of the selected range";
    })
    ++ lib.imap0 (
      i: key:
      usd {
        title = "${key.name} · Today (UTC)";
        x = (if hermes then 8 else 0) + i * 8;
        y = 0;
        w = if hermes then 8 else 24;
        h = 5;
        expr = today key;
        description = "OpenRouter's total for this key since midnight UTC. No data is not zero spend";
      }
    ) keys
    ++ lib.imap0 (
      i: key:
      panel {
        title = "${key.name} · Spend by UTC day";
        x = i * 12;
        y = 5;
        w = if builtins.length keys == 1 then 24 else 12;
        h = 10;
        unit = "currencyUSD";
        decimals = 4;
        min = 0;
        dailyBars = true;
        description = "Each bar ends at midnight UTC. The last minutes of spend may be absent. A gap means no recent sample. The two charts use independent scales";
        queries = [ (query "A" roles.series-1 (day key) key.name) ];
      }
    ) keys
    ++ [
      (row "OpenRouter · Forecast" null 15)
      (usd {
        title = "Next 30 days · Total";
        x = 0;
        y = 16;
        w = forecastWidth;
        h = 6;
        decimals = 2;
        expr = projected (lib.concatMapStringsSep " + " (key: "(${pace key})") keys) horizons."30 days";
        description = "The last week and the two weeks before it have equal weight. Each key needs at least five recent and seven earlier daily samples. The estimate assumes a constant daily rate and excludes subscriptions";
      })
    ]
    ++ lib.imap0 (
      i: key:
      table {
        title = "${key.name} · Projected spend";
        x = (i + 1) * forecastWidth;
        y = 16;
        w = forecastWidth;
        h = 6;
        unit = "currencyUSD";
        expr =
          lib.concatStringsSep "\n or " (
            lib.mapAttrsToList (
              horizon: days:
              ''label_replace(${projected (pace key) days}, "horizon", "${horizon}", "__name__", ".*")''
            ) horizons
          )
          + ''
            or label_replace(${
              projected (smoothedPace key) horizons."30 days"
            }, "horizon", "30 days (smoothed)", "__name__", ".*")
          '';
        labels = [ "horizon" ];
        valueName = "USD";
        coloured = false;
        description = "Compare the two 30-day estimates. The smoothed estimate gives each older day ${smoothing.decay} times the weight of the next day. It needs ${toString smoothing.minimum} samples in ${toString smoothing.days} days and one in the last three days";
      }
    ) keys
    ++ [ (row "OpenRouter · Spend and limits by key" null 22) ]
    ++ lib.imap0 (
      i: key:
      table {
        title = "${key.name} key";
        x = i * 12;
        y = 23;
        w = if builtins.length keys == 1 then 24 else 12;
        h = 6;
        unit = "currencyUSD";
        expr = keySummary key;
        labels = [ "item" ];
        valueName = "USD";
        coloured = false;
        description = "Month to date uses UTC. OpenRouter omits a limit when the key has none";
      }
    ) keys
    ++ lib.optionals hermes [
      (row "OpenCode Go · Allowance, not extra charges" null 29)
      (table {
        title = "Shared allowance used";
        x = 0;
        y = 30;
        w = 9;
        h = 8;
        unit = "percent";
        expr = withPush "mya_go_window_percent" goFresh;
        labels = [
          "account"
          "window"
        ];
        valueName = "Used";
        coloured = true;
        thresholds = 100;
        description = "100% means that the allowance for the window is exhausted";
      })
      (usd {
        title = "Hermes · Usage value this month";
        x = 9;
        y = 30;
        w = 6;
        h = 8;
        expr = withPush "mya_go_hermes_month_usd" goFresh;
        decimals = 2;
        description = "Hermes records this usage value against the plan. This value is not an extra charge or the subscription price";
      })
      (table {
        title = "Hermes · Usage value by model";
        x = 15;
        y = 30;
        w = 9;
        h = 8;
        unit = "currencyUSD";
        expr = withPush "mya_go_hermes_month_usd_by_model" goFresh;
        labels = [ "model" ];
        valueName = "USD";
        coloured = false;
        sortDesc = true;
      })
      (row "Model prices · Estimates, not bills" null 38)
      (table {
        title = "Daily cost at current hosts";
        x = 0;
        y = 39;
        w = 12;
        h = 9;
        unit = "currencyUSD";
        expr = withPush "mya_price_usd_per_day" priceFresh;
        labels = [
          "model"
          "host"
        ];
        valueName = "USD/day";
        coloured = false;
        sortDesc = true;
        description = "Estimated with the fixed token profile of the price watcher. It does not measure actual use";
      })
      (table {
        title = "Daily cost at the cheapest alternative";
        x = 12;
        y = 39;
        w = 12;
        h = 9;
        unit = "currencyUSD";
        expr = withPush "mya_price_cheapest_usd_per_day" priceFresh;
        labels = [
          "model"
          "host"
        ];
        valueName = "USD/day";
        coloured = false;
        sortDesc = true;
        description = "Same token profile as the current host. Check precision and availability before a change of host";
      })
    ];
}
