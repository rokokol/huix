{
  lib,
  pkgs,
  ruLayout,
  ...
}:

let
  # `langmap` separates its pairs with `,` and `;`, so those two and `"` are escaped
  langmap = lib.concatMapStringsSep "," (p: p.ru + lib.escape [ "," ";" "\"" ] p.en) ruLayout;
  letters = builtins.filter (p: builtins.match "[A-Za-z]" p.en != null) ruLayout;
  cmdLayout = lib.concatMapStringsSep ", " (p: ''["${p.ru}"] = "${p.en}"'') letters;
in
{
  programs.nixvim = {
    opts = {
      inherit langmap;
      langremap = true;
    };

    extraPlugins = with pkgs; [ vimPlugins.langmapper-nvim ];

    extraConfigLua = ''
      local ok, lm = pcall(require, 'langmapper')

      if not ok then
        return
      end

      -- langmapper's built-in RU layout maps the physical `/?` key to `.`/`,`.
      -- With `hack_keymap` this makes every plugin `/` mapping silently create
      -- a twin on `.`, which overrides the real `.` mappings (e.g.
      -- `.` = set_root in neo-tree). We make this key identity so the
      -- `.`/`,` twins don't multiply; this matches the native `langmap` above,
      -- which drops this pair too
      local ru_layout = require('langmapper.config').config.layouts.ru.layout
      ru_layout = ru_layout:gsub(',ё', '?ё'):gsub('%.$', '/')

      lm.setup({
        hack_keymap = true,
        map_all_ctrl = true,
        layouts = { ru = { layout = ru_layout } },
      })

      lm.automapping({ global = true, buffer = true })

      -- The command-line mode isn't covered by `langmap`/langmapper (only modes
      -- n/v/x/s). So `:` enters cmdline via langmap (Ж -> :), but the command
      -- itself is typed in the active layout: `:q` becomes `:й`.
      --
      -- We translate Cyrillic -> Latin, but ONLY while the cursor is still inside the
      -- *name* of a `:` ex-command (only command-name characters have been typed). As soon
      -- as a space, `/`, `%` or `#` appears, and also for the search prompts `/`?`,
      -- we leave characters as-is, so Cyrillic search patterns and arguments
      -- (`:e файл`, `:s/foo/привет/`) keep working
      local cmd_layout = { ${cmdLayout} }

      for cyr, lat in pairs(cmd_layout) do
        vim.keymap.set("c", cyr, function()
          if vim.fn.getcmdtype() == ":" and not vim.fn.getcmdline():find("[%s/%%#]") then
            return lat
          end
          return cyr
        end, { expr = true, desc = "Layout-agnostic ex-command name" })
      end
    '';
  };
}
