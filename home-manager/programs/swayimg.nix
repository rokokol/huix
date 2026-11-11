{
  config,
  lib,
  pkgs,
  ...
}:

# swayimg 5.x reads a Lua config, init.lua, and no longer the INI file of 4.x, so the
# overlay scheme and the keys live here; the pin from scripts/pin-screen.sh passes its
# own geometry with --position and --size, never through this file
{
  options.rokokol.swayimg.enable = lib.mkEnableOption "swayimg as the image viewer" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.swayimg.enable {
    home.packages = with pkgs; [ swayimg ];

    # Every image type; mime-apps.nix overrides the layered formats and the books with
    # exact keys, which win over this prefix
    xdg.mimeApps = {
      enable = true;
      defaultApplications."image/*" = "swayimg.desktop";
    };

    home.file.".config/swayimg/init.lua".text = ''
      swayimg.mode = "viewer"
      swayimg.viewer.default_scale = "fit"
      -- Transparent, blurred background derived from the image itself (as in older
      -- versions), not a black fill. "auto" = extend/mirror by aspect ratio.
      swayimg.viewer.set_window_background("auto")

      -- No text overlay by default: empty schemes for all corners.
      local no_text = { topleft = {}, topright = {}, bottomleft = {}, bottomright = {} }
      swayimg.viewer.text = no_text
      swayimg.text.timeout = 0 -- if info is toggled on by hand, it stays until toggled off

      -- Info toggle on a key (the former `i`): show/hide the image summary.
      local info_on = false
      local function toggle_info()
        if info_on then
          swayimg.viewer.text = no_text
          swayimg.text.visible = false
          info_on = false
        else
          swayimg.viewer.text = {
            topleft = {
              "File: {name}",
              "Format: {format}",
              "Size: {frame.width}x{frame.height}",
              "File size: {sizehr}",
              "Image: {list.index} of {list.total}",
            },
          }
          swayimg.text.visible = true
          info_on = true
        end
      end

      -- Copy the file contents to the clipboard (as before: wl-copy < file),
      -- but without a shell — so it doesn't break on paths with special chars ($, `, \).
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

      -- Latin and Cyrillic (one physical layout) → shared handlers.
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

      -- swayimg 5.7 replaced the per-button wheel binds with one scroll handler, and a
      -- handler of our own replaces the stock one whole: what it did on its own, zoom
      -- at the pointer under Ctrl, has to be repeated below
      local step = 10
      local zoom_divisor = 10
      swayimg.viewer.on_scroll(function(kmods, dx, dy)
        if kmods == "Ctrl" then
          -- wheel up (dy below zero) zooms in, the image point under the pointer stays put
          local mouse = swayimg.get_mouse_pos()
          local scale = swayimg.viewer.scale
          swayimg.viewer.set_abs_scale(scale - scale * dy / zoom_divisor, mouse.x, mouse.y)
          return
        end
        -- The stock movement moves the image against the wheel (up moves it up), so the
        -- signs are reversed here to make the wheel scroll the view like a page
        local pos = swayimg.viewer.get_position()
        swayimg.viewer.set_abs_position(pos.x - dx * step, pos.y - dy * step)
      end)
    '';
  };
}
