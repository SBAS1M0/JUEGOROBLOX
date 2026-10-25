-- Muchos jugadores: cada uno recibe su propio terreno, lejos de los demás, y el
-- terreno se borra al salir. DataStore no disponible.
FAIL_DS = true
local T = dofile(SIM_DIR .. "/test.lua")
local R = T.R
local S = R.services
local Config = T.Config
local plots = R.workspace.Plots
local others = {}
for i = 2, Config.MAX_PLOTS + 1 do
	local p = R.makePlayer(200 + i, "P" .. i)
	p.Parent = S.Players
	S.Players.PlayerAdded:Fire(p)
	R.makeCharacter(p)
	table.insert(others, p)
end
R.run(20)
T.check(#plots:GetChildren() == Config.MAX_PLOTS, Config.MAX_PLOTS .. " lots for " .. (Config.MAX_PLOTS + 1) .. " players")
local owners = {}
for _, lot in ipairs(plots:GetChildren()) do
	local owner = lot:GetAttribute("OwnerUserId")
	T.check(owner ~= 0 and not owners[owner], lot.Name .. " has a unique owner")
	owners[owner] = true
end
local minGap = math.huge
for _, a in ipairs(plots:GetChildren()) do
	for _, b in ipairs(plots:GetChildren()) do
		if a ~= b then
			minGap = math.min(minGap, (a:GetPivot().Position - b:GetPivot().Position).Magnitude)
		end
	end
end
T.check(minGap >= 2000, "lots are far apart (" .. math.floor(minGap) .. " studs)")
for _, p in ipairs(others) do
	local lot
	for _, l in ipairs(plots:GetChildren()) do
		if l:GetAttribute("OwnerUserId") == p.UserId then
			lot = l
		end
	end
	if lot then
		local d = (p.Character.HumanoidRootPart.Position - lot:GetPivot().Position).Magnitude
		T.check(d < 80, p.Name .. " stands in own lot")
	end
end

local foreign = plots.Lot3.Workshop.DrawPrompt.ProximityPrompt
T.check(foreign.MaxActivationDistance == 0, "foreign workshop prompt hidden locally")
T.check(plots.Lot1.Workshop.DrawPrompt.ProximityPrompt.MaxActivationDistance == 12, "own prompt visible")
foreign.Triggered:Fire(T.player)
R.run(0.2)
T.check(not T.player.PlayerGui.DesignPicker.Window.Visible, "cannot use another workshop")
plots.Lot1.Workshop.DrawPrompt.ProximityPrompt.Triggered:Fire(T.player)
R.run(0.2)
T.check(T.player.PlayerGui.DesignPicker.Window.Visible, "own workshop opens designs")

-- Uno se va: su terreno desaparece y el que esperaba recibe uno.
local leaving = others[2]
leaving.Parent = nil
S.Players.PlayerRemoving:Fire(leaving)
R.run(2)
T.check(#plots:GetChildren() == Config.MAX_PLOTS, "lot rebuilt for the waiting player")
local terrainCleared = false
for _, fill in ipairs(R.terrainFills) do
	if fill.kind == "block" and fill.material == "Air" then
		terrainCleared = true
	end
end
T.check(terrainCleared, "lot terrain cleared")
local waiting = others[#others]
local waitingLot
for _, l in ipairs(plots:GetChildren()) do
	if l:GetAttribute("OwnerUserId") == waiting.UserId then
		waitingLot = l
	end
end
T.check(waitingLot ~= nil, "player who waited (server full) got the freed lot")
local wd = (waiting.Character.HumanoidRootPart.Position - waitingLot:GetPivot().Position).Magnitude
T.check(wd < 80, "waiting player teleported to the lot")
others[3].Parent = nil
S.Players.PlayerRemoving:Fire(others[3])
R.run(2)
local late = R.makePlayer(999, "Tarde")
late.Parent = S.Players
S.Players.PlayerAdded:Fire(late)
R.makeCharacter(late)
R.run(3)
local lateLot
for _, l in ipairs(plots:GetChildren()) do
	if l:GetAttribute("OwnerUserId") == 999 then
		lateLot = l
	end
end
T.check(lateLot ~= nil, "freed slot reused by a new player")
for _, f in ipairs(R.closeCallbacks) do
	R.task.spawn(f)
end
R.run(2)
print("errors:", #R.errors, "warnings:", #R.warnings)
for _, w in ipairs(R.warnings) do
	print("warn:", w)
end
