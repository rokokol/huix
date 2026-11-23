{
  lib,
  roles,
  datasource,
}:

# The pieces every dashboard uses in Grafana's JSON model
rec {
  ds = {
    type = "prometheus";
    uid = datasource;
  };

  query = refId: expr: legend: {
    inherit refId expr;
    datasource = ds;
    legendFormat = legend;
  };

  seriesColor.mode = "palette-classic-by-name";

  # The danger threshold is a line on a graph and the colour of a value past it, above it or,
  # with dangerBelow, under it
  thresholdSteps =
    threshold: dangerBelow:
    let
      bottom = if dangerBelow then roles.danger else roles.ok;
      top = if dangerBelow then roles.ok else roles.danger;
    in
    {
      mode = "absolute";
      steps = [
        {
          color = bottom;
          value = null;
        }
      ]
      ++ lib.optional (threshold != null) {
        color = top;
        value = threshold;
      };
    };

  panel =
    {
      title,
      x,
      y,
      w,
      unit,
      queries,
      min ? null,
      max ? null,
      # The axis starts at this value and grows past it when the data needs room
      softMax ? null,
      thresholds ? null,
      dangerBelow ? false,
      decimals ? null,
      h ? 8,
      bars ? false,
      steps ? false,
      interval ? null,
      # Shown as the panel's info tooltip: a series name alone does not say what is measured
      description ? null,
    }:
    {
      type = "timeseries";
      inherit title;
      datasource = ds;
      gridPos = {
        inherit
          x
          y
          w
          h
          ;
      };
      targets = map (
        q:
        q
        // {
          instant = false;
          range = true;
        }
        // lib.optionalAttrs (interval != null) { inherit interval; }
      ) queries;
      fieldConfig = {
        defaults = {
          inherit unit;
          color = seriesColor;
          custom = {
            lineWidth = 2;
            fillOpacity = 10;
            spanNulls = false;
            thresholdsStyle.mode = if thresholds == null then "off" else "dashed";
          }
          // lib.optionalAttrs (softMax != null) { axisSoftMax = softMax; }
          // lib.optionalAttrs steps { lineInterpolation = "stepAfter"; }
          // lib.optionalAttrs bars {
            drawStyle = "bars";
            barAlignment = -1;
            barWidthFactor = 0.9;
            fillOpacity = 80;
            lineWidth = 0;
          };
          thresholds = thresholdSteps thresholds dangerBelow;
        }
        // lib.optionalAttrs (min != null) { inherit min; }
        // lib.optionalAttrs (max != null) { inherit max; }
        // lib.optionalAttrs (decimals != null) { inherit decimals; };
        overrides = [ ];
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
          showLegend = true;
        };
        tooltip.mode = "multi";
      };
    }
    # Grafana draws the info icon only when the key is present, so an absent description must
    # stay absent rather than become an empty string
    // lib.optionalAttrs (description != null) { inherit description; }
    // lib.optionalAttrs (interval != null) { inherit interval; };

  stat =
    {
      title,
      x,
      y,
      w,
      h ? 4,
      unit,
      expr,
      legend ? "",
      thresholds ? null,
      dangerBelow ? false,
      decimals ? null,
      description ? null,
      mappings ? { },
    }:
    {
      type = "stat";
      inherit title;
      datasource = ds;
      gridPos = {
        inherit
          x
          y
          w
          h
          ;
      };
      targets = [
        (
          (query "A" expr legend)
          // {
            instant = true;
            range = false;
          }
        )
      ];
      fieldConfig = {
        defaults = {
          inherit unit;
          noValue = "No data";
          thresholds = thresholdSteps thresholds dangerBelow;
          mappings = [
            {
              type = "special";
              options = {
                match = "null";
                result = {
                  text = "No data";
                  color = roles.muted;
                };
              };
            }
          ]
          ++ lib.optional (mappings != { }) {
            type = "value";
            options = mappings;
          };
        }
        // lib.optionalAttrs (decimals != null) { inherit decimals; };
        overrides = [ ];
      };
      options = {
        graphMode = "none";
        colorMode = if thresholds != null || mappings != { } then "value" else "none";
        textMode = if legend == "" then "value" else "value_and_name";
        reduceOptions.calcs = [ "lastNotNull" ];
      };
    }
    // lib.optionalAttrs (description != null) { inherit description; };

  # The state of each series over time, as a band: a value maps to a word and a colour
  states =
    {
      title,
      x,
      y,
      w,
      h ? 8,
      expr,
      legend,
      mappings,
      description ? null,
    }:
    {
      type = "state-timeline";
      inherit title;
      datasource = ds;
      gridPos = {
        inherit
          x
          y
          w
          h
          ;
      };
      targets = [ (query "A" expr legend) ];
      fieldConfig = {
        defaults = {
          # Under "thresholds" a state timeline paints every state the base colour and drops
          # the colour of each mapping
          color.mode = "fixed";
          mappings = [
            {
              type = "value";
              options = mappings;
            }
          ];
        };
        overrides = [ ];
      };
      options = {
        showValue = "never";
        mergeValues = true;
        legend.showLegend = false;
      };
    }
    // lib.optionalAttrs (description != null) { inherit description; };

  # The current values of a query, one line each, coloured past the threshold
  table =
    {
      title,
      x,
      y,
      w,
      h ? 8,
      expr ? null,
      # Several expressions become one column each: with `instant = false` Grafana answers a
      # range query with a row per step, which turns a per-day figure into a per-day table
      queries ? null,
      unit,
      thresholds ? null,
      dangerBelow ? false,
      # The labels shown beside the value, by name; every other label is hidden
      labels ? [ ],
      # Set the value heading to null to show only the labels
      valueName ? "Value",
      # true for the largest value first, false for the smallest, null for the labels' order
      sortDesc ? null,
      # false for a value that is a fact rather than good or bad
      coloured ? true,
      instant ? true,
      # The smallest step the datasource may take, so a range table groups by a whole day
      interval ? null,
      # Shown as the panel's info tooltip: a series name alone does not say what is measured
      description ? null,
    }:
    let
      single = [ (query "A" expr "") ];
      targets = map (
        target:
        target
        // {
          inherit instant;
          range = !instant;
          format = "table";
        }
        // lib.optionalAttrs (interval != null) { inherit interval; }
      ) (if queries != null then queries else single);
      # A row of labels is what the filters and the value column address; a table of several
      # expressions keeps the series names instead
      byValue = labels != [ ];
    in
    {
      type = "table";
      inherit title;
      datasource = ds;
      gridPos = {
        inherit
          x
          y
          w
          h
          ;
      };
      inherit targets;
      fieldConfig = {
        defaults = {
          thresholds = thresholdSteps thresholds dangerBelow;
          # Grafana's own minimum, 150px, leaves no room for the value in a narrow panel
          custom.minWidth = 60;
        };
        overrides = lib.optional (byValue && valueName != null) {
          matcher = {
            id = "byName";
            options = "Value";
          };
          # The value alone is coloured: a label is text, which no threshold reaches, so it
          # would take the base colour
          properties = [
            {
              id = "unit";
              value = unit;
            }
            {
              id = "displayName";
              value = valueName;
            }
          ]
          ++ lib.optional coloured {
            id = "custom.cellOptions";
            value.type = "color-text";
          };
        };
      };
      transformations = lib.optional byValue {
        id = "organize";
        options.includeByName = lib.genAttrs (labels ++ lib.optional (valueName != null) "Value") (_: true);
      };
      options = {
        showHeader = true;
      }
      // lib.optionalAttrs (sortDesc != null && byValue && valueName != null) {
        sortBy = [
          {
            displayName = valueName;
            desc = sortDesc;
          }
        ];
      };
    }
    // lib.optionalAttrs (description != null) { inherit description; };

  # The current value of each series as a bar, the largest first
  bars =
    {
      title,
      x,
      y,
      w,
      h ? 8,
      expr,
      legend,
      unit,
      description ? null,
    }:
    {
      type = "bargauge";
      inherit title;
      datasource = ds;
      gridPos = {
        inherit
          x
          y
          w
          h
          ;
      };
      targets = [ ((query "A" expr legend) // { instant = true; }) ];
      fieldConfig = {
        defaults = {
          inherit unit;
          min = 0;
          color = seriesColor;
        };
        overrides = [ ];
      };
      # The series turned into rows so that they can be sorted: a bar gauge keeps the order its
      # frames arrive in, which is the labels' order
      transformations = [
        {
          id = "reduce";
          options = {
            reducers = [ "lastNotNull" ];
            mode = "seriesToRows";
          };
        }
        {
          id = "sortBy";
          options.sort = [
            {
              field = "Last *";
              desc = true;
            }
          ];
        }
      ];
      options = {
        orientation = "horizontal";
        displayMode = "basic";
        showUnfilled = true;
        reduceOptions = {
          values = true;
          calcs = [ ];
          fields = "/^Last/";
        };
      };
    }
    // lib.optionalAttrs (description != null) { inherit description; };

  # Who knocks on a node: the addresses a jail found most in the last day and the latest bans, as
  # each kind of node pushes them under its own prefix. The jail says what a row is
  attackers = prefix: selector: y: [
    (table {
      title = "Addresses found most in a day";
      description = "IP addresses with the most fail2ban findings during the reported day, by jail";
      x = 0;
      inherit y;
      w = 12;
      expr = "${prefix}_fail2ban_top_attempts{${selector}}";
      unit = "short";
      labels = [
        "instance"
        "jail"
        "ip"
      ];
      valueName = "findings";
      sortDesc = true;
      coloured = false;
    })
    (table {
      title = "Latest bans";
      description = "Time since the latest reported ban of each IP address, by jail";
      x = 12;
      inherit y;
      w = 12;
      expr = "time() - ${prefix}_fail2ban_recent_ban_timestamp_seconds{${selector}}";
      unit = "s";
      labels = [
        "instance"
        "jail"
        "ip"
      ];
      valueName = "ago";
      sortDesc = false;
      coloured = false;
    })
  ];

  row = title: repeat: y: {
    type = "row";
    inherit title repeat;
    collapsed = false;
    gridPos = {
      inherit y;
      x = 0;
      w = 24;
      h = 1;
    };
    panels = [ ];
  };

  # A selector of every value that a label takes in a series
  variable =
    name: series: label:
    let
      values = "label_values(${series}, ${label})";
    in
    {
      inherit name;
      type = "query";
      datasource = ds;
      query = {
        query = values;
        refId = name;
      };
      definition = values;
      refresh = 2;
      multi = true;
      includeAll = true;
      current = {
        text = [ "All" ];
        value = [ "$__all" ];
      };
      sort = 1;
    };

  # The settings every dashboard here shares
  dashboard =
    attrs:
    {
      editable = false;
      schemaVersion = 39;
      time = {
        from = "now-24h";
        to = "now";
      };
      refresh = "30s";
    }
    // attrs;
}
