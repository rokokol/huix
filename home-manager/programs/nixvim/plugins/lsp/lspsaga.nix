{ ... }:

{
  programs.nixvim.plugins.lspsaga = {
    enable = true;
    settings = {
      lightbulb.enable = true;
      ui.border = "rounded";
      symbol_in_winbar.enable = true;
      hover = {
        max_width = 0.6;
        open_link = "gx";
        open_browser = "!firefox";
      };
    };
  };
}
