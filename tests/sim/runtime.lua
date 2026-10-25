-- Builds the DataModel, services and script loader on top of mock.lua
local M = dofile(SIM_DIR .. "/mock.lua")
local G = M.globals
local new = M.newInstance
local task = M.task

local function service(className, name)
	local s = new(className, true)
	s.props.Name = name or className
	return s
end

local game = new("DataModel", true)
game.props.Name = "Game"
local services = {}
local function addService(className)
	local s = service(className)
	s.parent = game
	table.insert(game.children, s)
	services[className] = s
	return s
end
for _, cls in ipairs({
	"Workspace",
	"Players",
	"Lighting",
	"ReplicatedStorage",
	"ServerScriptService",
	"StarterPlayer",
	"StarterGui",
	"SoundService",
	"RunService",
	"DataStoreService",
	"HttpService",
	"TweenService",
	"UserInputService",
	"ProximityPromptService",
	"GuiService",
	"TextService",
}) do
	addService(cls)
end
local workspace = services.Workspace
local camera = new("Camera")
camera.Parent = workspace
workspace.allowWrite = true
workspace.CurrentCamera = camera
workspace.allowWrite = nil

M.method("DataModel", "GetService", function(self, name)
	local s = services[name]
	if not s then
		error("GetService: service not mocked: " .. tostring(name), 2)
	end
	return s
end)
local closeCallbacks = {}
M.method("DataModel", "BindToClose", function(self, f)
	table.insert(closeCallbacks, f)
end)
M.closeCallbacks = closeCallbacks

-- RunService
M.method("RunService", "IsStudio", function()
	return true
end)
M.method("RunService", "IsServer", function()
	return true
end)
M.method("RunService", "IsClient", function()
	return true
end)

-- HttpService
local guidCounter = 0
M.method("HttpService", "GenerateGUID", function(self, braces)
	guidCounter = guidCounter + 1
	return string.format("%08x-0000-0000-0000-%012d", guidCounter, guidCounter)
end)

-- DataStore (in-memory)
local storeData = {}
M.storeData = storeData
M.method("DataStoreService", "GetDataStore", function(self, name)
	if M.dataStoreFails then
		error("You must publish this place to the web to access DataStore.")
	end
	local store = {}
	storeData[name] = storeData[name] or {}
	local data = storeData[name]
	local function copy(v)
		-- simulate serialization round-trip and validate types
		local t = type(v)
		if t == "table" then
			local isArray = #v > 0
			local out = {}
			for k, val in pairs(v) do
				if type(k) ~= "string" and type(k) ~= "number" then
					error("DataStore: invalid key type")
				end
				if isArray and type(k) ~= "number" then
					error("DataStore: mixed table keys " .. tostring(k))
				end
				out[k] = copy(val)
			end
			return out
		elseif t == "string" or t == "number" or t == "boolean" or t == "nil" then
			return v
		end
		error("DataStore: cannot store value of type " .. G.typeof(v))
	end
	function store:GetAsync(key)
		task.wait(0.05)
		if M.getAsyncFails then
			error("502: API Services rejected request with error. Error code: 0 Reason: StudioAccessToApisNotAllowed")
		end
		return copy(data[key])
	end
	function store:SetAsync(key, value)
		task.wait(0.05)
		data[key] = copy(value)
	end
	function store:UpdateAsync(key, f)
		task.wait(0.05)
		local result = f(copy(data[key]))
		if result ~= nil then
			data[key] = copy(result)
		end
		return result
	end
	return store
end)

-- TweenService
M.method("TweenService", "Create", function(self, inst, info, props)
	if G.typeof(inst) ~= "Instance" then
		error("TweenService:Create expects Instance", 2)
	end
	if G.typeof(info) ~= "TweenInfo" then
		error("TweenService:Create expects TweenInfo", 2)
	end
	for k, v in pairs(props) do
		local _ = inst[k] -- validates property existence
		local cur = inst[k]
		if G.typeof(cur) ~= G.typeof(v) then
			error("Tween property type mismatch " .. k .. ": " .. G.typeof(cur) .. " vs " .. G.typeof(v), 2)
		end
		local tv = G.typeof(v)
		if not (tv == "number" or tv == "Vector3" or tv == "Vector2" or tv == "CFrame" or tv == "Color3" or tv == "UDim2" or tv == "UDim" or tv == "boolean") then
			error("Property not tweenable: " .. k, 2)
		end
	end
	local tween = new("Tween", true)
	tween.target = { inst = inst, info = info, props = props }
	return tween
end)
M.method("Tween", "Play", function(self)
	local t = self.target
	task.delay(t.info.Time, function()
		if not t.inst.destroyed then
			for k, v in pairs(t.props) do
				t.inst[k] = v
			end
		end
		self.Completed:Fire()
	end)
end)
M.method("Tween", "Cancel", function() end)

-- SoundService
M.method("SoundService", "PlayLocalSound", function(self, sound)
	if G.typeof(sound) ~= "Instance" or sound.ClassName ~= "Sound" then
		error("PlayLocalSound expects Sound", 2)
	end
	local id = sound.SoundId
	if not id:match("^rbxasset://sounds/") then
		error("unexpected sound id " .. id)
	end
end)

-- StarterGui
M.method("StarterGui", "SetCoreGuiEnabled", function(self, coreType, enabled)
	if G.typeof(coreType) ~= "EnumItem" or coreType.EnumType ~= "CoreGuiType" then
		error("SetCoreGuiEnabled bad enum", 2)
	end
end)

-- UserInputService
M.method("UserInputService", "GetMouseLocation", function()
	return M.v2(0, 0)
end)

-- Players
local players = services.Players
M.method("Players", "GetPlayers", function(self)
	local list = {}
	for _, c in ipairs(self.children) do
		if c.ClassName == "Player" then
			table.insert(list, c)
		end
	end
	return list
end)
M.method("Players", "GetPlayerFromCharacter", function(self, character)
	for _, p in ipairs(self:GetPlayers()) do
		if p.props.Character == character then
			return p
		end
	end
	return nil
end)

-- Remotes: same VM plays server and client.
M.method("RemoteEvent", "FireServer", function(self, ...)
	self.OnServerEvent:Fire(M.localPlayer, ...)
end)
M.method("RemoteEvent", "FireClient", function(self, player, ...)
	if G.typeof(player) ~= "Instance" or player.ClassName ~= "Player" then
		error("FireClient expects Player", 2)
	end
	if player == M.localPlayer then
		self.OnClientEvent:Fire(...)
	end
end)
M.method("RemoteEvent", "FireAllClients", function(self, ...)
	self.OnClientEvent:Fire(...)
end)
local function deepCopy(v)
	-- remote arguments are copied (functions/metatables lost)
	if type(v) == "function" then
		error("Cannot send function through remote")
	end
	if type(v) == "table" and not getmetatable(v) then
		local out = {}
		for k, val in pairs(v) do
			out[k] = deepCopy(val)
		end
		return out
	end
	return v
end
M.method("RemoteFunction", "InvokeServer", function(self, ...)
	local f = self.props.OnServerInvoke
	if not f then
		error("OnServerInvoke not set for " .. self.props.Name)
	end
	local args = table.pack(...)
	for i = 1, args.n do
		args[i] = deepCopy(args[i])
	end
	local results = table.pack(f(M.localPlayer, table.unpack(args, 1, args.n)))
	for i = 1, results.n do
		results[i] = deepCopy(results[i])
	end
	return table.unpack(results, 1, results.n)
end)

-- Loader -----------------------------------------------------------------------------
local loaded = {}
local function convertLuau(src, name)
	-- compound assignment -> plain Lua
	local out = {}
	for line in (src .. "\n"):gmatch("(.-)\n") do
		local indent, lhs, op, rhs = line:match("^(%s*)([%w_%.%[%]\"]+)%s*([%+%-%*/])=%s*(.+)$")
		if indent then
			line = indent .. lhs .. " = " .. lhs .. " " .. op .. " (" .. rhs .. ")"
		end
		table.insert(out, line)
	end
	return table.concat(out, "\n")
end

local baseEnv = {}
for k, v in pairs(_G) do
	baseEnv[k] = v
end
for k, v in pairs(G) do
	baseEnv[k] = v
end
baseEnv.game = game
baseEnv.workspace = workspace
baseEnv.warn = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	local msg = table.concat(parts, " ")
	table.insert(M.warnings, msg)
	print("[warn] " .. msg)
end
baseEnv.print = print
baseEnv.tick = function()
	return M.time
end
local mathx = {}
for k, v in pairs(math) do
	mathx[k] = v
end
mathx.clamp = function(x, a, b)
	assert(type(x) == "number" and a <= b, "math.clamp bad args")
	return math.max(a, math.min(b, x))
end
mathx.sign = function(x)
	return x > 0 and 1 or (x < 0 and -1 or 0)
end
mathx.round = function(x)
	return math.floor(x + 0.5)
end
baseEnv.math = mathx
local osx = {
	clock = function()
		return M.time
	end,
	time = function()
		return math.floor(1700000000 + M.time + (M.timeOffset or 0))
	end,
	date = os.date,
}
baseEnv.os = osx
local tablex = {}
for k, v in pairs(table) do
	tablex[k] = v
end
tablex.find = function(t, v)
	for i, x in ipairs(t) do
		if x == v then
			return i
		end
	end
	return nil
end
tablex.clear = function(t)
	for k in pairs(t) do
		t[k] = nil
	end
end
baseEnv.table = tablex
-- string.format("%d", nonInteger) must error in Luau too: keep Lua 5.4 behaviour.

local function requireModule(inst)
	if G.typeof(inst) ~= "Instance" or inst.ClassName ~= "ModuleScript" then
		error("require expects ModuleScript, got " .. tostring(inst), 2)
	end
	if loaded[inst] ~= nil then
		return loaded[inst].value
	end
	if inst.mockModule then
		loaded[inst] = { value = inst.mockModule }
		return inst.mockModule
	end
	local env = setmetatable({ script = inst }, { __index = baseEnv })
	env.require = requireModule
	local src = convertLuau(io.open(inst.sourcePath):read("a"), inst.sourcePath)
	local chunk, err = load(src, "@" .. inst.sourcePath, "t", env)
	if not chunk then
		error("Compile error: " .. err)
	end
	local value = chunk()
	if value == nil then
		error("Module did not return a value: " .. inst.sourcePath)
	end
	loaded[inst] = { value = value }
	return value
end
baseEnv.require = requireModule
M.require = requireModule

function M.runScript(inst)
	local env = setmetatable({ script = inst }, { __index = baseEnv })
	env.require = requireModule
	local src = convertLuau(io.open(inst.sourcePath):read("a"), inst.sourcePath)
	local chunk, err = load(src, "@" .. inst.sourcePath, "t", env)
	if not chunk then
		error("Compile error: " .. err)
	end
	return task.spawn(chunk)
end

-- Builds instances from a directory listing (provided by python).
function M.mount(parent, name, files)
	-- files: list of {relpath, abspath}
	local root = new("Folder")
	root.Name = name
	root.Parent = parent
	for _, f in ipairs(files) do
		local rel, abs = f[1], f[2]
		local dir = root
		local parts = {}
		for seg in rel:gmatch("[^/]+") do
			table.insert(parts, seg)
		end
		for i = 1, #parts - 1 do
			local child = dir:FindFirstChild(parts[i])
			if not child then
				child = new("Folder")
				child.Name = parts[i]
				child.Parent = dir
			end
			dir = child
		end
		local file = parts[#parts]
		local cls, base = "ModuleScript", file:gsub("%.lua$", "")
		if file:match("%.server%.lua$") then
			cls, base = "Script", file:gsub("%.server%.lua$", "")
		elseif file:match("%.client%.lua$") then
			cls, base = "LocalScript", file:gsub("%.client%.lua$", "")
		end
		local s = new(cls)
		s.Name = base
		s.sourcePath = abs
		s.Parent = dir
	end
	return root
end

-- Simulation loop
local heartbeat = services.RunService.Heartbeat
local render = services.RunService.RenderStepped
function M.step(dt)
	M.time = M.time + dt
	-- wake threads
	local ready = {}
	local keep = {}
	for _, t in ipairs(M.threads) do
		if t.wake <= M.time then
			table.insert(ready, t)
		else
			table.insert(keep, t)
		end
	end
	for i = #M.threads, 1, -1 do
		M.threads[i] = nil
	end
	for _, t in ipairs(keep) do
		table.insert(M.threads, t)
	end
	for _, t in ipairs(ready) do
		if coroutine.status(t.co) == "suspended" then
			M.resume(t.co, table.unpack(t.args, 1, t.args.n))
		end
	end
	heartbeat:Fire(dt)
	render:Fire(dt)
end
function M.run(seconds, dt)
	dt = dt or 1 / 30
	local steps = math.floor(seconds / dt + 0.5)
	for _ = 1, steps do
		M.step(dt)
	end
end

function M.makePlayer(userId, name)
	local p = new("Player", true)
	p.props.Name = name
	p.allowWrite = true
	p.UserId = userId
	p.DisplayName = name
	p.allowWrite = nil
	local gui = new("PlayerGui", true)
	gui.props.Name = "PlayerGui"
	gui.Parent = p
	local ps = new("PlayerScripts", true)
	ps.props.Name = "PlayerScripts"
	ps.Parent = p
	local pm = new("ModuleScript")
	pm.Name = "PlayerModule"
	M.controlsEnabled = true
	pm.mockModule = {
		GetControls = function()
			return {
				Enable = function()
					M.controlsEnabled = true
				end,
				Disable = function()
					M.controlsEnabled = false
				end,
			}
		end,
	}
	pm.Parent = ps
	return p
end

function M.makeCharacter(player)
	local character = new("Model")
	character.Name = player.Name
	local hrp = new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Parent = character
	character.PrimaryPart = hrp
	local hum = new("Humanoid")
	hum.Parent = character
	character.Parent = workspace
	player.allowWrite = true
	player.Character = character
	player.allowWrite = nil
	player.CharacterAdded:Fire(character)
	return character
end

M.game = game
M.services = services
M.workspace = workspace
return M
