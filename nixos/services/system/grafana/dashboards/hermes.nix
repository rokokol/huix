{ roles, panels }:

let
  inherit (panels)
    panel
    query
    row
    states
    table
    ;
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
  uid = "hermes";
  title = "Hermes";
  panels = [
    (row "OpenRouter" null 0)
    (panel {
      title = "Account balance";
      x = 0;
      y = 1;
      w = 8;
      unit = "currencyUSD";
      queries = [ (query "A" roles.series-1 "openrouter_balance_usd" "Balance") ];
    })
    (panel {
      title = "Key spend";
      x = 8;
      y = 1;
      w = 8;
      unit = "currencyUSD";
      decimals = 2;
      queries = [
        (query "A" roles.series-1 "openrouter_key_usage_daily_usd" "Current UTC day")
        (query "B" roles.series-3 "openrouter_key_usage_monthly_usd" "Current UTC month")
      ];
    })
    (panel {
      title = "Budget remaining";
      x = 16;
      y = 1;
      w = 8;
      unit = "currencyUSD";
      shaded = true;
      queries = [
        (query "A" roles.series-1 "openrouter_budget_remaining_usd" "{{scope}} / {{interval}} / {{layer}}")
      ];
    })
    (row "Sessions and skills" null 9)
    (panel {
      title = "Sessions by source";
      x = 0;
      y = 10;
      w = 12;
      unit = "short";
      shaded = true;
      queries = [ (query "A" roles.series-1 "hermes_sessions" "{{source}}") ];
    })
    (panel {
      title = "Recorded tokens";
      x = 12;
      y = 10;
      w = 12;
      unit = "short";
      queries = [
        (query "A" roles.series-1 "hermes_input_tokens" "Input")
        (query "B" roles.series-3 "hermes_output_tokens" "Output")
      ];
    })
    (table {
      title = "Skill events";
      x = 0;
      y = 18;
      w = 24;
      expr = "hermes_skill_events";
      unit = "short";
      labels = [
        "skill"
        "action"
      ];
      valueName = "Events";
      sortDesc = true;
      coloured = false;
    })
    (row "Service health" null 26)
    (states {
      title = "Gateway";
      x = 0;
      y = 27;
      w = 8;
      expr = "max(hermes_gateway_up)";
      legend = "Gateway";
      mappings = upDown;
    })
    # The state label changes with the state, so one platform keeps one band only aggregated
    (states {
      title = "Platforms";
      x = 8;
      y = 27;
      w = 8;
      expr = "max by (hermes_platform) (hermes_platform_up)";
      legend = "{{hermes_platform}}";
      mappings = upDown;
    })
    (panel {
      title = "Active work";
      x = 16;
      y = 27;
      w = 8;
      unit = "short";
      queries = [
        (query "A" roles.series-1 "hermes_gateway_active_agents" "Active agents")
        (query "B" roles.series-3 "hermes_gateway_background_work" "Background work")
      ];
    })
    (states {
      title = "Collection status";
      x = 8;
      y = 35;
      w = 8;
      expr = "hermes_collect_success";
      legend = "{{source}}";
      mappings = {
        "0" = {
          text = "failed";
          color = roles.danger;
        };
        "1" = {
          text = "ok";
          color = roles.ok;
        };
      };
    })
    (panel {
      title = "Cron jobs";
      x = 0;
      y = 35;
      w = 8;
      unit = "short";
      queries = [
        (query "A" roles.series-1 "hermes_cron_jobs_enabled" "Enabled")
        (query "B" roles.series-3 "hermes_cron_jobs_running" "Running")
        (query "C" roles.series-4 "hermes_cron_jobs_overdue" "Overdue")
      ];
    })
    (panel {
      title = "Time since the last usage sample";
      x = 16;
      y = 35;
      w = 8;
      unit = "s";
      queries = [
        (query "A" roles.series-1 "time() - hermes_collect_timestamp_seconds" "hermes-monitor")
      ];
    })
    # Pushed by the cron scripts themselves through the station's pushgateway: the Go
    # allowance windows come from opencode-go-usage, the per-day model costs from
    # model-price-watch. Both are no_agent crons, so nothing here costs a token.
    (row "Cron reports" null 43)
    (panel {
      title = "OpenCode Go windows";
      description = "Share of each allowance window already spent on the Go plan: the rolling 5 hours, the week and the month. 100 % means the window is used up, and the allowance is shared by every host that uses the key, not just Hermes";
      x = 0;
      y = 44;
      w = 8;
      unit = "percent";
      max = 100;
      queries = [
        (query "A" roles.series-1 "mya_go_window_percent{window=\"5h\"}" "5 hours")
        (query "B" roles.series-3 "mya_go_window_percent{window=\"week\"}" "week")
        (query "C" roles.series-4 "mya_go_window_percent{window=\"month\"}" "month")
      ];
    })
    (panel {
      title = "Hermes spend on Go this month";
      description = "USD Hermes itself recorded against the Go plan this month, from state.db, as a total and per model. Whatever the account windows show beyond this figure is spent by other hosts";
      x = 8;
      y = 44;
      w = 8;
      unit = "currencyUSD";
      decimals = 2;
      queries = [
        (query "A" roles.series-1 "mya_go_hermes_month_usd" "total")
        (query "B" roles.series-3 "mya_go_hermes_month_usd_by_model" "{{model}}")
      ];
    })
    (panel {
      title = "Model price per day";
      description = "What one day of his real token profile costs on the host each model is routed to: 3.9M input, 98M cache reads and 505k output tokens. A flat line means the price did not move";
      x = 16;
      y = 44;
      w = 8;
      unit = "currencyUSD";
      decimals = 2;
      queries = [ (query "A" roles.series-1 "mya_price_usd_per_day" "{{model}} at {{host}}") ];
    })
    (panel {
      title = "Cheapest host per model";
      description = "The cheapest other host carrying the same model, priced on the same daily profile. The gap against the host he pays is what a re-route would save; an fp4 host trades precision for the lower price";
      x = 0;
      y = 52;
      w = 12;
      unit = "currencyUSD";
      decimals = 2;
      shaded = true;
      queries = [ (query "A" roles.series-1 "mya_price_cheapest_usd_per_day" "{{model}} at {{host}}") ];
    })
    (panel {
      title = "Time since the last price watch";
      description = "Seconds since model-price-watch last pushed its numbers. The cron ticks every 15 minutes, so anything above about 20 minutes means the watcher stopped rather than that nothing changed";
      x = 12;
      y = 52;
      w = 12;
      unit = "s";
      queries = [ (query "A" roles.series-1 "time() - mya_price_last_run" "model-price-watch") ];
    })
  ];
}
