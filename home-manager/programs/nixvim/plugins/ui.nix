{
  programs.nixvim.plugins = {
    lualine.enable = true;
    web-devicons.enable = true;

    bufferline = {
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

    # Image rendering in terminal
    image = {
      enable = true;
      backend = "kitty";
      integrations.telescope = true;
    };
  };
}
