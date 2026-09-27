-- The pure half of main.lua, run by plain Lua with yazi's globals stubbed out: `lua test.lua`
-- from this directory, or the yazi-plugin-tests flake check
ya = {
	sync = function(fn) return fn end,
	percent_decode = function(s)
		return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
	end,
	-- yazi's RFC_3986 set in yazi-shim: controls, the space, `"#%<>?[\]^`{|}` and every byte
	-- past ASCII
	percent_encode = function(s)
		return (s:gsub('[%c "#%%<>?%[\\%]^`{|}\128-\255]', function(c) return string.format("%%%02X", c:byte()) end))
	end,
}
local clipboard = dofile("main.lua")

local failed = 0
local function expect(what, got, want)
	if got ~= want then
		failed = failed + 1
		io.stderr:write(string.format("%s: want %q, got %q\n", what, tostring(want), tostring(got)))
	end
end

-- A file manager's clipboard: the first line says copy or cut, the rest are URIs
local cut = clipboard.files("cut\nfile:///home/me/a%20b.txt\nfile:///home/me/%D1%84.md", nil)
expect("cut", cut and cut.cut, true)
expect("cut count", cut and #cut.paths, 2)
expect("cut decoded", cut and cut.paths[1], "/home/me/a b.txt")
expect("cut cyrillic", cut and cut.paths[2], "/home/me/ф.md")
local copy = clipboard.files("copy\nfile:///a\n", "file:///ignored\r\n")
expect("copy", copy and copy.cut, false)
expect("gnome wins", copy and copy.paths[1], "/a")
expect("gnome count", copy and #copy.paths, 1)

-- A uri-list alone is a copy; comments, remote URIs and blank lines are not files
local list = clipboard.files(nil, "# comment\r\nfile:///x/y\r\nhttps://example.org/z\r\n\r\nfile:///w\r\n")
expect("list copy", list and list.cut, false)
expect("list count", list and #list.paths, 2)
expect("list first", list and list.paths[1], "/x/y")
expect("list second", list and list.paths[2], "/w")
expect("no local files", clipboard.files(nil, "https://example.org/\r\n"), nil)
expect("nothing", clipboard.files(nil, nil), nil)

-- What export offers reads back as the same files
local paths = { "/home/me/a b.txt", "/home/me/ф.md", "/tmp/100%.txt", "/tmp/[x]|y#z.txt" }
local gnome, uris = clipboard.offers(paths, true)
expect("gnome head", gnome:match("^[^\n]*"), "cut")
expect("uris line end", uris:sub(-2), "\r\n")
expect("space encoded", uris:match("a%%20b") ~= nil, true)
expect("percent encoded", uris:match("100%%25") ~= nil, true)
for _, source in ipairs { { gnome, nil }, { nil, uris } } do
	local back = clipboard.files(source[1], source[2])
	for i, path in ipairs(paths) do
		expect("round trip " .. i, back and back.paths[i], path)
	end
end
expect("copy head", (clipboard.offers({ "/a" }, false)):match("^[^\n]*"), "copy")

-- The same files in any order are the same set; one more or one other is not
expect("same", clipboard.same({ "/a", "/b" }, { "/b", "/a" }), true)
expect("one more", clipboard.same({ "/a" }, { "/a", "/b" }), false)
expect("one fewer", clipboard.same({ "/a", "/b" }, { "/a" }), false)
expect("one other", clipboard.same({ "/a", "/b" }, { "/a", "/c" }), false)
expect("both empty", clipboard.same({}, {}), false)

if failed > 0 then
	io.stderr:write(failed .. " failed\n")
	os.exit(1)
end
print("clipboard-sync: all passed")
