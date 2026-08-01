{ pkgs, huixDir, ... }:

{
  services.swayosd.enable = true;
  services.playerctld.enable = true;

  imports = [
    ./hypridle.nix
  ];

  home.packages = with pkgs; [
    kitty
    awww
    dex
    hypridle
    hyprpolkitagent
    hyprpicker
    libnotify
    pavucontrol
    cliphist
    grim
    slurp
    (pkgs.satty.overrideAttrs (
      _:
      let
        src = pkgs.fetchFromGitHub {
          owner = "rokokol";
          repo = "Satty";
          rev = "feat/image-tool";
          hash = "sha256-12UXatLyjI/ZliomKHhQjrTF9AFbACzBJEhdoU1ej4Y=";
        };
      in
      {
        version = "unstable";

        inherit src;

        cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
          inherit src;
          hash = "sha256-IzJQ/5yRZrWuM4M9shGm87k7HQkU1p1OiEtCku4+8p0=";
        };
      }
    ))
    jq
    curl
    imagemagick
    lm_sensors
    pup
    rofimoji
    swayimg
    swayosd
    wl-clipboard
    (tesseract5.override {
      enableLanguages = [
        "rus"
        "eng"
      ];
    })
  ];

  wayland.windowManager.hyprland.extraConfig = ''
    source = ${huixDir}/home-manager/desktop/hyprland/hyprland.conf
  '';

  # swayimg 5.x перешёл на Lua-конфиг (init.lua); старый INI ~/.config/swayimg/config
  # больше не читается, поэтому и info-оверлей, и биндинги задаём здесь.
  home.file.".config/swayimg/init.lua".text = ''
    swayimg.set_mode("viewer")
    swayimg.viewer.set_default_scale("fit")
    -- Прозрачно-заблюренный фон из самой картинки (как в старых версиях),
    -- а не чёрная заливка. "auto" = extend/mirror по соотношению сторон.
    swayimg.viewer.set_window_background("auto")

    -- По умолчанию никакого текстового оверлея: пустые схемы для всех углов.
    swayimg.viewer.set_text("topleft", {})
    swayimg.viewer.set_text("topright", {})
    swayimg.viewer.set_text("bottomleft", {})
    swayimg.viewer.set_text("bottomright", {})
    swayimg.text.set_timeout(0) -- если info включат руками — висит, пока не выключат

    -- Тумблер info по клавише (бывший `i`): показать/скрыть сводку об изображении.
    local info_on = false
    local function toggle_info()
      if info_on then
        swayimg.viewer.set_text("topleft", {})
        swayimg.text.hide()
        info_on = false
      else
        swayimg.viewer.set_text("topleft", {
          "File: {name}",
          "Format: {format}",
          "Size: {frame.width}x{frame.height}",
          "File size: {sizehr}",
          "Image: {list.index} of {list.total}",
        })
        swayimg.text.show()
        info_on = true
      end
    end

    -- Копирование содержимого файла в буфер (как раньше: wl-copy < файл),
    -- но без шелла — чтобы не ломаться на путях со спецсимволами ($, `, \).
    local function copy_to_clipboard()
      local img = swayimg.viewer.get_image()
      if not (img and img.path) then return end
      local f = io.open(img.path, "rb")
      if not f then return end
      local data = f:read("*a")
      f:close()
      local p = io.popen("wl-copy", "w")
      if p then
        p:write(data)
        p:close()
      end
    end

    -- Латиница и кириллица (одна физическая раскладка) → общие обработчики.
    local function switch(dir) return function() swayimg.viewer.switch_image(dir) end end
    local function rotate() swayimg.viewer.rotate(90) end
    local function flip() swayimg.viewer.flip_horizontal() end
    local keymap = {
      Escape = function() swayimg.exit() end,
      Left = switch("prev"), Right = switch("next"),
      ["Ctrl-c"] = copy_to_clipboard, ["Ctrl-с"] = copy_to_clipboard,
      c = copy_to_clipboard, ["с"] = copy_to_clipboard,
      i = toggle_info,       ["ш"] = toggle_info,
      h = switch("prev"),    ["р"] = switch("prev"),
      l = switch("next"),    ["д"] = switch("next"),
      r = rotate,            ["к"] = rotate,
      m = flip,              ["ь"] = flip,
    }
    for key, fn in pairs(keymap) do swayimg.viewer.on_key(key, fn) end
  '';
}
