-- The pure half of main.lua, run by plain Lua with yazi's globals stubbed out: `lua test.lua`
-- from this directory, or the yazi-plugin-tests flake check
ya = { sync = function(fn) return fn end }
local mount = dofile("main.lua")

local failed = 0
local function expect(what, got, want)
	if got ~= want then
		failed = failed + 1
		io.stderr:write(string.format("%s: want %q, got %q\n", what, tostring(want), tostring(got)))
	end
end

-- /proc/self/stat starts with the process id, and the name after it may hold anything
expect("pid", mount.pid("48213 (yazi) S 1 48213 48213 0 -1 4194560\n"), 48213)
expect("odd name", mount.pid("7 (a) b 9) R 1\n"), 7)
expect("no stat", mount.pid(""), nil)

-- A folder is inside a mount when it is the mount or below it, and a sibling that shares the
-- start of its name is not
local at = "/run/user/1000/yazi-archives/42/photos.zip"
expect("the mount", mount.inside(at, at), true)
expect("below", mount.inside(at .. "/2024/june", at), true)
expect("sibling", mount.inside(at .. ".bak", at), false)
expect("above", mount.inside("/run/user/1000/yazi-archives/42", at), false)

-- A mount is kept while any tab looks into it
local mounts = { at, "/run/user/1000/yazi-archives/42/music.tar" }
local left = mount.unused(mounts, { at .. "/2024", "/home/me" })
expect("unused count", #left, 1)
expect("unused one", left[1], "/run/user/1000/yazi-archives/42/music.tar")
expect("all in use", #mount.unused(mounts, { at, mounts[2] .. "/a" }), 0)

if failed > 0 then
	io.stderr:write(failed .. " failed\n")
	os.exit(1)
end
print("archive-mount: all passed")
