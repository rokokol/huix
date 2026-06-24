{ ... }:

{
  programs.nixvim.plugins.treesitter = {
    enable = true;
    nixGrammars = true;
    settings = {
      indent.enable = true;
      highlight.enable = true;
      ensure_installed = [
        "markdown"
        "markdown_inline"
        "bash"
        "css"
        "html"
        "hyprlang"
        "json"
        "arduino"
        "matlab"
      ];
    };
  };
}
