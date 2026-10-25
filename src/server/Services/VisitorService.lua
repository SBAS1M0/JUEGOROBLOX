-- Visitantes: avatares reales de Roblox (los amigos del dueño o avatares
-- conocidos) que entran a la galería, miran un cuadro expuesto y lo compran.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local VisitorService = {}

VisitorService.COLLISION_GROUP = "Visitantes"

local ANIMATIONS = {
	walk = "rbxassetid://507777826",
	idle = "rbxassetid://507766388",
	cheer = "rbxassetid://507770677",
	wave = "rbxassetid://507770239",
}
local FALLBACK_NAMES =
	{ "Lucía", "Mateo", "Sofía", "Diego", "Valentina", "Leo", "Camila", "Hugo", "Martina", "Bruno" }
local SKIN_TONES = {
	Color3.fromRGB(255, 224, 196),
	Color3.fromRGB(241, 194, 150),
	Color3.fromRGB(214, 160, 120),
	Color3.fromRGB(170, 116, 80),
	Color3.fromRGB(120, 80, 56),
}
local SHIRT_COLORS = {
	Color3.fromRGB(255, 140, 160),
	Color3.fromRGB(120, 190, 255),
	Color3.fromRGB(130, 220, 160),
	Color3.fromRGB(255, 200, 100),
	Color3.fromRGB(190, 150, 255),
}

-- Callbacks que asigna el servidor principal.
VisitorService.getProfile = nil -- (player) -> datos
VisitorService.availableSlots = nil -- (player) -> { hueco, ... } con cuadro
VisitorService.onPurchase = nil -- (player, hueco, nombre) -> precio o nil

local rng = Random.new()
local states = {}
local descriptionCache = {}
local friendsOf = {}

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

-- Avatares ----------------------------------------------------------------------------
local function loadFriends(owner)
	if friendsOf[owner] then
		return
	end
	friendsOf[owner] = {}
	task.spawn(function()
		local ok, pages = pcall(function()
			return Players:GetFriendsAsync(owner.UserId)
		end)
		if not ok or not pages then
			return
		end
		local okPage, page = pcall(function()
			return pages:GetCurrentPage()
		end)
		if okPage and type(page) == "table" then
			local list = {}
			for _, friend in ipairs(page) do
				if type(friend) == "table" and friend.Id then
					table.insert(list, { id = friend.Id, name = friend.DisplayName or friend.Username })
				end
			end
			if owner.Parent then
				friendsOf[owner] = list
			end
		end
	end)
end

local function getDescription(userId)
	local cached = descriptionCache[userId]
	if cached ~= nil then
		return cached or nil
	end
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	descriptionCache[userId] = (ok and description) or false
	return ok and description or nil
end

local function randomDescription()
	local description = Instance.new("HumanoidDescription")
	local skin = pick(SKIN_TONES)
	local shirt = pick(SHIRT_COLORS)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = Color3.fromRGB(70, 70, 110)
	description.RightLegColor = Color3.fromRGB(70, 70, 110)
	return description
end

local function setCollisionGroup(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = VisitorService.COLLISION_GROUP
		end
	end
end

local function createAvatar(owner)
	local friends = friendsOf[owner] or {}
	local userId, name
	if #friends > 0 and rng:NextNumber() < 0.75 then
		local friend = pick(friends)
		userId, name = friend.id, friend.name
	else
		userId = pick(Config.FALLBACK_AVATARS)
	end
	local description = getDescription(userId) or randomDescription()
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(randomDescription(), Enum.HumanoidRigType.R15)
		end)
		if not ok or not model then
			return nil
		end
	end
	return model, name or pick(FALLBACK_NAMES)
end

-- Movimiento y animaciones -------------------------------------------------------------
local function loadTracks(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local tracks = {}
	for name, id in pairs(ANIMATIONS) do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Looped = name == "walk" or name == "idle"
			tracks[name] = track
		end
	end
	return tracks
end

local function play(visitor, name)
	for trackName, track in pairs(visitor.tracks) do
		if trackName ~= name and track.IsPlaying then
			track:Stop(0.2)
		end
	end
	local track = visitor.tracks[name]
	if track and not track.IsPlaying then
		track:Play(0.2)
	end
end

local function alive(visitor)
	return visitor.model.Parent ~= nil and visitor.humanoid.Parent ~= nil
end

local function walkTo(visitor, target)
	if not alive(visitor) then
		return false
	end
	play(visitor, "walk")
	local reached = false
	local connection = visitor.humanoid.MoveToFinished:Connect(function()
		reached = true
	end)
	visitor.humanoid:MoveTo(target.Position)
	local started = os.clock()
	while not reached and alive(visitor) and os.clock() - started < 9 do
		task.wait(0.1)
	end
	connection:Disconnect()
	if not alive(visitor) then
		return false
	end
	-- Si se atascó, lo acercamos al destino para que nunca se quede trabado.
	local root = visitor.root
	local offset = root.Position - target.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > 3 then
		visitor.model:PivotTo(target * CFrame.new(0, 3, 0))
	end
	return true
end

-- Ciclo de un visitante -----------------------------------------------------------------
local function runVisitor(state, slot)
	local plot = state.plot
	local owner = state.owner
	local model, name = createAvatar(owner)
	if not model or states[plot.index] ~= state then
		state.reserved[slot] = nil
		if model then
			model:Destroy()
		end
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) then
		state.reserved[slot] = nil
		model:Destroy()
		return
	end
	model.Name = "Visitante"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 11
	model:SetAttribute("VisitorName", name)
	model:SetAttribute("Owner", owner.UserId)
	model:SetAttribute("Reaction", "")
	setCollisionGroup(model)
	model:PivotTo(plot.street * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.pi, 0))
	model.Parent = plot.visitorsFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local visitor = { model = model, humanoid = humanoid, root = root, tracks = loadTracks(humanoid) }
	state.visitors[visitor] = true

	local function finish()
		state.visitors[visitor] = nil
		state.reserved[slot] = nil
		if model.Parent then
			model:Destroy()
		end
	end

	local stand = plot.standPoints[slot]
	for _, point in ipairs({ plot.entrance, plot.inside, stand }) do
		if not walkTo(visitor, point) then
			finish()
			return
		end
	end

	-- Admira el cuadro.
	model:PivotTo(stand * CFrame.new(0, 3, 0))
	play(visitor, "idle")
	model:SetAttribute("Reaction", "🤔")
	task.wait(rng:NextNumber(2.5, 4))
	if not alive(visitor) or states[plot.index] ~= state then
		finish()
		return
	end

	local price = VisitorService.onPurchase and VisitorService.onPurchase(owner, slot, name)
	if price then
		model:SetAttribute("Reaction", pick(Config.BuyerLines) .. "\n💰 " .. price)
		play(visitor, "cheer")
	else
		model:SetAttribute("Reaction", "Oh... ya no está 😢")
		play(visitor, "wave")
	end
	state.reserved[slot] = nil
	task.wait(2.5)

	for _, point in ipairs({ plot.inside, plot.entrance, plot.street }) do
		if not walkTo(visitor, point) then
			break
		end
	end
	finish()
end

-- API pública --------------------------------------------------------------------------
function VisitorService.attach(plot, owner)
	loadFriends(owner)
	states[plot.index] = {
		plot = plot,
		owner = owner,
		timer = 0,
		visitors = {},
		reserved = {},
	}
end

function VisitorService.detach(plot)
	local state = states[plot.index]
	states[plot.index] = nil
	if state then
		for visitor in pairs(state.visitors) do
			if visitor.model.Parent then
				visitor.model:Destroy()
			end
		end
		friendsOf[state.owner] = nil
	end
	plot.visitorsFolder:ClearAllChildren()
end

function VisitorService.start()
	RunService.Heartbeat:Connect(function(dt)
		for _, state in pairs(states) do
			local profile = VisitorService.getProfile(state.owner)
			if profile then
				local levels = profile.upgrades
				local count = 0
				for _ in pairs(state.visitors) do
					count += 1
				end
				state.timer += dt
				if count < Config.maxBuyers(levels) and state.timer >= Config.buyerInterval(levels) then
					local options = {}
					for _, slot in ipairs(VisitorService.availableSlots(state.owner)) do
						if not state.reserved[slot] then
							table.insert(options, slot)
						end
					end
					if #options > 0 then
						state.timer = 0
						local slot = pick(options)
						state.reserved[slot] = true
						task.spawn(runVisitor, state, slot)
					else
						state.timer = Config.buyerInterval(levels) * 0.7
					end
				end
			end
		end
	end)
end

return VisitorService
