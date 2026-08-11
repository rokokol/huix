{ config, lib, ... }:

{
  programs.nixvim = {
    plugins.bufferline = {
      enable = true;
      # Its highlights go in with default = true otherwise, and nvim_set_hl then refuses to
      # touch a group that already exists — which is every one of them on a second pass
      settings.options.themable = false;
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

    # bufferline shades its bar out of Normal when it sets up, and that is before anything can
    # clear the ground, so the tabline keeps a tint of a background nothing draws any more.
    # These are the two calls it makes itself on a colorscheme change, and mkAfter puts them
    # behind the sweep
    extraConfigLuaPost = lib.mkIf config.rokokol.nixvim.transparent (lib.mkAfter ''
      require("bufferline.highlights").set_all(require("bufferline.config").update_highlights())
    '');
  };
}
