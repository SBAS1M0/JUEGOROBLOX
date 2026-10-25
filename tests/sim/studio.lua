GETASYNC_FAILS = true
local T = dofile(SIM_DIR .. "/test.lua")
T.check(T.R.time < 35, "no long retry delay (t=" .. T.R.time .. ")")
print("errors:", #T.R.errors, "warnings:", #T.R.warnings)
for _, w in ipairs(T.R.warnings) do print("warn:", w) end
