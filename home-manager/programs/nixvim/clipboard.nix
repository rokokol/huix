_:

# A yank must reach the terminal's clipboard both in a desktop session and over SSH on a host
# whose desktop belongs to another machine. The host cannot answer which of the two this is:
# the same configuration runs everywhere, and a workstation reached over SSH has no display for
# wl-copy, so a host-role check sends a yank on the PC over SSH into nothing. The session
# answers it at startup instead. A session with a Wayland socket and wl-copy keeps nvim's own
# provider, so the real clipboard is both written and read. Any other session sends the yank as
# OSC 52, which kitty writes to the clipboard it does own. A paste from that clipboard is the
# terminal's paste key: an OSC 52 read makes kitty ask for permission, and with 'clipboard' at
# unnamedplus every `p` would read it. So `p` returns the last text this nvim yanked, with its
# register type
{
  programs.nixvim.extraConfigLuaPre = ''
    do
      -- Wayland takes either a name under XDG_RUNTIME_DIR or an absolute path
      local display = vim.env.WAYLAND_DISPLAY or ""
      local socket = display
      if display ~= "" and display:sub(1, 1) ~= "/" then
        socket = (vim.env.XDG_RUNTIME_DIR or "") .. "/" .. display
      end
      local own = socket ~= ""
        and vim.fn.executable("wl-copy") == 1
        and vim.uv.fs_stat(socket) ~= nil

      if not own then
        local osc52 = require("vim.ui.clipboard.osc52")
        local yanked = {}

        local function copy(reg)
          local send = osc52.copy(reg)
          return function(lines, regtype)
            yanked[reg] = { lines, regtype }
            send(lines)
          end
        end

        local function paste(reg)
          return function()
            return yanked[reg] or { { "" }, "v" }
          end
        end

        vim.g.clipboard = {
          name = "OSC 52, yank only",
          copy = { ["+"] = copy("+"), ["*"] = copy("*") },
          paste = { ["+"] = paste("+"), ["*"] = paste("*") },
        }
      end
    end
  '';
}
