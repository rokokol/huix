--- @since 26.9.1
--- @sync entry

-- Folds the which popup: the chords that share their next key become one row under the group's
-- name, and that key opens the group as a popup of its own, as nixvim's which-key does

local NAMED = { Escape = "Esc", Fn = "F" }

-- The notation of `Chord::on()` in Yazi, so group names are written as keys in keymap.toml are
local function key_str(key)
	local plain = not (key.ctrl or key.alt or key.super) and key.type == "Char"
	if plain and key.value == " " then
		return "<Space>"
	elseif plain then
		return key.value
	end

	local mods = (key.super and "D-" or "") .. (key.ctrl and "C-" or "") .. (key.alt and "A-" or "")
	if key.shift and key.type ~= "Char" then
		mods = mods .. "S-"
	end

	local name = key.type == "Char" and key.value or (NAMED[key.type] or key.type) .. (key.value or "")
	return "<" .. mods .. (name == " " and "Space" or name) .. ">"
end

local function prefix_str(on, n)
	local s = ""
	for i = 1, n do
		s = s .. key_str(on[i])
	end
	return s
end

-- Replaces each run of chords that share their next key with one row that opens them as a group
local function fold(st, cands, times, layer)
	local order, buckets, direct = {}, {}, {}
	for _, c in ipairs(cands) do
		local next = prefix_str(c.on, times + 1)
		if not buckets[next] then
			order[#order + 1], buckets[next] = next, {}
		end
		if #c.on == times + 1 then
			direct[next] = true
		end
		table.insert(buckets[next], c)
	end

	local rows = {}
	for _, next in ipairs(order) do
		local members, name = buckets[next], st.groups[next]
		if direct[next] or (#members < 2 and not name) then
			for _, c in ipairs(members) do
				rows[#rows + 1] = c
			end
		else
			st.last = st.last + 1
			st.stash[st.last] = { cands = members, times = times + 1, layer = layer }

			local on = {}
			for i = 1, times + 1 do
				on[i] = members[1].on[i]
			end
			rows[#rows + 1] = { on = on, run = "plugin which-fold " .. st.last, desc = name or "+" .. #members }
		end
	end
	return rows
end

local function setup(st, opts)
	st.groups = opts and opts.groups or {}
	st.stash, st.last = {}, 0

	ps.sub("ind-which-activate", function(args)
		-- which-delay hides the popup through the same table and marks it shown again later
		st.stash, st.event = {}, args
		local ok, rows = pcall(fold, st, args.cands, args.times, tostring(args.layer))
		if ok then
			args.cands = rows
		else
			ya.err("which-fold: " .. tostring(rows))
		end
		return args
	end)
end

local function entry(st, job)
	local group = st.stash[tonumber(job.args[1])]
	if not group then
		return
	end

	local opt = fold(st, group.cands, group.times, group.layer)
	opt.layer, opt.times, opt.silent = group.layer, group.times, st.event.silent == true
	ya.emit("which:activate", opt)
end

return { setup = setup, entry = entry }
