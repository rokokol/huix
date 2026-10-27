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
      title = "Collection age";
      x = 16;
      y = 35;
      w = 8;
      unit = "s";
      queries = [ (query "A" roles.series-1 "time() - hermes_collect_timestamp_seconds" "Age") ];
    })
  ];
}
