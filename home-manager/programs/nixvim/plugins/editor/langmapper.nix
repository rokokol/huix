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
      local ru = vim.deepcopy(require('langmapper.config').config.layouts.ru)
      ru.layout = ru.layout:gsub(',ё', '?ё'):gsub('%.$', '/')

      lm.setup({
        hack_keymap = true,
        map_all_ctrl = true,
        layouts = { ru = ru },
      })

      lm.automapping({ global = true, buffer = true })
    '';
  };
}
