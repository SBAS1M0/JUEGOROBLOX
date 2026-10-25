-- Punto de entrada del servidor: crea el mundo, asigna galerías y gestiona la
-- máquina de colores, los cuadros, la galería, las ventas y las mejoras.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Colors = require(Shared.Colors)
local Designs = require(Shared.Designs)

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local WorldBuilder = require(Services.WorldBuilder)
local VisitorService = require(Services.VisitorService)

local rng = Random.new()

-- Remotos -------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(class, name)
	local r = Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end
local GetState = remote("RemoteFunction", "GetState")
local StateChanged = remote("RemoteEvent", "StateChanged")
local Notify = remote("RemoteEvent", "Notify")
local Roll = remote("RemoteFunction", "Roll")
local SetAutoRoll = remote("RemoteEvent", "SetAutoRoll")
local RollResult = remote("RemoteEvent", "RollResult")
local OpenDesigns = remote("RemoteEvent", "OpenDesigns")
local UnlockDesign = remote("RemoteFunction", "UnlockDesign")
local StartPainting = remote("RemoteFunction", "StartPainting")
local CancelPainting = remote("RemoteEvent", "CancelPainting")
local FinishPainting = remote("RemoteFunction", "FinishPainting")
local BuyUpgrade = remote("RemoteFunction", "BuyUpgrade")
local ClaimDaily = remote("RemoteFunction", "ClaimDaily")
local GoHome = remote("RemoteEvent", "GoHome")
remotes.Parent = ReplicatedStorage

-- Colisiones: los visitantes no empujan a los jugadores ni entre ellos.
local PLAYER_GROUP = "Jugadores"
pcall(function()
	PhysicsService:RegisterCollisionGroup(VisitorService.COLLISION_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(VisitorService.COLLISION_GROUP, VisitorService.COLLISION_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(VisitorService.COLLISION_GROUP, PLAYER_GROUP, false)
end)

-- Mundo ---------------------------------------------------------------------------
local plots = WorldBuilder.build()
local plotOf = {}
local sessions = {}

local function getSession(player)
	local session = sessions[player]
	if not session then
		session = { nextRoll = 0, painting = nil, lastHome = 0 }
		sessions[player] = session
	end
	return session
end

local function notify(player, text, kind)
	Notify:FireClient(player, text, kind or "info")
end

local function dailyStatus(data)
	local now = os.time()
	local ready = now - data.lastDaily >= Config.DAILY_COOLDOWN
	local streak = data.dailyStreak
	if now - data.lastDaily > Config.DAILY_COOLDOWN * 2.4 then
		streak = 0
	end
	local nextStreak = math.min(streak + 1, 7)
	local amount = 80 + nextStreak * 40
	return ready, amount, math.max(0, Config.DAILY_COOLDOWN - (now - data.lastDaily)), nextStreak
end

local function openLevel(data)
	local level = 1
	for l = 2, Designs.MAX_LEVEL do
		if Designs.isLevelOpen(l, data.made) then
			level = l
		end
	end
	return level
end

local function buildState(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local session = getSession(player)
	local ready, amount, wait, nextStreak = dailyStatus(data)
	local plot = plotOf[player]
	return {
		coins = data.coins,
		paints = data.paints,
		unlocked = data.unlocked,
		made = data.made,
		upgrades = data.upgrades,
		openLevel = openLevel(data),
		slots = Config.gallerySlots(data.upgrades),
		displayed = #data.gallery,
		autoRoll = data.autoRoll,
		lastRoll = data.lastRoll,
		rollInterval = Config.rollInterval(data.upgrades),
		sold = data.sold,
		earned = data.earned,
		painting = session.painting and session.painting.designId or nil,
		dailyReady = ready,
		dailyAmount = amount,
		dailyWait = wait,
		dailyStreak = nextStreak,
		plotIndex = plot and plot.index or 0,
	}
end

local function updateLeaderstats(player)
	local data = DataService.get(player)
	local stats = player:FindFirstChild("leaderstats")
	if data and stats then
		stats.Monedas.Value = data.coins
		stats.Vendidos.Value = data.sold
	end
end

local function pushState(player)
	local state = buildState(player)
	if state then
		StateChanged:FireClient(player, state)
	end
	updateLeaderstats(player)
end

-- Visuales de la parcela ---------------------------------------------------------------
local function rarityIndex(colorId)
	return Colors.rarityOf(Colors.ById[colorId]).index
end

local function renderShelf(plot, data)
	local owned = {}
	for colorId, count in pairs(data and data.paints or {}) do
		if count > 0 and Colors.ById[colorId] then
			table.insert(owned, colorId)
		end
	end
	table.sort(owned, function(a, b)
		local ra, rb = rarityIndex(a), rarityIndex(b)
		if ra ~= rb then
			return ra > rb
		end
		return Colors.ById[a].index < Colors.ById[b].index
	end)
	for i, can in ipairs(plot.workshop.shelfCans) do
		local colorId = owned[i]
		if colorId then
			local rarity = rarityIndex(colorId)
			can.Color = Colors.mainColor(colorId)
			can.Transparency = 0
			can.Material = rarity >= 6 and Enum.Material.Neon
				or (rarity >= 5 and Enum.Material.Metal or Enum.Material.SmoothPlastic)
		else
			can.Color = Color3.fromRGB(230, 230, 236)
			can.Transparency = 0.7
			can.Material = Enum.Material.SmoothPlastic
		end
	end
end

local function renderMachine(plot, colorId)
	local workshop = plot.workshop
	local entry = Colors.ById[colorId]
	workshop.machineTop:SetAttribute("ColorId", entry and colorId or "")
	if entry then
		workshop.machineCan.Color = Colors.mainColor(colorId)
		workshop.machineGlow.Color = Colors.rarityOf(entry).color
	end
end

local function slotEntry(data, slot)
	for i, entry in ipairs(data.gallery) do
		if entry.s == slot then
			return entry, i
		end
	end
	return nil
end

local function renderGallery(plot, data)
	local slots = data and Config.gallerySlots(data.upgrades) or 0
	for i = 1, Config.GALLERY_SIZE do
		local canvas = plot.canvases[i]
		local plaque = plot.plaques[i]
		local entry = data and slotEntry(data, i)
		local design = entry and Designs.get(entry.d)
		canvas:SetAttribute("Locked", i > slots)
		if design then
			canvas:SetAttribute("Design", entry.d)
			canvas:SetAttribute("Colors", entry.c)
			canvas:SetAttribute("Price", entry.v)
			plaque.Text = design.name .. " · 💰" .. entry.v
		else
			canvas:SetAttribute("Design", "")
			canvas:SetAttribute("Colors", "")
			canvas:SetAttribute("Price", 0)
			plaque.Text = i > slots and "🔒 Más paredes" or "Espacio libre"
		end
	end
end

local function renderEasel(plot, designId, colors)
	plot.workshop.easelCanvas:SetAttribute("Design", designId or "")
	plot.workshop.easelCanvas:SetAttribute("Colors", colors or "")
end

-- Galerías -----------------------------------------------------------------------------
local function assignPlot(player)
	for _, plot in ipairs(plots) do
		if plot.model:GetAttribute("OwnerUserId") == 0 then
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			plotOf[player] = plot
			plot.signLabel.Text = "Galería de " .. player.DisplayName
			return plot
		end
	end
	return nil
end

local function releasePlot(player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	VisitorService.detach(plot)
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.signLabel.Text = "Galería libre"
	renderGallery(plot, nil)
	renderShelf(plot, nil)
	renderMachine(plot, "")
	renderEasel(plot, nil, nil)
	WorldBuilder.setDecorLevel(plot, 0)
end

local function teleportHome(player)
	local plot = plotOf[player]
	local character = player.Character
	if plot and character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(plot.ownerSpawn)
	end
end

local function refreshPlot(player)
	local plot = plotOf[player]
	local data = DataService.get(player)
	if plot and data then
		renderGallery(plot, data)
		renderShelf(plot, data)
	end
end

-- Máquina de colores ---------------------------------------------------------------------
local function addPaint(data, colorId, amount)
	data.paints[colorId] = math.min(Config.MAX_PAINT_STACK, (data.paints[colorId] or 0) + amount)
end

local function doRoll(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local entry = Colors.roll(Config.luck(data.upgrades), rng)
	addPaint(data, entry.id, 1)
	data.lastRoll = entry.id
	local plot = plotOf[player]
	if plot then
		renderMachine(plot, entry.id)
		renderShelf(plot, data)
	end
	RollResult:FireClient(player, entry.id)
	pushState(player)
	return entry.id
end

local function tryRoll(player)
	local data = DataService.get(player)
	local session = getSession(player)
	if not data then
		return nil
	end
	local now = os.clock()
	if now < session.nextRoll then
		return nil
	end
	session.nextRoll = now + Config.rollInterval(data.upgrades)
	return doRoll(player)
end

Roll.OnServerInvoke = function(player)
	return tryRoll(player)
end

SetAutoRoll.OnServerEvent:Connect(function(player, enabled)
	local data = DataService.get(player)
	if data and type(enabled) == "boolean" then
		data.autoRoll = enabled
		pushState(player)
	end
end)

-- Diseños y pintura ------------------------------------------------------------------------
UnlockDesign.OnServerInvoke = function(player, designId)
	local data = DataService.get(player)
	local design = type(designId) == "string" and Designs.get(designId)
	if not (data and design) then
		return false, "Diseño no válido."
	end
	if data.unlocked[designId] then
		return false, "Ya lo tienes."
	end
	if not Designs.isLevelOpen(design.level, data.made) then
		return false, "Pinta todos los diseños del nivel " .. (design.level - 1) .. " primero."
	end
	if data.coins < design.price then
		return false, "Te faltan " .. (design.price - data.coins) .. " monedas."
	end
	data.coins -= design.price
	data.unlocked[designId] = true
	pushState(player)
	return true, "¡Desbloqueaste «" .. design.name .. "»!"
end

-- Cuántas unidades de cada color pide la elección (las básicas no se gastan).
local function paintCost(colors)
	local cost = {}
	for _, colorId in pairs(colors) do
		local entry = Colors.ById[colorId]
		if entry and not entry.basic then
			cost[colorId] = (cost[colorId] or 0) + 1
		end
	end
	return cost
end

StartPainting.OnServerInvoke = function(player, designId, colors)
	local data = DataService.get(player)
	local session = getSession(player)
	local design = type(designId) == "string" and Designs.get(designId)
	if not (data and design) or type(colors) ~= "table" then
		return false, "Diseño no válido."
	end
	if session.painting then
		return false, "Ya estás pintando un cuadro."
	end
	if not data.unlocked[designId] or not Designs.isLevelOpen(design.level, data.made) then
		return false, "Ese diseño está bloqueado."
	end
	local chosen = {}
	for _, area in ipairs(design.areas) do
		local colorId = colors[area.id]
		if type(colorId) ~= "string" or not Colors.ById[colorId] then
			return false, "Elige un color para «" .. area.name .. "»."
		end
		chosen[area.id] = colorId
	end
	local cost = paintCost(chosen)
	for colorId, amount in pairs(cost) do
		if (data.paints[colorId] or 0) < amount then
			return false, "No tienes suficiente «" .. Colors.ById[colorId].name .. "»."
		end
	end
	for colorId, amount in pairs(cost) do
		data.paints[colorId] -= amount
		if data.paints[colorId] <= 0 then
			data.paints[colorId] = nil
		end
	end
	session.painting = {
		designId = designId,
		colors = chosen,
		started = os.clock(),
		minTime = Config.minPaintTime(design, data.upgrades),
	}
	refreshPlot(player)
	pushState(player)
	return true
end

local function cancelPainting(player)
	local data = DataService.get(player)
	local session = getSession(player)
	local painting = session.painting
	if not (data and painting) then
		return
	end
	session.painting = nil
	-- Devolvemos las pinturas usadas.
	for colorId, amount in pairs(paintCost(painting.colors)) do
		addPaint(data, colorId, amount)
	end
	refreshPlot(player)
	pushState(player)
end

CancelPainting.OnServerEvent:Connect(cancelPainting)

local function freeSlot(data)
	for slot = 1, Config.gallerySlots(data.upgrades) do
		if not slotEntry(data, slot) then
			return slot
		end
	end
	return nil
end

FinishPainting.OnServerInvoke = function(player, choice)
	local data = DataService.get(player)
	local session = getSession(player)
	local painting = session.painting
	if not (data and painting) then
		return { ok = false, reason = "No estás pintando nada." }
	end
	if os.clock() - painting.started < painting.minTime then
		return { ok = false, reason = "¡Aún no está terminado!" }
	end
	local design = Designs.get(painting.designId)
	local madeBefore = data.made[design.id] or 0
	local value = Config.paintingValue(design, painting.colors, data.upgrades, madeBefore)
	local encoded = Designs.encodeColors(painting.colors)
	local levelBefore = openLevel(data)
	local tierBefore = Config.masteryFor(madeBefore)

	session.painting = nil
	data.made[design.id] = madeBefore + 1

	local result = { ok = true, value = value, designId = design.id }
	local slot = choice == "galeria" and freeSlot(data)
	if slot then
		local price = math.floor(value * Config.GALLERY_BONUS)
		table.insert(data.gallery, { s = slot, d = design.id, c = encoded, v = price })
		result.displayed = true
		result.price = price
		result.slot = slot
	else
		data.coins += value
		data.earned += value
		data.sold += 1
		result.displayed = false
		result.price = value
	end

	local tierAfter = Config.masteryFor(data.made[design.id])
	if tierAfter and tierAfter ~= tierBefore then
		result.mastery = tierAfter.name
	end
	local levelAfter = openLevel(data)
	if levelAfter > levelBefore then
		result.newLevel = levelAfter
	end

	local plot = plotOf[player]
	if plot then
		renderEasel(plot, design.id, encoded)
	end
	refreshPlot(player)
	pushState(player)
	return result
end

-- Ventas a visitantes --------------------------------------------------------------------
VisitorService.getProfile = function(player)
	return DataService.get(player)
end

VisitorService.availableSlots = function(player)
	local data = DataService.get(player)
	local list = {}
	if data then
		for _, entry in ipairs(data.gallery) do
			table.insert(list, entry.s)
		end
	end
	return list
end

VisitorService.onPurchase = function(player, slot, buyerName)
	local data = DataService.get(player)
	if not data or not player.Parent then
		return nil
	end
	local entry, index = slotEntry(data, slot)
	if not entry then
		return nil
	end
	table.remove(data.gallery, index)
	data.coins += entry.v
	data.earned += entry.v
	data.sold += 1
	local design = Designs.get(entry.d)
	notify(
		player,
		"🖼️ "
			.. tostring(buyerName)
			.. " compró «"
			.. (design and design.name or "tu cuadro")
			.. "» por 💰"
			.. entry.v,
		"gold"
	)
	refreshPlot(player)
	pushState(player)
	return entry.v
end

-- Mejoras y regalo diario -------------------------------------------------------------------
BuyUpgrade.OnServerInvoke = function(player, id)
	local data = DataService.get(player)
	local upgrade = type(id) == "string" and Config.UpgradeById[id]
	if not (data and upgrade) then
		return false, "Mejora no válida."
	end
	local level = data.upgrades[id] or 0
	if level >= upgrade.max then
		return false, "¡Ya está al máximo!"
	end
	local cost = Config.upgradeCost(id, level)
	if data.coins < cost then
		return false, "Te faltan " .. (cost - data.coins) .. " monedas."
	end
	data.coins -= cost
	data.upgrades[id] = level + 1
	local plot = plotOf[player]
	if plot then
		if id == "decoracion" then
			WorldBuilder.setDecorLevel(plot, level + 1)
		elseif id == "paredes" then
			renderGallery(plot, data)
		end
	end
	pushState(player)
	return true, upgrade.name .. " subió a nivel " .. (level + 1) .. "!"
end

ClaimDaily.OnServerInvoke = function(player)
	local data = DataService.get(player)
	if not data then
		return false
	end
	local ready, amount, _, nextStreak = dailyStatus(data)
	if not ready then
		return false
	end
	data.lastDaily = os.time()
	data.dailyStreak = nextStreak
	data.coins += amount
	-- Además regala un color raro o mejor.
	local gift
	for _ = 1, 60 do
		gift = Colors.roll(4, rng)
		if Colors.rarityOf(gift).index >= 3 then
			break
		end
	end
	addPaint(data, gift.id, 1)
	refreshPlot(player)
	pushState(player)
	return true, amount, gift.id
end

GetState.OnServerInvoke = function(player)
	for _ = 1, 50 do
		if DataService.get(player) then
			break
		end
		task.wait(0.2)
	end
	return buildState(player)
end

GoHome.OnServerEvent:Connect(function(player)
	local session = getSession(player)
	if os.clock() - session.lastHome >= 2 then
		session.lastHome = os.clock()
		teleportHome(player)
	end
end)

-- Jugadores ----------------------------------------------------------------------------------
local function setCharacterGroup(character)
	local function apply(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = PLAYER_GROUP
		end
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		apply(descendant)
	end
	character.DescendantAdded:Connect(apply)
end

local function onPlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in ipairs({ "Monedas", "Vendidos" }) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player

	player.CharacterAdded:Connect(function(character)
		setCharacterGroup(character)
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.2)
		teleportHome(player)
	end)

	local data = DataService.load(player)
	if not player.Parent then
		return
	end
	local plot = assignPlot(player)
	if plot then
		renderGallery(plot, data)
		renderShelf(plot, data)
		renderMachine(plot, data.lastRoll)
		WorldBuilder.setDecorLevel(plot, data.upgrades.decoracion or 0)
		VisitorService.attach(plot, player)
	else
		notify(player, "Todas las galerías están ocupadas. ¡Explora la plaza!", "error")
	end
	if player.Character then
		setCharacterGroup(player.Character)
		task.defer(teleportHome, player)
	end
	pushState(player)
	notify(player, "¡Bienvenido a tu taller! Tira colores y pinta tu primer cuadro 🎨", "success")
end

local function onPlayerRemoving(player)
	cancelPainting(player)
	releasePlot(player)
	DataService.release(player)
	sessions[player] = nil
end

-- Avisos del taller: solo responden al dueño de la parcela.
for _, plot in ipairs(plots) do
	plot.workshop.drawPrompt.Triggered:Connect(function(who)
		if plotOf[who] == plot then
			OpenDesigns:FireClient(who)
		else
			notify(who, "Este taller es de otro artista 😉", "error")
		end
	end)
	plot.workshop.machinePrompt.Triggered:Connect(function(who)
		if plotOf[who] == plot then
			tryRoll(who)
		end
	end)
end

-- Arranque -----------------------------------------------------------------------------------
DataService.start()
VisitorService.start()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Tiradas automáticas de la máquina.
task.spawn(function()
	while true do
		task.wait(0.2)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = DataService.get(player)
			if data and data.autoRoll and plotOf[player] then
				tryRoll(player)
			end
		end
	end
end)

-- Refresca el contador del regalo diario.
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			pushState(player)
		end
	end
end)
