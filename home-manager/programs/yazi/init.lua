-- git.yazi's status column, hidden until the git-column plugin turns it on (see WORKAROUNDS.md)
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

-- Every directory yazi enters goes into zoxide's database, as a cd in the shell does
require("zoxide"):setup { update_db = true }

-- A prepended chord shadows a stock one only in part: when the keys typed so far complete a
-- chord, yazi runs it at once, however many longer chords share the start. So a chord that is
-- a prefix of, or equal to, a chord above it goes, which lets the leader take <Space>. A group
-- label is a prefix by design and runs nothing, so it stays
do
	local rules = km.mgr.rules
	local seen, doomed = {}, {}
	for _, chord in pairs(rules:match()) do
		local keys = {}
		for i, key in ipairs(chord.on) do
			keys[i] = ya.json_encode(key)
		end
		if #chord.run > 0 and seen[table.concat(keys, "\0")] then
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

-- Horizontal scrolling, a touchpad swipe or a tilted wheel, moves as h and l do. A swipe sends a
-- run of events, one per line it scrolls, so a run with no gap longer than GAP seconds is one
-- step: the first event of a run moves, the rest only keep the run going
do
	local GAP, last = 0.3, 0
	function Root:touch(_, step)
		if tostring(cx.layer) ~= "mgr" then
			return
		end
		local now = ya.time()
		local fresh = now - last > GAP
		last = now
		if fresh then
			ya.emit(step < 0 and "leave" or "enter", {})
		end
	end
end
