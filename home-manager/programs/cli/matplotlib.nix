{ palette, ... }:

let
  # A chart assigns series from this list in order, and the order is the safety mechanism rather
  # than a taste: adjacent entries are what a stacked bar or a multi-line chart puts side by side.
  # Each neighbour pair clears deuteranopia and protanopia (Machado-Oliveira-Fernandes 2009 at
  # severity 1.0) by OKLab distance x100 >= 8, and >= 15 unsimulated. Reordering is a visible
  # change even though no colour moves
  lightCycle = [
    palette.plum
    palette.bow
    palette.rule
    palette.monikaEye
    palette.yuri
  ];

  # Three, not five. The palette is polarised — the same reason base16 draws different accents per
  # variant — and everything else either leaves the dark lightness band or falls under 3:1 on ink
  darkCycle = [
    palette.plum
    palette.bow
    palette.rule
  ];

  # matplotlib wants hex without the "#" everywhere in an rcparam value: the parser treats the
  # rest of the line after a "#" as a comment, so a quoted "#BB5599" is read as an unterminated
  # string and the whole cycler is silently discarded for the stock one
  bare = c: builtins.substring 1 6 c;

  cycler =
    colours: "cycler('color', [${builtins.concatStringsSep ", " (map (c: "'${bare c}'") colours)}])";

  # No axes.grid here: it would mean "on every axes", and a heatmap or an image draws above the
  # grid whatever axisbelow says, so the lines end up cutting across the data. A chart that wants
  # one calls ax.grid(axis="y") for the direction its values actually run
  common = ''
    figure.dpi:          140
    savefig.dpi:         140
    savefig.bbox:        tight
    font.size:           9
    axes.titlesize:      11
    axes.titleweight:    bold
    axes.titlelocation:  left
    axes.spines.top:     False
    axes.spines.right:   False
    axes.axisbelow:      True
    grid.linewidth:      0.7
    legend.frameon:      False
    lines.linewidth:     1.8
  '';

  style =
    {
      ground,
      ink,
      muted,
      grid,
      cycle,
    }:
    ''
      axes.prop_cycle:  ${cycler cycle}

      figure.facecolor:  ${bare ground}
      savefig.facecolor: ${bare ground}
      axes.facecolor:    ${bare ground}
      axes.edgecolor:    ${bare grid}
      grid.color:        ${bare grid}

      text.color:        ${bare ink}
      axes.labelcolor:   ${bare ink}
      axes.titlecolor:   ${bare ink}
      xtick.color:       ${bare muted}
      ytick.color:       ${bare muted}
      xtick.labelcolor:  ${bare ink}
      ytick.labelcolor:  ${bare ink}

    ''
    + common;
in
{
  # matplotlib finds a named style by filename under stylelib/, so the file name is the API:
  # plt.style.use("ddlc"). The colours come from ddlc-palette through commonArgs, so no hex is
  # spelled here — a re-measured colour reaches the charts by a flake update
  xdg.configFile."matplotlib/stylelib/ddlc.mplstyle".text = style {
    ground = palette.paper;
    ink = palette.ink;
    muted = palette.jacket;
    grid = palette.ash;
    cycle = lightCycle;
  };

  xdg.configFile."matplotlib/stylelib/ddlc-dark.mplstyle".text = style {
    ground = palette.ink;
    ink = palette.paper;
    muted = palette.jacket;
    grid = palette.yuri;
    cycle = darkCycle;
  };

  # A colormap is an object, not an rcparam, so it cannot live in a .mplstyle. Importing this
  # registers the four by name, after which they are strings like any built-in: cmap="ddlc_seq"
  xdg.configFile."matplotlib/ddlc_cmaps.py".text = ''
    """DDLC colormaps for matplotlib, registered by name.

    import ddlc_cmaps  # noqa: F401 — registers on import
    plt.imshow(data, cmap="ddlc_seq")

    Sequential runs one hue toward the foreground of its ground, so more-is-darker on paper and
    more-is-lighter on ink. Diverging is two one-hue arms about a neutral middle, so "no
    difference" reads as nothing at all; its midpoint is the only grey in each.
    """

    from matplotlib.colors import LinearSegmentedColormap
    from matplotlib import colormaps

    _MAPS = {
        "ddlc_seq": ["${palette.dot}", "${palette.pink}", "${palette.plum}"],
        "ddlc_seq_dark": ["${palette.plum}", "${palette.pink}", "${palette.dot}"],
        "ddlc_div": [
            "${palette.yuri}",
            "${palette.rule}",
            "${palette.ash}",
            "${palette.bow}",
            "${palette.bowShadow}",
        ],
        "ddlc_div_dark": [
            "${palette.sayoriEye}",
            "${palette.skirt}",
            "${palette.jacket}",
            "${palette.bow}",
            "${palette.sayori}",
        ],
    }

    for _name, _colours in _MAPS.items():
        for _key, _steps in ((_name, _colours), (_name + "_r", _colours[::-1])):
            if _key not in colormaps:
                colormaps.register(LinearSegmentedColormap.from_list(_key, _steps))
  '';
}
