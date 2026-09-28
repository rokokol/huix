-- The system clipboard as yazi's own. `export`, run after a yank, offers the yanked files to
-- other programs, and one picture as the picture too; `paste` puts what the clipboard holds
-- into the current folder, and with `--force` overwrites a file of the same name instead of
-- picking a free one. Files are copied, or moved when they were cut, as yazi tasks; an image
-- or a text becomes a file of its own. yazi's built-in `clipboard` reads files through the
-- terminal on kitty's paste and only copies them; this one works in any terminal. `files`,
-- `offers`, `same`, `pick` and `picture` are pure and are what test.lua checks
local M = {}

local GNOME = "x-special/gnome-copied-files"
local URIS = "text/uri-list"
local TEXT = "text/plain;charset=utf-8"

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

-- The gnome-copied-files and uri-list texts that offer these files, and the plain text of their
-- paths for a program that pastes text
function M.offers(paths, cut)
  local uris = {}
  for i, path in ipairs(paths) do
    uris[i] = "file://" .. ya.percent_encode(path)
  end
  return (cut and "cut" or "copy") .. "\n" .. table.concat(uris, "\n"),
      table.concat(uris, "\r\n") .. "\r\n",
      table.concat(paths, "\n")
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
  for _, mime in ipairs { TEXT, "text/plain", URIS } do
    if has[mime] then
      return mime
    end
  end
end

-- The types a browser pastes as a picture, where a link to the file would go in as its path
-- Only pictures: Zen gives a page no video/mp4 from the clipboard, as a paste into GitHub shows
local PICTURES = { ["image/png"] = true, ["image/jpeg"] = true, ["image/gif"] = true, ["image/webp"] = true }

-- The type to offer a yank's contents in beside its files: only for one picture
function M.picture(count, mime) return count == 1 and PICTURES[mime] and mime or nil end

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

  local gnome, uris, text = M.offers(paths, cut)
  local dir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
  local gnome_file, uris_file = dir .. "/yazi-clipboard-gnome", dir .. "/yazi-clipboard-uris"
  local text_file = dir .. "/yazi-clipboard-text"
  if not (write(gnome_file, gnome) and write(uris_file, uris) and write(text_file, text)) then
    return fail("Cannot write the offers to " .. dir)
  end
  -- wl-copy offers the first text type also as text/plain, STRING and the rest, so the paths
  -- come first and a text field gets them rather than the file:// links
  local args = { "--offer", TEXT, text_file, "--offer", GNOME, gnome_file, "--offer", URIS, uris_file }
  -- one picture goes as the picture too, so a web page takes the image and not its path
  local mime = #paths == 1 and run("file", { "-b", "--mime-type", "--", paths[1] })
  local picture = mime and M.picture(1, (mime:gsub("%s+$", "")))
  if picture then
    args[#args + 1], args[#args + 2], args[#args + 3] = "--offer", picture, paths[1]
  end
  -- wl-copy reads every file before it forks, so they are free again once it returns
  local _, err = run(bin .. "/wl-copy", args)
  if err then
    return fail("wl-copy: " .. err)
  end
  set_exported(uris)
end

-- Files that another program put on the clipboard, copied or moved here as yazi tasks, which
-- show progress and, unless forced, pick a free name when the one here is taken
local function transfer(bin, files, cwd, force)
  for _, path in ipairs(files.paths) do
    local from = Url(path)
    if from.name then
      local op = files.cut and "move" or "copy"
      ya.task(op, { from = from, to = Url(cwd):join(from.name), force = force }):spawn()
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

local function paste(force)
  local bin = state()
  local types = run(bin .. "/wl-paste", { "--list-types" }) or ""
  local has = function(mime) return ("\n" .. types .. "\n"):find("\n" .. mime:gsub("%p", "%%%0") .. "\n") ~= nil end

  local files = M.files(has(GNOME) and paste_type(bin, GNOME), has(URIS) and paste_type(bin, URIS))
  if files then
    -- Thunar moves a cut that another program put on the clipboard and cannot clear it after,
    -- so it can name files that are gone, which a yazi task would wait for forever
    local found = {}
    for _, path in ipairs(files.paths) do
      if fs.cha(Url(path)) then
        found[#found + 1] = path
      end
    end
    if #found < #files.paths then
      -- nothing pasted is a failed paste; some pasted is a paste with a warning
      local content = string.format("%d of %d files are gone", #files.paths - #found, #files.paths)
      ya.notify { title = "Clipboard", content = content, level = #found == 0 and "error" or "warn", timeout = 5 }
    end
    if #found == 0 then
      return run(bin .. "/wl-copy", { "--clear" })
    end
    files.paths = found
  end

  local own, own_cut, cwd = yanked()
  if files and M.same(own, files.paths) then
    -- the clipboard holds yazi's own yank: its paste shows progress and can be cancelled
    ya.emit("paste", { force = force })
    if own_cut then
      run(bin .. "/wl-copy", { "--clear" })
    end
  elseif files then
    transfer(bin, files, cwd, force)
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
    paste(job.args.force == true)
  else
    fail("Unknown action: " .. tostring(action))
  end
end

return M
