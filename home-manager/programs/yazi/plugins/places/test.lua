-- The pure half of main.lua, run by plain Lua with yazi's globals stubbed out: `lua test.lua`
-- from this directory, or the yazi-plugin-tests flake check
ya = {
	sync = function(fn) return fn end,
	percent_decode = function(s)
		return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
	end,
}
local places = dofile("main.lua")

local failed = 0
local function expect(what, got, want)
	if got ~= want then
		failed = failed + 1
		io.stderr:write(string.format("%s: want %q, got %q\n", what, tostring(want), tostring(got)))
	end
end

local list = places.parse(table.concat({
	"file:///home/me/Downloads/",
	"file:///home/me/My%20Notes/ Notes",
	"file:///",
	"sftp://host/srv/",
	"trash:///",
	"",
	"file:///home/me/%D0%9F%D1%80%D0%BE%D0%B5%D0%BA%D1%82%D1%8B/",
}, "\n"))

-- A remote location has no path to cd into, and a blank line is nothing
expect("count", #list, 4)

-- A trailing slash goes, percent escapes decode, a label wins over the directory's name, and
-- the root is called what Thunar calls it
expect("path 1", list[1].path, "/home/me/Downloads")
expect("label 1", list[1].label, "Downloads")
expect("path 2", list[2].path, "/home/me/My Notes")
expect("label 2", list[2].label, "Notes")
expect("root path", list[3].path, "/")
expect("root label", list[3].label, "File System")
expect("cyrillic label", list[4].label, "Проекты")

-- A place takes the first letter of its label that is still free, in the case the label
-- writes it; a later letter only when the earlier ones are taken
local keys = places.keys({ { label = "Downloads" }, { label = "dotfiles" }, { label = "Docs" }, { label = "myWiki" } })
expect("key 1", keys[1], "D")
expect("key 2", keys[2], "d")
expect("key 3", keys[3], "o")
expect("key 4", keys[4], "m")

-- A label with no free Latin letter gets no key, and a later place is not moved for it
local rest = places.keys({ { label = "ab" }, { label = "ba" }, { label = "/" }, { label = "Проекты" }, { label = "c" } })
expect("taken key", rest[2], "b")
expect("no letters", rest[3], nil)
expect("cyrillic", rest[4], nil)
expect("after a gap", rest[5], "c")
local full = places.keys({ { label = "a" }, { label = "a" } })
expect("all taken", full[2], nil)

-- Recent files: only local ones, the newest first, escapes decoded
local recent = places.recent(table.concat({
	'<bookmark href="file:///home/me/old.pdf" added="2026-01-01T00:00:00Z" modified="2026-01-01T00:00:00Z">',
	'<bookmark href="https://example.org/" added="2026-05-01T00:00:00Z" modified="2026-05-01T00:00:00Z">',
	'<bookmark href="file:///home/me/%D0%BD%D0%BE%D0%B2%D1%8B%D0%B9.md" added="2026-03-01T00:00:00Z" modified="2026-03-02T00:00:00Z">',
}, "\n"))
expect("recent count", #recent, 2)
expect("recent newest", recent[1], "/home/me/новый.md")
expect("recent oldest", recent[2], "/home/me/old.pdf")

if failed > 0 then
	io.stderr:write(failed .. " failed\n")
	os.exit(1)
end
print("places: all passed")
