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
    stat
    table
    ;
  operations = "round(sum by (operation, success) (increase(hindsight_operation_operations_total[$__range])))";
in
panels.dashboard {
  uid = "hindsight";
  title = "Hindsight";
  links = [
    {
      title = "AI Spend";
      type = "link";
      url = "/d/ai-spend/ai-spend";
    }
  ];
  panels = [
    (stat {
      title = "API";
      x = 0;
      y = 0;
      w = 6;
      unit = "short";
      expr = ''min(up{job="hindsight"})'';
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
      title = "Failed operations in range";
      x = 6;
      y = 0;
      w = 6;
      unit = "short";
      thresholds = 1;
      expr = ''round(sum(increase(hindsight_operation_operations_total{success="false"}[$__range])))'';
    })
    (stat {
      title = "DB pool in use";
      x = 12;
      y = 0;
      w = 6;
      unit = "percentunit";
      thresholds = 1;
      expr = "(sum(hindsight_db_pool_size) - sum(hindsight_db_pool_idle)) / ${toString poolMax}";
      description = "Share of the configured connection limit in use";
    })
    (stat {
      title = "Rerank calls in range";
      x = 18;
      y = 0;
      w = 6;
      unit = "short";
      expr = "round(sum(increase(hindsight_rerank_model_calls_total[$__range])))";
      description = "Observed model calls for the shared bank, including errors. This is not a count of charges";
    })
    (table {
      title = "Operations by result";
      x = 0;
      y = 4;
      w = 10;
      h = 9;
      expr = "${operations} > 0";
      unit = "short";
      labels = [
        "operation"
        "success"
      ];
      valueName = "Operations";
      sortDesc = true;
      coloured = false;
      description = "Nonzero operation counts over the selected range";
    })
    (panel {
      title = "Slowest operations · p95 by type";
      x = 10;
      y = 4;
      w = 14;
      h = 9;
      unit = "s";
      min = 0;
      shaded = true;
      description = "Each point uses the last hour. Gaps mean no duration samples for the operation";
      queries = [
        (query "A" roles.series-1
          "histogram_quantile(0.95, sum by (le, operation) (rate(hindsight_operation_duration_seconds_bucket[1h])))"
          "{{operation}}"
        )
      ];
    })
    (table {
      title = "Average model and phase latency";
      x = 0;
      y = 13;
      w = 12;
      unit = "s";
      expr = ''
        label_replace(sum(increase(hindsight_recall_phase_duration_seconds_sum{phase="generate_query_embedding"}[$__range])) / (sum(increase(hindsight_recall_phase_duration_seconds_count{phase="generate_query_embedding"}[$__range])) > 0), "item", "Query embedding phase", "__name__", ".*")
        or label_replace(sum(increase(hindsight_recall_phase_duration_seconds_sum{phase="reranking"}[$__range])) / (sum(increase(hindsight_recall_phase_duration_seconds_count{phase="reranking"}[$__range])) > 0), "item", "Reranking phase", "__name__", ".*")
        or label_replace(sum(increase(hindsight_llm_duration_seconds_sum{model="${memoryModel}"}[$__range])) / (sum(increase(hindsight_llm_duration_seconds_count{model="${memoryModel}"}[$__range])) > 0), "item", "Memory LLM calls", "__name__", ".*")
      '';
      labels = [ "item" ];
      valueName = "Average";
      coloured = false;
      description = "Average over the selected range. Query embedding includes temporal analysis. Rerank includes candidate preparation and fallback";
    })
    (panel {
      title = "Requests waiting for a DB connection";
      x = 12;
      y = 13;
      w = 12;
      unit = "short";
      min = 0;
      queries = [ (query "A" roles.series-1 "sum(hindsight_db_pool_waiting)" "Waiting") ];
    })
  ];
}
