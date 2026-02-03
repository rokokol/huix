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
                Text = "(Txt)", Method = "(Met)", Function = "(Fnc)",
                Constructor = "(Con)", Field = "(Fld)", Variable = "(Var)",
                Class = "(Cls)", Interface = "(Int)", Module = "(Mod)",
                Property = "(Prp)", Unit = "(Unt)", Value = "(Val)",
                Enum = "(Enm)", Keyword = "(Key)", Snippet = "(Snp)",
                Color = "(Col)", File = "(Fil)", Reference = "(Ref)",
                Folder = "(Fol)", EnumMember = "(Mem)", Constant = "(Cst)",
                Struct = "(Str)", Event = "(Evt)", Operator = "(Opr)",
                TypeParameter = "(Typ)"
              }
              vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind] or "", vim_item.kind)
              return vim_item
            end
          '';
        };
      };
    };

    luasnip.enable = true;
  };
}
