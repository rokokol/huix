{ roles, panels }:

let
  inherit (panels)
    panel
    query
    stat
    states
    table
    ;
  upDown = {
    "0" = {
      text = "Down";
      color = roles.danger;
    };
    "1" = {
      text = "Up";
      color = roles.ok;
    };
  };
in
panels.dashboard {
  uid = "hermes";
  title = "Hermes";
  tags = [
    "ai"
    "agent"
  ];
  links = [
    {
      title = "AI Spend";
      type = "link";
      url = "/d/ai-spend/ai-spend";
    }
  ];
  panels = [
    (stat {
      title = "Gateway";
      description = "Whether the Hermes gateway reports that it is running";
      x = 0;
      y = 0;
      w = 8;
      unit = "short";
      expr = "min(hermes_gateway_up)";
      mappings = upDown;
    })
    (panel {
      title = "Active agents";
      description = "Agents active in the gateway at each sample";
      x = 8;
      y = 0;
      w = 8;
      h = 4;
      unit = "short";
      min = 0;
      bars = true;
      queries = [ (query "A" "sum(hermes_gateway_active_agents)" "Active agents") ];
    })
    (stat {
      title = "Overdue jobs";
      description = "Scheduled Hermes jobs that are past their expected run time";
      x = 16;
      y = 0;
      w = 8;
      unit = "short";
      thresholds = 1;
      expr = "sum(hermes_cron_jobs_overdue)";
    })
    (states {
      title = "Platform availability";
      description = "Connection status reported by the Hermes gateway for each platform";
      x = 0;
      y = 4;
      w = 12;
      expr = "min by (hermes_platform) (hermes_platform_up)";
      legend = "{{hermes_platform}}";
      mappings = upDown;
    })
    (states {
      title = "Collector results";
      description = "Whether each Hermes monitor data source was read successfully";
      x = 12;
      y = 4;
      w = 12;
      expr = "min by (source) (hermes_collect_success)";
      legend = "{{source}}";
      mappings = {
        "0" = {
          text = "Failed";
          color = roles.danger;
        };
        "1" = {
          text = "OK";
          color = roles.ok;
        };
      };
    })
    (table {
      title = "Recorded sessions by source";
      x = 0;
      y = 12;
      w = 12;
      h = 7;
      expr = "sum by (source) (hermes_sessions) > 0";
      unit = "short";
      labels = [ "source" ];
      valueName = "Sessions";
      sortDesc = true;
      coloured = false;
      description = "All sessions in the state database at the end of the selected range";
    })
    (table {
      title = "Recorded skill events";
      x = 12;
      y = 12;
      w = 12;
      h = 7;
      expr = "topk(10, sum by (skill, action) (hermes_skill_events) > 0)";
      unit = "short";
      labels = [
        "skill"
        "action"
      ];
      valueName = "Events";
      sortDesc = true;
      coloured = false;
      description = "The ten most frequent skill and action pairs in the collector state";
    })
  ];
}
