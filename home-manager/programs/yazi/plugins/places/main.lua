-- The GTK bookmarks Thunar shows in its side pane, in a which popup that goes to the chosen
-- one; Thunar's own places can be put before them. `parse`, `keys` and `recent` are pure and
-- are what test.lua checks
local M = {}

-- One bookmark a line, a URI and an optional label; only local ones have a path to enter
function M.parse(text)
	local list = {}
	for line in text:gmatch("[^\n]+") do
		local uri, label = line:match("^(%S+)%s*(.-)%s*$")
		local path = uri and uri:match("^file://(/.*)$")
		if path then
			path = ya.percent_decode(path)
			path = path == "/" and path or path:gsub("/+$", "")
			if label == "" then
				label = path == "/" and "File System" or path:match("([^/]+)$")
			end
			list[#list + 1] = { path = path, label = label }
		end
	end
	return list
end

-- The first Latin letter of the label, in the case the label writes it, that no earlier place
-- took; a place whose letters are all taken, or that has none, gets no key
function M.keys(list)
	local taken, keys = {}, {}
	for i, place in ipairs(list) do
		for c in place.label:gmatch("[A-Za-z]") do
			if not taken[c] then
				keys[i], taken[c] = c, true
				break
			end
		end
	end
	return keys
end

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

local function xdg(var, fallback) return os.getenv(var) or (os.getenv("HOME") .. fallback) end

-- fzf over the recent files takes the terminal, as yazi's own fzf plugin does
local function pick_recent()
	local paths = M.recent(read(xdg("XDG_DATA_HOME", "/.local/share") .. "/recently-used.xbel"))
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

-- The places Thunar adds on its own, none of them in the bookmarks file; setup's `extras`
-- picks which come first and in what order
local EXTRAS = {
	home = function() return { label = "Home", path = os.getenv("HOME") } end,
	computer = function() return { label = "Computer", plugin = "mount" } end,
	recent = function() return { label = "Recent", recent = true } end,
	trash = function() return { label = "Trash", plugin = "trash" } end,
}

function M:setup(opts) self.extras = opts and opts.extras or {} end

local extras = ya.sync(function(self) return self.extras or {} end)

local function places()
	local list = {}
	for _, name in ipairs(extras()) do
		local make = EXTRAS[name]
		if make then
			list[#list + 1] = make()
		else
			ya.notify { title = "Places", content = "Unknown extra: " .. tostring(name), level = "warn", timeout = 5 }
		end
	end
	for _, place in ipairs(M.parse(read(xdg("XDG_CONFIG_HOME", "/.config") .. "/gtk-3.0/bookmarks"))) do
		list[#list + 1] = place
	end
	return list
end

function M:entry()
	local list = places()
	local keys, cands, shown = M.keys(list), {}, {}
	for i, place in ipairs(list) do
		if keys[i] then
			local desc = place.path and (place.label .. "  " .. place.path) or place.label
			table.insert(cands, { on = keys[i], desc = desc })
			table.insert(shown, place)
		end
	end
	local chosen = ya.which { cands = cands }
	local place = chosen and shown[chosen]
	if not place then
		return
	elseif place.path then
		ya.emit("cd", { Url(place.path) })
	elseif place.recent then
		pick_recent()
	else
		ya.emit("plugin", { place.plugin })
	end
end

return M
