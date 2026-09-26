-- The name conversions of main.lua, run by plain Lua with yazi's globals stubbed out:
-- `lua test.lua` from this directory, or the yazi-plugin-tests flake check
ya = { sync = function(fn) return fn end }
local convert = dofile("main.lua").convert

local failed = 0
local function expect(mode, name, is_dir, want)
	local got = convert(name, is_dir, mode)
	if got ~= want then
		failed = failed + 1
		io.stderr:write(string.format("%s %q: want %q, got %q\n", mode, name, want, tostring(got)))
	end
end

-- Words split at separators and at a change of case, and the extension is left as it was
expect("kebab", "My File_name.TXT", false, "my-file-name.TXT")
expect("snake", "myFileName.md", false, "my_file_name.md")
expect("caps", "my-file name.md", false, "MY_FILE_NAME.md")
expect("pascal", "my_file-name.md", false, "MyFileName.md")
expect("camel", "My File Name.md", false, "myFileName.md")

-- An acronym stays one word until a lower-case letter starts the next
expect("snake", "HTTPServer.go", false, "http_server.go")

-- Digits stay with the word they touch
expect("kebab", "Version2 Final.txt", false, "version2-final.txt")

-- A directory has no extension, a dotfile keeps its dot, a tarball keeps both suffixes
expect("kebab", "My Photos.2024", true, "my-photos-2024")
expect("snake", ".Hidden Config", false, ".hidden_config")
expect("kebab", "Old Backup.tar.gz", false, "old-backup.tar.gz")

-- Cyrillic changes case too
expect("caps", "мой файл.txt", false, "МОЙ_ФАЙЛ.txt")
expect("pascal", "мой ёжик.txt", false, "МойЁжик.txt")

-- ICAO: digraphs, a capital that opens one, a soft sign dropped, anything Latin untouched
expect("icao", "Щука и ёж.txt", false, "Shchuka i ezh.txt")
expect("icao", "Юля-2 ПЬЕСА.md", false, "Iulia-2 PESA.md")
expect("icao", "Хорошо mix.txt", false, "Khorosho mix.txt")

if failed > 0 then
	io.stderr:write(failed .. " failed\n")
	os.exit(1)
end
print("naming: all passed")
