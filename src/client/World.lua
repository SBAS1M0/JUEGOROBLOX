-- Parte visual del mundo que se dibuja en el cliente: cuadros de los stands
-- (con su etiqueta de precio), avisos de los huecos libres, caballete del
-- taller y globos de diálogo de los visitantes.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Colors = require(Shared.Colors)
local Config = require(Shared.Config)
local Designs = require(Shared.Designs)
local Exhibition = require(Shared.Exhibition)

local UI = script.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local DesignArt = require(UI.DesignArt)

local World = {}

local C = Theme.Colors
local player = Players.LocalPlayer

-- Cuadros -------------------------------------------------------------------------------
local function setupCanvas(canvas)
	if canvas:FindFirstChild("ArtGui") then
		return
	end
	local gui = Theme.new("SurfaceGui", {
		Name = "ArtGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(300, 300),
		LightInfluence = 0.35,
		Brightness = 1.15,
		Parent = canvas,
	})
	local art = Theme.new("Frame", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(252, 248, 240),
		BorderSizePixel = 0,
		Parent = gui,
	})
	local placeholder = Theme.label({
		Name = "Placeholder",
		Size = UDim2.fromScale(0.84, 0.5),
		Position = UDim2.fromScale(0.08, 0.25),
		Text = "",
		TextColor3 = Color3.fromRGB(176, 180, 190),
		Font = Theme.Fonts.Medium,
		MaxTextSize = 34,
		Parent = art,
	})
	local stars = Theme.label({
		Name = "Stars",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(84, 28),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.25,
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.Gold,
		MaxTextSize = 22,
		ZIndex = 5,
		Parent = art,
	})
	Theme.round().Parent = stars
	-- Etiqueta de precio con el color de la banda (ganga, justo, caro...).
	local priceTag = Theme.label({
		Name = "PriceTag",
		Position = UDim2.new(0, 8, 1, -36),
		Size = UDim2.fromOffset(130, 28),
		BackgroundColor3 = C.Primary,
		BackgroundTransparency = 0,
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.White,
		MaxTextSize = 22,
		Visible = false,
		ZIndex = 5,
		Parent = art,
	})
	Theme.round().Parent = priceTag
	local glitter = nil
	local function refresh()
		local design = Designs.get(canvas:GetAttribute("Design") or "")
		local starCount = canvas:GetAttribute("Stars") or 0
		stars.Text = design and string.rep("★", starCount) or ""
		stars.Visible = stars.Text ~= ""
		local price = canvas:GetAttribute("Price") or 0
		local market = canvas:GetAttribute("Market") or 0
		priceTag.Visible = design ~= nil and price > 0
		if priceTag.Visible then
			priceTag.Text = "💵 " .. Config.formatNumber(price)
			priceTag.BackgroundColor3 = Exhibition.band(price / math.max(1, market)).color
		end
		local best = 0
		if design then
			placeholder.Visible = false
			local colors = Designs.decodeColors(canvas:GetAttribute("Colors"))
			for _, colorId in pairs(colors) do
				best = math.max(best, Colors.rarityOf(Colors.ById[colorId]).index)
			end
			DesignArt.render(art, design, {
				mode = "color",
				colors = colors,
				outlineThickness = 1.5,
			})
		else
			local old = art:FindFirstChild("Art")
			if old then
				old:Destroy()
			end
			placeholder.Visible = true
			placeholder.Text = canvas:GetAttribute("Locked") and "🔒" or "Espacio libre"
		end
		-- Los cuadros con colores legendarios o míticos brillan.
		if best >= 5 and not glitter then
			glitter = Theme.new("ParticleEmitter", {
				Name = "Glitter",
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(best >= 6 and Color3.fromRGB(255, 140, 220) or Color3.fromRGB(255, 214, 110)),
				Size = NumberSequence.new(0.35, 0),
				Lifetime = NumberRange.new(0.8, 1.4),
				Rate = best >= 6 and 6 or 3,
				Speed = NumberRange.new(0.3, 0.8),
				SpreadAngle = Vector2.new(60, 60),
				LightEmission = 0.6,
				Parent = canvas,
			})
		elseif best < 5 and glitter then
			glitter:Destroy()
			glitter = nil
		end
	end
	for _, attribute in ipairs({ "Design", "Colors", "Locked", "Stars", "Price", "Market" }) do
		canvas:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()
end

-- Visitantes -----------------------------------------------------------------------------
local function setupVisitor(model)
	local head = model:WaitForChild("Head", 10)
	if not head or head:FindFirstChild("VisitorBubble") then
		return
	end
	local billboard = Theme.new("BillboardGui", {
		Name = "VisitorBubble",
		Size = UDim2.fromOffset(240, 110),
		StudsOffset = Vector3.new(0, 3.2, 0),
		MaxDistance = 70,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = head,
	})
	local bubble = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(220, 54),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = billboard,
	}, { Theme.corner(14), Theme.stroke(model:GetAttribute("VIP") and C.Gold or C.Border, 1.5) })
	local reaction = Theme.label({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = "",
		MaxTextSize = 22,
		Parent = bubble,
	})
	local name = Theme.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(220, 26),
		Text = (model:GetAttribute("VIP") and "👑 " or "") .. tostring(model:GetAttribute("VisitorName") or ""),
		Font = Theme.Fonts.Heavy,
		TextColor3 = model:GetAttribute("VIP") and C.Gold or Color3.new(1, 1, 1),
		MaxTextSize = 22,
		Parent = billboard,
	})
	Theme.textStroke(C.Ink, 1.5, 0.2).Parent = name
	local function refresh()
		local text = model:GetAttribute("Reaction") or ""
		bubble.Visible = text ~= ""
		reaction.Text = text
		bubble.Size = UDim2.fromOffset(text == "🤔" and 60 or 220, string.find(text, "\n") and 64 or 46)
		if bubble.Visible then
			Theme.pop(bubble, 0.5)
		end
	end
	model:GetAttributeChangedSignal("Reaction"):Connect(refresh)
	refresh()
end

-- Hueco de la sala: cartel «＋ Stand» con su precio (solo lo ve el dueño).
local function setupSpot(anchor, plot)
	if anchor:FindFirstChild("SpotTag") then
		return
	end
	local billboard = Theme.new("BillboardGui", {
		Name = "SpotTag",
		Size = UDim2.fromOffset(170, 64),
		StudsOffset = Vector3.new(0, 0.5, 0),
		MaxDistance = 60,
		LightInfluence = 0,
		AlwaysOnTop = false,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = anchor,
	})
	local card = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(160, 56),
		BackgroundColor3 = C.Navy,
		BackgroundTransparency = 0.08,
		Parent = billboard,
	}, { Theme.corner(16), Theme.stroke(C.White, 2, 0.4) })
	local title = Theme.label({
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 26),
		Text = "＋ Stand",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		MaxTextSize = 22,
		Parent = card,
	})
	local cost = Theme.label({
		Position = UDim2.fromOffset(8, 30),
		Size = UDim2.new(1, -16, 0, 20),
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.Gold,
		MaxTextSize = 18,
		Parent = card,
	})
	local function refresh()
		local mine = plot:GetAttribute("OwnerUserId") == player.UserId
		local open = anchor:GetAttribute("Open") == true
		local owned = anchor:GetAttribute("Owned") == true
		billboard.Enabled = mine and open and not owned
		local price = anchor:GetAttribute("Cost") or 0
		title.Text = "＋ Stand"
		cost.Text = price > 0 and ("💵 " .. Config.formatNumber(price)) or "¡Gratis!"
	end
	for _, attribute in ipairs({ "Open", "Owned", "Cost" }) do
		anchor:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	refresh()
end

-- Avisos (taller y sala) solo para el dueño del terreno.
local function setPromptDistance(plot, prompt)
	local mine = plot:GetAttribute("OwnerUserId") == player.UserId
	local inGallery = prompt:IsDescendantOf(plot:FindFirstChild("Gallery") or plot)
	prompt.MaxActivationDistance = mine and (inGallery and 10 or 12) or 0
end

local function updatePrompts(plot)
	for _, folderName in ipairs({ "Workshop", "Gallery" }) do
		local folder = plot:FindFirstChild(folderName)
		if folder then
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("ProximityPrompt") then
					setPromptDistance(plot, descendant)
				end
			end
		end
	end
end

local function watchPlot(plot)
	local gallery = plot:WaitForChild("Gallery", 10)
	if gallery then
		local function check(descendant)
			if descendant.Name == "Canvas" and descendant:IsA("BasePart") then
				setupCanvas(descendant)
			elseif descendant:IsA("ProximityPrompt") then
				setPromptDistance(plot, descendant)
			elseif
				descendant:IsA("BasePart")
				and descendant:GetAttribute("Index")
				and descendant.Parent.Name == "Spots"
			then
				setupSpot(descendant, plot)
			end
		end
		for _, descendant in ipairs(gallery:GetDescendants()) do
			task.spawn(check, descendant)
		end
		gallery.DescendantAdded:Connect(function(descendant)
			task.defer(check, descendant)
		end)
	end
	local workshop = plot:WaitForChild("Workshop", 10)
	local easel = workshop and workshop:WaitForChild("Easel", 10)
	local easelCanvas = easel and easel:WaitForChild("Canvas", 10)
	if easelCanvas then
		setupCanvas(easelCanvas)
	end
	local visitors = plot:WaitForChild("Visitors", 10)
	if visitors then
		for _, model in ipairs(visitors:GetChildren()) do
			task.spawn(setupVisitor, model)
		end
		visitors.ChildAdded:Connect(function(model)
			task.spawn(setupVisitor, model)
		end)
		-- El cuadro que se lleva el visitante que lo compró.
		visitors.DescendantAdded:Connect(function(descendant)
			if descendant.Name == "Canvas" and descendant:IsA("BasePart") then
				task.defer(setupCanvas, descendant)
			end
		end)
	end
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		updatePrompts(plot)
	end)
	updatePrompts(plot)
end

-- El cuadro que llevas a la espalda.
local function watchCharacter(character)
	local function check(child)
		if child.Name == "CarriedPainting" then
			local canvas = child:WaitForChild("Canvas", 5)
			if canvas then
				setupCanvas(canvas)
			end
		end
	end
	for _, child in ipairs(character:GetChildren()) do
		task.spawn(check, child)
	end
	character.ChildAdded:Connect(function(child)
		task.spawn(check, child)
	end)
end

function World.start()
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
	local plots = Workspace:WaitForChild("Plots")
	for _, plot in ipairs(plots:GetChildren()) do
		task.spawn(watchPlot, plot)
	end
	plots.ChildAdded:Connect(function(plot)
		task.spawn(watchPlot, plot)
	end)
end

return World
