--- @sync entry
-- A new tab inside the hovered directory. The bare tab_create only reveals the hovered entry
-- in its parent, so a directory is handed over by path; a file still gets that reveal
return {
	entry = function()
		local hovered = cx.active.current.hovered
		if hovered and hovered.cha.is_dir then
			ya.emit("tab_create", { hovered.url })
		else
			ya.emit("tab_create", { current = true })
		end
	end,
}
