-- An archive as a folder. `open` mounts the hovered archive read-only through fuse-archive and
-- enters it; `open --edit` mounts it through archivemount, which writes the changes back into
-- the archive on unmount and keeps the old one as <name>.orig. `tidy`, run on every cd,
-- unmounts the archives no tab looks into any more and those a yazi that has exited left
-- behind. Mounts live in $XDG_RUNTIME_DIR/yazi-archives/<pid>, the pid of the yazi that made
-- them. `pid`, `inside`, `unused` and `serves` are pure and are what test.lua checks
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

-- Whether a /proc/<pid>/cmdline is an archivemount that has `mount` as one of its arguments
function M.serves(cmdline, mount)
	local args = {}
	for arg in cmdline:gmatch("([^%z]*)%z") do
		args[#args + 1] = arg
	end
	if #args == 0 or not args[1]:match("archivemount$") then
		return false
	end
	for i = 2, #args do
		if args[i] == mount then
			return true
		end
	end
	return false
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

-- What each mount of this yazi serves, by mount: { archive, edit }, and for an edit the pid of
-- its archivemount and the archive's mtime when it was mounted
local mounted = ya.sync(function(self) return self.mounted or {} end)

local remember = ya.sync(function(self, mount, entry)
	self.mounted = self.mounted or {}
	self.mounted[mount] = entry
end)

-- The hovered file and whether it is an archive: whatever yazi previews as one, so the list of
-- their types stays yazi's, as in the info plugin
local hovered = ya.sync(function()
	local h = cx.active.current.hovered
	if not h then
		return
	end
	local archive = false
	for _, v in pairs(rt.plugin.previewers:match { file = h, mime = h:mime() or "" }) do
		archive = v.name == "archive"
		break
	end
	return tostring(h.url), h.name, archive
end)

local cwds = ya.sync(function()
	local list = {}
	for i = 1, #cx.tabs do
		list[i] = tostring(cx.tabs[i].current.cwd)
	end
	return list, tostring(cx.active.current.cwd)
end)

local function mtime(path)
	local cha = fs.cha(Url(path))
	return cha and cha.mtime
end

-- The archivemount that serves `mount`: it forks away from the command that started it
local function server(mount)
	for _, dir in ipairs(fs.read_dir(Url("/proc"), {}) or {}) do
		if dir.name:match("^%d+$") and M.serves(read("/proc/" .. dir.name .. "/cmdline"), mount) then
			return dir.name
		end
	end
end

-- archivemount writes the archive only once the mount is gone, in its own process, so yazi
-- goes on while it does; a mount of an unchanged archive writes nothing
local function unmount(mount, entry)
	run("fusermount3", { "-uz", mount })
	if entry and entry.edit and entry.pid then
		while fs.cha(Url("/proc/" .. entry.pid)) do
			ya.sleep(0.2)
		end
		if mtime(entry.archive) ~= entry.mtime then
			local name = entry.archive:match("[^/]+$")
			ya.notify {
				title = "Archive",
				content = string.format("Saved %s, the old one is %s.orig", name, name),
				level = "info",
				timeout = 5,
			}
		end
	end
	fs.remove("dir", Url(mount))
end

-- A watch that outlives yazi for a mount open for editing: yazi has no hook on exit, and a
-- closed window or a crash would skip one anyway. It ends by itself once yazi unmounts; if
-- yazi dies first, it unmounts, waits for archivemount's write and tells the desktop. setsid
-- takes it out of yazi's session, whose hangup would end it too
local WATCH = [[
yazi=$1 mount=$2 archive=$3 server=$4 before=$5
while kill -0 "$yazi" 2>/dev/null && mountpoint -q "$mount"; do sleep 1; done
mountpoint -q "$mount" || exit 0
fusermount3 -u "$mount" || exit 1
tail --pid="$server" -f /dev/null
rmdir "$mount" 2>/dev/null
name=${archive##*/}
[ "$(stat -c %Y "$archive")" = "$before" ] || notify-send Archive "Saved $name, the old one is $name.orig"
]]

local function watch(mount, entry)
	Command("setsid")
		:arg({ "-f", "sh", "-c", WATCH, "archive-mount-watch" })
		:arg({ tostring(M.pid(read("/proc/self/stat"))), mount, entry.archive, entry.pid })
		:arg({ string.format("%d", math.floor(entry.mtime)) })
		:stdin(Command.NULL)
		:stdout(Command.NULL)
		:stderr(Command.NULL)
		:status()
end

local function open(edit)
	local archive, name, is_archive = hovered()
	if not archive or not is_archive then
		return fail("Hover an archive to open")
	end
	for mount, entry in pairs(mounted()) do
		if entry.archive == archive and fs.cha(Url(mount)) then
			-- a second mount of one archive would show the edits in one of them only
			if entry.edit ~= edit then
				return fail("The archive is open " .. (entry.edit and "for editing" or "read-only") .. " already")
			end
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
	local entry = { archive = archive, edit = edit }
	if edit then
		-- both paths are absolute, so neither reads as an option
		entry.mtime = mtime(archive)
		_, err = run("archivemount", { archive, mount })
		entry.pid = not err and server(mount) or nil
	else
		_, err = run("fuse-archive", { "--", archive, mount })
	end
	if err then
		fs.remove("dir", Url(mount))
		return fail(err)
	end
	remember(mount, entry)
	if entry.pid then
		watch(mount, entry)
	end
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
		-- forgotten before the unmount, which can wait for a write, so the next tidy skips it
		remember(mount, nil)
		-- `h` at the root of a mount lands in the folder of mounts; the archive's own is better
		if active == own() then
			ya.emit("reveal", { Url(archives[mount].archive) })
		end
		unmount(mount, archives[mount])
	end
end

function M:setup()
	ps.sub("cd", function() ya.emit("plugin", { "archive-mount", "tidy" }) end)
end

function M:entry(job)
	local action = job.args[1]
	if action == "open" then
		open(job.args.edit == true)
	elseif action == "tidy" then
		tidy()
	else
		fail("Unknown action: " .. tostring(action))
	end
end

return M
