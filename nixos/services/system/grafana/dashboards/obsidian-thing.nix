{ panels, roles }:

let
  inherit (panels)
    panel
    query
    stat
    table
    ;
  metric = name: "obsidian_thing_${name}";
  rate = name: "rate(${metric name}{job=\"obsidian-thing\"}[$__rate_interval])";
  latency = name: label: "histogram_quantile(0.95, sum by (le, ${label}) (${rate name}))";
  unknown = ''sum(rate(${metric "embedding_cost_records_total"}{job="obsidian-thing",kind="unknown"}[$__range]))'';
  remote = ''sum(rate(${metric "embedding_cost_records_total"}{job="obsidian-thing",kind!="local"}[$__range]))'';
  scan = ''${metric "last_full_index_scan_timestamp_seconds"}{job="obsidian-thing"}'';
in
panels.dashboard {
  uid = "obsidian-thing";
  title = "Obsidian Thing";
  tags = [
    "mcp"
    "search"
  ];
  panels = [
    (stat {
      title = "API";
      description = "Whether Prometheus can scrape Obsidian Thing";
      x = 0;
      y = 0;
      w = 6;
      unit = "short";
      expr = ''min(up{job="obsidian-thing"})'';
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
      title = "Files in queue";
      description = "Candidates in the index snapshot before the worker checks their files";
      x = 6;
      y = 0;
      w = 6;
      unit = "short";
      expr = ''sum(${metric "embedding_queue_files"}{job="obsidian-thing"})'';
    })
    (stat {
      title = "Calls without a price";
      description = "Share of remote calls with no price in the selected range. No remote calls means no data";
      x = 12;
      y = 0;
      w = 6;
      unit = "percentunit";
      expr = "${unknown} / (${remote} > 0)";
    })
    (stat {
      title = "Full scan age";
      description = "Time since the last successful full scan. No data means that no full scan has completed";
      x = 18;
      y = 0;
      w = 6;
      unit = "s";
      expr = "time() - max(${scan} > 0)";
    })
    (panel {
      title = "MCP requests by result";
      description = "Request rate by MCP method and result. This does not count notifications";
      x = 0;
      y = 4;
      w = 12;
      h = 8;
      unit = "reqps";
      queries = [
        (query "A" "sum by (method, status) (${rate "mcp_requests_total"})" "{{method}} · {{status}}")
      ];
    })
    (panel {
      title = "Provider calls by result";
      description = "Embedding call rate by provider, operation and result. A cache hit does not call the provider";
      x = 12;
      y = 4;
      w = 12;
      h = 8;
      unit = "reqps";
      queries = [
        (query "A" "sum by (operation, provider, status) (${rate "embedding_requests_total"})"
          "{{provider}} · {{operation}} · {{status}}"
        )
      ];
    })
    (panel {
      title = "MCP requests · p95 by method";
      description = "Gaps mean no request duration samples for the method";
      x = 0;
      y = 12;
      w = 12;
      h = 8;
      unit = "s";
      queries = [ (query "A" (latency "mcp_request_duration_seconds_bucket" "method") "{{method}}") ];
    })
    (panel {
      title = "Provider calls · p95 by operation";
      description = "Gaps mean no call duration samples for the operation";
      x = 12;
      y = 12;
      w = 12;
      h = 8;
      unit = "s";
      queries = [
        (query "A" (latency "embedding_request_duration_seconds_bucket" "operation") "{{operation}}")
      ];
    })
    (table {
      title = "Embedding cost by source";
      description = "Amounts in the selected range. Reported cost and local estimates are separate. These are not invoice totals";
      x = 0;
      y = 20;
      w = 8;
      h = 8;
      unit = "currencyUSD";
      labels = [ "kind" ];
      valueName = "Cost";
      coloured = false;
      expr = ''sum by (kind) (increase(${metric "embedding_cost_usd_total"}{job="obsidian-thing"}[$__range]))'';
    })
    (table {
      title = "Cache lookups by result";
      description = "Vector cache hits and misses in the selected range";
      x = 8;
      y = 20;
      w = 8;
      h = 8;
      unit = "short";
      labels = [ "result" ];
      valueName = "Lookups";
      coloured = false;
      expr = ''round(sum by (result) (increase(${metric "embedding_cache_total"}{job="obsidian-thing"}[$__range])))'';
    })
    (stat {
      title = "Scan errors in range";
      description = "Errors by scan scope. No data means no error series was recorded";
      x = 16;
      y = 20;
      w = 8;
      h = 8;
      unit = "short";
      thresholds = 1;
      legend = "{{scope}}";
      expr = ''round(sum by (scope) (increase(${metric "index_scan_errors_total"}{job="obsidian-thing"}[$__range])))'';
    })
  ];
}
