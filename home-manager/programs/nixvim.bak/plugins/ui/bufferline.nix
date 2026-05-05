{ ... }:

{
  programs.nixvim.plugins.bufferline = {
    enable = true;
    settings.options.offsets = [
      {
        filetype = "neo-tree";
        text = "File Explorer";
        highlight = "Directory";
        separator = true;
        text_align = "left";
      }
    ];
  };
}
