{ config, lib, ... }:

# A host without a desktop has no clipboard of its own, and the owner reaches it over SSH from
# a terminal. A yank goes to that terminal's clipboard as OSC 52. A paste from that clipboard is
# the terminal's own paste key. An OSC 52 read makes kitty ask for permission, and with
# 'clipboard' at unnamedplus every `p` would read it. So `p` returns the last text this nvim
# yanked, with its register type
lib.mkIf (!config.rokokol.workstation.enable) {
  programs.nixvim.extraConfigLuaPre = ''
    do
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
  '';
}
