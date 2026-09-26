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

-- A prepended chord shadows a stock one only in part: when the keys typed so far complete a
-- chord, yazi runs it at once, however many longer chords share the start. So a chord that is
-- a prefix of, or equal to, a chord above it goes, which lets the leader take <Space>
do
	local rules = km.mgr.rules
	local seen, doomed = {}, {}
	for _, chord in pairs(rules:match()) do
		local keys = {}
		for i, key in ipairs(chord.on) do
			keys[i] = ya.json_encode(key)
		end
		if seen[table.concat(keys, "\0")] then
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
