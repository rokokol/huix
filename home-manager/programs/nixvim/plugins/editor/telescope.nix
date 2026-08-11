{ base16, ... }:

let
  c = base16.dark;
  # No ground of its own, the way gruvbox has it: the pane is whatever the window behind it is,
  # and the frame carries the shape. base16-nvim instead darkens base00 and base02 into a slab —
  # and its darken() hands base00 back unchanged, which kitty then draws at background_opacity,
  # so the panes came out a hole with a bar floating over them
  pane = { fg = c.base05; };
  frame = { fg = c.base04; };
in
{
  imports = [ ./telescope-helpers.nix ];

  programs.nixvim = {
    highlightOverride = {
      TelescopeNormal = pane;
      TelescopeResultsNormal = pane;
      TelescopePreviewNormal = pane;
      TelescopePromptNormal = pane;

      TelescopeBorder = frame;
      TelescopeResultsBorder = frame;
      TelescopePreviewBorder = frame;
      TelescopePromptBorder = frame;

      TelescopeTitle.fg = c.base04;
      TelescopeResultsTitle.fg = c.base04;
      TelescopePreviewTitle.fg = c.base0B;
      TelescopePromptTitle.fg = c.base0E;
      TelescopePromptPrefix.fg = c.base0E;

      TelescopeSelection.bg = c.base02;
      TelescopeSelectionCaret.fg = c.base0E;
      TelescopeMultiSelection.fg = c.base03;
      TelescopeMatching.fg = c.base0A;
      TelescopePreviewLine.bg = c.base01;
    };

    dependencies = {
      chafa.enable = true;
      poppler-utils.enable = true;
    };

    plugins.telescope = {
      enable = true;
      settings.defaults =
        let
          # i and n share one set of preview scroll binds
          scrollMappings = {
            "<M-k>".__raw = "require('telescope.actions').preview_scrolling_up";
            "<M-j>".__raw = "require('telescope.actions').preview_scrolling_down";
            "<M-h>".__raw = "require('telescope.actions').preview_scrolling_left";
            "<M-l>".__raw = "require('telescope.actions').preview_scrolling_right";
          };
        in
        {
          layout_strategy = "vertical";
          layout_config = {
            vertical = {
              mirror = true;
              prompt_position = "top";
              preview_height = 0.5;
            };
          };
          mappings = {
            i = scrollMappings;
            n = scrollMappings;
          };
        };

      extensions.fzf-native.enable = true;
    };
  };
}
