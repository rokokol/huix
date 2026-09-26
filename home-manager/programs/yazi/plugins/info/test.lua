-- The pure half of main.lua, run by plain Lua with yazi's globals stubbed out: `lua test.lua`
-- from this directory, or the yazi-plugin-tests flake check. The tool outputs below are real
-- ones, cut down to the lines the parsers read
ya = { sync = function(fn) return fn end }
local info = dofile("main.lua")

local failed = 0
local function expect(what, got, want)
	if got ~= want then
		failed = failed + 1
		io.stderr:write(string.format("%s: want %q, got %q\n", what, tostring(want), tostring(got)))
	end
end

-- compsize -b: the TOTAL row, in bytes
local disk = info.compsize(table.concat({
	"Processed 3 files, 3 regular extents (3 refs), 0 inline, 1 fragments.",
	"Type       Perc     Disk Usage   Uncompressed Referenced  ",
	"TOTAL       24%     7680         31744        31744       ",
	"zstd        24%     7680         31744        31744       ",
}, "\n"))
expect("disk", disk and disk.disk, 7680)
expect("uncompressed", disk and disk.uncompressed, 31744)
expect("percent", disk and disk.percent, 24)
expect("no total", info.compsize("All empty or still-delalloced files.\n"), nil)

-- 7z l -slt: a 7z marks a folder by its attributes, a zip by Folder = +
local seven = info.archive(table.concat({
	"--",
	"Path = plain.7z",
	"Type = 7z",
	"Method = LZMA2:6k",
	"",
	"----------",
	"Path = d",
	"Size = 0",
	"Attributes = D drwxr-xr-x",
	"Encrypted = -",
	"",
	"Path = a.txt",
	"Size = 2400",
	"Attributes = A -rw-r--r--",
	"Encrypted = -",
	"Method = LZMA2:6k",
	"",
	"Path = d/b.txt",
	"Size = 2400",
	"Attributes = A -rw-r--r--",
	"Encrypted = -",
	"Method = Copy",
	"",
}, "\n"))
expect("7z type", seven.type, "7z")
expect("7z method", seven.method, "LZMA2:6k")
expect("7z files", seven.files, 2)
expect("7z dirs", seven.dirs, 1)
expect("7z size", seven.size, 4800)
expect("7z not encrypted", seven.encrypted, nil)

local zip = info.archive(table.concat({
	"--",
	"Path = enc.zip",
	"Type = zip",
	"",
	"----------",
	"Path = a.txt",
	"Folder = -",
	"Size = 2400",
	"Attributes =  -rw-r--r--",
	"Encrypted = +",
	"Method = ZipCrypto Deflate",
	"",
	"Path = sub",
	"Folder = +",
	"Size = 0",
	"Encrypted = -",
	"",
}, "\n"))
expect("zip files", zip.files, 1)
expect("zip dirs", zip.dirs, 1)
expect("zip method from an entry", zip.method, "ZipCrypto Deflate")
expect("zip encrypted", zip.encrypted, "contents")

local hidden = info.archive("ERROR: hdr.7z : Cannot open encrypted archive. Wrong password?\n")
expect("encrypted names", hidden.encrypted, "names")
expect("unknown count", hidden.files, nil)

-- pdfinfo, and what it says without the password
local pdf = info.pdf(table.concat({
	"Title:           Report",
	"Producer:        LaTeX with hyperref",
	"Pages:           12",
	"Encrypted:       yes (print:yes copy:no change:no addNotes:no algorithm:AES-256)",
	"Page size:       595.276 x 841.89 pts (A4)",
}, "\n"))
expect("pdf pages", pdf.pages, 12)
expect("pdf title", pdf.title, "Report")
expect("pdf producer", pdf.producer, "LaTeX with hyperref")
expect("pdf page size", pdf.page_size, "595.276 x 841.89 pts (A4)")
expect("pdf restricted", pdf.encrypted, "restrictions")
expect("pdf open", info.pdf("Pages:           1\nEncrypted:       no\n").encrypted, nil)
expect("pdf password", info.pdf("Command Line Error: Incorrect password\n").encrypted, "password")

-- ffprobe's json, decoded
local media = info.media({
	format = { duration = "3725.5", bit_rate = "131316" },
	streams = {
		{ codec_type = "video", codec_name = "h264", width = 320, height = 240, avg_frame_rate = "30000/1001", bit_rate = "47228" },
		{ codec_type = "audio", codec_name = "aac", sample_rate = "44100", channels = 1, channel_layout = "mono", bit_rate = "69694" },
		{ codec_type = "subtitle", codec_name = "subrip" },
		{ codec_type = "video", codec_name = "vp9", width = 1920, height = 1080, avg_frame_rate = "25/1" },
		{ codec_type = "audio", codec_name = "opus", sample_rate = "48000", channels = 6 },
	},
})
expect("duration", media.duration, "1:02:05")
expect("bitrate", media.bitrate, "131 kb/s")
expect("streams", #media.streams, 5)
expect("video stream", media.streams[1], "h264, 320x240, 29.97 fps, 47 kb/s")
expect("audio stream", media.streams[2], "aac, 44.1 kHz, mono, 70 kb/s")
expect("other stream", media.streams[3], "subtitle: subrip")
expect("whole fps", media.streams[4], "vp9, 1920x1080, 25 fps")
expect("channels only", media.streams[5], "opus, 48 kHz, 6 ch")
-- yazi runs in the user's locale, where the decimal separator may be a comma
expect("comma zeros", info.trim_zeros("25,00"), "25")
expect("comma tail", info.trim_zeros("30,50"), "30,5")
expect("comma kept", info.trim_zeros("44,1"), "44,1")
expect("tens kept", info.trim_zeros("100,00"), "100")
expect("dot zeros", info.trim_zeros("48.0"), "48")
expect("whole number", info.trim_zeros("100"), "100")
local short = info.media({ format = { duration = "3.0" }, streams = {} })
expect("short duration", short.duration, "0:03")
expect("no bitrate", short.bitrate, nil)

-- magick identify -format "%m|%Q|%C": quality means something for a JPEG only
local jpeg = info.image("JPEG|83|JPEG\n")
expect("jpeg quality", jpeg.quality, "83")
expect("jpeg compression", jpeg.compression, "JPEG")
local png = info.image("PNG|92|Zip\n")
expect("png quality", png.quality, nil)
expect("png compression", png.compression, "Zip")

-- find -printf %y: one letter a node, d for a directory
local dirs, files = info.count("dffldf")
expect("count dirs", dirs, 2)
expect("count files", files, 4)

if failed > 0 then
	io.stderr:write(failed .. " failed\n")
	os.exit(1)
end
print("info: all passed")
