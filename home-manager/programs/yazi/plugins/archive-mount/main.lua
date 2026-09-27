-- An archive as a read-only folder, through fuse-archive. `open` mounts the hovered archive and
-- enters it; `tidy`, run on every cd, unmounts the archives no tab looks into any more and those
-- a yazi that has exited left behind. Mounts live in $XDG_RUNTIME_DIR/yazi-archives/<pid>, the
-- pid of the yazi that made them. `pid`, `inside` and `unused` are pure and are what test.lua
-- checks
local M = {}

-- The process id that /proc/<pid>/stat starts with
function M.pid(stat) return tonumber(stat:match("^(%d+)")) end

-- Whether `path` is the folder `mount` or below it
function M.inside(path, mount) return path == mount or path:sub(1, #mount + 1) == mount .. "/" end

-- The mounts that no folder in `cwds` is inside
function M.unused(mounts, cwds)
	local left = {}
	for _, mount in ipairs(mounts) do
		local used = false
		for _, cwd in ipairs(cwds) do
			used = used or M.inside(cwd, mount)
		end
		if not used then
			left[#left + 1] = mount
		end
	end
	return left
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

local function base() return (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/yazi-archives" end

-- yazi runs this plugin in its own process, so /proc/self is yazi
local function own() return base() .. "/" .. tostring(M.pid(read("/proc/self/stat"))) end

local function fail(content) ya.notify { title = "Archive", content = content, level = "error", timeout = 5 } end

local function run(cmd, args)
	local output, err = Command(cmd):arg(args):stdout(Command.PIPED):stderr(Command.PIPED):output()
	if not output then
		return nil, tostring(err)
	elseif not output.status.success then
		return nil, output.stderr
	end
	return output.stdout
end

-- The archive each mount of this yazi serves, by mount
local mounted = ya.sync(function(self) return self.mounted or {} end)

local remember = ya.sync(function(self, mount, archive)
	self.mounted = self.mounted or {}
	self.mounted[mount] = archive
end)

local hovered = ya.sync(function()
	local h = cx.active.current.hovered
	if h then
		return tostring(h.url), h.name, h.cha.is_dir
	end
end)

local cwds = ya.sync(function()
	local list = {}
	for i = 1, #cx.tabs do
		list[i] = tostring(cx.tabs[i].current.cwd)
	end
	return list, tostring(cx.active.current.cwd)
end)

local function unmount(mount)
	run("fusermount3", { "-uz", mount })
	fs.remove("dir", Url(mount))
end

local function open()
	local archive, name, is_dir = hovered()
	if not archive or is_dir then
		return fail("Hover an archive to open")
	end
	for mount, source in pairs(mounted()) do
		if source == archive and fs.cha(Url(mount)) then
			return ya.emit("cd", { Url(mount) })
		end
	end

	-- fs.unique looks for a free name inside a folder that has to be there already, and makes
	-- the folder it names
	local _, err = fs.create("dir_all", Url(own()))
	local mount
	if not err then
		mount, err = fs.unique("dir", Url(own() .. "/" .. name))
	end
	if err then
		return fail(tostring(err))
	end
	mount = tostring(mount)
	_, err = run("fuse-archive", { "--", archive, mount })
	if err then
		fs.remove("dir", Url(mount))
		return fail(err)
	end
	remember(mount, archive)
	ya.emit("cd", { Url(mount) })
end

-- What a yazi that has exited left behind: its folder under base, named by a pid that is gone
local function sweep()
	local self = own()
	for _, dir in ipairs(fs.read_dir(Url(base()), {}) or {}) do
		local path = tostring(dir.url)
		if path ~= self and dir.name:match("^%d+$") and not fs.cha(Url("/proc/" .. dir.name)) then
			for _, left in ipairs(fs.read_dir(dir.url, {}) or {}) do
				unmount(tostring(left.url))
			end
			fs.remove("dir", dir.url)
		end
	end
end

local function tidy()
	sweep()
	local tabs, active = cwds()
	local archives, list = mounted(), {}
	for mount in pairs(archives) do
		list[#list + 1] = mount
	end
	for _, mount in ipairs(M.unused(list, tabs)) do
		unmount(mount)
		remember(mount, nil)
		-- `h` at the root of a mount lands in the folder of mounts; the archive's own is better
		if active == own() then
			ya.emit("reveal", { Url(archives[mount]) })
		end
	end
end

function M:setup()
	ps.sub("cd", function() ya.emit("plugin", { "archive-mount", "tidy" }) end)
end

function M:entry(job)
	local action = job.args[1]
	if action == "open" then
		open()
	elseif action == "tidy" then
		tidy()
	else
		fail("Unknown action: " .. tostring(action))
	end
end

return M
