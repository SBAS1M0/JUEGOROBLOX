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
for _, n in ipairs({ "HUD", "MachineHud", "DesignPicker", "ColorPicker", "Painter", "Shop", "Collection", "Notifications" }) do
	check(pg:FindFirstChild(n) ~= nil, "gui " .. n .. " exists")
end

local Designs = R.require(S.ReplicatedStorage.Shared.Designs)
local Colors = R.require(S.ReplicatedStorage.Shared.Colors)
local Config = R.require(S.ReplicatedStorage.Shared.Config)
local DataService = R.require(server.Services.DataService)

return {
	Designs = Designs,
	Colors = Colors,
	Config = Config,
	DataService = DataService,
	R = R,
	player = player,
	plots = plots,
	fireClick = fireClick,
	buttonWithText = buttonWithText,
	buttonWithLabel = buttonWithLabel,
	findAll = findAll,
	check = check,
}
