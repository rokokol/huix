--- @sync entry
-- yazi's search with a switch for the files a .gitignore names, beside the switch for hidden
-- files that yazi's search already follows. `names` searches with fd, `content` with rga, which
-- reads pdf and office files as well; `toggle` flips the switch. It starts off, as in git
local M = {}

local VIA = { names = "fd", content = "rga" }

function M:entry(job)
	local action = job.args[1]
	if action == "toggle" then
		self.ignored = not self.ignored
		return ya.notify {
			title = "Search",
			content = self.ignored and "Finds ignored files too" or "Skips ignored files",
			level = "info",
			timeout = 3,
		}
	end
	local via = VIA[action]
	if not via then
		return ya.notify { title = "Search", content = "Unknown action: " .. tostring(action), level = "error", timeout = 5 }
	end
	ya.emit("search", { via = via, args = self.ignored and "--no-ignore-vcs" or "" })
end

return M
