-- Ilustraciones: desbloquear el dibujo de líneas, pintarlo zona a zona (el
-- pincel no se sale de las líneas), terminarlo y exponerlo.
SEED_DATA = {
	coins = 5000,
	paints = {},
	unlocked = { globo = true, sol = true, taza = true, gatito = true },
	made = { globo = 1, sol = 1, taza = 1, gatito = 1 },
	upgrades = {},
	tutorial = 0,
	sold = 3,
}
local T = dofile(SIM_DIR .. "/test.lua")
local R, check, player = T.R, T.check, T.player
local G = R.globals
local Enum = G.Enum
local S = R.services
local pg = player.PlayerGui
local Designs, Config = T.Designs, T.Config
local UIS = S.UserInputService
local D = dofile(SIM_DIR .. "/dump.lua")
local data = T.DataService.get(player)
local lot = R.workspace.Plots.Lot1

local function dumpGui(name, gui)
	D.write(SIM_DIR .. "/out_" .. name .. ".json", D.gui(gui, G.typeof))
end
local function buttonStarting(root, prefix)
	for _, d in ipairs(root:GetDescendants()) do
		if d.ClassName == "TextButton" and d.Text:sub(1, #prefix) == prefix then
			return d
		end
	end
end
local function click(root, prefix)
	local b = buttonStarting(root, prefix)
	check(b ~= nil, "button '" .. prefix .. "' found")
	T.fireClick(b)
	R.run(0.2)
end
local function named(root, name)
	return T.findAll(root, function(d)
		return d.Name == name and d.ClassName == "TextButton"
	end)[1]
end

local chica = Designs.get("chica")
print("== The illustration is a design")
check(chica ~= nil and chica.kind == "image", "illustration loaded")
check(#chica.shapes > 50 and #chica.areas == 7, #chica.shapes .. " zones in 7 colors")
check(Designs.levelName(chica.level) == "Ilustraciones", "own category")
check(Designs.isLevelOpen(chica.level, data.made), "open once level 1 is painted")
check(Designs.shapeAt(chica, 0.02, 0.02) ~= nil, "background zone in the corner")

print("== Unlock and start")
lot.Workshop.DrawPrompt.ProximityPrompt.Triggered:Fire(player)
R.run(0.3)
T.fireClick(named(pg.DesignPicker, "chica"))
R.run(0.3)
dumpGui("picker_ilu", pg.DesignPicker)
click(pg.DesignPicker, "Desbloquear")
check(data.unlocked.chica, "illustration unlocked")
click(pg.DesignPicker, "Empezar a pintar")
check(pg.ColorPicker.Window.Visible, "color picker open")
dumpGui("colors_ilu", pg.ColorPicker)
click(pg.ColorPicker, "Empezar a pintar")
R.run(0.5)
check(pg.Painter.Enabled, "painter open")
local canvasImage = T.findAll(pg.Painter, function(d)
	return d.ClassName == "ImageLabel" and d.Name == "Image"
end)[1]
check(canvasImage ~= nil, "drawing shown as an editable image")
local image = canvasImage.ImageContent.object
check(image.width == 512 and image.writes >= 1, "512x512 image written")
dumpGui("painter_ilu_start", pg.Painter)

print("== Paint zone by zone")
local catcher = T.findAll(pg.Painter, function(d)
	return d.Name == "PaintInput"
end)[1]
local function move(x, y)
	UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = R.v2(x * 512, y * 512) })
	R.step(1 / 30)
end
local function sweep(x0, y0, x1, y1)
	local r = Config.brushRadius(data.upgrades)
	catcher.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = R.v2(x0 * 512, y0 * 512) })
	local row, y = 0, y0
	while y <= y1 + r * 0.5 do
		local forward = row % 2 == 0
		local x = forward and x0 or x1
		while (forward and x <= x1) or (not forward and x >= x0) do
			move(x, math.min(y, 1))
			x = x + (forward and r * 1.1 or -r * 1.1)
		end
		row = row + 1
		y = y + r * 1.4
	end
	UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 }, false)
end
local function pixel(x, y)
	local o = (y * 512 + x) * 4
	local d = image.pixels.d
	return d[o] or 0, d[o + 1] or 0, d[o + 2] or 0
end
for index, area in ipairs(chica.areas) do
	T.fireClick(named(pg.Painter, "Paint_" .. area.id))
	R.run(0.2)
	if index == 2 then
		dumpGui("painter_ilu_focus", pg.Painter)
	end
	local x0, y0, x1, y1 = 1, 1, 0, 0
	for _, shape in ipairs(chica.shapes) do
		if shape.area == area.id then
			x0, y0 = math.min(x0, shape.x - shape.w / 2), math.min(y0, shape.y - shape.h / 2)
			x1, y1 = math.max(x1, shape.x + shape.w / 2), math.max(y1, shape.y + shape.h / 2)
		end
	end
	sweep(math.max(0, x0), math.max(0, y0), math.min(1, x1), math.min(1, y1))
	if area.id == "fondo" then
		-- El fondo está pintado y la cara (otra zona) sigue sin pintar.
		local r, g, b = pixel(10, 10)
		local fr, fg, fb = pixel(220, 210)
		check(r > 200 and g > 150 and b < 140, "background painted yellow (" .. r .. "," .. g .. "," .. b .. ")")
		check(not (fr > 200 and fg > 150 and fb < 140), "brush stays out of the face")
		dumpGui("painter_ilu_mid", pg.Painter)
	end
end
R.run(1.5)
local carry = buttonStarting(pg.Painter, "🖼️ Llevar")
check(carry ~= nil, "illustration completed")
dumpGui("painter_ilu_done", pg.Painter)
T.fireClick(carry)
R.run(0.5)
check(#data.storage == 1 and data.storage[1].d == "chica", "illustration stored")
check(data.storage[1].v > 300, "worth more than simple designs (" .. data.storage[1].v .. ")")

print("== Exhibit it")
local spot = lot.Gallery.Spots.Spot1
spot.StandPrompt.Triggered:Fire(player)
R.run(0.3)
click(pg.StandPanel, "🖼️ Exponer")
R.run(0.5)
local canvas = lot.Gallery.Stands.Stand1:FindFirstChild("Canvas", true)
check(canvas:GetAttribute("Design") == "chica", "illustration on the stand")
local worldImage = T.findAll(canvas, function(d)
	return d.ClassName == "ImageLabel" and d.Name == "Image"
end)[1]
check(worldImage ~= nil, "stand shows the illustration")
local live, freed = 0, 0
for _, img in ipairs(R.editableImages) do
	if img.destroyed then
		freed = freed + 1
	else
		live = live + 1
	end
end
check(freed > 0 and live <= 12, "replaced images are freed (" .. live .. " alive, " .. freed .. " freed)")
print("errors:", #R.errors, "warnings:", #R.warnings)
