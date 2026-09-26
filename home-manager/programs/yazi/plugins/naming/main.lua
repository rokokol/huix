-- Renames the selected files, or the hovered one, into a case style or into ICAO Latin.
-- `convert` is pure and is what test.lua beside this file checks
local M = {}

local SEPARATORS = { [32] = true, [45] = true, [46] = true, [95] = true }

-- ICAO Doc 9303, the romanisation Russian passports use; the soft sign has no letter
local ICAO = {
	["а"] = "a", ["б"] = "b", ["в"] = "v", ["г"] = "g", ["д"] = "d", ["е"] = "e", ["ё"] = "e",
	["ж"] = "zh", ["з"] = "z", ["и"] = "i", ["й"] = "i", ["к"] = "k", ["л"] = "l", ["м"] = "m",
	["н"] = "n", ["о"] = "o", ["п"] = "p", ["р"] = "r", ["с"] = "s", ["т"] = "t", ["у"] = "u",
	["ф"] = "f", ["х"] = "kh", ["ц"] = "ts", ["ч"] = "ch", ["ш"] = "sh", ["щ"] = "shch",
	["ъ"] = "ie", ["ы"] = "y", ["ь"] = "", ["э"] = "e", ["ю"] = "iu", ["я"] = "ia",
}

-- string.upper and string.lower know ASCII alone, so Cyrillic moves by code point
local function is_upper(cp) return (cp >= 65 and cp <= 90) or (cp >= 0x410 and cp <= 0x42F) or cp == 0x401 end

local function is_lower(cp) return (cp >= 97 and cp <= 122) or (cp >= 0x430 and cp <= 0x44F) or cp == 0x451 end

local function lower(cp)
	if cp == 0x401 then
		return 0x451
	end
	return is_upper(cp) and cp + 32 or cp
end

local function upper(cp)
	if cp == 0x451 then
		return 0x401
	end
	return is_lower(cp) and cp - 32 or cp
end

local function codes(s)
	local list = {}
	for _, cp in utf8.codes(s) do
		list[#list + 1] = cp
	end
	return list
end

-- A dotfile's leading dots stay outside the name; a directory has no extension; a tarball
-- keeps both of its suffixes
local function split(name, is_dir)
	local lead, rest = name:match("^(%.*)(.*)$")
	if is_dir then
		return lead, rest, ""
	end
	local stem, ext = rest:match("^(.+)(%.tar%.[^.]+)$")
	if not stem then
		stem, ext = rest:match("^(.+)(%.[^.]+)$")
	end
	return lead, stem or rest, ext or ""
end

-- Words end at a separator, where a lower-case letter or a digit meets a capital, and before
-- the last capital of an acronym that a lower-case letter continues
local function words(stem)
	local cps, list, word = codes(stem), {}, {}
	for i, cp in ipairs(cps) do
		if SEPARATORS[cp] then
			if #word > 0 then
				list[#list + 1], word = word, {}
			end
		else
			local prev, next = cps[i - 1], cps[i + 1]
			local starts = #word > 0
				and is_upper(cp)
				and (not is_upper(prev) or (next and is_lower(next)))
			if starts then
				list[#list + 1], word = word, {}
			end
			word[#word + 1] = cp
		end
	end
	if #word > 0 then
		list[#list + 1] = word
	end
	return list
end

local function spell(word, first, rest)
	local out = {}
	for i, cp in ipairs(word) do
		out[i] = (i == 1 and first or rest)(cp)
	end
	return utf8.char(table.unpack(out))
end

local STYLES = {
	kebab = { sep = "-", first = lower, rest = lower },
	snake = { sep = "_", first = lower, rest = lower },
	caps = { sep = "_", first = upper, rest = upper },
	pascal = { sep = "", first = upper, rest = lower },
	camel = { sep = "", first = upper, rest = lower, lead = lower },
}

local function restyle(stem, style)
	local out = {}
	for i, word in ipairs(words(stem)) do
		local first = i == 1 and style.lead or style.first
		out[i] = spell(word, first, style.rest)
	end
	return table.concat(out, style.sep)
end

-- A capital opens its digraph as Sh, or spells it SH when a neighbour is a capital too
local function icao(stem)
	local cps, out = codes(stem), {}
	for i, cp in ipairs(cps) do
		local latin = ICAO[utf8.char(lower(cp))]
		if not latin then
			out[#out + 1] = utf8.char(cp)
		elseif not is_upper(cp) then
			out[#out + 1] = latin
		elseif is_upper(cps[i - 1] or 0) or is_upper(cps[i + 1] or 0) then
			out[#out + 1] = latin:upper()
		else
			out[#out + 1] = latin:sub(1, 1):upper() .. latin:sub(2)
		end
	end
	return table.concat(out)
end

function M.convert(name, is_dir, mode)
	local lead, stem, ext = split(name, is_dir)
	local style = STYLES[mode]
	if style then
		return lead .. restyle(stem, style) .. ext
	elseif mode == "icao" then
		return lead .. icao(stem) .. ext
	end
end

local targets = ya.sync(function()
	local list = {}
	for _, file in pairs(cx.active.selected) do
		list[#list + 1] = { url = tostring(file.url), is_dir = file.cha.is_dir }
	end
	local hovered = cx.active.current.hovered
	if #list == 0 and hovered then
		list[1] = { url = tostring(hovered.url), is_dir = hovered.cha.is_dir }
	end
	return list
end)

local function warn(content, level) ya.notify { title = "Rename", content = content, level = level or "warn", timeout = 5 } end

function M:entry(job)
	local mode = job.args[1]
	local clashes, last = {}, nil
	for _, target in ipairs(targets()) do
		local from = Url(target.url)
		local name = M.convert(from.name, target.is_dir, mode)
		if not name then
			return warn("Unknown style: " .. tostring(mode), "error")
		end
		local to = from.parent:join(name)
		if name == from.name then
			last = from
		elseif fs.cha(to) then
			clashes[#clashes + 1] = name
		else
			local ok, err = fs.rename(from, to)
			if not ok then
				return warn(string.format("%s: %s", from.name, tostring(err)), "error")
			end
			last = to
		end
	end
	-- the cursor follows the file, so the next style applies to the new name
	if last then
		ya.emit("reveal", { last })
	end
	if #clashes > 0 then
		warn("Already taken, left as they were: " .. table.concat(clashes, ", "))
	end
end

return M
