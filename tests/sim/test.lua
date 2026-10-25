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
local first = R.mount(S.ReplicatedFirst, "First", FILES.first)

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
check(R.workspace:FindFirstChild("Llegada") ~= nil, "spawn platform built")
local plots = R.workspace:FindFirstChild("Plots")
check(plots == nil or #plots:GetChildren() == 0, "no lots before anyone joins")
check(S.ReplicatedStorage:FindFirstChild("Remotes") ~= nil, "remotes created")

print("== Player joins")
local player = R.makePlayer(101, "Simon")
R.localPlayer = player
S.Players.allowWrite = true
S.Players.LocalPlayer = player
S.Players.allowWrite = nil
player.Parent = S.Players
S.Players.PlayerAdded:Fire(player)
local character = R.makeCharacter(player)
R.runScript(first.Loading)
R.run(1)
check(#R.errors == 0, "player join without errors")
plots = R.workspace:FindFirstChild("Plots")
check(plots and #plots:GetChildren() == 1, "exactly one lot: the player's own")
check(plots.Lot1:GetAttribute("OwnerUserId") == 101, "lot assigned to player")
check(R.persistentPlayers[plots.Lot1] == player, "lot streams persistently to its owner")
local distance = (character.HumanoidRootPart.Position - plots.Lot1:GetPivot().Position).Magnitude
check(distance < 80, "character teleported to own lot (" .. math.floor(distance) .. " studs)")
check(player.PlayerGui:FindFirstChild("Loading") ~= nil, "loading screen visible while joining")

print("== Client start")
R.runScript(client.Main)
R.run(4)
check(#R.errors == 0, "client boots")
local pg = player.PlayerGui
for _, n in ipairs({
	"HUD",
	"MachineHud",
	"DesignPicker",
	"ColorPicker",
	"Painter",
	"Shop",
	"Collection",
	"Daily",
	"Notifications",
}) do
	check(pg:FindFirstChild(n) ~= nil, "gui " .. n .. " exists")
end
check(pg:FindFirstChild("Loading") == nil, "loading screen removed once ready")

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
	S = S,
	server = server,
	client = client,
	makeCharacter = R.makeCharacter,
	player = player,
	character = character,
	plots = plots,
	fireClick = fireClick,
	buttonWithText = buttonWithText,
	buttonWithLabel = buttonWithLabel,
	findAll = findAll,
	check = check,
}
