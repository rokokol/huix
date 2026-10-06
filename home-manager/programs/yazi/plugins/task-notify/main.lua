-- A notice inside yazi once a batch of tasks that ran for long enough is over: a paste, a
-- deletion, an extraction. A batch starts when the first task runs and ends when none runs. yazi
-- has no event for that and shows a plugin the task summary alone, so the watch rides on the
-- progress gauge, which yazi redraws on every change of that summary. The names of the tasks
-- reach Lua only while the task manager is open, so the notice speaks of the batch as a whole.
-- A cancelled task leaves the summary as a finished one does, so `x` in the task manager calls
-- `cancelling` before it cancels. `watch`, `cancel` and `duration` are pure and are what
-- test.lua checks
local M = {}

-- "12s", "1m 12s", "1h 02m"
function M.duration(seconds)
	local s = math.floor(seconds)
	if s < 60 then
		return string.format("%ds", s)
	elseif s < 3600 then
		return string.format("%dm %02ds", s // 60, s % 60)
	end
	return string.format("%dh %02dm", s // 3600, s % 3600 // 60)
end

-- Takes the task summary at time `now` and returns the notice for a batch that has just ended
-- after at least `after` seconds. A failed task stays in the summary until it is inspected or
-- cancelled, so only the failures that came during the batch count
function M.watch(state, summary, now, after)
	if summary.total - summary.success - summary.failed > 0 then
		if not state.since then
			state.since, state.failed, state.cancelled = now, summary.failed, 0
		end
		return
	elseif not state.since then
		return
	end

	local took, broke = now - state.since, math.max(0, summary.failed - state.failed)
	state.since = nil
	if took < after then
		return
	elseif broke == 0 and state.cancelled == 0 then
		return { level = "info", content = "Done in " .. M.duration(took) }
	end
	local parts = {}
	if broke > 0 then
		parts[#parts + 1] = string.format("%d failed", broke)
	end
	if state.cancelled > 0 then
		parts[#parts + 1] = string.format("%d cancelled", state.cancelled)
	end
	local content = string.format("Ended in %s: %s", M.duration(took), table.concat(parts, ", "))
	if broke > 0 then
		return { level = "warn", content = content .. ", press w to see why" }
	end
	return { level = "info", content = content }
end

-- `x` on a failed task only takes it out of the list, and only a running one is cancelled
function M.cancel(state, running)
	if state.since and running then
		state.cancelled = state.cancelled + 1
	end
end

-- Runs in the main Lua state through the `lua` command, while the task under the cursor is
-- still in the snapshots
function M:cancelling()
	local snap = cx.tasks.snaps[cx.tasks.cursor + 1]
	M.cancel(M.state, snap and snap.running)
end

-- The gauge is redrawn on every frame as well, which leaves the state as it is
function M:setup(opts)
	local after, redraw = (opts or {}).after or 5, Progress.redraw
	M.state = {}
	function Progress:redraw(...)
		local notice = M.watch(M.state, cx.tasks.summary, ya.time(), after)
		if notice then
			ya.notify { title = "Tasks", content = notice.content, level = notice.level, timeout = 5 }
		end
		return redraw(self, ...)
	end
end

return M
