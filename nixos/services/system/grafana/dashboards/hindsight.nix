{
  roles,
  panels,
  memoryModel,
  inputPrice,
  outputPrice,
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

  spend =
    window:
    "("
    + "sum(increase(hindsight_llm_tokens_input_tokens_total{model=\"${memoryModel}\"}[${window}])) * ${inputPrice}"
    + " + sum(increase(hindsight_llm_tokens_output_tokens_total{model=\"${memoryModel}\"}[${window}])) * ${outputPrice}"
    + " + sum(increase(hindsight_llm_tokens_thoughts_tokens_total{model=\"${memoryModel}\"}[${window}])) * ${outputPrice}"
    + ")";

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
      expr = "round(sum by (operation, success) (increase(hindsight_operation_operations_total[$__range])))";
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
    (row "LLM usage and estimated spend" null 26)
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
      title = "Estimated spend";
      x = 0;
      y = 35;
      w = 12;
      unit = "currencyUSD";
      decimals = 4;
      queries = [
        (query "A" roles.series-1 (spend "24h") "Last 24h")
        (query "B" roles.series-3 (spend "24h" + " * 30") "30-day projection")
      ];
    })
    (row "Last 7 days" null 43)
    (table {
      title = "Memory updates in the last 7 days";
      x = 0;
      y = 44;
      w = 24;
      expr = "round(sum by (operation) (increase(hindsight_operation_operations_total[7d])))";
      unit = "short";
      labels = [ "operation" ];
      valueName = "Updates";
      sortDesc = true;
      coloured = false;
    })
  ];
}
