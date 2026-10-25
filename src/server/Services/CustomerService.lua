-- Clientes: aparecen, caminan hasta la galería, esperan con su pedido y se van.
-- Cada cliente es un modelo hecho con piezas (no necesita assets externos).

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Templates = require(Shared.Templates)

local CustomerService = {}

local WALK_SPEED = 10
local ROOT_HEIGHT = 2.6
local PATIENCE_UPDATE = 0.2

local SKIN_TONES = {
	Color3.fromRGB(255, 224, 196),
	Color3.fromRGB(241, 194, 150),
	Color3.fromRGB(214, 160, 120),
	Color3.fromRGB(170, 116, 80),
	Color3.fromRGB(120, 80, 56),
}

local rng = Random.new()
local plotStates = {}
local customersById = {}

-- Callbacks que asigna el GameService.
CustomerService.getProfile = nil
CustomerService.onExpired = nil

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

-- Construcción del muñequito ------------------------------------------------------
local function attachPart(model, root, props, offset)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		p[key] = value
	end
	p.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local function ball(size)
	return Vector3.new(size, size, size)
end

local function buildModel(startCF, vip)
	local model = Instance.new("Model")
	model.Name = "Customer"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 2, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CFrame = startCF * CFrame.new(0, ROOT_HEIGHT, 0)
	root.Parent = model
	model.PrimaryPart = root

	local skin = pick(SKIN_TONES)
	local shirt = pick(Config.CustomerColors)
	if vip then
		shirt = Color3.fromRGB(255, 214, 90)
	end

	local body =
		attachPart(model, root, { Name = "Body", Size = Vector3.new(3, 3.6, 2.8), Color = shirt }, CFrame.new())
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body

	attachPart(
		model,
		root,
		{ Name = "Head", Shape = Enum.PartType.Ball, Size = ball(2.8), Color = skin },
		CFrame.new(0, 2.9, 0)
	)
	for _, side in ipairs({ -1, 1 }) do
		attachPart(
			model,
			root,
			{ Shape = Enum.PartType.Ball, Size = ball(0.45), Color = Color3.fromRGB(40, 30, 50) },
			CFrame.new(side * 0.5, 3.05, -1.22)
		)
		attachPart(model, root, {
			Shape = Enum.PartType.Ball,
			Size = ball(0.16),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.Neon,
		}, CFrame.new(side * 0.45, 3.15, -1.42))
		attachPart(model, root, {
			Shape = Enum.PartType.Ball,
			Size = ball(0.42),
			Color = Color3.fromRGB(255, 140, 160),
			Transparency = 0.35,
		}, CFrame.new(side * 0.88, 2.6, -1.08))
		attachPart(
			model,
			root,
			{ Name = "Hand", Shape = Enum.PartType.Ball, Size = ball(0.9), Color = skin },
			CFrame.new(side * 1.6, -0.3, -0.2)
		)
		attachPart(
			model,
			root,
			{ Name = "Foot", Shape = Enum.PartType.Ball, Size = ball(0.95), Color = Color3.fromRGB(70, 56, 90) },
			CFrame.new(side * 0.65, -2.15, -0.15)
		)
	end
	attachPart(
		model,
		root,
		{ Size = Vector3.new(0.55, 0.12, 0.1), Color = Color3.fromRGB(150, 60, 70) },
		CFrame.new(0, 2.42, -1.33)
	)

	local hatStyle = vip and "crown" or pick({ "none", "beret", "tophat", "bow", "cap", "none" })
	local hatColor = pick(Config.CustomerColors):Lerp(Color3.new(0, 0, 0), 0.25)
	if hatStyle == "beret" then
		attachPart(
			model,
			root,
			{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.6, 2.6), Color = hatColor },
			CFrame.new(0.25, 4.2, 0) * CFrame.Angles(0, 0, math.rad(80))
		)
	elseif hatStyle == "tophat" then
		attachPart(
			model,
			root,
			{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.9, 2.9), Color = Color3.fromRGB(40, 32, 50) },
			CFrame.new(0, 4.15, 0) * CFrame.Angles(0, 0, math.rad(90))
		)
		attachPart(
			model,
			root,
			{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 1.9, 1.9), Color = Color3.fromRGB(40, 32, 50) },
			CFrame.new(0, 4.95, 0) * CFrame.Angles(0, 0, math.rad(90))
		)
		attachPart(
			model,
			root,
			{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 1.95, 1.95), Color = hatColor },
			CFrame.new(0, 4.45, 0) * CFrame.Angles(0, 0, math.rad(90))
		)
	elseif hatStyle == "bow" then
		for _, side in ipairs({ -1, 1 }) do
			attachPart(
				model,
				root,
				{ Shape = Enum.PartType.Ball, Size = ball(0.8), Color = Color3.fromRGB(255, 110, 170) },
				CFrame.new(side * 0.45, 4.25, 0.2)
			)
		end
		attachPart(
			model,
			root,
			{ Shape = Enum.PartType.Ball, Size = ball(0.4), Color = Color3.fromRGB(230, 70, 140) },
			CFrame.new(0, 4.25, 0.2)
		)
	elseif hatStyle == "cap" then
		attachPart(
			model,
			root,
			{ Shape = Enum.PartType.Ball, Size = ball(2.9), Color = hatColor },
			CFrame.new(0, 3.35, 0.05)
		)
		attachPart(model, root, { Size = Vector3.new(1.8, 0.15, 1.2), Color = hatColor }, CFrame.new(0, 3.75, -1.5))
	elseif hatStyle == "crown" then
		local gold = Color3.fromRGB(255, 200, 60)
		attachPart(model, root, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.7, 1.9, 1.9),
			Color = gold,
			Material = Enum.Material.Metal,
			Reflectance = 0.2,
		}, CFrame.new(0, 4.35, 0) * CFrame.Angles(0, 0, math.rad(90)))
		for i = 0, 4 do
			local angle = i / 5 * math.pi * 2
			attachPart(model, root, {
				Shape = Enum.PartType.Ball,
				Size = ball(0.42),
				Color = (i % 2 == 0) and Color3.fromRGB(255, 80, 120) or Color3.fromRGB(90, 200, 255),
				Material = Enum.Material.Neon,
			}, CFrame.new(math.cos(angle) * 0.8, 4.85, math.sin(angle) * 0.8))
		end
		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = gold
		sparkle.Parent = body
	end

	return model, root
end

-- Pedidos ---------------------------------------------------------------------------
local function chooseTemplate(level)
	local unlocked = Templates.unlockedFor(level)
	local total = 0
	local weights = {}
	for i in ipairs(unlocked) do
		-- Las obras recién desbloqueadas salen un poco más a menudo.
		local weight = 1 + i / #unlocked
		weights[i] = weight
		total += weight
	end
	local roll = rng:NextNumber() * total
	for i, template in ipairs(unlocked) do
		roll -= weights[i]
		if roll <= 0 then
			return template
		end
	end
	return unlocked[#unlocked]
end

local function chooseMode(level)
	local total = 0
	for _, id in ipairs(Config.ModeOrder) do
		local mode = Config.Modes[id]
		if mode.level <= level then
			total += mode.weight
		end
	end
	local roll = rng:NextNumber() * total
	for _, id in ipairs(Config.ModeOrder) do
		local mode = Config.Modes[id]
		if mode.level <= level then
			roll -= mode.weight
			if roll <= 0 then
				return id
			end
		end
	end
	return "original"
end

-- Elige el color principal del dibujo y un color nuevo que no esté en la plantilla.
local function chooseSwap(template)
	local counts = {}
	local background = string.sub(template.flat, 1, 1)
	for i = 1, #template.flat do
		local key = string.sub(template.flat, i, i)
		if key ~= Palette.OUTLINE and key ~= background then
			counts[key] = (counts[key] or 0) + 1
		end
	end
	local from, best = nil, 0
	for key, count in pairs(counts) do
		if count > best then
			from, best = key, count
		end
	end
	from = from or background
	local options = {}
	for _, entry in ipairs(Palette.List) do
		if not string.find(template.flat, entry.key, 1, true) then
			table.insert(options, entry.key)
		end
	end
	return from, pick(options)
end

local function makeOrder(profile, levels)
	local level = profile.level
	local template = chooseTemplate(level)
	local mode = chooseMode(level)
	local vip = rng:NextNumber() < Config.vipChance(levels)
	local order = {
		templateId = template.id,
		mode = mode,
		vip = vip,
		theme = "",
		swapFrom = "",
		swapTo = "",
	}
	if mode == "remix" then
		order.swapFrom, order.swapTo = chooseSwap(template)
	elseif mode == "tema" then
		order.theme = pick(Config.Themes).id
	end
	local price = template.reward * Config.Modes[mode].pay * Config.payMultiplier(levels)
	if vip then
		price *= Config.VIP_MULTIPLIER
	end
	order.reward = math.floor(price)
	local patience = template.patience * Config.patienceMultiplier(levels)
	if mode == "remix" or mode == "tema" then
		patience *= 1.1
	end
	order.patience = patience
	return order
end

-- Movimiento ------------------------------------------------------------------------
local function walk(customer, points, onDone)
	if customer.walkConnection then
		customer.walkConnection:Disconnect()
	end
	local root = customer.root
	local index = 1
	local elapsed = 0
	local position = root.Position - Vector3.new(0, ROOT_HEIGHT, 0)
	customer.walkConnection = RunService.Heartbeat:Connect(function(dt)
		if not root.Parent then
			customer.walkConnection:Disconnect()
			return
		end
		elapsed += dt
		local target = points[index].Position
		local offset = target - position
		local distance = offset.Magnitude
		local step = WALK_SPEED * dt
		local direction = distance > 0.01 and offset.Unit or Vector3.new(0, 0, -1)
		if distance <= step then
			position = target
			index += 1
		else
			position += direction * step
		end
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude < 0.01 then
			flat = root.CFrame.LookVector
		end
		local hop = math.abs(math.sin(elapsed * 9)) * 0.55
		if index > #points then
			customer.walkConnection:Disconnect()
			customer.walkConnection = nil
			root.CFrame = points[#points] * CFrame.new(0, ROOT_HEIGHT, 0)
			if onDone then
				onDone()
			end
			return
		end
		local sway = math.sin(elapsed * 9) * 0.08
		root.CFrame = CFrame.lookAt(position, position + flat)
			* CFrame.new(0, ROOT_HEIGHT + hop, 0)
			* CFrame.Angles(0, 0, sway)
	end)
end

local function setState(customer, state)
	customer.state = state
	customer.model:SetAttribute("State", state)
	customer.prompt.Enabled = state == "waiting"
end

local function removeCustomer(customer)
	if customer.walkConnection then
		customer.walkConnection:Disconnect()
		customer.walkConnection = nil
	end
	customersById[customer.id] = nil
	local plotState = plotStates[customer.plot.index]
	if plotState then
		plotState.customers[customer.id] = nil
		if plotState.spotsTaken[customer.spotIndex] == customer then
			plotState.spotsTaken[customer.spotIndex] = nil
		end
	end
	if customer.model then
		customer.model:Destroy()
	end
end

local function leave(customer, reaction)
	if customer.state == "leaving" then
		return
	end
	setState(customer, "leaving")
	if reaction then
		customer.model:SetAttribute("Reaction", reaction)
	end
	local plotState = plotStates[customer.plot.index]
	if plotState and plotState.spotsTaken[customer.spotIndex] == customer then
		plotState.spotsTaken[customer.spotIndex] = nil
	end
	local plot = customer.plot
	local spot = plot.spots[customer.spotIndex]
	task.delay(1.6, function()
		if not customer.model.Parent then
			return
		end
		walk(customer, {
			spot * CFrame.new(0, 0, -6),
			plot.inside,
			plot.entrance,
			plot.street,
		}, function()
			removeCustomer(customer)
		end)
	end)
end

local function spawnCustomer(plotState)
	local plot = plotState.plot
	local owner = plotState.owner
	local profile = CustomerService.getProfile(owner)
	if not profile then
		return
	end
	local spotIndex
	local free = {}
	for i = 1, #plot.spots do
		if not plotState.spotsTaken[i] then
			table.insert(free, i)
		end
	end
	if #free == 0 then
		return
	end
	spotIndex = pick(free)

	local order = makeOrder(profile, profile.upgrades)
	local id = HttpService:GenerateGUID(false)
	local model, root = buildModel(plot.street, order.vip)
	local name = pick(Config.CustomerNames)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pintar pedido"
	prompt.ObjectText = name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = root

	model:SetAttribute("OrderId", id)
	model:SetAttribute("Owner", owner.UserId)
	model:SetAttribute("CustomerName", name)
	model:SetAttribute("TemplateId", order.templateId)
	model:SetAttribute("Mode", order.mode)
	model:SetAttribute("Theme", order.theme)
	model:SetAttribute("SwapFrom", order.swapFrom)
	model:SetAttribute("SwapTo", order.swapTo)
	model:SetAttribute("VIP", order.vip)
	model:SetAttribute("Reward", order.reward)
	model:SetAttribute("MaxPatience", order.patience)
	model:SetAttribute("Patience", order.patience)
	model:SetAttribute("Painting", false)
	model:SetAttribute("Reaction", "")
	model.Name = "Customer_" .. name

	local customer = {
		id = id,
		plot = plot,
		owner = owner,
		model = model,
		root = root,
		prompt = prompt,
		spotIndex = spotIndex,
		order = order,
		patience = order.patience,
		painting = false,
		sinceUpdate = 0,
	}
	plotState.spotsTaken[spotIndex] = customer
	plotState.customers[id] = customer
	customersById[id] = customer
	setState(customer, "entering")
	model.Parent = plot.customersFolder

	prompt.Triggered:Connect(function(player)
		if CustomerService.onPromptTriggered then
			CustomerService.onPromptTriggered(player, customer)
		end
	end)

	local spot = plot.spots[spotIndex]
	walk(customer, {
		plot.entrance,
		plot.inside,
		spot * CFrame.new(0, 0, -6),
		spot,
	}, function()
		if customer.state ~= "entering" then
			return
		end
		root.CFrame = spot * CFrame.new(0, ROOT_HEIGHT, 0) * CFrame.Angles(0, math.pi, 0)
		setState(customer, "waiting")
	end)
end

-- API pública ------------------------------------------------------------------------
function CustomerService.attach(plot, owner)
	plotStates[plot.index] = {
		plot = plot,
		owner = owner,
		customers = {},
		spotsTaken = {},
		spawnTimer = Config.BASE_SPAWN_INTERVAL - 2,
	}
end

function CustomerService.detach(plot)
	local plotState = plotStates[plot.index]
	if not plotState then
		return
	end
	plotStates[plot.index] = nil
	for _, customer in pairs(plotState.customers) do
		removeCustomer(customer)
	end
	plot.customersFolder:ClearAllChildren()
end

-- Devuelve el cliente si el pedido es válido para ese jugador.
function CustomerService.getWaiting(player, orderId)
	local customer = customersById[orderId]
	if customer and customer.owner == player and customer.state == "waiting" then
		return customer
	end
	return nil
end

function CustomerService.setPainting(customer, painting)
	customer.painting = painting
	if customer.model.Parent then
		customer.model:SetAttribute("Painting", painting)
	end
end

function CustomerService.complete(customer, stars, line)
	customer.painting = false
	local emoji = stars >= 3 and "😍" or (stars >= 2 and "😊" or (stars >= 1 and "🙂" or "😕"))
	leave(customer, emoji .. " " .. line)
	if stars >= 2 then
		local hearts = Instance.new("ParticleEmitter")
		hearts.Rate = 0
		hearts.Lifetime = NumberRange.new(1, 1.6)
		hearts.Speed = NumberRange.new(4, 7)
		hearts.SpreadAngle = Vector2.new(60, 60)
		hearts.LightEmission = 0.6
		hearts.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(1, 0),
		})
		hearts.Color = ColorSequence.new(Color3.fromRGB(255, 120, 180), Color3.fromRGB(255, 220, 120))
		hearts.EmissionDirection = Enum.NormalId.Top
		hearts.Parent = customer.root
		hearts:Emit(stars >= 3 and 40 or 20)
	end
end

function CustomerService.countFor(player)
	local count = 0
	for _, customer in pairs(customersById) do
		if customer.owner == player and customer.state ~= "leaving" then
			count += 1
		end
	end
	return count
end

function CustomerService.start()
	RunService.Heartbeat:Connect(function(dt)
		for _, plotState in pairs(plotStates) do
			local owner = plotState.owner
			local profile = CustomerService.getProfile(owner)
			if profile then
				local levels = profile.upgrades
				-- Generar clientes nuevos.
				local active = 0
				for _, customer in pairs(plotState.customers) do
					if customer.state ~= "leaving" then
						active += 1
					end
				end
				if active < Config.maxQueue(levels) then
					plotState.spawnTimer += dt
					if plotState.spawnTimer >= Config.spawnInterval(levels) then
						plotState.spawnTimer = 0
						spawnCustomer(plotState)
					end
				else
					plotState.spawnTimer = math.min(plotState.spawnTimer, Config.spawnInterval(levels) * 0.5)
				end

				-- Paciencia de los clientes que esperan.
				for _, customer in pairs(plotState.customers) do
					if customer.state == "waiting" then
						local rate = customer.painting and Config.PAINTING_PATIENCE_RATE or 1
						customer.patience -= dt * rate
						customer.sinceUpdate += dt
						if customer.patience <= 0 then
							customer.patience = 0
							customer.model:SetAttribute("Patience", 0)
							leave(customer, pick(Config.AngryLines))
							if CustomerService.onExpired then
								task.spawn(CustomerService.onExpired, owner, customer)
							end
						elseif customer.sinceUpdate >= PATIENCE_UPDATE then
							customer.sinceUpdate = 0
							customer.model:SetAttribute("Patience", customer.patience)
						end
					end
				end
			end
		end
	end)
end

return CustomerService
