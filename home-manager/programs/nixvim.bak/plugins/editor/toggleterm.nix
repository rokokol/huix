{ ... }:

{
  programs.nixvim.plugins.toggleterm = {
    enable = true;
    settings = {
      open_mapping = "[[<C-t>]]";
      float_opts.border = "curved";
    };
  };
}
