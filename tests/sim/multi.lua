FAIL_DS = true
local T = dofile(SIM_DIR .. "/test.lua")
local R = T.R
local S = R.services
local others = {}
for i = 2, 7 do
	local p = R.makePlayer(200 + i, "P" .. i)
	p.Parent = S.Players
	S.Players.PlayerAdded:Fire(p)
	R.makeCharacter(p)
	table.insert(others, p)
end
R.run(30)
local owned = 0
for _, plot in ipairs(T.plots:GetChildren()) do
	if plot:GetAttribute("OwnerUserId") ~= 0 then owned = owned + 1 end
end
T.check(owned == 6, "6 plots owned with 7 players")
T.check(#T.plots.Plot3.Customers:GetChildren() > 0, "other players get customers")
-- local player triggers someone else's customer
local foreign = T.plots.Plot3.Customers:GetChildren()[1]
foreign.Root.ProximityPrompt.Triggered:Fire(T.player)
R.run(0.2)
T.check(not T.player.PlayerGui.Studio.Enabled, "cannot paint other gallery's order")
T.check(foreign.Root.ProximityPrompt.MaxActivationDistance == 0, "foreign prompt hidden locally")
-- a player leaves; the 7th still has no plot, fine
others[2].Parent = nil
S.Players.PlayerRemoving:Fire(others[2])
R.run(2)
for _, f in ipairs(R.closeCallbacks) do R.task.spawn(f) end
R.run(2)
print("errors:", #R.errors, "warnings:", #R.warnings)
for _, w in ipairs(R.warnings) do print("warn:", w) end
