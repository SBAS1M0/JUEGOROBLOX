-- Visitantes: avatares reales de Roblox (los amigos del dueño o avatares
-- conocidos) que entran a la galería, miran los cuadros expuestos y, si el
-- precio les convence, van a la caja a pagarlo o a hacerte una oferta.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Exhibition = require(Shared.Exhibition)

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
VisitorService.listings = nil -- (player) -> { [stand] = { price, market, tier, d, c, st } }
VisitorService.isTutorial = nil -- (player) -> true si el tutorial espera la primera venta
VisitorService.hasCashier = nil -- (player) -> true con la mejora Cajero
VisitorService.askOwner = nil -- (player, oferta) -> "accept" | "reject" | "counter" | "timeout"
VisitorService.onSale = nil -- (player, stand, precio, nombre, vip, cómo) -> cuadro vendido o nil
VisitorService.onPass = nil -- (player, stand, ratio, nombre): no lo compró por caro

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
	return model, name or pick(FALLBACK_NAMES), userId
end

-- Movimiento y animaciones -------------------------------------------------------------
local PATH_PARAMS = { AgentRadius = 1.6, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 4 }

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

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Un paso con MoveTo; espera a que llegue o a que pase el tiempo.
local function stepTo(visitor, position, timeout)
	local finished = false
	local connection = visitor.humanoid.MoveToFinished:Connect(function()
		finished = true
	end)
	visitor.humanoid:MoveTo(position)
	local started = os.clock()
	while not finished and alive(visitor) and os.clock() - started < timeout do
		task.wait(0.1)
	end
	connection:Disconnect()
	return alive(visitor)
end

-- Camina hasta el punto esquivando los stands (PathfindingService). Si no
-- encuentra camino va en línea recta y, si se atasca, se le acerca al destino.
local function walkTo(visitor, target)
	if not alive(visitor) then
		return false
	end
	play(visitor, "walk")
	local goal = target.Position
	-- Fuera (calle y jardín) se camina en línea recta; dentro hay stands.
	local indoors = goal.Y > 1
	local ok, path = false, nil
	if indoors then
		ok, path = pcall(function()
			local newPath = PathfindingService:CreatePath(PATH_PARAMS)
			newPath:ComputeAsync(visitor.root.Position, goal)
			return newPath
		end)
	end
	if ok and path and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		for i = 2, #waypoints do
			if not stepTo(visitor, waypoints[i].Position, 4) then
				return false
			end
			if flatDistance(visitor.root.Position, waypoints[i].Position) > 4 then
				break
			end
		end
	end
	for _ = 1, 3 do
		if not alive(visitor) then
			return false
		end
		if flatDistance(visitor.root.Position, goal) <= 3 then
			return true
		end
		stepTo(visitor, goal, 9)
	end
	if not alive(visitor) then
		return false
	end
	if flatDistance(visitor.root.Position, goal) > 3 then
		visitor.model:PivotTo(target * CFrame.new(0, 3, 0))
	end
	return true
end

local function walkRoute(visitor, points)
	for _, point in ipairs(points) do
		if not walkTo(visitor, point) then
			return false
		end
	end
	return true
end

-- Recorridos dentro de la galería (las ampliaciones están al fondo).
local function pathTo(plot, slot)
	local list = table.clone(plot.roomPaths[Exhibition.roomOf(slot)] or {})
	table.insert(list, plot.standPoints[slot])
	return list
end

local function pathBack(plot, slot)
	local list = {}
	local path = plot.roomPaths[Exhibition.roomOf(slot)] or {}
	for i = #path, 1, -1 do
		table.insert(list, path[i])
	end
	table.insert(list, plot.hub)
	return list
end

local function goToStand(visitor, plot, fromSlot, slot)
	if fromSlot and Exhibition.roomOf(fromSlot) == Exhibition.roomOf(slot) then
		return walkTo(visitor, plot.standPoints[slot])
	end
	if fromSlot and not walkRoute(visitor, pathBack(plot, fromSlot)) then
		return false
	end
	return walkRoute(visitor, pathTo(plot, slot))
end

local function standStill(visitor, cf)
	visitor.model:PivotTo(cf * CFrame.new(0, 3, 0))
	play(visitor, "idle")
end

-- El cuadro comprado se lo lleva bajo el brazo (a la espalda).
local function carryPainting(visitor, bought)
	local root = visitor.root
	local holder = Instance.new("Model")
	holder.Name = "BoughtPainting"
	local base = root.CFrame * CFrame.new(0, 0.3, 0.9) * CFrame.Angles(math.rad(-8), math.pi, 0)
	local back = Instance.new("Part")
	back.Name = "Back"
	back.Size = Vector3.new(3, 3, 0.25)
	back.CFrame = base
	back.Color = Color3.fromRGB(214, 176, 128)
	back.Material = Enum.Material.Wood
	local canvas = Instance.new("Part")
	canvas.Name = "Canvas"
	canvas.Size = Vector3.new(2.6, 2.6, 0.1)
	canvas.CFrame = base * CFrame.new(0, 0, -0.16)
	canvas.Color = Color3.fromRGB(250, 248, 242)
	for _, piece in ipairs({ back, canvas }) do
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = true
		piece.CastShadow = false
		piece.CollisionGroup = VisitorService.COLLISION_GROUP
		piece.Parent = holder
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = piece
		weld.Parent = piece
	end
	canvas:SetAttribute("Design", bought.d)
	canvas:SetAttribute("Colors", bought.c)
	canvas:SetAttribute("Stars", bought.st or 1)
	holder.Parent = visitor.model
end

-- Cola de la caja ------------------------------------------------------------------------
local function queueIndex(state, visitor)
	for i, other in ipairs(state.queue) do
		if other == visitor then
			return i
		end
	end
	return nil
end

local function leaveQueue(state, visitor)
	local index = queueIndex(state, visitor)
	if index then
		table.remove(state.queue, index)
	end
end

-- Hace cola hasta ser el primero; devuelve false si algo sale mal.
local function waitTurn(state, visitor)
	local plot = state.plot
	table.insert(state.queue, visitor)
	local lastSpot = nil
	while alive(visitor) and states[plot.index] == state do
		local index = queueIndex(state, visitor)
		if not index then
			return false
		end
		local spot = math.min(index, #plot.caja.queue)
		if spot ~= lastSpot then
			lastSpot = spot
			if not walkTo(visitor, plot.caja.queue[spot]) then
				return false
			end
			standStill(visitor, plot.caja.queue[spot])
			if index > 1 then
				visitor.model:SetAttribute("Reaction", "⏳")
			end
		end
		if index == 1 then
			return true
		end
		task.wait(0.3)
	end
	return false
end

-- Regateo en la caja: devuelve lo que paga (o nil) y cómo se cerró.
local function negotiate(visitor, owner, info, listing, budget, tutorial)
	local model = visitor.model
	local function say(text)
		model:SetAttribute("Reaction", text)
	end
	local offer = Exhibition.roundPrice(math.max(budget, listing.market * Exhibition.PRICE_MIN))
	if offer >= listing.price then
		return listing.price, nil
	end
	say("💬 ¿Te doy 💵" .. Config.formatNumber(offer) .. "?")
	local base = {
		buyer = info.name,
		userId = info.userId,
		vip = info.vip,
		d = listing.d,
		c = listing.c,
		st = listing.st,
		price = listing.price,
		market = listing.market,
	}
	base.offer = offer
	base.final = false
	local answer = VisitorService.askOwner(owner, base)
	if answer == "accept" then
		return offer, nil
	elseif answer == "counter" then
		local counter = Exhibition.counterPrice(offer, listing.price)
		local flex = tutorial and 10 or rng:NextNumber(1, 1.16)
		if counter <= budget * flex then
			say("🤝 ¡Trato hecho!")
			task.wait(1)
			return counter, nil
		end
		if rng:NextNumber() < 0.55 then
			local final = math.max(offer, Exhibition.roundPrice(offer + (counter - offer) * rng:NextNumber(0.3, 0.6)))
			say("Mi última oferta: 💵" .. Config.formatNumber(final))
			base.offer = final
			base.final = true
			local second = VisitorService.askOwner(owner, base)
			if second == "accept" then
				return final, nil
			elseif second == "timeout" and VisitorService.hasCashier(owner) then
				if final >= listing.price * Exhibition.CASHIER_ACCEPT then
					return final, "cashier"
				end
			end
		end
		say("¡Es demasiado para mí! 😤")
		return nil, nil
	elseif answer == "timeout" then
		if VisitorService.hasCashier(owner) then
			if offer >= listing.price * Exhibition.CASHIER_ACCEPT then
				return offer, "cashier"
			end
			say("El cajero dijo que no… 😕")
			return nil, nil
		end
		say("Nadie me atiende… 😕")
		return nil, nil
	end
	say("Vaya… otra vez será 😕")
	return nil, nil
end

-- Ciclo de un visitante -----------------------------------------------------------------
local function runVisitor(state, slot)
	local plot = state.plot
	local owner = state.owner
	local model, name, userId = createAvatar(owner)
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
	local profile = VisitorService.getProfile(owner)
	local vip = profile ~= nil and rng:NextNumber() < Config.vipChance(profile.upgrades)
	model.Name = vip and "Coleccionista" or "Visitante"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 13
	model:SetAttribute("VisitorName", name)
	model:SetAttribute("VIP", vip)
	model:SetAttribute("Owner", owner.UserId)
	model:SetAttribute("Reaction", "")
	setCollisionGroup(model)
	local start = plot.route[1]
	model:PivotTo(CFrame.lookAt(start.Position, plot.route[2].Position) * CFrame.new(0, 3, 0))
	model.Parent = plot.visitorsFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	if vip then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 210, 80)
		sparkles.Parent = root
	end

	local visitor = { model = model, humanoid = humanoid, root = root, tracks = loadTracks(humanoid) }
	state.visitors[visitor] = true
	local info = { name = name, userId = userId, vip = vip }

	local function finish()
		leaveQueue(state, visitor)
		state.visitors[visitor] = nil
		state.reserved[slot] = nil
		if model.Parent then
			model:Destroy()
		end
	end
	local function valid()
		return alive(visitor) and states[plot.index] == state
	end
	local function leave(fromSlot)
		state.reserved[slot] = nil
		if fromSlot then
			walkRoute(visitor, pathBack(plot, fromSlot))
		end
		walkRoute(visitor, plot.exitFromHub)
		finish()
	end

	if not walkRoute(visitor, plot.route) then
		finish()
		return
	end

	-- Mira otro cuadro antes de decidirse (si hay más de uno).
	local current = nil
	local others = {}
	for other in pairs(VisitorService.listings(owner)) do
		if other ~= slot then
			table.insert(others, other)
		end
	end
	if #others > 0 and rng:NextNumber() < 0.6 then
		local browse = pick(others)
		if goToStand(visitor, plot, nil, browse) then
			standStill(visitor, plot.standPoints[browse])
			model:SetAttribute("Reaction", "👀")
			task.wait(rng:NextNumber(1.5, 2.5))
			current = browse
		end
	end

	-- Se planta frente al cuadro elegido y lo admira.
	if not goToStand(visitor, plot, current, slot) or not valid() then
		finish()
		return
	end
	standStill(visitor, plot.standPoints[slot])
	model:SetAttribute("Reaction", vip and "🧐✨" or "🤔")
	task.wait(rng:NextNumber(2.5, 4))
	if not valid() then
		finish()
		return
	end

	local listing = VisitorService.listings(owner)[slot]
	if not listing then
		model:SetAttribute("Reaction", "Oh... ya no está 😢")
		play(visitor, "wave")
		task.wait(2)
		leave(slot)
		return
	end
	local tutorial = VisitorService.isTutorial(owner)
	local ratio = listing.price / math.max(1, listing.market)
	local effective = vip and ratio / 1.8 or ratio
	if not tutorial and rng:NextNumber() > Exhibition.interest(effective) then
		model:SetAttribute(
			"Reaction",
			effective > 1.25 and pick(Config.TooExpensiveLines) or pick(Config.NotForMeLines)
		)
		if VisitorService.onPass then
			VisitorService.onPass(owner, slot, effective, name)
		end
		task.wait(2.4)
		leave(slot)
		return
	end

	-- Le encanta: va a la caja a pagar o a hacerte una oferta.
	model:SetAttribute("Reaction", pick(Config.InterestedLines))
	task.wait(1.4)
	if not walkRoute(visitor, pathBack(plot, slot)) or not waitTurn(state, visitor) then
		finish()
		return
	end
	local caja = plot.caja.queue[1]
	standStill(visitor, caja)

	listing = VisitorService.listings(owner)[slot]
	local amount, how = nil, nil
	if listing then
		local budget = tutorial and listing.price * 0.9 or Exhibition.budget(listing.market, vip, rng)
		if listing.price <= budget then
			amount = listing.price
			model:SetAttribute("Reaction", "¡Pago lo que pides! 💵" .. Config.formatNumber(amount))
			task.wait(1.2)
		else
			amount, how = negotiate(visitor, owner, info, listing, budget, tutorial)
		end
	else
		model:SetAttribute("Reaction", "Oh... ya no está 😢")
	end
	if not valid() then
		finish()
		return
	end
	local bought = amount and VisitorService.onSale and VisitorService.onSale(owner, slot, amount, name, vip, how)
	if bought then
		carryPainting(visitor, bought)
		local line = vip and "¡Una joya para mi colección! 👑" or pick(Config.BuyerLines)
		model:SetAttribute("Reaction", line .. "\n💰 " .. Config.formatNumber(amount))
		play(visitor, "cheer")
	elseif amount then
		model:SetAttribute("Reaction", "Oh... ya no está 😢")
		play(visitor, "wave")
	else
		play(visitor, "wave")
	end
	leaveQueue(state, visitor)
	state.reserved[slot] = nil
	task.wait(2.6)
	walkRoute(visitor, plot.exitRoute)
	finish()
end

-- Elige un cuadro: los más baratos (respecto a su precio medio) y los
-- stands mejores atraen más.
local function chooseListing(state)
	local options, total = {}, 0
	for slot, listing in pairs(VisitorService.listings(state.owner)) do
		if not state.reserved[slot] then
			local ratio = listing.price / math.max(1, listing.market)
			local weight = Exhibition.interest(ratio) * (1 + Exhibition.tierBonus(listing.tier))
			table.insert(options, { slot = slot, weight = weight })
			total += weight
		end
	end
	if #options == 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, option in ipairs(options) do
		roll -= option.weight
		if roll <= 0 then
			return option.slot
		end
	end
	return options[#options].slot
end

-- API pública --------------------------------------------------------------------------
function VisitorService.attach(plot, owner)
	loadFriends(owner)
	local exitFromHub = table.clone(plot.exitRoute)
	table.remove(exitFromHub, 1)
	plot.exitFromHub = exitFromHub
	states[plot.index] = {
		plot = plot,
		owner = owner,
		timer = 0,
		visitors = {},
		reserved = {},
		queue = {},
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
				-- En el tutorial el primer visitante llega enseguida.
				local interval = VisitorService.isTutorial(state.owner) and 4 or Config.buyerInterval(levels)
				state.timer += dt
				if count < Config.maxBuyers(levels) and state.timer >= interval then
					local slot = chooseListing(state)
					if slot then
						state.timer = 0
						state.reserved[slot] = true
						task.spawn(runVisitor, state, slot)
					else
						state.timer = interval * 0.7
					end
				end
			end
		end
	end)
end

return VisitorService
