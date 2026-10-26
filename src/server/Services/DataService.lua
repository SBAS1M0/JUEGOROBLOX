-- Guarda y carga el progreso de cada jugador con DataStoreService.
-- Si los DataStores no están disponibles (por ejemplo en Studio sin publicar)
-- el juego sigue funcionando, solo que sin guardar.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Exhibition = require(Shared.Exhibition)

local DataService = {}

local STORE_NAME = "GaleriaPincelada_v2"
local MAX_RETRIES = 4

local store = nil
local profiles = {}
local loaded = {}

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Galería] DataStores no disponibles, el progreso no se guardará: " .. tostring(result))
	end
end

local function defaultStands()
	local stands = {}
	for i = 1, Exhibition.SPOT_COUNT do
		stands[i] = i <= Exhibition.FREE_STANDS and 1 or 0
	end
	return stands
end

local function defaultData()
	return {
		coins = Config.START_COINS,
		paints = {}, -- colorId -> cantidad
		unlocked = { globo = true }, -- diseños comprados
		made = {}, -- diseñoId -> veces pintado
		upgrades = {},
		gallery = {}, -- { s = stand, d = diseño, c = colores, v = valor, p = precio, st = estrellas }
		storage = {}, -- cuadros terminados sin exponer (el primero es el que llevas)
		stands = defaultStands(), -- calidad del stand de cada hueco (0 = sin comprar)
		rooms = 1, -- salas abiertas
		best = 0, -- mejor venta
		autoRoll = false,
		lastRoll = "",
		rolls = 0,
		pity = 0, -- tiradas seguidas sin nada Raro o mejor
		discovered = {}, -- colorId -> true (colección)
		quests = {},
		questDay = 0,
		questBonus = false,
		tutorial = 1,
		tutorialProgress = 0,
		sold = 0,
		earned = 0,
		lastDaily = 0,
		dailyStreak = 0,
	}
end

-- Partidas de la versión con marcos fijos y la mejora «Más paredes»: cada
-- marco que tenías pasa a ser un stand de galería con su cuadro expuesto.
local function migrate(data)
	if type(data) ~= "table" or data.stands ~= nil then
		return data
	end
	local upgrades = type(data.upgrades) == "table" and data.upgrades or {}
	local frames = math.clamp(3 + (tonumber(upgrades.paredes) or 0), 1, 8)
	upgrades.paredes = nil
	local stands = {}
	for i = 1, Exhibition.SPOT_COUNT do
		stands[i] = i <= frames and 2 or 0
	end
	data.stands = stands
	data.rooms = 1
	if type(data.gallery) == "table" then
		local kept = {}
		for _, entry in ipairs(data.gallery) do
			if type(entry) == "table" and #kept < frames then
				entry.s = #kept + 1
				entry.p = entry.v
				table.insert(kept, entry)
			end
		end
		data.gallery = kept
	end
	return data
end

-- Rellena campos que falten (por ejemplo tras una actualización del juego).
local function reconcile(data)
	local template = defaultData()
	data = migrate(data)
	if type(data) ~= "table" then
		return template
	end
	for key, value in pairs(template) do
		if type(data[key]) ~= type(value) then
			data[key] = value
		end
	end
	for id in pairs(data.upgrades) do
		if not Config.UpgradeById[id] then
			data.upgrades[id] = nil
		end
	end
	for i = 1, Exhibition.SPOT_COUNT do
		if type(data.stands[i]) ~= "number" then
			data.stands[i] = 0
		end
		data.stands[i] = math.clamp(math.floor(data.stands[i]), 0, Exhibition.MAX_TIER)
	end
	data.rooms = math.clamp(math.floor(data.rooms), 1, #Exhibition.Rooms)
	return data
end

-- Errores que no se arreglan reintentando (Studio sin acceso a las APIs).
local function isPermanentError(message)
	message = tostring(message)
	return string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(message, "publish", 1, true) ~= nil
end

local function disableStore(reason)
	if store then
		store = nil
		warn("[Galería] DataStores no disponibles, el progreso no se guardará: " .. tostring(reason))
	end
end

local function withRetries(callback)
	local lastError
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastError = result
		if isPermanentError(result) then
			disableStore(result)
			break
		end
		task.wait(attempt * 1.5)
	end
	return false, lastError
end

function DataService.load(player)
	local data
	local canSave = store ~= nil
	local currentStore = store
	if currentStore then
		local ok, result = withRetries(function()
			return currentStore:GetAsync("player_" .. player.UserId)
		end)
		if ok then
			data = result
		else
			-- No guardamos encima de datos que no pudimos leer.
			canSave = false
			if store then
				warn("[Galería] No se pudo cargar a " .. player.Name .. ": " .. tostring(result))
			end
		end
	end
	data = reconcile(data)
	if player.Parent then
		profiles[player] = data
		loaded[player] = canSave
	end
	return data
end

function DataService.get(player)
	return profiles[player]
end

function DataService.save(player)
	local data = profiles[player]
	local currentStore = store
	if not (currentStore and data and loaded[player]) then
		return
	end
	local ok, result = withRetries(function()
		return currentStore:UpdateAsync("player_" .. player.UserId, function()
			return data
		end)
	end)
	if not ok then
		warn("[Galería] No se pudo guardar a " .. player.Name .. ": " .. tostring(result))
	end
end

function DataService.release(player)
	DataService.save(player)
	profiles[player] = nil
	loaded[player] = nil
end

function DataService.start()
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(DataService.save, player)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				DataService.save(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService
