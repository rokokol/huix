{ ... }:

{
  programs.nixvim.plugins = {
    # --- Language Servers ---
    lsp = {
      enable = true;
      inlayHints = true;
      servers = {
        nixd.enable = true;
        pyright.enable = true;
        clangd.enable = true;
        lua_ls.enable = true;
        bashls.enable = true;
        html.enable = true;
        cssls.enable = true;
        marksman.enable = true;
        hyprls.enable = true;
      };
    };

    # --- Formatting & Linting ---
    none-ls = {
      enable = true;
      sources = {
        formatting.nixfmt.enable = true;
        formatting.black.enable = true;
        formatting.shfmt.enable = true;
        diagnostics.deadnix.enable = true;
      };
    };

    # --- LSP UI ---
    lspsaga = {
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

    lsp-lines.enable = true;

    # Doesn't work
    # plugins.otter = {
    #   enable = true;
    #   settings = {
    #     languages = [
    #       "html"
    #       "css"
    #       "bash"
    #       "python"
    #       "hyprlang"
    #       "lua"
    #     ];
    #     handle_leading_whitespace = true;
    #   };
    # };

    # Function argument signatures
    lsp-signature = {
      enable = true;
      settings = {
        bind = true;
        floating_window = false;
        always_trigger = false;
        hint_enable = false; # Disable inlay hints to avoid duplication
        handler_opts.border = "rounded";
        toggle_key = "<C-x>";
      };
    };
  };
}
