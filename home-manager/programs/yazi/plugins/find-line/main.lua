--- @sync entry
-- fzf over the lines of the hovered file, and nvim on the line picked. A folder has no lines, so
-- it gets a word instead of an empty fzf; Esc in fzf leaves nothing to open and ends quietly
local M = {}

function M:entry()
	local hovered = cx.active.current.hovered
	if not hovered or hovered.cha.is_dir then
		return ya.notify { title = "Find line", content = "Hover a file to search its lines", level = "warn", timeout = 5 }
	end
	-- yazi puts the hovered path in for %h, quoted, and reads %% as a literal %, hence cut and
	-- not ${n%%:*}
	ya.emit("shell", {
		'n=$(grep -nI "" -- %h | fzf --delimiter=: --nth=2.. | cut -d: -f1); [ -z "$n" ] || nvim "+$n" -- %h',
		block = true,
	})
end

return M
