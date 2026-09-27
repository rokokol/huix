--- @sync entry
-- The selected files side by side in `nvim -d`, in the terminal yazi runs in, as `e` opens one.
-- nvim compares two to eight files, so any other count is refused up front rather than opened
-- as plain buffers
local M = {}

local MIN, MAX = 2, 8

function M:entry()
	local paths = {}
	for _, file in pairs(cx.active.selected) do
		paths[#paths + 1] = ya.quote(tostring(file.path))
	end
	if #paths < MIN or #paths > MAX then
		return ya.notify {
			title = "Diff",
			content = string.format("Select %d to %d files, not %d", MIN, MAX, #paths),
			level = "error",
			timeout = 5,
		}
	end
	ya.emit("shell", { "nvim -d " .. table.concat(paths, " "), block = true })
end

return M
