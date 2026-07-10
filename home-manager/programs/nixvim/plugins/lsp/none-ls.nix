{ ... }:

{
  programs.nixvim.plugins.none-ls = {
    enable = true;
    sources = {
      formatting.nixfmt.enable = true;
      formatting.black.enable = true;
      formatting.shfmt.enable = true;
      formatting.prettier.enable = true;
      formatting.prettier.disableTsServerFormatter = true;
      diagnostics.deadnix.enable = true;
    };
  };
}
