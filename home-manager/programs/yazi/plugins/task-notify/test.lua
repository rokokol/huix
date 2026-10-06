-- The pure half of main.lua, run by plain Lua with yazi's globals stubbed out: `lua test.lua`
-- from this directory, or the yazi-plugin-tests flake check
local notify = dofile("main.lua")

local failed = 0
local function expect(what, got, want)
	if got ~= want then
		failed = failed + 1
		io.stderr:write(string.format("%s: want %q, got %q\n", what, tostring(want), tostring(got)))
	end
end

local function summary(total, success, failed_)
	return { total = total, success = success or 0, failed = failed_ or 0 }
end

-- Feeds the summaries one by one, each at its own time, and returns the last notice
local function run(steps, after)
	local state, notice = {}, nil
	for _, step in ipairs(steps) do
		notice = notify.watch(state, step[2], step[1], after or 5)
	end
	return notice, state
end

expect("idle", run { { 0, summary(0) }, { 9, summary(0) } }, nil)

expect("short batch", run { { 0, summary(0) }, { 1, summary(2) }, { 4, summary(0) } }, nil)

local long = run { { 0, summary(0) }, { 1, summary(2) }, { 3, summary(2, 1) }, { 13, summary(0) } }
expect("long batch", long and long.level, "info")
expect("long batch says how long", long and long.content:find("12s", 1, true) ~= nil, true)

-- a redraw while the batch runs must not restart its clock
local busy = run {
	{ 0, summary(1) },
	{ 3, summary(1) },
	{ 5, summary(1) },
	{ 6, summary(0) },
}
expect("redraws keep the start", busy and busy.level, "info")

-- the batch ends while a failed task stays in the list, waiting to be inspected
local broken = run { { 0, summary(2) }, { 8, summary(1, 0, 1) } }
expect("failure", broken and broken.level, "warn")
expect("failure count", broken and broken.content:find("1", 1, true) ~= nil, true)

-- a failure left from an earlier batch is not this batch's
local old = run { { 0, summary(1, 0, 1) }, { 1, summary(2, 0, 1) }, { 9, summary(1, 0, 1) } }
expect("old failure", old and old.level, "info")

-- each batch is timed from its own start
local second = run {
	{ 0, summary(1) },
	{ 2, summary(0) },
	{ 50, summary(1) },
	{ 52, summary(0) },
}
expect("second batch", second, nil)

expect("threshold", run({ { 0, summary(1) }, { 3, summary(0) } }, 2) ~= nil, true)

-- yazi drops a cancelled task from the summary as it drops a finished one, so the batch is
-- told of a cancel by the key that makes it
local function cancelled(running, steps_after)
	local state = {}
	notify.watch(state, summary(2), 0, 5)
	notify.cancel(state, running)
	local notice
	for _, step in ipairs(steps_after) do
		notice = notify.watch(state, step[2], step[1], 5)
	end
	return notice, state
end

local stopped = cancelled(true, { { 6, summary(0) } })
expect("cancel is no success", stopped and stopped.content:find("Done", 1, true), nil)
expect("cancel is told", stopped and stopped.content:find("1 cancelled", 1, true) ~= nil, true)
expect("cancel is no failure", stopped and stopped.level, "info")

-- x on a failed task only takes it out of the list
local dismissed = cancelled(false, { { 6, summary(0) } })
expect("dismissal", dismissed and dismissed.content:find("cancelled", 1, true), nil)

-- a cancel counts towards its own batch only
local _, after = cancelled(true, { { 1, summary(0) } })
notify.watch(after, summary(1), 2, 5)
local next_batch = notify.watch(after, summary(0), 9, 5)
expect("cancel forgotten", next_batch and next_batch.content:find("cancelled", 1, true), nil)
local idle = {}
notify.cancel(idle, true)
expect("cancel outside a batch", idle.cancelled, nil)

local both = cancelled(true, { { 6, summary(1, 0, 1) } })
expect("cancel and failure", both and both.level, "warn")
expect("cancel and failure told", both and both.content:find("1 cancelled", 1, true) ~= nil, true)

expect("seconds", notify.duration(12), "12s")
expect("minutes", notify.duration(72.6), "1m 12s")
expect("hours", notify.duration(3725), "1h 02m")

if failed > 0 then
	io.stderr:write(failed .. " failed\n")
	os.exit(1)
end
print("task-notify: all passed")
