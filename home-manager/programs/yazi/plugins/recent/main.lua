-- The files GTK programs recently touched, as Thunar's Recent shows them, picked through fzf and
-- revealed in their folder. `recent` is pure and is what test.lua checks
local M = {}

-- The local files of GTK's recently-used.xbel, the most recently touched first
function M.recent(xml)
	local list = {}
	for uri, modified in xml:gmatch('<bookmark href="file://([^"]+)"[^>]-modified="([^"]+)"') do
		list[#list + 1] = { path = ya.percent_decode(uri), modified = modified }
	end
	table.sort(list, function(a, b) return a.modified > b.modified end)
	local paths = {}
	for i, file in ipairs(list) do
		paths[i] = file.path
	end
	return paths
end

local function read(path)
	local file = io.open(path)
	if not file then
		return ""
	end
	local text = file:read("a")
	file:close()
	return text
end

-- fzf takes the terminal, as yazi's own fzf plugin does
function M:entry()
	local data = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
	local paths = M.recent(read(data .. "/recently-used.xbel"))
	if #paths == 0 then
		return ya.notify { title = "Recent", content = "No recent files", level = "info", timeout = 5 }
	end

	local permit = ui.hide()
	local child = Command("fzf"):stdin(Command.PIPED):stdout(Command.PIPED):spawn()
	if not child then
		permit:drop()
		return ya.notify { title = "Recent", content = "Cannot start fzf", level = "error", timeout = 5 }
	end
	child:write_all(table.concat(paths, "\n"))
	child:flush()
	local output = child:wait_with_output()
	permit:drop()

	local chosen = output and output.stdout:gsub("\n$", "")
	if chosen and chosen ~= "" then
		ya.emit("reveal", { Url(chosen) })
	end
end

return M
