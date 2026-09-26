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

-- A letter of the label goes first as it is and then as a capital, before the next letter
local keys = places.keys({ { label = "Downloads" }, { label = "dotfiles" }, { label = "Docs" }, { label = "/" } })
expect("key 1", keys[1], "d")
expect("key 2", keys[2], "D")
expect("key 3", keys[3], "o")
expect("key 4", keys[4], "1")

-- With no Latin letter of its own, a Cyrillic label takes a digit
local cyr = places.keys({ { label = "Проекты" }, { label = "Загрузки" } })
expect("cyrillic key 1", cyr[1], "1")
expect("cyrillic key 2", cyr[2], "2")

-- Past the label's letters come the digits, then any free letter, then any free capital, and
-- past those nothing
local many = {}
for i = 1, 62 do
	many[i] = { label = "x" }
end
local lots = places.keys(many)
expect("2nd key", lots[2], "X")
expect("3rd key", lots[3], "1")
expect("11th key", lots[11], "9")
expect("12th key", lots[12], "a")
expect("36th key", lots[36], "z")
expect("37th key", lots[37], "A")
expect("61st key", lots[61], "Z")
expect("62nd key", lots[62], nil)

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
