{ inputs, ... }:

{
  # The styles and colormaps render in ddlc-terminal-themes now, out of ddlc-palette like the
  # rest of the family. The filenames stay the API — plt.style.use("ddlc"), import ddlc_cmaps
  imports = [ inputs.ddlc-terminal-themes.homeModules.default ];

  ddlc.matplotlib.enable = true;
}
