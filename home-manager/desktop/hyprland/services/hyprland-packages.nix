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
    swayosd
    swayimg
    lm_sensors
    pup
    jq
    rofimoji
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
    swayimg.config.viewer.scale = "fit"

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

    -- Копирование содержимого файла в буфер (как раньше: wl-copy < файл).
    local function copy_to_clipboard()
      local img = swayimg.viewer.get_image()
      if img and img.path then
        os.execute(("wl-copy < %q"):format(img.path))
      end
    end

    local function bind(key, fn) swayimg.viewer.on_key(key, fn) end

    bind("Escape", function() swayimg.exit() end)

    -- Латиница
    bind("Ctrl-c", copy_to_clipboard)
    bind("c", copy_to_clipboard)
    bind("i", toggle_info)
    bind("Left", function() swayimg.viewer.switch_image("prev") end)
    bind("Right", function() swayimg.viewer.switch_image("next") end)
    bind("h", function() swayimg.viewer.switch_image("prev") end)
    bind("l", function() swayimg.viewer.switch_image("next") end)
    bind("r", function() swayimg.viewer.rotate(90) end)
    bind("m", function() swayimg.viewer.flip_horizontal() end)

    -- Кириллица (та же раскладка клавиш)
    bind("Ctrl-с", copy_to_clipboard)
    bind("с", copy_to_clipboard)
    bind("ш", toggle_info)
    bind("р", function() swayimg.viewer.switch_image("prev") end)
    bind("д", function() swayimg.viewer.switch_image("next") end)
    bind("к", function() swayimg.viewer.rotate(90) end)
    bind("ь", function() swayimg.viewer.flip_horizontal() end)
  '';
}
