--- @sync entry
-- Shows or hides the git status column that init.lua wraps around git.yazi's own
return {
	entry = function()
		GIT_COLUMN = not GIT_COLUMN
		ui.render()
	end,
}
