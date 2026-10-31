{
  roles,
  panels,
  memoryModel,
  inputPrice,
  outputPrice,
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
      queries = [
        (query "A" roles.series-1 "hindsight_db_pool_size" "size")
        (query "B" roles.series-3 "hindsight_db_pool_idle" "idle")
        (query "C" roles.series-4 "hindsight_db_pool_waiting" "waiting")
      ];
    })
    (row "Operations" null 9)
    (table {
      title = "Operations by result";
      x = 0;
      y = 10;
      w = 12;
      expr = "sum by (operation, success) (hindsight_operation_operations_total)";
      unit = "short";
      labels = [
        "operation"
        "success"
      ];
      valueName = "Count";
      sortDesc = true;
      coloured = false;
    })
    (panel {
      title = "Operation duration";
      x = 12;
      y = 10;
      w = 12;
      unit = "s";
      shaded = true;
      queries = [
        (query "A" roles.series-1
          "sum by (operation) (rate(hindsight_operation_duration_seconds_sum[5m])) / sum by (operation) (rate(hindsight_operation_duration_seconds_count[5m]))"
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
      title = "LLM calls";
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
      expr = "sum by (operation) (increase(hindsight_operation_operations_total[7d]))";
      unit = "short";
      labels = [ "operation" ];
      valueName = "Updates";
      sortDesc = true;
      coloured = false;
    })
  ];
}
