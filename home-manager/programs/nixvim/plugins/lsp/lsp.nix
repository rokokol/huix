{ ... }:

{
  programs.nixvim.plugins.lsp = {
    enable = true;
    inlayHints = true;
    servers = {
      nixd.enable = true;
      pyright.enable = true;
      lua_ls.enable = true;
      bashls.enable = true;
      html.enable = true;
      cssls.enable = true;
      ts_ls.enable = true;
      eslint.enable = true;
      jsonls.enable = true;
      emmet_language_server.enable = true;
      marksman.enable = true;
      hyprls.enable = true;
      texlab.enable = true;
      clangd.enable = true;
    };
  };
}
