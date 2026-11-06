{
  roles,
  panels,
  memoryModel,
  poolMax,
}:

let
  inherit (panels)
    panel
    query
    row
    states
    table
    ;

  # The key's counter is cumulative, and delta reads it as the spend of a window rather than as
  # a rate, so a provider's own figure needs no price and no token count
  spend = window: "delta(hindsight_spend_key_usage_usd[" + window + "])";

  # A result that never happened still has a zero series, and a row of zero is noise: the filter
  # drops those rows. Both tables read the same counter and differ only in their window
  operations =
    window:
    "round(sum by (operation, success) (increase(hindsight_operation_operations_total["
    + window
    + "]))) > 0";

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
in
panels.dashboard {
  uid = "hindsight";
  title = "Hindsight";
  panels = [
    (row "Service" null 0)
    (states {
      title = "API";
      x = 0;
      y = 1;
      w = 8;
      expr = ''max(up{job="hindsight"})'';
      legend = "Hindsight";
      mappings = upDown;
    })
    (panel {
      title = "Process memory";
      x = 8;
      y = 1;
      w = 8;
      unit = "bytes";
      queries = [
        (query "A" roles.series-1 "hindsight_process_memory_bytes" "RSS")
      ];
    })
    (panel {
      title = "DB pool";
      x = 16;
      y = 1;
      w = 8;
      unit = "short";
      # The pool holds its ceiling open whatever the load: idle equals size minus what is in
      # use, so those two lines said one thing twice. The ceiling stays, as the threshold, and
      # the axis is pinned to it so that the line is always in view
      min = 0;
      max = poolMax;
      thresholds = poolMax;
      queries = [
        (query "A" roles.series-1 "sum(hindsight_db_pool_size) - sum(hindsight_db_pool_idle)" "active")
        (query "B" roles.series-3 "sum(hindsight_db_pool_waiting)" "waiting")
      ];
    })
    (row "Operations" null 9)
    (table {
      title = "Operations by result";
      x = 0;
      y = 10;
      w = 12;
      expr = operations "$__range";
      unit = "short";
      labels = [
        "operation"
        "success"
      ];
      valueName = "Operations";
      sortDesc = true;
      coloured = false;
    })
    # A ratio of two rates is NaN where the window holds no operation, and NaN is a hole in the
    # graph, so the window is an hour: a hole then means what it says, that no operation ran
    (panel {
      title = "Operation duration, median";
      x = 12;
      y = 10;
      w = 6;
      unit = "s";
      shaded = true;
      queries = [
        (query "A" roles.series-1
          "histogram_quantile(0.5, sum by (le, operation) (rate(hindsight_operation_duration_seconds_bucket[1h])))"
          "{{operation}}"
        )
      ];
    })
    (panel {
      title = "Operation duration, 95th percentile";
      x = 18;
      y = 10;
      w = 6;
      unit = "s";
      shaded = true;
      queries = [
        (query "A" roles.series-1
          "histogram_quantile(0.95, sum by (le, operation) (rate(hindsight_operation_duration_seconds_bucket[1h])))"
          "{{operation}}"
        )
      ];
    })
    (panel {
      title = "Retain throughput";
      x = 0;
      y = 18;
      w = 12;
      unit = "short";
      queries = [
        (query "A" roles.series-1 "sum(rate(hindsight_retain_documents_total[5m]))" "documents/s")
      ];
    })
    (panel {
      title = "HTTP responses";
      x = 12;
      y = 18;
      w = 12;
      unit = "short";
      shaded = true;
      queries = [
        (query "A" roles.series-1 "sum by (status_class) (rate(hindsight_http_requests_total[5m]))"
          "{{status_class}}"
        )
      ];
    })
    (row "LLM usage" null 26)
    (panel {
      title = "Tokens";
      x = 0;
      y = 27;
      w = 12;
      unit = "short";
      queries = [
        (query "A" roles.series-1
          "sum(rate(hindsight_llm_tokens_input_tokens_total{model=\"${memoryModel}\"}[5m]))"
          "input/s"
        )
        (query "B" roles.series-3
          "sum(rate(hindsight_llm_tokens_output_tokens_total{model=\"${memoryModel}\"}[5m]))"
          "output/s"
        )
        (query "C" roles.series-4
          "sum(rate(hindsight_llm_tokens_thoughts_tokens_total{model=\"${memoryModel}\"}[5m]))"
          "thoughts/s"
        )
      ];
    })
    (panel {
      title = "LLM calls per second";
      x = 12;
      y = 27;
      w = 12;
      unit = "short";
      shaded = true;
      queries = [
        (query "A" roles.series-1
          "sum by (scope) (rate(hindsight_llm_calls_total{model=\"${memoryModel}\"}[5m]))"
          "{{scope}}"
        )
      ];
    })
    (panel {
      title = "Completed reranking phases";
      x = 0;
      y = 35;
      w = 12;
      unit = "short";
      shaded = true;
      queries = [
        (query "A" roles.series-1
          "sum(rate(hindsight_recall_phase_duration_seconds_count{phase=\"reranking\"}[5m]))"
          "recalls/s"
        )
      ];
    })
    (panel {
      title = "Reranking phase, p95";
      x = 12;
      y = 35;
      w = 12;
      unit = "s";
      shaded = true;
      queries = [
        (query "A" roles.series-1
          "histogram_quantile(0.95, sum by (le) (rate(hindsight_recall_phase_duration_seconds_bucket{phase=\"reranking\"}[1h])))"
          "p95"
        )
      ];
    })
    (row "Rerank model calls" null 43)
    (table {
      title = "Observed rerank model calls over 24 hours";
      x = 0;
      y = 44;
      w = 12;
      unit = "short";
      expr = ''label_replace(sum(increase(hindsight_rerank_model_calls_total[1d])), "item", "Model calls", "__name__", ".*")'';
      labels = [ "item" ];
      valueName = "Calls";
      coloured = false;
      description = "Estimated increase in recorded model calls for the shared bank, including errors; this does not measure paid calls or fallback";
    })
    (table {
      title = "Average model and phase latency";
      x = 12;
      y = 44;
      w = 12;
      unit = "s";
      expr = ''
        label_replace(sum(increase(hindsight_recall_phase_duration_seconds_sum{phase="generate_query_embedding"}[$__range])) / sum(increase(hindsight_recall_phase_duration_seconds_count{phase="generate_query_embedding"}[$__range])), "item", "Query embedding phase", "__name__", ".*")
        or label_replace(sum(increase(hindsight_recall_phase_duration_seconds_sum{phase="reranking"}[$__range])) / sum(increase(hindsight_recall_phase_duration_seconds_count{phase="reranking"}[$__range])), "item", "Reranking phase", "__name__", ".*")
        or label_replace(sum(increase(hindsight_llm_duration_seconds_sum{model="${memoryModel}"}[$__range])) / sum(increase(hindsight_llm_duration_seconds_count{model="${memoryModel}"}[$__range])), "item", "Memory LLM calls", "__name__", ".*")
      '';
      labels = [ "item" ];
      valueName = "Average";
      coloured = false;
      description = "Average over the selected range. Query embedding includes temporal analysis; reranking includes candidate preparation and fallback. LLM counts model calls";
    })
    (row "Spend" null 52)
    (panel {
      title = "Spend";
      x = 0;
      y = 53;
      w = 12;
      unit = "currencyUSD";
      decimals = 4;
      # The provider's own number for the key every Hindsight model shares, so it covers chat,
      # embeddings and rerank together and needs no price kept beside the model
      description = "What OpenRouter billed the key of every Hindsight model, read from its counter rather than estimated from tokens";
      queries = [
        (query "A" roles.series-1 (spend "24h") "Last 24h")
        (query "B" roles.series-3 (spend "24h" + " * 30") "30-day projection")
      ];
    })
    (panel {
      title = "Spend by OpenRouter period";
      x = 12;
      y = 53;
      w = 12;
      unit = "currencyUSD";
      decimals = 4;
      description = "The periods OpenRouter totals itself, so each one starts again when it ends";
      queries = [
        (query "A" roles.series-1 "hindsight_spend_key_usage_daily_usd" "Current UTC day")
        (query "B" roles.series-3 "hindsight_spend_key_usage_weekly_usd" "Current UTC week")
        (query "C" roles.series-4 "hindsight_spend_key_usage_monthly_usd" "Current UTC month")
      ];
    })
    (states {
      title = "Spend counter";
      x = 0;
      y = 61;
      w = 8;
      expr = "max(hindsight_spend_collect_success)";
      legend = "Hindsight key";
      mappings = upDown;
    })
    (table {
      title = "OpenRouter key balance";
      x = 8;
      y = 61;
      w = 16;
      unit = "currencyUSD";
      expr = ''
        label_replace(hindsight_spend_key_usage_usd, "item", "Spent", "__name__", ".*")
        or label_replace(hindsight_spend_key_limit_remaining_usd, "item", "Available", "__name__", ".*")
        or label_replace(hindsight_spend_key_limit_usd, "item", "Limit", "__name__", ".*")
      '';
      labels = [ "item" ];
      valueName = "USD";
      coloured = false;
      description = "Current spend, remaining key limit, and the full limit from OpenRouter's key endpoint";
    })
    (row "Last 7 days" null 69)
    (table {
      title = "Memory operations in the last 7 days";
      x = 0;
      y = 70;
      w = 24;
      # The window is fixed on purpose: the dashboard opens on a day, and this row is a week
      expr = operations "7d";
      unit = "short";
      labels = [
        "operation"
        "success"
      ];
      valueName = "Operations";
      sortDesc = true;
      coloured = false;
    })
  ];
}
