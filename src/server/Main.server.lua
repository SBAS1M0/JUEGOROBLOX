-- Punto de entrada del servidor: crea el terreno propio de cada jugador y
-- gestiona la máquina de colores, los cuadros, la galería, las ventas,
-- las mejoras, las misiones diarias y el tutorial.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Colors = require(Shared.Colors)
local Designs = require(Shared.Designs)
local Exhibition = require(Shared.Exhibition)

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
local RollResult = remote("RemoteEvent", "RollResult")
local OpenDesigns = remote("RemoteEvent", "OpenDesigns")
local UnlockDesign = remote("RemoteFunction", "UnlockDesign")
local StartPainting = remote("RemoteFunction", "StartPainting")
local CancelPainting = remote("RemoteEvent", "CancelPainting")
local FinishPainting = remote("RemoteFunction", "FinishPainting")
local BuyUpgrade = remote("RemoteFunction", "BuyUpgrade")
local SelectStored = remote("RemoteEvent", "SelectStored")
local OpenStand = remote("RemoteEvent", "OpenStand")
local StandAction = remote("RemoteFunction", "StandAction")
local Offer = remote("RemoteEvent", "Offer")
local OfferClosed = remote("RemoteEvent", "OfferClosed")
local RespondOffer = remote("RemoteEvent", "RespondOffer")
local OpenMixer = remote("RemoteEvent", "OpenMixer")
local MixColors = remote("RemoteFunction", "MixColors")
local SkipTutorial = remote("RemoteEvent", "SkipTutorial")
local ClaimDaily = remote("RemoteFunction", "ClaimDaily")
local ClaimQuest = remote("RemoteFunction", "ClaimQuest")
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

local tryRoll
local renderAutoPrompt
local toggleAutoRoll
local buyStand
local buyRoom

-- Estado de la sesión --------------------------------------------------------------------
local plotOf = {}
local usedSlots = {}
local sessions = {}

local function getSession(player)
	local session = sessions[player]
	if not session then
		session = { nextRoll = 0, nextAuto = 0, painting = nil, lastHome = 0, lastPass = 0 }
		sessions[player] = session
	end
	return session
end

local function notify(player, text, kind)
	Notify:FireClient(player, text, kind or "info")
end

local function openLevel(data)
	local level = 1
	for l = 2, Designs.MAIN_LEVELS do
		if Designs.isLevelOpen(l, data.made) then
			level = l
		end
	end
	return level
end

local function dailyStatus(data)
	local now = os.time()
	local ready = now - data.lastDaily >= Config.DAILY_COOLDOWN
	local streak = data.dailyStreak
	if now - data.lastDaily > Config.DAILY_COOLDOWN * 2.4 then
		streak = 0
	end
	local nextStreak = math.min(streak + 1, 7)
	local amount = math.floor((80 + nextStreak * 40) * Config.questScale(openLevel(data)))
	return ready, amount, math.max(0, Config.DAILY_COOLDOWN - (now - data.lastDaily)), nextStreak
end

-- Misiones diarias -----------------------------------------------------------------------
local function ensureQuests(data)
	local day = math.floor(os.time() / 86400)
	if data.questDay == day and #data.quests == Config.QUESTS_PER_DAY then
		return
	end
	data.questDay = day
	data.questBonus = false
	data.quests = {}
	local scale = Config.questScale(openLevel(data))
	local pool = {}
	for _, def in ipairs(Config.QuestTypes) do
		table.insert(pool, def)
	end
	for _ = 1, Config.QUESTS_PER_DAY do
		local def = table.remove(pool, rng:NextInteger(1, #pool))
		local tier = rng:NextInteger(1, #def.goals)
		local goal = def.goals[tier]
		if def.scale then
			goal = math.floor(goal * scale / 10 + 0.5) * 10
		end
		table.insert(data.quests, {
			id = def.id,
			goal = goal,
			progress = 0,
			reward = math.floor((40 + 35 * tier) * scale),
			claimed = false,
		})
	end
end

-- Tutorial ----------------------------------------------------------------------------------
local pushState

local function tutorialEvent(player, data, step, amount)
	if data.tutorial ~= step then
		return
	end
	local def = Config.Tutorial[step]
	data.tutorialProgress += amount or 1
	if data.tutorialProgress >= def.goal then
		data.tutorial += 1
		data.tutorialProgress = 0
		if data.tutorial > #Config.Tutorial then
			data.tutorial = 0
			data.coins += Config.TUTORIAL_REWARD
			notify(player, "🎓 ¡Tutorial completado! +💵" .. Config.TUTORIAL_REWARD, "gold")
		end
	end
end

local function questEvent(player, data, id, amount)
	ensureQuests(data)
	for _, quest in ipairs(data.quests) do
		if quest.id == id and quest.progress < quest.goal then
			quest.progress = math.min(quest.goal, quest.progress + amount)
			if quest.progress >= quest.goal then
				notify(player, "✅ Misión lista: " .. Config.questText(quest) .. " (¡reclámala!)", "success")
			end
		end
	end
end

local function earn(player, data, amount)
	data.coins += amount
	data.earned += amount
	questEvent(player, data, "ganar", amount)
end

-- Estado para el cliente -------------------------------------------------------------------
local function buildState(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	ensureQuests(data)
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
		stands = data.stands,
		standCount = Exhibition.countStands(data.stands),
		standCost = Exhibition.standCost(Exhibition.countStands(data.stands)),
		rooms = data.rooms,
		gallery = data.gallery,
		displayed = #data.gallery,
		storage = data.storage,
		storageMax = Config.STORAGE_SIZE,
		hasCashier = Config.hasCashier(data.upgrades),
		best = data.best,
		autoUnlocked = Config.hasAutoRoll(data.upgrades),
		autoRoll = data.autoRoll and Config.hasAutoRoll(data.upgrades),
		lastRoll = data.lastRoll,
		rolls = data.rolls,
		discovered = data.discovered,
		pity = data.pity,
		pityMax = Config.PITY_ROLLS,
		rollInterval = Config.rollInterval(data.upgrades),
		sold = data.sold,
		earned = data.earned,
		painting = session.painting and session.painting.designId or nil,
		quests = data.quests,
		questBonus = data.questBonus,
		tutorial = data.tutorial,
		tutorialProgress = data.tutorialProgress,
		dailyReady = ready,
		dailyAmount = amount,
		dailyWait = wait,
		dailyStreak = nextStreak,
		plotName = plot and plot.model.Name or "",
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

function pushState(player)
	local state = buildState(player)
	if state then
		StateChanged:FireClient(player, state)
	end
	updateLeaderstats(player)
end

-- Visuales del terreno ----------------------------------------------------------------------
local function rarityIndex(colorId)
	return Colors.rarityOf(Colors.ById[colorId]).index
end

local function ownedSorted(data)
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
	return owned
end

local function renderShelf(plot, data)
	local owned = ownedSorted(data)
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
	-- Las bolas de la máquina muestran tus colores.
	if #owned > 0 then
		for i, ball in ipairs(plot.workshop.machineBalls) do
			ball.Color = Colors.mainColor(owned[(i - 1) % #owned + 1])
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

renderAutoPrompt = function(plot, data)
	if not (plot and data) then
		return
	end
	local autoPrompt = plot.workshop.autoPrompt
	autoPrompt.Enabled = Config.hasAutoRoll(data.upgrades)
	autoPrompt.ActionText = data.autoRoll and "Pausar Auto-Rolling" or "Activar Auto-Rolling"
end

local function slotEntry(data, slot)
	for i, entry in ipairs(data.gallery) do
		if entry.s == slot then
			return entry, i
		end
	end
	return nil
end

-- Stands, cuadros expuestos y tapias de ampliación de la sala.
local function renderStands(plot, data, animateSpot)
	for room = 1, data.rooms do
		WorldBuilder.openRoom(plot, room, false)
	end
	local owned = Exhibition.countStands(data.stands)
	local cost = Exhibition.standCost(owned)
	for i, spot in ipairs(plot.spots) do
		local open = spot.def.room <= data.rooms
		local tier = data.stands[i] or 0
		WorldBuilder.setStand(plot, i, tier, animateSpot == i)
		local entry = slotEntry(data, i)
		local design = entry and Designs.get(entry.d)
		local anchor, standPrompt = spot.anchor, spot.prompt
		anchor:SetAttribute("Open", open)
		anchor:SetAttribute("Owned", tier > 0)
		anchor:SetAttribute("Tier", tier)
		anchor:SetAttribute("Cost", cost)
		anchor:SetAttribute("HasPainting", design ~= nil)
		standPrompt.Enabled = open
		if tier == 0 then
			standPrompt.ActionText = "Comprar stand"
			standPrompt.ObjectText = cost > 0 and ("💵 " .. Config.formatNumber(cost)) or "Gratis"
			standPrompt.HoldDuration = 0.6
		else
			standPrompt.HoldDuration = 0
			if design then
				standPrompt.ActionText = "Gestionar"
				standPrompt.ObjectText = design.name .. " · 💵 " .. Config.formatNumber(entry.p)
			else
				standPrompt.ActionText = #data.storage > 0 and "Exponer cuadro" or "Ver stand"
				standPrompt.ObjectText = Exhibition.tierName(i, tier)
			end
		end
		local canvas = spot.canvas
		if canvas then
			canvas:SetAttribute("Design", design and entry.d or "")
			canvas:SetAttribute("Colors", design and entry.c or "")
			canvas:SetAttribute("Stars", design and (entry.st or 1) or 0)
			canvas:SetAttribute("Price", design and entry.p or 0)
			canvas:SetAttribute("Market", design and Exhibition.marketPrice(entry.v, tier) or 0)
			spot.plaque.Text = design and (design.name .. "  ·  💵 " .. Config.formatNumber(entry.p))
				or Exhibition.tierName(i, tier)
		end
	end
	for index, hoarding in pairs(plot.hoardings) do
		local def = Exhibition.Rooms[index]
		local ready = owned >= def.needStands
		hoarding.prompt.Enabled = data.rooms == index - 1
		hoarding.prompt.ActionText = ready and "Ampliar la galería" or ("Necesitas " .. def.needStands .. " stands")
		hoarding.prompt.ObjectText = def.name .. " · 💵 " .. Config.formatNumber(def.cost)
		hoarding.status.Text = ready and ("Ampliar por 💵 " .. Config.formatNumber(def.cost))
			or string.format("Compra %d stands (%d/%d)", def.needStands, owned, def.needStands)
	end
end

-- El cuadro que llevas a la espalda (el primero del almacén).
local function renderCarry(player, data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local old = character:FindFirstChild("CarriedPainting")
	if old then
		old:Destroy()
	end
	local entry = data and data.storage[1]
	if not entry then
		return
	end
	local model = Instance.new("Model")
	model.Name = "CarriedPainting"
	local base = root.CFrame * CFrame.new(0, 0.4, 0.95) * CFrame.Angles(math.rad(-8), math.pi, 0)
	local back = Instance.new("Part")
	back.Name = "Back"
	back.Size = Vector3.new(3.4, 3.4, 0.25)
	back.CFrame = base
	back.Color = Color3.fromRGB(44, 48, 56)
	back.Material = Enum.Material.Metal
	local canvas = Instance.new("Part")
	canvas.Name = "Canvas"
	canvas.Size = Vector3.new(3, 3, 0.1)
	canvas.CFrame = base * CFrame.new(0, 0, -0.16)
	canvas.Color = Color3.fromRGB(250, 248, 242)
	for _, piece in ipairs({ back, canvas }) do
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = true
		piece.CastShadow = false
		piece.Parent = model
	end
	canvas:SetAttribute("Design", entry.d)
	canvas:SetAttribute("Colors", entry.c)
	canvas:SetAttribute("Stars", entry.st or 1)
	for _, piece in ipairs({ back, canvas }) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = piece
		weld.Parent = piece
	end
	model.Parent = character
end

local function renderEasel(plot, designId, colors)
	plot.workshop.easelCanvas:SetAttribute("Design", designId or "")
	plot.workshop.easelCanvas:SetAttribute("Colors", colors or "")
end

local function refreshPlot(player)
	local plot = plotOf[player]
	local data = DataService.get(player)
	if plot and data then
		renderStands(plot, data)
		renderShelf(plot, data)
	end
end

-- Terreno propio de cada jugador ----------------------------------------------------------------
local function createPlot(player, data)
	local slot
	for i = 1, Config.MAX_PLOTS do
		if not usedSlots[i] then
			slot = i
			break
		end
	end
	if not slot then
		return nil
	end
	usedSlots[slot] = player
	local plot = WorldBuilder.buildLot(slot)
	plot.model:SetAttribute("OwnerUserId", player.UserId)
	pcall(function()
		plot.model:AddPersistentPlayer(player)
	end)
	WorldBuilder.setOwnerName(plot, player.DisplayName)
	plotOf[player] = plot
	renderStands(plot, data)
	renderShelf(plot, data)
	WorldBuilder.setCashier(plot, Config.hasCashier(data.upgrades))
	renderMachine(plot, data.lastRoll)
	WorldBuilder.setDecorLevel(plot, data.upgrades.decoracion or 0)
	VisitorService.attach(plot, player)

	plot.workshop.drawPrompt.Triggered:Connect(function(who)
		if who == player then
			OpenDesigns:FireClient(player)
		end
	end)
	plot.workshop.machinePrompt.Triggered:Connect(function(who)
		if who == player then
			tryRoll(player)
		end
	end)
	plot.workshop.autoPrompt.Triggered:Connect(function(who)
		if who == player then
			toggleAutoRoll(player)
		end
	end)
	plot.workshop.mixPrompt.Triggered:Connect(function(who)
		if who == player then
			OpenMixer:FireClient(player)
		end
	end)
	renderAutoPrompt(plot, data)
	for i, spot in ipairs(plot.spots) do
		spot.prompt.Triggered:Connect(function(who)
			if who ~= player then
				return
			end
			local current = DataService.get(player)
			if current and (current.stands[i] or 0) > 0 then
				OpenStand:FireClient(player, i)
			else
				buyStand(player, i)
			end
		end)
	end
	for index, hoarding in pairs(plot.hoardings) do
		hoarding.prompt.Triggered:Connect(function(who)
			if who == player then
				buyRoom(player, index)
			end
		end)
	end
	return plot
end

local function releasePlot(player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	usedSlots[plot.slot] = nil
	VisitorService.detach(plot)
	WorldBuilder.destroyLot(plot)
end

local function teleportHome(player)
	local plot = plotOf[player]
	local character = player.Character
	if not (plot and character and character:FindFirstChild("HumanoidRootPart")) then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(plot.ownerSpawn.Position, 5)
	end)
	if character.Parent then
		character:PivotTo(plot.ownerSpawn)
	end
end

-- Máquina de colores ---------------------------------------------------------------------------
-- Suma pintura y la apunta en la colección; devuelve true si es nueva.
local function addPaint(data, colorId, amount)
	data.paints[colorId] = math.min(Config.MAX_PAINT_STACK, (data.paints[colorId] or 0) + amount)
	if not data.discovered[colorId] then
		data.discovered[colorId] = true
		return true
	end
	return false
end

local function doRoll(player, auto)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	-- Tras muchas tiradas sin suerte, la siguiente es Raro o mejor seguro.
	local guaranteed = data.pity + 1 >= Config.PITY_ROLLS
	local entry = Colors.roll(Config.luck(data.upgrades), rng, guaranteed and Config.PITY_RARITY or 1)
	local rarity = Colors.rarityOf(entry)
	local isNew = addPaint(data, entry.id, 1)
	data.lastRoll = entry.id
	data.rolls += 1
	data.pity = rarity.index >= Config.PITY_RARITY and 0 or data.pity + 1
	questEvent(player, data, "tirar", 1)
	if rarity.index >= 3 then
		questEvent(player, data, "raro", 1)
	end
	if isNew then
		local bonus = Config.discoveryBonus(rarity)
		earn(player, data, bonus)
		notify(player, "✨ Color nuevo en tu colección: +💵" .. bonus, "gold")
	end
	tutorialEvent(player, data, 1, 1)
	local plot = plotOf[player]
	if plot then
		renderMachine(plot, entry.id)
		renderShelf(plot, data)
	end
	RollResult:FireClient(player, entry.id, auto == true)
	pushState(player)
	return entry.id
end

function tryRoll(player)
	local data = DataService.get(player)
	local session = getSession(player)
	if not data then
		return nil
	end
	local now = os.clock()
	if now < session.nextRoll then
		return nil
	end
	local interval = Config.rollInterval(data.upgrades)
	session.nextRoll = now + interval
	-- El aviso de la máquina desaparece mientras gira.
	local plot = plotOf[player]
	if plot then
		local machinePrompt = plot.workshop.machinePrompt
		machinePrompt.Enabled = false
		task.delay(interval, function()
			if plotOf[player] == plot then
				machinePrompt.Enabled = true
			end
		end)
	end
	return doRoll(player, false)
end

toggleAutoRoll = function(player)
	local data = DataService.get(player)
	if not (data and Config.hasAutoRoll(data.upgrades)) then
		return
	end
	data.autoRoll = not data.autoRoll
	renderAutoPrompt(plotOf[player], data)
	notify(player, data.autoRoll and "🤖 Auto-Rolling activado" or "⏸ Auto-Rolling en pausa", "info")
	pushState(player)
end

-- Diseños y pintura -------------------------------------------------------------------------------
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
		local info = Designs.LevelInfo[design.level]
		return false,
			"Pinta todos los diseños del nivel " .. ((info and info.requires or design.level) - 1) .. " primero."
	end
	if data.coins < design.price then
		return false, "Te faltan " .. (design.price - data.coins) .. " monedas."
	end
	data.coins -= design.price
	data.unlocked[designId] = true
	pushState(player)
	return true, "¡Desbloqueaste «" .. design.name .. "»!"
end

-- Unidades de cada color que pide la elección (las básicas no se gastan).
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
	if #data.storage >= Config.STORAGE_SIZE then
		return false, "Tu almacén está lleno: expón tus cuadros en los stands de la sala."
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
	tutorialEvent(player, data, 2, 1)
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
	for colorId, amount in pairs(paintCost(painting.colors)) do
		addPaint(data, colorId, amount)
	end
	refreshPlot(player)
	pushState(player)
end

CancelPainting.OnServerEvent:Connect(cancelPainting)

-- Primer stand comprado y sin cuadro.
local function freeStand(data)
	for i, tier in ipairs(data.stands) do
		if tier > 0 and Exhibition.roomOf(i) <= data.rooms and not slotEntry(data, i) then
			return i
		end
	end
	return nil
end

FinishPainting.OnServerInvoke = function(player)
	local data = DataService.get(player)
	local session = getSession(player)
	local painting = session.painting
	if not (data and painting) then
		return { ok = false, reason = "No estás pintando nada." }
	end
	local elapsed = os.clock() - painting.started
	if elapsed < painting.minTime then
		return { ok = false, reason = "¡Aún no está terminado!" }
	end
	local design = Designs.get(painting.designId)
	local madeBefore = data.made[design.id] or 0
	-- Las estrellas se calculan sobre el primer intento de entrega.
	painting.stars = painting.stars or Config.starsFor(design, data.upgrades, elapsed)
	local stars = painting.stars
	local value = Config.paintingValue(design, painting.colors, data.upgrades, madeBefore, stars)
	local encoded = Designs.encodeColors(painting.colors)
	local levelBefore = openLevel(data)
	local tierBefore = Config.masteryFor(madeBefore)

	session.painting = nil
	data.made[design.id] = madeBefore + 1
	questEvent(player, data, "pintar", 1)
	if stars >= 3 then
		questEvent(player, data, "estrellas", 1)
	end
	tutorialEvent(player, data, 3, 1)

	-- El cuadro no se vende aquí: va al almacén y lo expones en un stand.
	local market = math.floor(value * Config.GALLERY_BONUS)
	table.insert(data.storage, 1, { d = design.id, c = encoded, v = market, st = stars })
	local result = { ok = true, value = value, price = market, stars = stars, designId = design.id }
	result.freeStands = freeStand(data) ~= nil

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
	renderCarry(player, data)
	refreshPlot(player)
	pushState(player)
	return result
end

-- Stands y ampliaciones de la sala ---------------------------------------------------------------
buyStand = function(player, index)
	local data = DataService.get(player)
	local plot = plotOf[player]
	local def = Exhibition.Spots[index]
	if not (data and plot and def) or def.room > data.rooms or (data.stands[index] or 0) > 0 then
		return
	end
	local cost = Exhibition.standCost(Exhibition.countStands(data.stands))
	if data.coins < cost then
		notify(player, "Te faltan 💵" .. Config.formatNumber(cost - data.coins) .. " para este stand.", "error")
		return
	end
	data.coins -= cost
	data.stands[index] = 1
	notify(player, "🛠️ ¡Stand nuevo! Pulsa sobre él para exponer un cuadro.", "success")
	renderStands(plot, data, index)
	pushState(player)
end

buyRoom = function(player, index)
	local data = DataService.get(player)
	local plot = plotOf[player]
	local def = Exhibition.Rooms[index]
	if not (data and plot and def) or data.rooms ~= index - 1 then
		return
	end
	local owned = Exhibition.countStands(data.stands)
	if owned < def.needStands then
		notify(player, "Compra " .. def.needStands .. " stands para ampliar (tienes " .. owned .. ").", "error")
		return
	end
	if data.coins < def.cost then
		notify(player, "Te faltan 💵" .. Config.formatNumber(def.cost - data.coins) .. " para ampliar.", "error")
		return
	end
	data.coins -= def.cost
	data.rooms = index
	WorldBuilder.openRoom(plot, index, true)
	notify(player, "🏗️ ¡Galería ampliada! Nueva sala: " .. def.name, "gold")
	renderStands(plot, data)
	pushState(player)
end

-- Acciones del panel de un stand: exponer, cambiar precio, retirar y mejorar.
StandAction.OnServerInvoke = function(player, action, index, a, b)
	local data = DataService.get(player)
	local plot = plotOf[player]
	if not (data and plot) or type(action) ~= "string" or type(index) ~= "number" then
		return false, "Acción no válida."
	end
	index = math.floor(index)
	local def = Exhibition.Spots[index]
	local tier = def and data.stands[index] or 0
	if not def or tier == 0 or def.room > data.rooms then
		return false, "Ese stand no es tuyo."
	end
	local entry, entryIndex = slotEntry(data, index)
	local message
	local animate = nil
	if action == "exhibit" then
		if entry then
			return false, "Ese stand ya tiene un cuadro."
		end
		local storageIndex = math.floor(tonumber(a) or 1)
		local stored = data.storage[storageIndex]
		if not stored then
			return false, "No tienes ese cuadro."
		end
		local price = Exhibition.clampPrice(b, Exhibition.marketPrice(stored.v, tier))
		table.remove(data.storage, storageIndex)
		table.insert(data.gallery, { s = index, d = stored.d, c = stored.c, v = stored.v, p = price, st = stored.st })
		tutorialEvent(player, data, 4, 1)
		local design = Designs.get(stored.d)
		message = "🖼️ «"
			.. (design and design.name or "Tu cuadro")
			.. "» a la venta por 💵"
			.. Config.formatNumber(price)
			.. ". ¡Pronto vendrán visitantes!"
	elseif action == "price" then
		if not entry then
			return false, "Ese stand está vacío."
		end
		entry.p = Exhibition.clampPrice(a, Exhibition.marketPrice(entry.v, tier))
		message = "🏷️ Nuevo precio: 💵" .. Config.formatNumber(entry.p)
	elseif action == "takedown" then
		if not entry then
			return false, "Ese stand está vacío."
		end
		if #data.storage >= Config.STORAGE_SIZE then
			return false, "Tu almacén está lleno."
		end
		table.remove(data.gallery, entryIndex)
		table.insert(data.storage, 1, { d = entry.d, c = entry.c, v = entry.v, st = entry.st })
		message = "Retiraste el cuadro: ahora lo llevas a la espalda."
	elseif action == "upgrade" then
		if tier >= Exhibition.MAX_TIER then
			return false, "Este stand ya es de la mejor calidad."
		end
		local cost = Exhibition.upgradeCost(tier, def.room)
		if data.coins < cost then
			return false, "Te faltan 💵" .. Config.formatNumber(cost - data.coins) .. "."
		end
		data.coins -= cost
		data.stands[index] = tier + 1
		animate = index
		message = "✨ Stand mejorado: «" .. Exhibition.tierName(index, tier + 1) .. "»"
	else
		return false, "Acción no válida."
	end
	renderCarry(player, data)
	renderStands(plot, data, animate)
	pushState(player)
	return true, message
end

SkipTutorial.OnServerEvent:Connect(function(player)
	local data = DataService.get(player)
	if data and data.tutorial ~= 0 then
		data.tutorial = 0
		data.tutorialProgress = 0
		notify(player, "Tutorial omitido. ¡Suerte con tu galería!", "info")
		pushState(player)
	end
end)

-- Elige qué cuadro del almacén llevas (pasa al primer puesto).
SelectStored.OnServerEvent:Connect(function(player, index)
	local data = DataService.get(player)
	if not data or type(index) ~= "number" then
		return
	end
	index = math.floor(index)
	if index < 2 or index > #data.storage then
		return
	end
	local entry = table.remove(data.storage, index)
	table.insert(data.storage, 1, entry)
	renderCarry(player, data)
	pushState(player)
end)

-- Ventas a visitantes ---------------------------------------------------------------------------
VisitorService.getProfile = function(player)
	return DataService.get(player)
end

-- Cuadros a la venta: precio que pusiste y precio medio en su stand.
VisitorService.listings = function(player)
	local data = DataService.get(player)
	local list = {}
	if data then
		for _, entry in ipairs(data.gallery) do
			local tier = data.stands[entry.s] or 1
			list[entry.s] = {
				price = entry.p,
				market = Exhibition.marketPrice(entry.v, tier),
				tier = tier,
				room = Exhibition.roomOf(entry.s),
				d = entry.d,
				c = entry.c,
				st = entry.st,
			}
		end
	end
	return list
end

VisitorService.isTutorial = function(player)
	local data = DataService.get(player)
	return data ~= nil and data.tutorial == 5
end

VisitorService.hasCashier = function(player)
	local data = DataService.get(player)
	return data ~= nil and Config.hasCashier(data.upgrades)
end

-- Un visitante mira un cuadro y no se anima: te lo cuenta (de vez en cuando).
VisitorService.onPass = function(player, slot, ratio, buyerName)
	local data = DataService.get(player)
	local session = getSession(player)
	local entry = data and slotEntry(data, slot)
	local design = entry and Designs.get(entry.d)
	if not design or ratio < 1.25 or os.clock() - session.lastPass < 25 then
		return
	end
	session.lastPass = os.clock()
	notify(
		player,
		"😬 A " .. tostring(buyerName) .. " le pareció caro «" .. design.name .. "». Prueba a bajar el precio.",
		"info"
	)
end

VisitorService.onSale = function(player, slot, amount, buyerName, vip, how)
	local data = DataService.get(player)
	if not data or not player.Parent then
		return nil
	end
	local entry, index = slotEntry(data, slot)
	if not entry then
		return nil
	end
	table.remove(data.gallery, index)
	amount = math.max(1, math.floor(amount))
	earn(player, data, amount)
	data.sold += 1
	data.best = math.max(data.best, amount)
	questEvent(player, data, "vender", 1)
	if amount > Exhibition.marketPrice(entry.v, data.stands[slot] or 1) then
		questEvent(player, data, "caro", 1)
	end
	tutorialEvent(player, data, 5, 1)
	local design = Designs.get(entry.d)
	local name = design and design.name or "tu cuadro"
	local text
	if how == "cashier" then
		text = "🧑‍💼 Tu cajero vendió «" .. name .. "» a " .. tostring(buyerName)
	else
		text = (vip and "👑 " or "💵 ") .. tostring(buyerName) .. " compró «" .. name .. "»"
	end
	notify(player, text .. " por 💵" .. Config.formatNumber(amount), "sale")
	refreshPlot(player)
	pushState(player)
	return { d = entry.d, c = entry.c, st = entry.st }
end

-- Ofertas en la caja: el dueño acepta, rechaza o pide más.
local offers = {}
local offerCounter = 0

VisitorService.askOwner = function(player, info)
	offerCounter += 1
	local id = offerCounter
	local record = { player = player, answer = nil, final = info.final == true }
	offers[id] = record
	local cashier = VisitorService.hasCashier(player)
	local tutorial = VisitorService.isTutorial(player)
	local timeout = tutorial and 60 or (cashier and Exhibition.CASHIER_TIME or Exhibition.OFFER_TIME)
	Offer:FireClient(player, {
		id = id,
		buyer = info.buyer,
		userId = info.userId,
		vip = info.vip,
		designId = info.d,
		colors = info.c,
		stars = info.st,
		price = info.price,
		market = info.market,
		offer = info.offer,
		counter = Exhibition.counterPrice(info.offer, info.price),
		final = record.final,
		time = timeout,
		cashier = cashier,
	})
	local started = os.clock()
	while not record.answer and player.Parent and os.clock() - started < timeout do
		task.wait(0.1)
	end
	offers[id] = nil
	if player.Parent then
		OfferClosed:FireClient(player, id)
	end
	return record.answer or "timeout"
end

RespondOffer.OnServerEvent:Connect(function(player, id, action)
	local record = offers[id]
	if not record or record.player ~= player or record.answer then
		return
	end
	if action == "accept" or action == "reject" or (action == "counter" and not record.final) then
		record.answer = action
	end
end)

-- Mejoras, regalo diario y misiones ----------------------------------------------------------------
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
		elseif id == "cajero" then
			WorldBuilder.setCashier(plot, true)
		end
	end
	if id == "auto" then
		data.autoRoll = true
		renderAutoPrompt(plotOf[player], data)
	end
	pushState(player)
	return true, upgrade.name .. " subió a nivel " .. (level + 1) .. "!"
end

local function rareGift(minRarity)
	local gift
	for _ = 1, 200 do
		gift = Colors.roll(4, rng)
		if Colors.rarityOf(gift).index >= (minRarity or 3) then
			break
		end
	end
	return gift
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
	earn(player, data, amount)
	-- El séptimo día de racha regala un color Épico o mejor.
	local gift = rareGift(nextStreak >= 7 and 4 or 3)
	addPaint(data, gift.id, 1)
	refreshPlot(player)
	pushState(player)
	return true, amount, gift.id
end

ClaimQuest.OnServerInvoke = function(player, index)
	local data = DataService.get(player)
	if not data or type(index) ~= "number" then
		return false
	end
	ensureQuests(data)
	local quest = data.quests[index]
	if not quest or quest.claimed or quest.progress < quest.goal then
		return false
	end
	quest.claimed = true
	data.coins += quest.reward
	local result = { reward = quest.reward }
	local allDone = true
	for _, q in ipairs(data.quests) do
		if not q.claimed then
			allDone = false
		end
	end
	if allDone and not data.questBonus then
		data.questBonus = true
		local bonus = nil
		for _ = 1, 80 do
			bonus = Colors.roll(6, rng)
			if Colors.rarityOf(bonus).index >= 4 then
				break
			end
		end
		addPaint(data, bonus.id, 1)
		result.bonusColor = bonus.id
	end
	refreshPlot(player)
	pushState(player)
	return true, result
end

-- Mezclador: varios colores de una rareza dan uno de la rareza siguiente.
MixColors.OnServerInvoke = function(player, rarityId, picks)
	local data = DataService.get(player)
	local need = type(rarityId) == "string" and Colors.MixCost[rarityId]
	if not (data and need) or type(picks) ~= "table" then
		return false, "Mezcla no válida."
	end
	local total = 0
	for colorId, count in pairs(picks) do
		local entry = Colors.ById[colorId]
		if not entry or entry.rarity ~= rarityId or type(count) ~= "number" or count < 1 or count % 1 ~= 0 then
			return false, "Mezcla no válida."
		end
		if (data.paints[colorId] or 0) < count then
			return false, "No tienes suficiente «" .. entry.name .. "»."
		end
		total += count
	end
	if total ~= need then
		return false, "Pon " .. need .. " colores en el mezclador."
	end
	for colorId, count in pairs(picks) do
		data.paints[colorId] -= count
		if data.paints[colorId] <= 0 then
			data.paints[colorId] = nil
		end
	end
	local result = Colors.mix(rarityId, rng, data.discovered)
	local isNew = addPaint(data, result.id, 1)
	local rarity = Colors.rarityOf(result)
	if rarity.index >= 3 then
		questEvent(player, data, "raro", 1)
	end
	if isNew then
		earn(player, data, Config.discoveryBonus(rarity))
	end
	local plot = plotOf[player]
	if plot then
		plot.workshop.mixLiquid.Color = Colors.mainColor(result.id)
	end
	refreshPlot(player)
	pushState(player)
	return true, result.id, isNew
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

-- Jugadores -----------------------------------------------------------------------------------------
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
		renderCarry(player, DataService.get(player))
	end)

	local data = DataService.load(player)
	if not player.Parent then
		return
	end
	-- Los jugadores que ya habían vendido no necesitan el tutorial.
	if data.tutorial ~= 0 and data.sold > 0 then
		data.tutorial = 0
	end
	if not Config.hasAutoRoll(data.upgrades) then
		data.autoRoll = false
	end
	-- Partidas anteriores: la colección empieza con los colores que ya tenías.
	for colorId, count in pairs(data.paints) do
		if count > 0 then
			data.discovered[colorId] = true
		end
	end
	-- Cuadros expuestos en stands que ya no existen vuelven al almacén.
	local kept, seen = {}, {}
	for _, entry in ipairs(data.gallery) do
		local def = Exhibition.Spots[entry.s]
		if def and def.room <= data.rooms and (data.stands[entry.s] or 0) > 0 and not seen[entry.s] then
			seen[entry.s] = true
			entry.p = entry.p or entry.v
			table.insert(kept, entry)
		elseif #data.storage < Config.STORAGE_SIZE then
			table.insert(data.storage, { d = entry.d, c = entry.c, v = entry.v, st = entry.st })
		end
	end
	data.gallery = kept
	ensureQuests(data)

	local plot = createPlot(player, data)
	if not plot then
		notify(player, "El servidor está lleno, prueba en otro servidor.", "error")
	end
	if player.Character then
		setCharacterGroup(player.Character)
		task.defer(teleportHome, player)
	end
	pushState(player)
	notify(player, "¡Bienvenido a tu galería! 🎨", "success")
end

-- Si el servidor estaba lleno, el primero que esperaba recibe el terreno libre.
local function assignWaitingPlayers()
	for _, waiting in ipairs(Players:GetPlayers()) do
		local data = DataService.get(waiting)
		if data and not plotOf[waiting] then
			if not createPlot(waiting, data) then
				return
			end
			teleportHome(waiting)
			pushState(waiting)
			notify(waiting, "¡Tu galería está lista! 🎨", "success")
		end
	end
end

local function onPlayerRemoving(player)
	cancelPainting(player)
	releasePlot(player)
	DataService.release(player)
	sessions[player] = nil
	task.defer(assignWaitingPlayers)
end

-- Arranque -------------------------------------------------------------------------------------------
WorldBuilder.buildSpawn()
DataService.start()
VisitorService.start()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Tiradas automáticas (solo con la mejora Auto-Rolling).
task.spawn(function()
	while true do
		task.wait(0.2)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local data = DataService.get(player)
			local session = sessions[player]
			if data and session and data.autoRoll and Config.hasAutoRoll(data.upgrades) and plotOf[player] then
				if now >= session.nextAuto then
					session.nextAuto = now + Config.autoRollInterval(data.upgrades)
					doRoll(player, true)
				end
			end
		end
	end
end)

-- Refresca el contador del regalo diario y cambia las misiones al cambiar el día.
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			pushState(player)
		end
	end
end)
