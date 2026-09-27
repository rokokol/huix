-- The system clipboard as yazi's own. `export`, run after a yank, offers the yanked files to
-- other programs; `paste` puts what the clipboard holds into the current folder. Files are
-- copied, or moved when they were cut, as yazi tasks; an image or a text becomes a file of its
-- own. yazi's built-in `clipboard` reads files through the terminal on kitty's paste and only
-- copies them; this one works in any terminal. `files`, `offers`, `same` and `pick` are pure
-- and are what test.lua checks
local M = {}

local GNOME = "x-special/gnome-copied-files"
local URIS = "text/uri-list"

-- The local files a clipboard holds, and whether they were cut. `gnome` is the
-- x-special/gnome-copied-files text, which file managers use and which alone says cut; `uris`
-- is text/uri-list, read only when there is no `gnome`
function M.files(gnome, uris)
	local cut, lines = false, uris
	if gnome and gnome ~= "" then
		local op, rest = gnome:match("^(%a+)\n(.*)$")
		cut, lines = op == "cut", rest or gnome
	end
	local paths = {}
	for line in (lines or ""):gmatch("[^\r\n]+") do
		local path = line:match("^file://(/.*)$")
		if path then
			paths[#paths + 1] = ya.percent_decode(path)
		end
	end
	return #paths > 0 and { cut = cut, paths = paths } or nil
end

-- The gnome-copied-files and uri-list texts that offer these files
function M.offers(paths, cut)
	local uris = {}
	for i, path in ipairs(paths) do
		uris[i] = "file://" .. ya.percent_encode(path)
	end
	return (cut and "cut" or "copy") .. "\n" .. table.concat(uris, "\n"), table.concat(uris, "\r\n") .. "\r\n"
end

-- Whether two lists hold the same files, in any order; two empty lists hold nothing to compare
function M.same(a, b)
	if #a == 0 or #a ~= #b then
		return false
	end
	local set = {}
	for _, path in ipairs(a) do
		set[path] = true
	end
	for _, path in ipairs(b) do
		if not set[path] then
			return false
		end
	end
	return true
end

-- The type to save as a file when the clipboard holds no files, from `wl-paste --list-types`:
-- an image before any text, and UTF-8 text first
function M.pick(types)
	local image, has = nil, {}
	for mime in types:gmatch("[^\n]+") do
		image = image or (mime:match("^image/") and mime)
		has[mime] = true
	end
	if image then
		return image
	end
	for _, mime in ipairs { "text/plain;charset=utf-8", "text/plain", URIS } do
		if has[mime] then
			return mime
		end
	end
end

function M:setup(opts) self.bin = (opts or {}).wl_clipboard end

local state = ya.sync(function(self) return self.bin, self.exported end)

local set_exported = ya.sync(function(self, uris) self.exported = uris end)

-- The yanked local files, whether they were cut, and the folder in view
local yanked = ya.sync(function()
	local paths = {}
	for _, file in pairs(cx.yanked) do
		paths[#paths + 1] = tostring(file.path)
	end
	return paths, cx.yanked.is_cut, tostring(cx.active.current.cwd)
end)

local function fail(content) ya.notify { title = "Clipboard", content = content, level = "error", timeout = 5 } end

local function run(cmd, args)
	local output, err = Command(cmd):arg(args):stdout(Command.PIPED):stderr(Command.PIPED):output()
	if not output then
		return nil, tostring(err)
	elseif not output.status.success then
		return nil, output.stderr
	end
	return output.stdout
end

local function paste_type(bin, mime) return run(bin .. "/wl-paste", { "--no-newline", "--type", mime }) end

local function write(path, text)
	local file = io.open(path, "w")
	if file then
		file:write(text)
		file:close()
	end
	return file ~= nil
end

local function export()
	local bin, exported = state()
	local paths, cut = yanked()
	if #paths == 0 then
		-- after an unyank: take back what export offered, but nothing another program put there
		if exported and paste_type(bin, URIS) == exported then
			run(bin .. "/wl-copy", { "--clear" })
		end
		return set_exported(nil)
	end

	local gnome, uris = M.offers(paths, cut)
	local dir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
	local gnome_file, uris_file = dir .. "/yazi-clipboard-gnome", dir .. "/yazi-clipboard-uris"
	if not (write(gnome_file, gnome) and write(uris_file, uris)) then
		return fail("Cannot write the offers to " .. dir)
	end
	-- wl-copy reads both files before it forks, so they are free again once it returns
	local _, err = run(bin .. "/wl-copy", { "--offer", GNOME, gnome_file, "--offer", URIS, uris_file })
	if err then
		return fail("wl-copy: " .. err)
	end
	set_exported(uris)
end

-- Files that another program put on the clipboard, copied or moved here as yazi tasks, which
-- show progress and pick a free name when the one here is taken
local function transfer(bin, files, cwd)
	for _, path in ipairs(files.paths) do
		local from = Url(path)
		if from.name then
			ya.task(files.cut and "move" or "copy", { from = from, to = Url(cwd):join(from.name) }):spawn()
		end
	end
	if files.cut then
		-- a cut is used up once it is pasted, as in a file manager
		run(bin .. "/wl-copy", { "--clear" })
	end
end

-- An image or a text saved as img.EXT or text.EXT under a free name here; the extension comes
-- from yazi's built-in clipboard plugin, as for a dropped image
local function save(bin, mime, cwd)
	local data, err = paste_type(bin, mime)
	if not data then
		return fail(err)
	end
	local ext = require("clipboard").mime_ext(mime:match("^[^;]*"))
	local name = (mime:match("^image/") and "img." or "text.") .. ext
	local url, err = fs.unique("file", Url(cwd):join(name))
	if not url then
		return fail(tostring(err))
	end
	local ok, err = fs.write(url, data)
	if not ok then
		return fail(tostring(err))
	end
	ya.emit("reveal", { url })
end

local function paste()
	local bin = state()
	local types = run(bin .. "/wl-paste", { "--list-types" }) or ""
	local has = function(mime) return ("\n" .. types .. "\n"):find("\n" .. mime:gsub("%p", "%%%0") .. "\n") ~= nil end

	local files = M.files(has(GNOME) and paste_type(bin, GNOME), has(URIS) and paste_type(bin, URIS))
	local own, own_cut, cwd = yanked()
	if files and M.same(own, files.paths) then
		-- Thunar moves a cut it did not put there and cannot clear the clipboard after it, so
		-- the files may be gone; then the yank is spent, as if pasted here
		for _, path in ipairs(own) do
			if not fs.cha(Url(path)) then
				ya.emit("unyank", {})
				run(bin .. "/wl-copy", { "--clear" })
				return ya.notify { title = "Clipboard", content = "The yanked files are gone", level = "info", timeout = 5 }
			end
		end
		-- the clipboard holds yazi's own yank: its paste shows progress and can be cancelled
		ya.emit("paste", {})
		if own_cut then
			run(bin .. "/wl-copy", { "--clear" })
		end
	elseif files then
		transfer(bin, files, cwd)
	else
		local mime = M.pick(types)
		if mime then
			save(bin, mime, cwd)
		end
	end
end

function M:entry(job)
	local action = job.args[1]
	if action == "export" then
		export()
	elseif action == "paste" then
		paste()
	else
		fail("Unknown action: " .. tostring(action))
	end
end

return M
