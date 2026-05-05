{ ... }:

{
  programs.nixvim.plugins.lsp-signature = {
    enable = true;
    settings = {
      bind = true;
      floating_window = false;
      always_trigger = false;
      hint_enable = false;
      handler_opts.border = "rounded";
      toggle_key = "<C-x>";
    };
  };
}
