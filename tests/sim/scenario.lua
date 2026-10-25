local T = dofile(SIM_DIR .. "/test.lua")
local R, check, player, plots = T.R, T.check, T.player, T.plots
local G = R.globals
local Enum = G.Enum
local S = R.services
local pg = player.PlayerGui

local D = dofile(SIM_DIR .. "/dump.lua")
local function dumpGui(name, gui)
	D.write(SIM_DIR .. "/out_" .. name .. ".json", D.gui(gui, G.typeof))
end
local function dumpWorld(name)
	local list = D.parts(R.workspace, G.typeof, R.isA)
	D.write(SIM_DIR .. "/out_" .. name .. ".json", "[" .. table.concat(list, ",") .. "]")
end
dumpGui("hud", pg.HUD)
print("== Mock sanity (must error)")
local function mustFail(f, what)
	local ok, err = pcall(f)
	check(not ok, "mock rejects " .. what .. " (" .. tostring(err):sub(1, 70) .. ")")
end
mustFail(function() G.Instance.new("Part").Foo = 1 end, "unknown property")
mustFail(function() G.Instance.new("Part").Shape = Enum.Font.Arial end, "wrong enum")
mustFail(function() G.Instance.new("TextLabel").MaxTextSize = 3 end, "TextLabel.MaxTextSize")
mustFail(function() G.Instance.new("Frame").Size = G.Vector3.new() end, "wrong type")
mustFail(function() return Enum.Font.NotAFont end, "missing enum item")
mustFail(function() G.Instance.new("Players") end, "creating service")

local UIS = S.UserInputService
local function key(code)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode[code], UserInputType = Enum.UserInputType.Keyboard }, false)
end
local studioGui = pg.Studio
local catcher = T.findAll(studioGui, function(d) return d.Name == "Input" and d.ClassName == "TextButton" end)[1]
check(catcher ~= nil, "canvas input catcher found")
local paletteFrame = T.findAll(studioGui, function(d) return d.Name == "Palette" and d.ClassName == "Frame" end)[1]

local function cellPos(i)
	local col = (i - 1) % 16
	local row = (i - 1) // 16
	return R.v2(col * 32 + 16, row * 32 + 16)
end
local function press(i)
	catcher.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = cellPos(i) })
end
local function release()
	UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 }, false)
end
local function selectColor(k)
	T.fireClick(paletteFrame:FindFirstChild(k))
end

local function paintModel(model, quality)
	local template = T.Templates.get(model:GetAttribute("TemplateId"))
	local order = {
		mode = model:GetAttribute("Mode"),
		swapFrom = model:GetAttribute("SwapFrom"),
		swapTo = model:GetAttribute("SwapTo"),
		theme = model:GetAttribute("Theme"),
	}
	local target = T.Scoring.targetString(order, template)
	if not target then
		-- tema / libre: build a nice canvas using theme colors per template region
		local keys = order.mode == "tema" and T.Config.ThemeById[order.theme].keys or "rgbym"
		local map, n = {}, 0
		local out = {}
		for i = 1, 256 do
			local k = template.flat:sub(i, i)
			if k == "k" then
				out[i] = "k"
			else
				if not map[k] then
					n = n + 1
					map[k] = keys:sub((n - 1) % #keys + 1, (n - 1) % #keys + 1)
				end
				out[i] = map[k]
			end
		end
		target = table.concat(out)
	end
	-- group cells per color
	local byColor = {}
	for i = 1, 256 do
		local k = target:sub(i, i)
		if k ~= "k" and math.random() <= quality then
			byColor[k] = byColor[k] or {}
			table.insert(byColor[k], i)
		end
	end
	key("B")
	for k, list in pairs(byColor) do
		selectColor(k)
		for _, i in ipairs(list) do
			press(i)
			release()
		end
	end
	return target
end

local function submit()
	local btn = T.buttonWithText(studioGui, "✅ Entregar obra") or T.buttonWithText(studioGui, "¿Entregar incompleta?")
	check(btn ~= nil, "submit button found")
	T.fireClick(btn)
	local again = T.buttonWithText(studioGui, "¿Entregar incompleta?")
	if again then
		T.fireClick(again)
	end
end

local function closeResults()
	R.run(4)
	local ok = T.buttonWithText(pg.Results, "¡Genial!")
	T.fireClick(ok)
	local lvl = T.buttonWithText(pg.Results, "¡A pintar!")
	if pg.Results.LevelUp.Visible then
		print("  (level up shown)")
		T.fireClick(lvl)
	end
end

print("== Serve orders")
local served = 0
local modesSeen = {}
for round = 1, 18 do
	R.run(1)
	local list = T.waiting()
	if #list == 0 then
		R.run(12)
		list = T.waiting()
	end
	local model = list[1]
	if model then
		model.Root.ProximityPrompt.Triggered:Fire(player)
		R.run(0.2)
		check(studioGui.Enabled, "studio opened for " .. model:GetAttribute("Mode") .. " " .. model:GetAttribute("TemplateId"))
		check(R.controlsEnabled == false, "controls disabled while painting")
		check(model:GetAttribute("Painting") == true, "server marks painting")
		modesSeen[model:GetAttribute("Mode")] = true
		if round == 2 then
			-- try tools: fill, undo, clear, eraser, drag
			key("F"); press(1); release(); key("Z"); key("X"); press(2); release()
			key("B"); press(17); UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = cellPos(40) }, false); release()
			T.fireClick(T.buttonWithText(studioGui, "🗑️ Limpiar"))
			-- close and reopen keeps draft
			T.fireClick(T.buttonWithText(studioGui, "✕"))
			check(not studioGui.Enabled and R.controlsEnabled, "studio closes with X")
			check(model:GetAttribute("Painting") == false, "painting flag cleared")
			model.Root.ProximityPrompt.Triggered:Fire(player)
			R.run(0.1)
		end
		local quality = (round % 5 == 0) and 0.7 or 1
		if round == 3 then
			paintModel(model, 0.6)
			dumpGui("studio", studioGui)
		end
		paintModel(model, quality)
		local coinsBefore = T.DataService.get(player).coins
		submit()
		R.run(0.1)
		check(not studioGui.Enabled, "studio closed after submit")
		check(pg.Results.Results.Visible, "results visible")
		check(T.DataService.get(player).coins > coinsBefore, "coins increased " .. coinsBefore .. " -> " .. T.DataService.get(player).coins)
		served = served + 1
		if round == 3 then
			R.run(3)
			dumpGui("results", pg.Results)
		end
		closeResults()
	end
	check(#R.errors == 0, "no errors after round " .. round)
end
local data = T.DataService.get(player)
print("  served", served, "level", data.level, "coins", data.coins, "sold", data.sold, "perfect", data.perfect)
local modeList = {}
for m in pairs(modesSeen) do table.insert(modeList, m) end
print("  modes seen: " .. table.concat(modeList, ","))
check(plots.Plot1.Gallery.Frame1.Canvas:GetAttribute("Cells") ~= "", "gallery frame shows painting")
check(#plots.Plot1.Gallery.Frame1.Canvas.ArtGui.Art.Pixels:GetChildren() > 0, "gallery rendered client-side")

print("== Shop")
data.coins = 50000000
local shopButton = T.buttonWithLabel(pg.HUD, "Mejoras")
T.fireClick(shopButton)
check(pg.Shop.Enabled, "shop open")
dumpGui("shop", pg.Shop)
R.run(0.5)
for _ = 1, 20 do
	for _, upgrade in ipairs(T.Config.Upgrades) do
		local btns = T.findAll(pg.Shop, function(d) return d.ClassName == "TextButton" and d.Text:sub(1, 4) == "💰" end)
		for _, b in ipairs(btns) do T.fireClick(b) end
	end
end
for _, upgrade in ipairs(T.Config.Upgrades) do
	check((data.upgrades[upgrade.id] or 0) == upgrade.max, upgrade.id .. " maxed")
end
check(#plots.Plot1.Decor:GetChildren() == 6, "6 decor levels built")
T.fireClick(T.buttonWithText(pg.Shop, "✕"))
check(not pg.Shop.Enabled, "shop closed")

print("== Brush sizes after upgrade")
R.run(15)
local m = T.waiting()[1]
if m then
	m.Root.ProximityPrompt.Triggered:Fire(player)
	R.run(0.1)
	T.fireClick(T.buttonWithText(studioGui, "3x3"))
	press(100); release()
	submit()
	closeResults()
end

print("== Daily reward")
local before = data.coins
T.fireClick(T.buttonWithLabel(pg.HUD, "🎁"))
check(data.coins > before, "daily claimed +" .. (data.coins - before))
before = data.coins
T.fireClick(T.buttonWithLabel(pg.HUD, "🎁"))
check(data.coins == before, "daily not claimable twice")
T.fireClick(T.buttonWithLabel(pg.HUD, "Mi galería"))
T.fireClick(T.buttonWithLabel(pg.HUD, "Ayuda"))

R.run(20)
dumpWorld("world")
dumpGui("hud2", pg.HUD)
print("== Customers expire")
R.run(400)
check(#R.errors == 0, "expire path without errors")

print("== Expire while painting")
local w = T.waiting()[1]
w.Root.ProximityPrompt.Triggered:Fire(player)
R.run(0.1)
check(studioGui.Enabled, "studio open")
R.run(600)
check(not studioGui.Enabled, "studio auto-closed when customer left")
check(R.controlsEnabled, "controls re-enabled")

print("== Leave & rejoin")
local coinsSaved = data.coins
player.Parent = nil
S.Players.PlayerRemoving:Fire(player)
R.run(2)
check(plots.Plot1:GetAttribute("OwnerUserId") == 0, "plot released")
check(#plots.Plot1.Customers:GetChildren() == 0, "customers cleared")
local stored = R.storeData["GaleriaPincelada_v1"]["player_101"]
check(stored and stored.coins == coinsSaved, "data saved")
local p2 = R.makePlayer(101, "Simon")
R.localPlayer = p2
p2.Parent = S.Players
S.Players.PlayerAdded:Fire(p2)
R.makeCharacter(p2)
R.run(2)
local d2 = T.DataService.get(p2)
check(d2 and d2.coins == coinsSaved and d2.level == data.level, "data restored on rejoin")
check(#plots.Plot1.Decor:GetChildren() == 6, "decor restored")
for _, f in ipairs(R.closeCallbacks) do R.task.spawn(f) end
R.run(3)

print("errors:", #R.errors, "warnings:", #R.warnings)
for _, w in ipairs(R.warnings) do print("warn:", w) end
local total = 0
for cls, n in pairs(R.counts) do total = total + n end
print("instances created:", total, "parts:", R.counts.Part, "frames:", R.counts.Frame)
