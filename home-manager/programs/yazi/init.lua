-- git.yazi's status column, hidden until the git-column plugin turns it on. The plugin adds
-- its column through Linemode:children_add and keeps no switch of its own, so the column it
-- hands over is wrapped on the way in
GIT_COLUMN = false
do
	local add = Linemode.children_add
	Linemode.children_add = function(self, fn, order)
		return add(self, function(line)
			return GIT_COLUMN and fn(line) or ""
		end, order)
	end
	require("git"):setup()
	Linemode.children_add = add
end

local function spelling(chord)
	local keys = {}
	for i, key in ipairs(chord.on) do
		keys[i] = ya.json_encode(key)
	end
	return keys
end

-- A prepended chord shadows a stock one only in part: when the keys typed so far complete a
-- chord, yazi runs it at once, however many longer chords share the start. So a chord that is
-- a prefix of, or equal to, a chord above it goes, which lets the leader take <Space>
for _, layer in ipairs { "mgr" } do
	local rules = km[layer].rules
	local seen, doomed = {}, {}
	for _, chord in pairs(rules:match()) do
		local keys = spelling(chord)
		local path = table.concat(keys, "\0")
		if seen[path] then
			doomed[#doomed + 1] = chord.id
		end
		for n = 1, #keys do
			seen[table.concat(keys, "\0", 1, n)] = true
		end
	end
	for _, id in ipairs(doomed) do
		rules:remove { id = id }
	end
end

-- Cyrillic twins for the keymap. yazi matches a key by the character it types, so with the
-- Russian layout on, `j` arrives as `о` and misses every binding. For each chord made only of
-- plain characters, a twin with every character moved through RU_LAYOUT is appended, carrying
-- the same actions. Layers where keys type text (input, cmp, help's filter) are left alone
local function twin(chord)
	local on, moved = {}, false
	for i, key in ipairs(chord.on) do
		if key.type ~= "Char" or key.ctrl or key.alt or key.super then
			return nil
		end
		local ru = RU_LAYOUT[key.value]
		if ru then
			on[i], moved = ru, true
		elseif key.value == " " then
			on[i] = "<Space>"
		else
			on[i] = key.value
		end
	end
	return moved and on or nil
end

for _, layer in ipairs { "mgr", "spot", "tasks" } do
	local rules = km[layer].rules
	local chords = {}
	for _, chord in pairs(rules:match()) do
		chords[#chords + 1] = chord
	end
	for _, chord in ipairs(chords) do
		local on = twin(chord)
		if on then
			-- A chord built from a table takes its actions as strings only; the originals are
			-- objects, which update() accepts, so the twin is born with a placeholder
			local copy = rules:insert(-1, { on = on, run = "escape", desc = chord.desc })
			rules:update({ id = copy.id }, { run = chord.run })
		end
	end
end
