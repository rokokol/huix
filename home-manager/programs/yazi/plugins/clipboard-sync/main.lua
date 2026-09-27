-- The system clipboard as yazi's own. `export`, run after a yank, offers the yanked files to
-- other programs; `paste` puts what the clipboard holds into the current folder. Files are
-- copied, or moved when they were cut, as yazi tasks; an image or a text becomes a file of its
-- own. yazi's built-in `clipboard` reads files through the terminal on kitty's paste and only
-- copies them; this one works in any terminal. `files`, `offers` and `same` are pure and are
-- what test.lua checks
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

function M:setup(opts)
	opts = opts or {}
	self.bin, self.paste_as_file = opts.wl_clipboard, opts.paste_as_file
end

local state = ya.sync(function(self) return self.bin, self.paste_as_file, self.exported end)

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
	local bin, _, exported = state()
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

local function paste()
	local bin, paste_as_file = state()
	local types = run(bin .. "/wl-paste", { "--list-types" }) or ""
	local has = function(mime) return ("\n" .. types .. "\n"):find("\n" .. mime:gsub("%p", "%%%0") .. "\n") ~= nil end

	local files = M.files(has(GNOME) and paste_type(bin, GNOME), has(URIS) and paste_type(bin, URIS))
	local own, own_cut, cwd = yanked()
	if files and M.same(own, files.paths) then
		-- the clipboard holds yazi's own yank: its paste shows progress and can be cancelled
		ya.emit("paste", {})
		if own_cut then
			run(bin .. "/wl-copy", { "--clear" })
		end
	elseif files then
		transfer(bin, files, cwd)
	else
		local created, err = run(paste_as_file, { cwd })
		if err then
			return fail(err)
		end
		created = created and created:gsub("\n$", "")
		if created and created ~= "" then
			ya.emit("reveal", { Url(created) })
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
