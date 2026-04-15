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

      lm.setup({
        hack_keymap = true,
        map_all_queues = true,
      })

      lm.automapping({ global = true, buffer = true })
    '';
  };
}
