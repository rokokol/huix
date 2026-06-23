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
      -- With `hack_keymap` that makes every plugin `/` mapping silently create a
      -- twin on `.`, which overwrites real `.` mappings (e.g. neo-tree's
      -- `.` = set_root). Make that key identity so no `.`/`,` twins are produced;
      -- this matches the native `langmap` above, which also omits that pair.
      local ru_layout = require('langmapper.config').config.layouts.ru.layout
      ru_layout = ru_layout:gsub(',ё', '?ё'):gsub('%.$', '/')

      lm.setup({
        hack_keymap = true,
        map_all_ctrl = true,
        layouts = { ru = { layout = ru_layout } },
      })

      lm.automapping({ global = true, buffer = true })

      -- Command-line mode is not covered by `langmap`/langmapper (only n/v/x/s
      -- modes are). So `:` enters cmdline via the langmap (Ж -> :), but the
      -- command itself is typed in the active layout: `:q` becomes `:й`.
      --
      -- Translate Cyrillic -> Latin, but ONLY while the cursor is still inside
      -- the command *name* of a `:` ex-command (nothing but command-name chars
      -- typed yet). Once a space, `/`, `%` or `#` appears, or for `/`?` search
      -- prompts, characters are left untouched so Cyrillic search patterns and
      -- arguments (`:e файл`, `:s/foo/привет/`) keep working.
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
