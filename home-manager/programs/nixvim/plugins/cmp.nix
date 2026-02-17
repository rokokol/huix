{ ... }:

{
  programs.nixvim.plugins = {
    cmp = {
      enable = true;
      settings = {
        window = {
          completion.border = "rounded";
          documentation.border = "rounded";
        };
        performance.max_view_entries = 10;
        mapping = {
          "<C-Space>" = "cmp.mapping.complete()";
          "<C-d>" = "cmp.mapping.scroll_docs(-4)";
          "<C-f>" = "cmp.mapping.scroll_docs(4)";
          "<C-e>" = "cmp.mapping.close()";
          # "<CR>" = "cmp.mapping.confirm({ select = true })";
          "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
          "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
        };
        sources = [
          { name = "nvim_lsp"; }
          { name = "path"; }
          { name = "buffer"; }
          { name = "luasnip"; }
          { name = "otter"; }
        ];
        formatting = {
          fields = [
            "kind"
            "abbr"
            "menu"
          ];
          format = ''
            function(entry, vim_item)
              local kind_icons = {
                Text = "󰉿", Method = "󰆧", Function = "󰊕",
                Constructor = "", Field = "󰜢", Variable = "󰀫",
                Class = "󰠱", Interface = "", Module = "",
                Property = "󰜢", Unit = "󰙅", Value = "󰎠",
                Enum = "", Keyword = "󰌋", Snippet = "",
                Color = "󰏘", File = "󰈙", Reference = "󰬲",
                Folder = "󰉋", EnumMember = "", Constant = "󰏿",
                Struct = "󰙅", Event = "", Operator = "󰆕",
                TypeParameter = "󰏫"
                }
              vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind] or "", vim_item.kind)

              vim_item.menu = ({
                nvim_lsp = "[LSP]",
                luasnip  = "[Snip]",
                buffer   = "[Buf]",
                path     = "[Path]",
              })[entry.source.name]

              return vim_item
            end
          '';
        };
      };
    };

    luasnip.enable = true;
  };
}
