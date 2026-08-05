{ lib, pkgs, ... }:

let
  langmap = lib.concatStringsSep "," [
    "йq"
    "цw"
    "уe"
    "кr"
    "еt"
    "нy"
    "гu"
    "шi"
    "щo"
    "зp"
    "х["
    "ъ]"
    "фa"
    "ыs"
    "вd"
    "аf"
    "пg"
    "рh"
    "оj"
    "лk"
    "дl"
    "ж\\;"
    "э'"
    "яz"
    "чx"
    "сc"
    "мv"
    "иb"
    "тn"
    "ьm"
    "б\\,"
    "ю."
    "ЙQ"
    "ЦW"
    "УE"
    "КR"
    "ЕT"
    "НY"
    "ГU"
    "ШI"
    "ЩO"
    "ЗP"
    "Х{"
    "Ъ}"
    "ФA"
    "ЫS"
    "ВD"
    "АF"
    "ПG"
    "РH"
    "ОJ"
    "ЛK"
    "ДL"
    "Ж:"
    "Э\\\""
    "ЯZ"
    "ЧX"
    "СC"
    "МV"
    "ИB"
    "ТN"
    "ЬM"
    "Б<"
    "Ю>"
  ];
in

{
  programs.nixvim = {
    opts = {
      langmap = langmap;
      langremap = true;
    };

    extraPlugins = [
      pkgs.vimPlugins.langmapper-nvim
    ];

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
      local cmd_layout = {
        ["й"] = "q", ["ц"] = "w", ["у"] = "e", ["к"] = "r", ["е"] = "t",
        ["н"] = "y", ["г"] = "u", ["ш"] = "i", ["щ"] = "o", ["з"] = "p",
        ["ф"] = "a", ["ы"] = "s", ["в"] = "d", ["а"] = "f", ["п"] = "g",
        ["р"] = "h", ["о"] = "j", ["л"] = "k", ["д"] = "l", ["я"] = "z",
        ["ч"] = "x", ["с"] = "c", ["м"] = "v", ["и"] = "b", ["т"] = "n",
        ["ь"] = "m",
        ["Й"] = "Q", ["Ц"] = "W", ["У"] = "E", ["К"] = "R", ["Е"] = "T",
        ["Н"] = "Y", ["Г"] = "U", ["Ш"] = "I", ["Щ"] = "O", ["З"] = "P",
        ["Ф"] = "A", ["Ы"] = "S", ["В"] = "D", ["А"] = "F", ["П"] = "G",
        ["Р"] = "H", ["О"] = "J", ["Л"] = "K", ["Д"] = "L", ["Я"] = "Z",
        ["Ч"] = "X", ["С"] = "C", ["М"] = "V", ["И"] = "B", ["Т"] = "N",
        ["Ь"] = "M",
      }

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
