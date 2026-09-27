-- The pure half of main.lua, run by plain Lua with yazi's globals stubbed out: `lua test.lua`
-- from this directory, or the yazi-plugin-tests flake check
ya = {
	percent_decode = function(s)
		return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
	end,
}
local recent = dofile("main.lua")

local failed = 0
local function expect(what, got, want)
	if got ~= want then
		failed = failed + 1
		io.stderr:write(string.format("%s: want %q, got %q\n", what, tostring(want), tostring(got)))
	end
end

-- Only local files, the newest first, escapes decoded
local paths = recent.recent(table.concat({
	'<bookmark href="file:///home/me/old.pdf" added="2026-01-01T00:00:00Z" modified="2026-01-01T00:00:00Z">',
	'<bookmark href="https://example.org/" added="2026-05-01T00:00:00Z" modified="2026-05-01T00:00:00Z">',
	'<bookmark href="file:///home/me/%D0%BD%D0%BE%D0%B2%D1%8B%D0%B9.md" added="2026-03-01T00:00:00Z" modified="2026-03-02T00:00:00Z">',
}, "\n"))
expect("count", #paths, 2)
expect("newest", paths[1], "/home/me/новый.md")
expect("oldest", paths[2], "/home/me/old.pdf")

if failed > 0 then
	io.stderr:write(failed .. " failed\n")
	os.exit(1)
end
print("recent: all passed")
