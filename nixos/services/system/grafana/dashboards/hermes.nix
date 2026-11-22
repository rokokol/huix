{ roles, panels }:

let
  inherit (panels) stat states table;
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
      x = 0;
      y = 0;
      w = 8;
      unit = "short";
      expr = "min(hermes_gateway_up)";
      mappings = upDown;
    })
    (stat {
      title = "Active agents";
      x = 8;
      y = 0;
      w = 8;
      unit = "short";
      expr = "sum(hermes_gateway_active_agents)";
    })
    (stat {
      title = "Overdue jobs";
      x = 16;
      y = 0;
      w = 8;
      unit = "short";
      thresholds = 1;
      expr = "sum(hermes_cron_jobs_overdue)";
    })
    (states {
      title = "Platform availability";
      x = 0;
      y = 4;
      w = 12;
      expr = "min by (hermes_platform) (hermes_platform_up)";
      legend = "{{hermes_platform}}";
      mappings = upDown;
    })
    (states {
      title = "Collector results";
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
