{
  lib,
  roles,
  datasource,
}:

# The pieces every dashboard here is built of, as Grafana's JSON model. Every colour is a role of
# ddlc-themes. Grafana keeps one colour per series whatever its theme, so the colours are the dark
# roles and the UI is dark too. No series takes series-2: it is the red of danger, and a plain
# line in it reads as an alarm
rec {
  ds = {
    type = "prometheus";
    uid = datasource;
  };

  fixed = color: {
    mode = "fixed";
    fixedColor = color;
  };

  # One series of a query; its colour stays fixed, so a host looks the same on every visit
  query = refId: color: expr: legend: {
    target = {
      inherit refId expr;
      datasource = ds;
      legendFormat = legend;
    };
    override = {
      matcher = {
        id = "byFrameRefID";
        options = refId;
      };
      properties = [
        {
          id = "color";
          value = fixed color;
        }
      ];
    };
  };

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
      # A query of several series takes shades of its colour instead of one fixed colour
      shaded ? false,
      thresholds ? null,
      dangerBelow ? false,
    }:
    {
      type = "timeseries";
      inherit title;
      datasource = ds;
      gridPos = {
        inherit x y w;
        h = 8;
      };
      targets = map (q: q.target) queries;
      fieldConfig = {
        defaults = {
          inherit unit;
          color =
            if shaded then
              {
                mode = "shades";
                fixedColor = roles.series-1;
              }
            else
              fixed roles.series-1;
          custom = {
            lineWidth = 2;
            fillOpacity = 10;
            spanNulls = false;
            thresholdsStyle.mode = if thresholds == null then "off" else "dashed";
          };
          thresholds = thresholdSteps thresholds dangerBelow;
        }
        // lib.optionalAttrs (min != null) { inherit min; }
        // lib.optionalAttrs (max != null) { inherit max; };
        overrides = lib.optionals (!shaded) (map (q: q.override) queries);
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
        tooltip.mode = "multi";
      };
    };

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
      targets = [ (query "A" roles.series-1 expr legend).target ];
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
    };

  # The current values of a query, one line each, coloured past the threshold
  table =
    {
      title,
      x,
      y,
      w,
      h ? 8,
      expr,
      unit,
      thresholds ? null,
      dangerBelow ? false,
      # The labels shown beside the value, by name; every other label is hidden
      labels,
      # The heading of the value's column
      valueName ? "Value",
      # true for the largest value first, false for the smallest, null for the labels' order
      sortDesc ? null,
      # false for a value that is a fact rather than good or bad
      coloured ? true,
    }:
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
      targets = [
        (
          (query "A" roles.series-1 expr "").target
          // {
            instant = true;
            format = "table";
          }
        )
      ];
      fieldConfig = {
        defaults = {
          thresholds = thresholdSteps thresholds dangerBelow;
          # Grafana's own minimum, 150px, leaves no room for the value in a narrow panel
          custom.minWidth = 60;
        };
        overrides = [
          {
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
          }
        ];
      };
      transformations = [
        {
          id = "organize";
          options.includeByName = lib.genAttrs (labels ++ [ "Value" ]) (_: true);
        }
      ];
      options = {
        showHeader = true;
      }
      // lib.optionalAttrs (sortDesc != null) {
        sortBy = [
          {
            displayName = valueName;
            desc = sortDesc;
          }
        ];
      };
    };

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
      targets = [ ((query "A" roles.series-1 expr legend).target // { instant = true; }) ];
      fieldConfig = {
        defaults = {
          inherit unit;
          min = 0;
          color = fixed roles.series-1;
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
    };

  # Who knocks on a node: the addresses a jail found most in the last day and the latest bans, as
  # each kind of node pushes them under its own prefix. The jail says what a row is
  attackers = prefix: selector: y: [
    (table {
      title = "Addresses found most in a day";
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
