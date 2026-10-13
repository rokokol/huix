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
          color.mode = "thresholds";
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
          custom.cellOptions.type = "color-text";
        };
        overrides = [
          {
            matcher = {
              id = "byName";
              options = "Value";
            };
            properties = [
              {
                id = "unit";
                value = unit;
              }
            ];
          }
        ];
      };
      transformations = [
        {
          id = "organize";
          options.includeByName = lib.genAttrs (labels ++ [ "Value" ]) (_: true);
        }
      ];
      options.showHeader = true;
    };

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
