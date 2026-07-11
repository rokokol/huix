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

      -- Встроенная RU-раскладка langmapper мапит физическую клавишу `/?` на `.`/`,`.
      -- С `hack_keymap` это заставляет каждый плагинный маппинг `/` молча создавать
      -- двойника на `.`, который перезатирает настоящие маппинги `.` (например
      -- `.` = set_root у neo-tree). Делаем эту клавишу тождественной, чтобы
      -- двойники `.`/`,` не плодились; это совпадает с нативным `langmap` выше,
      -- который эту пару тоже опускает.
      local ru_layout = require('langmapper.config').config.layouts.ru.layout
      ru_layout = ru_layout:gsub(',ё', '?ё'):gsub('%.$', '/')

      lm.setup({
        hack_keymap = true,
        map_all_ctrl = true,
        layouts = { ru = { layout = ru_layout } },
      })

      lm.automapping({ global = true, buffer = true })

      -- Режим командной строки не покрывается `langmap`/langmapper (только режимы
      -- n/v/x/s). Так что `:` входит в cmdline через langmap (Ж -> :), но сама
      -- команда набирается в активной раскладке: `:q` превращается в `:й`.
      --
      -- Переводим кириллицу -> латиницу, но ТОЛЬКО пока курсор ещё внутри *имени*
      -- команды `:` ex-команды (набраны только символы имени команды). Как только
      -- появляется пробел, `/`, `%` или `#`, а также для поисковых промптов `/`?`,
      -- символы оставляем как есть, чтобы кириллические паттерны поиска и аргументы
      -- (`:e файл`, `:s/foo/привет/`) продолжали работать.
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
