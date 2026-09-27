-- The spot window on `I`, with more than yazi's own spotters show: owner, permissions, the size
-- on disk with the compression a btrfs gave it, file(1)'s verdict beside the type yazi took, and
-- a section for the kind of file. Multi-selection, trash, remote and unreadable files keep the
-- spotter they had. It also previews images, audio and video with their details under the
-- picture. The parsers are pure and are what test.lua checks
local M = {}

-- `compsize -b`: the TOTAL row, in bytes. Referenced counts an extent once for every file that
-- uses it, so it passes Uncompressed where reflinked copies or snapshots share data
function M.compsize(text)
	local percent, disk, uncompressed, referenced =
		("\n" .. text):match("\nTOTAL%s+(%d+)%%%s+(%d+)%s+(%d+)%s+(%d+)")
	if percent then
		return {
			percent = tonumber(percent),
			disk = tonumber(disk),
			uncompressed = tonumber(uncompressed),
			referenced = tonumber(referenced),
		}
	end
end

-- `du -sB1`: the bytes the file or the folder takes
function M.du(text) return tonumber(text:match("^(%d+)%s")) end

-- What the On disk row shows: the compression where compsize found some, else the plain size,
-- from compsize on an uncompressed btrfs and from du on any other filesystem; and the data the
-- files reach through extents another file holds as well
function M.on_disk(compressed, du)
	if not (compressed or du) then
		return
	end
	local shown = { disk = compressed and compressed.disk or du }
	if compressed and compressed.disk < compressed.uncompressed then
		shown.uncompressed, shown.percent = compressed.uncompressed, compressed.percent
	end
	if compressed and (compressed.referenced or 0) > compressed.uncompressed then
		shown.shared = compressed.referenced - compressed.uncompressed
	end
	return shown
end

-- `7z l -slt`: the archive's block, then one block an entry. `encrypted` is "contents" when an
-- entry is, and "names" when the listing itself is locked
function M.archive(text)
	if text:find("Cannot open encrypted archive", 1, true) then
		return { encrypted = "names" }
	end
	local head, body = text:match("^(.-)\n%-%-%-%-%-%-%-%-%-%-\n(.*)$")
	local result = {
		type = head and head:match("\nType = ([^\n]+)"),
		method = head and head:match("\nMethod = ([^\n]+)"),
	}
	if not body then
		return result
	end
	result.files, result.dirs, result.size = 0, 0, 0
	for entry in (body .. "\n\n"):gmatch("(.-)\n\n") do
		local field = function(name) return ("\n" .. entry):match("\n" .. name .. " = ([^\n]*)") end
		if field("Path") then
			if field("Folder") == "+" or (field("Attributes") or ""):match("^D") then
				result.dirs = result.dirs + 1
			else
				result.files = result.files + 1
				result.size = result.size + (tonumber(field("Size")) or 0)
			end
			if field("Encrypted") == "+" then
				result.encrypted = "contents"
			end
			local method = field("Method")
			if not result.method and method and method ~= "" then
				result.method = method
			end
		end
	end
	return result
end

-- pdfinfo; a PDF that needs a password to open has no fields at all. `encrypted` is "password"
-- then, and "restrictions" for one that opens but limits what may be done with it
function M.pdf(text)
	if text:find("Incorrect password", 1, true) then
		return { encrypted = "password" }
	end
	text = "\n" .. text .. "\n"
	local field = function(name) return text:match("\n" .. name .. ":%s+([^\n]-)%s*\n") end
	return {
		title = field("Title"),
		producer = field("Producer"),
		pages = tonumber(field("Pages")),
		page_size = field("Page size"),
		encrypted = (field("Encrypted") or ""):match("^yes") and "restrictions" or nil,
	}
end

local function duration(seconds)
	local s = math.floor(tonumber(seconds) or 0)
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, s % 3600 // 60, s % 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

local function kbps(bits)
	local n = tonumber(bits)
	return n and string.format("%d kb/s", math.floor(n / 1000 + 0.5))
end

-- The zeros a fraction ends in, and its separator when nothing is left after it. string.format
-- writes the separator of yazi's locale, which may be a comma
function M.trim_zeros(s)
	if not s:find("[.,]") then
		return s
	end
	return (s:gsub("0+$", ""):gsub("[.,]$", ""))
end

local function fps(rate)
	local num, den = (rate or ""):match("^(%d+)/(%d+)$")
	if num and tonumber(den) > 0 and tonumber(num) > 0 then
		return M.trim_zeros(string.format("%.2f", num / den)) .. " fps"
	end
end

local function khz(rate)
	local n = tonumber(rate)
	return n and M.trim_zeros(string.format("%.1f", n / 1000)) .. " kHz"
end

-- A stream as one line: the codec, then what matters for its type
local function stream(s)
	local parts = { s.codec_name or "?" }
	local function add(v)
		if v then
			parts[#parts + 1] = v
		end
	end
	if s.codec_type == "video" then
		add(s.width and s.height and string.format("%dx%d", s.width, s.height))
		add(fps(s.avg_frame_rate))
	elseif s.codec_type == "audio" then
		add(khz(s.sample_rate))
		add(s.channel_layout or (s.channels and s.channels .. " ch"))
	else
		return string.format("%s: %s", s.codec_type or "data", s.codec_name or "?")
	end
	add(kbps(s.bit_rate))
	return table.concat(parts, ", ")
end

-- ffprobe's json, decoded
function M.media(meta)
	local format, streams = meta.format or {}, {}
	for i, s in ipairs(meta.streams or {}) do
		streams[i] = stream(s)
	end
	return { duration = duration(format.duration), bitrate = kbps(format.bit_rate), streams = streams }
end

local TAGS = { "title", "artist", "album", "date" }

-- The lines a media preview shows, as { label, value }: the container's tags, whose keys come in
-- any case (FLAC and Ogg write TITLE), then what `media` reads out of the streams
function M.media_lines(meta)
	local tags, lines = {}, {}
	for key, value in pairs((meta.format or {}).tags or {}) do
		tags[key:lower()] = value
	end
	for _, tag in ipairs(TAGS) do
		if tags[tag] then
			lines[#lines + 1] = { tag:sub(1, 1):upper() .. tag:sub(2), tags[tag] }
		end
	end
	local m = M.media(meta)
	lines[#lines + 1] = { "Duration", m.duration }
	if m.bitrate then
		lines[#lines + 1] = { "Bitrate", m.bitrate }
	end
	for i, s in ipairs(m.streams) do
		lines[#lines + 1] = { "Stream " .. i, s }
	end
	return lines
end

-- What `magick identify` prints for M.image: one line, the fields split by |
M.IDENTIFY = "%m|%Q|%C|%wx%h|%[colorspace]|%[EXIF:Model]|%[EXIF:DateTimeOriginal]\n"

-- The first line of `magick identify -format IDENTIFY`; a warning about a missing EXIF field
-- follows it. The quality is an estimate a JPEG carries and a guess for anything else, so only
-- a JPEG shows it, and EXIF writes its date with colons
function M.image(text)
	local fields = {}
	for field in ((text:match("^[^\n]*") or "") .. "|"):gmatch("([^|]*)|") do
		fields[#fields + 1] = field ~= "" and field or nil
	end
	local format, quality, compression, size, color, camera, taken = table.unpack(fields, 1, 7)
	return {
		format = format,
		quality = format == "JPEG" and quality or nil,
		compression = compression,
		size = size,
		color = color,
		camera = camera,
		taken = taken and (taken:gsub("^(%d+):(%d+):(%d+)", "%1-%2-%3")),
	}
end

-- The lines an image shows in the preview and the spot window, as { label, value }
function M.image_lines(img)
	local lines = {}
	for _, field in ipairs {
		{ "Format", img.format },
		{ "Size", img.size },
		{ "Color", img.color },
		{ "Quality", img.quality },
		{ "Compression", img.compression },
		{ "Camera", img.camera },
		{ "Taken", img.taken },
	} do
		if field[2] then
			lines[#lines + 1] = field
		end
	end
	return lines
end

-- `find -printf %y`: a letter a node, `d` for a directory
function M.count(letters)
	local _, dirs = letters:gsub("d", "")
	return dirs, #letters - dirs
end

-- The spotters yazi keeps for files that are not local files or not a single one
local DELEGATED = { multi = true, vfs = true, trash = true, null = true }

function M:setup(opts) self.compsize = (opts or {}).compsize end

local compsize_path = ya.sync(function(self) return self.compsize end)

local function row(name, value) return ui.Row { "  " .. name .. ":", value or "-" } end

local function header(name) return ui.Row({ name }):style(ui.Style():fg("green")) end

local function run(cmd, args)
	local output = Command(cmd):arg(args):stdout(Command.PIPED):stderr(Command.PIPED):output()
	return output and (output.stdout .. output.stderr) or ""
end

local function show(job, rows)
	ya.spot_table(
		job,
		ui.Table(rows)
			:area(ui.Pos { "center", w = 64, h = 24 })
			:row(1)
			:col(1)
			:col_style(th.spot.tbl_col)
			:cell_style(th.spot.tbl_cell)
			:widths { ui.Constraint.Length(15), ui.Constraint.Fill(1) }
	)
end

local function kind(job)
	if job.file.cha.is_dir then
		return "folder"
	end
	local top = job.mime:match("^[^/]+")
	if top == "audio" or top == "video" or top == "image" then
		return top
	elseif job.mime == "application/pdf" then
		return "pdf"
	end
	-- An archive is whatever yazi previews as one, so the list of their types stays yazi's
	for _, v in pairs(rt.plugin.previewers:match { file = job.file, mime = job.mime }) do
		return v.name == "archive" and "archive" or nil
	end
end

local ENCRYPTION = {
	contents = "file contents",
	names = "names and contents",
	password = "password to open",
	restrictions = "opens, with restrictions",
}

local PENDING = "…"

-- A row whose probe has not answered yet shows PENDING, one it answered without a value "-"
local function probed(data, value)
	if data == nil then
		return PENDING
	end
	return value
end

local function ffprobe(path)
	return ya.json_decode(run("ffprobe", {
		"-v",
		"quiet",
		"-show_entries",
		"format=duration,bit_rate:format_tags:stream=codec_type,codec_name,width,height,avg_frame_rate,"
			.. "sample_rate,channels,channel_layout,bit_rate",
		"-of",
		"json=c=1",
		path,
	})) or false
end

-- What the slow tools say about a file of each kind. A probe runs once a spot, and gives false
-- when its tool had nothing to say
local PROBES = {
	audio = ffprobe,
	video = ffprobe,
	image = function(path) return M.image(run("magick", { "identify", "-format", M.IDENTIFY, path .. "[0]" })) end,
	archive = function(path) return M.archive(run("7zz", { "l", "-slt", "-p", "--", path })) end,
	pdf = function(path) return M.pdf(run("pdfinfo", { "--", path })) end,
}

-- A section from the { label, value } lines the preview shows too, or one PENDING row while the
-- probe runs and a "-" when it found nothing
local function lines_rows(title, lines, first)
	local rows = { header(title) }
	if lines == nil or #lines == 0 then
		rows[2] = row(first, probed(lines))
	end
	for _, line in ipairs(lines or {}) do
		rows[#rows + 1] = row(line[1], line[2])
	end
	return rows
end

local function media_rows(title, meta)
	if meta == nil then
		return lines_rows(title, nil, "Duration")
	end
	return lines_rows(title, type(meta) == "table" and M.media_lines(meta) or {}, "Duration")
end

-- The section for each kind of file, from its probe's answer, or nil while the probe runs. yazi
-- takes a row it draws, so a section is built anew for every draw
local SECTIONS = {
	audio = function(_, meta) return media_rows("Audio", meta) end,
	video = function(_, meta) return media_rows("Video", meta) end,
	image = function(_, img) return lines_rows("Image", img and M.image_lines(img), "Format") end,
	archive = function(_, a)
		local got = a or {}
		return {
			header("Archive"),
			row("Type", probed(a, got.type)),
			row("Method", got.method),
			row("Items", got.files and string.format("%d files, %d folders", got.files, got.dirs)),
			row("Unpacked", got.size and ya.readable_size(got.size)),
			row("Encrypted", probed(a, ENCRYPTION[got.encrypted] or "no")),
		}
	end,
	pdf = function(_, p)
		local got = p or {}
		return {
			header("PDF"),
			row("Title", got.title),
			row("Pages", probed(p, got.pages and tostring(got.pages))),
			row("Page size", got.page_size),
			row("Producer", got.producer),
			row("Encrypted", probed(p, ENCRYPTION[got.encrypted] or "no")),
		}
	end,
}

-- The size the file takes on disk and what file(1) calls it. compsize answers on btrfs alone and
-- only where it is set up; du answers everywhere else. `disk` is false when neither can
local function probe_general(job, path)
	local compsize = compsize_path()
	local compressed = compsize and M.compsize(run("sudo", { "-n", compsize, "-b", "-x", "--", path }))
	local du = not compressed and M.du(run("du", { "-sxB1", "--", path }))
	local verdict = not job.file.cha.is_dir and run("file", { "-b", "--", path }):gsub("\n$", "")
	return { disk = M.on_disk(compressed or nil, du or nil) or false, verdict = verdict or nil }
end

-- Owner, permissions and the probe's answers, or PENDING in their rows while `g` is nil
local function general(job, g)
	local cha = job.file.cha
	local rows = { header("File") }
	if not cha.is_dir then
		rows[#rows + 1] = row("Size", ya.readable_size(cha.len))
	end
	rows[#rows + 1] = row("Permissions", cha:perm())
	local user = ya.user_name and ya.user_name(cha.uid) or tostring(cha.uid)
	local group = ya.group_name and ya.group_name(cha.gid) or tostring(cha.gid)
	rows[#rows + 1] = row("Owner", string.format("%s:%s", user, group))

	local disk = g and g.disk
	local size = disk and ya.readable_size(disk.disk)
	if disk and disk.uncompressed then
		size = string.format("%s of %s (%d%%)", size, ya.readable_size(disk.uncompressed), disk.percent)
	end
	if disk and disk.shared then
		size = string.format("%s, %s shared", size, ya.readable_size(disk.shared))
	end
	rows[#rows + 1] = row("On disk", probed(g, size))
	if not cha.is_dir then
		rows[#rows + 1] = row("file(1)", probed(g, g and g.verdict))
	end
	return rows
end

local function merge(...)
	local all = {}
	for _, rows in ipairs { ... } do
		if #rows > 0 then
			if #all > 0 then
				all[#all + 1] = ui.Row {}
			end
			for _, r in ipairs(rows) do
				all[#all + 1] = r
			end
		end
	end
	return all
end

-- A folder: the item count and the size on disk come first, then yazi's own spotter counts the
-- size as it goes, which is the part that can take long
local function spot_folder(job, path)
	local function draw(size, count, g)
		local items = { header("Items"), row("Count", count) }
		show(job, merge(size, items, general(job, g), require("file"):spot_base(job)))
	end
	draw({ header("Folder"), row("Size", PENDING) }, PENDING, nil)
	local dirs, files = M.count(run("find", { path, "-mindepth", "1", "-printf", "%y" }))
	local count, g = string.format("%d files, %d folders", files, dirs), probe_general(job, path)

	local folder = require("folder")
	for rows in folder:spot_base(job) do
		draw(rows, count, g)
	end
	local url = job.file.url
	if folder.size then
		ya.emit("update_files", { op = fs.op("size", { url = url.trail, sizes = { [url.key] = folder.size } }) })
	end
end

function M:spot(job)
	local top = job.mime:match("^[^/]+")
	local path = job.file.path and tostring(job.file.path)
	if DELEGATED[top] or not path then
		for _, v in pairs(rt.plugin.spotters:match { file = job.file, mime = job.mime }) do
			if v.name ~= "info" then
				return require(v.name):spot(job)
			end
		end
		return
	end

	local what = kind(job)
	if what == "folder" then
		return spot_folder(job, path)
	end
	local section = SECTIONS[what] or function() return {} end
	local function draw(data, g) show(job, merge(section(job, data), general(job, g), require("file"):spot_base(job))) end
	draw(nil, nil)
	local probe = PROBES[what]
	draw(probe and probe(path), probe_general(job, path))
end

-- The preview of images, audio and video: a picture over the lines image_lines or media_lines
-- gives. For video it is the frame yazi's own previewer takes, which J and K move through; for
-- audio a spectrogram, made on the first hover and kept in yazi's cache
local function is_video(job) return job.mime:match("^video/") ~= nil end

-- The previewer yazi would pick for an image, which knows how to turn it into a picture: image
-- for the common formats, magick and svg for the rest
local function picture_plugin(job)
	for _, v in pairs(rt.plugin.previewers:match { file = job.file, mime = job.mime }) do
		if v.name ~= "info" then
			return v.name
		end
	end
end

local function is_image(job) return job.mime:match("^image/") ~= nil end

function M:preload(job)
	if is_video(job) then
		return require("video"):preload(job)
	elseif is_image(job) then
		local name = picture_plugin(job)
		return true, name and select(2, require(name):preload(job))
	end
	local cache = ya.file_cache(job)
	local cha = cache and fs.cha(cache)
	if not cache or (cha and cha.len > 0) then
		return true
	end
	local output, err = Command("ffmpeg")
		-- a log scale spreads a melody over the picture, where a linear one presses it to the floor
		:arg({ "-v", "error", "-y", "-i", tostring(job.file.path), "-lavfi", "showspectrumpic=s=1024x512:legend=0:fscale=log" })
		:arg({ "-frames:v", "1", "-f", "image2", "-c:v", "png", tostring(cache) })
		:stderr(Command.PIPED)
		:output()
	if not output then
		return true, Err("Failed to start `ffmpeg`, error: %s", err)
	elseif not output.status.success then
		return true, Err("ffmpeg: %s", output.stderr)
	end
	return true
end

function M:peek(job)
	local start = os.clock()
	local _, err = self:preload(job)

	local path, details = tostring(job.file.path), nil
	if is_image(job) then
		details = PROBES.image(path)
		details = M.image_lines(details)
	else
		local meta = ffprobe(path)
		details = type(meta) == "table" and M.media_lines(meta) or {}
	end
	local lines = {}
	for _, line in ipairs(details) do
		lines[#lines + 1] = ui.Line { ui.Span(line[1] .. ": "):style(th.spot.tbl_col), ui.Span(line[2]) }
	end
	if err then
		lines[#lines + 1] = ui.Line(tostring(err))
	end

	-- the picture takes what the lines leave, and at least half the area
	local text_h = math.min(#lines + 1, job.area.h // 2)
	local area = job.area
	ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))
	-- an image in a common format may have no cached copy, and then shows itself
	local picture = ya.file_cache(job)
	local cached = picture and fs.cha(picture)
	if is_image(job) and not (cached and cached.len > 0) then
		picture = job.file.url
	end
	local shown = picture and ya.image_show(picture, ui.Rect { x = area.x, y = area.y, w = area.w, h = area.h - text_h })
	local top = area.y + (shown and shown.h + 1 or 0)
	ya.preview_widget(job, {
		ui.Text(lines):area(ui.Rect { x = area.x, y = top, w = area.w, h = area.y + area.h - top }):wrap(ui.Wrap.YES),
	})
end

function M:seek(job)
	if is_video(job) then
		require("video"):seek(job)
	end
end

return M
