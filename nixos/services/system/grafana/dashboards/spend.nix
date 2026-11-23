{
  lib,
  panels,
  hermes,
  hindsight,
  lowBalance,
  modelRoutes,
  modelPricesMaxAge,
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
  withSample = expr: guard: "(${expr}) and on (job, instance, host) (${guard})";
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
  smoothing = {
    decay = "0.8";
    days = 14;
    minimum = 10;
  };
  pace =
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
  priceRoutes = lib.concatLists (
    lib.mapAttrsToList (
      model: providers: map (provider: { inherit model provider; }) providers
    ) modelRoutes
  );
  priceFresh = "time() - max(model_price_collection_timestamp_seconds) < ${toString modelPricesMaxAge}";
  priceQueries =
    kind:
    lib.imap0 (
      i: route:
      query "P${toString i}"
        ''model_price_usd_per_million{model="${route.model}",provider="${route.provider}",kind="${kind}"} and on () (${priceFresh})''
        "${route.model} · {{endpoint}}"
    ) priceRoutes;
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
        bars = true;
        interval = "1d";
        description = "Each bar ends at midnight UTC. The last minutes of spend may be absent. A gap means no recent sample. The two charts use independent scales";
        queries = [ (query "A" (day key) key.name) ];
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
        description = "The estimate gives each older day ${smoothing.decay} times the weight of the next day. Each key needs ${toString smoothing.minimum} samples in ${toString smoothing.days} days and one in the last three days. It excludes subscriptions";
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
        expr = lib.concatStringsSep "\n or " (
          lib.mapAttrsToList (
            horizon: days:
            ''label_replace(${projected (pace key) days}, "horizon", "${horizon}", "__name__", ".*")''
          ) horizons
        );
        labels = [ "horizon" ];
        valueName = "USD";
        coloured = false;
        description = "Each older day has ${smoothing.decay} times the weight of the next day. The estimate needs ${toString smoothing.minimum} samples in ${toString smoothing.days} days and one in the last three days";
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
    ++ [ (row "OpenRouter · Endpoint prices" null 29) ]
    ++
      lib.imap0
        (
          i: kind:
          panel {
            title = "${kind.title} price per million tokens";
            description = "The price published by each configured OpenRouter endpoint. A gap means that no price was collected";
            x = i * 8;
            y = 30;
            w = 8;
            unit = "currencyUSD";
            min = 0;
            steps = true;
            queries = priceQueries kind.value;
          }
        )
        [
          {
            title = "Input";
            value = "input";
          }
          {
            title = "Output";
            value = "output";
          }
          {
            title = "Cached input";
            value = "cache_read";
          }
        ]
    ++ [
      (table {
        title = "Configured endpoints not listed";
        description = "Configured providers absent from the last successful OpenRouter response";
        x = 0;
        y = 38;
        w = 9;
        unit = "short";
        expr = "(model_price_endpoint_available == 0) and on () (${priceFresh})";
        labels = [
          "model"
          "provider"
        ];
        valueName = "Available";
        thresholds = 1;
        dangerBelow = true;
      })
      (table {
        title = "Price requests that failed";
        description = "Models whose most recent OpenRouter request failed or returned invalid data";
        x = 9;
        y = 38;
        w = 9;
        unit = "short";
        expr = "(model_price_fetch_success == 0) and on () (${priceFresh})";
        labels = [ "model" ];
        valueName = "Success";
        thresholds = 1;
        dangerBelow = true;
      })
      (stat {
        title = "Price collection age";
        description = "Time since the price collector last wrote its result";
        x = 18;
        y = 38;
        w = 6;
        h = 8;
        unit = "s";
        expr = "time() - max(model_price_collection_timestamp_seconds)";
        thresholds = modelPricesMaxAge;
      })
    ];
}
