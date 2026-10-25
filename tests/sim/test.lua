local R = dofile(SIM_DIR .. "/runtime.lua")
R.dataStoreFails = FAIL_DS
R.getAsyncFails = GETASYNC_FAILS
local G = R.globals
local Enum = G.Enum
local v2 = R.v2
local S = R.services

local function check(cond, msg)
	if not cond then
		error("CHECK FAILED: " .. msg, 2)
	end
	print("  ok - " .. msg)
end

-- Mount project ---------------------------------------------------------------
R.mount(S.ReplicatedStorage, "Shared", FILES.shared)
local server = R.mount(S.ServerScriptService, "Server", FILES.server)
local sps = R.newInstance("StarterPlayerScripts", true)
sps.props.Name = "StarterPlayerScripts"
sps.Parent = S.StarterPlayer
local client = R.mount(sps, "Client", FILES.client)

-- helpers
local function findAll(root, pred)
	local out = {}
	for _, d in ipairs(root:GetDescendants()) do
		if pred(d) then
			table.insert(out, d)
		end
	end
	return out
end
local function fireClick(button)
	button.MouseButton1Down:Fire()
	button.MouseButton1Up:Fire()
	button.Activated:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
end
local function buttonWithText(root, text)
	for _, d in ipairs(root:GetDescendants()) do
		if d.ClassName == "TextButton" and d.Text == text then
			return d
		end
	end
	return nil
end
local function buttonWithLabel(root, text)
	for _, d in ipairs(root:GetDescendants()) do
		if d.ClassName == "TextLabel" and d.Text == text and d.Parent.ClassName == "TextButton" then
			return d.Parent
		end
	end
	return nil
end

print("== Server start")
R.runScript(server.Main)
R.run(0.5)
check(#R.errors == 0, "server boots without errors")
local plots = R.workspace:FindFirstChild("Plots")
check(plots and #plots:GetChildren() == 6, "6 plots built")
check(S.ReplicatedStorage:FindFirstChild("Remotes") ~= nil, "remotes created")

print("== Player joins")
local player = R.makePlayer(101, "Simon")
R.localPlayer = player
S.Players.allowWrite = true
S.Players.LocalPlayer = player
S.Players.allowWrite = nil
player.Parent = S.Players
S.Players.PlayerAdded:Fire(player)
R.makeCharacter(player)
R.run(1)
check(#R.errors == 0, "player join without errors")
check(plots.Plot1:GetAttribute("OwnerUserId") == 101, "plot assigned")

print("== Client start")
R.runScript(client.Main)
R.run(3)
check(#R.errors == 0, "client boots")
local pg = player.PlayerGui
for _, n in ipairs({ "HUD", "Studio", "Shop", "Results", "Notifications" }) do
	check(pg:FindFirstChild(n) ~= nil, "gui " .. n .. " exists")
end
-- close help popup shown to new players
local okHelp = buttonWithText(pg.Results, "¡Entendido!")
fireClick(okHelp)

local Scoring = R.require(S.ReplicatedStorage.Shared.Scoring)
local Templates = R.require(S.ReplicatedStorage.Shared.Templates)
local Config = R.require(S.ReplicatedStorage.Shared.Config)
local Palette = R.require(S.ReplicatedStorage.Shared.Palette)
local DataService = R.require(server.Services.DataService)

print("== Wait for customers")
R.run(25)
check(#R.errors == 0, "customers spawn and walk without errors")
local customersFolder = plots.Plot1.Customers
local function waiting()
	local list = {}
	for _, m in ipairs(customersFolder:GetChildren()) do
		if m:GetAttribute("State") == "waiting" then
			table.insert(list, m)
		end
	end
	return list
end
check(#waiting() >= 1, "at least one customer waiting (" .. #waiting() .. ")")
check(#findAll(plots.Plot2.Customers, function()
	return true
end) == 0, "no customers in unowned plot")

-- HUD order cards
R.run(0.5)
local orderCards = findAll(pg.HUD, function(d)
	return d.ClassName == "TextButton" and d.Text == "🎨\nPintar"
end)
check(#orderCards == #waiting(), "HUD shows one card per waiting customer (" .. #orderCards .. ")")

return { Scoring = Scoring, Templates = Templates, Config = Config, Palette = Palette, DataService = DataService, R = R, player = player, plots = plots, waiting = waiting, fireClick = fireClick, buttonWithText = buttonWithText, buttonWithLabel = buttonWithLabel, findAll = findAll, check = check }
