-- Construye todo el mundo por código: plaza, fuente, árboles y las galerías.
-- Así el juego funciona sin modelos externos ni assets que puedan fallar.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local WorldBuilder = {}

local PLOT_RADIUS = 120
local PLAZA_RADIUS = 58

local WALL_COLORS = {
	Color3.fromRGB(255, 196, 214),
	Color3.fromRGB(184, 236, 214),
	Color3.fromRGB(212, 196, 255),
	Color3.fromRGB(255, 214, 176),
	Color3.fromRGB(178, 220, 255),
	Color3.fromRGB(255, 236, 160),
}
local ACCENT_COLORS = {
	Color3.fromRGB(236, 72, 128),
	Color3.fromRGB(30, 170, 120),
	Color3.fromRGB(124, 92, 255),
	Color3.fromRGB(255, 120, 40),
	Color3.fromRGB(40, 130, 230),
	Color3.fromRGB(230, 170, 20),
}
local RAINBOW = {
	Color3.fromRGB(255, 90, 110),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(255, 225, 80),
	Color3.fromRGB(110, 220, 120),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(180, 120, 255),
}

local WOOD = Color3.fromRGB(196, 140, 96)
local DARK_WOOD = Color3.fromRGB(120, 78, 52)
local CREAM = Color3.fromRGB(255, 248, 236)
local GOLD = Color3.fromRGB(240, 190, 70)

-- Crea una pieza anclada con propiedades por defecto bonitas.
local function part(props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		if key ~= "Class" and key ~= "Parent" then
			p[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function cylinderUp(cf)
	return cf * CFrame.Angles(0, 0, math.rad(90))
end

local function addLight(parent, class, props)
	local light = Instance.new(class)
	for key, value in pairs(props) do
		light[key] = value
	end
	light.Parent = parent
	return light
end

local function surfaceText(parentPart, face, text, props)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = props.pps or 40
	gui.LightInfluence = props.lightInfluence or 0
	gui.Parent = parentPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = props.font or Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = props.color or Color3.new(1, 1, 1)
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	if props.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.stroke
		stroke.Thickness = props.strokeThickness or 3
		stroke.Parent = label
	end
	return label
end

-- Ambiente -----------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 14.6
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(105, 95, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 165)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(214, 190, 235)
	atmosphere.Decay = Color3.fromRGB(150, 120, 190)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.06
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 248, 242)
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.8
	rays.Parent = Lighting
end

-- Elementos decorativos -------------------------------------------------------
local function buildTree(parent, cf, scale, rng)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local trunkHeight = 9 * scale
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkHeight, 1.6 * scale, 1.6 * scale),
		CFrame = cylinderUp(cf * CFrame.new(0, trunkHeight / 2, 0)),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local leafColors = {
		Color3.fromRGB(110, 200, 110),
		Color3.fromRGB(90, 180, 100),
		Color3.fromRGB(255, 170, 200),
		Color3.fromRGB(130, 210, 120),
	}
	local leafColor = leafColors[rng:NextInteger(1, #leafColors)]
	for i = 1, 4 do
		local size = (6 + rng:NextNumber() * 3) * scale
		local offset = Vector3.new(rng:NextNumber(-2, 2), trunkHeight + rng:NextNumber(-1, 3), rng:NextNumber(-2, 2))
			* scale
		if i == 1 then
			offset = Vector3.new(0, trunkHeight + 1.5 * scale, 0)
		end
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			CFrame = cf * CFrame.new(offset),
			Color = leafColor:Lerp(Color3.new(1, 1, 1), rng:NextNumber() * 0.12),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = model,
		})
	end
	model.Parent = parent
end

local function buildLampPost(parent, cf)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(12, 0.7, 0.7),
		CFrame = cylinderUp(cf * CFrame.new(0, 6, 0)),
		Color = Color3.fromRGB(60, 50, 80),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 2, 2),
		CFrame = cylinderUp(cf * CFrame.new(0, 0.3, 0)),
		Color = Color3.fromRGB(60, 50, 80),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local bulb = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = cf * CFrame.new(0, 12.6, 0),
		Color = Color3.fromRGB(255, 226, 170),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	addLight(
		bulb,
		"PointLight",
		{ Range = 18, Brightness = 1.3, Color = Color3.fromRGB(255, 214, 160), Shadows = false }
	)
	model.Parent = parent
end

local function buildBench(parent, cf)
	local model = Instance.new("Model")
	model.Name = "Bench"
	part({
		Size = Vector3.new(6, 0.4, 2),
		CFrame = cf * CFrame.new(0, 1.8, 0),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	part({
		Size = Vector3.new(6, 1.6, 0.3),
		CFrame = cf * CFrame.new(0, 3, 0.9),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	for _, x in ipairs({ -2.5, 2.5 }) do
		part({
			Size = Vector3.new(0.4, 1.6, 1.8),
			CFrame = cf * CFrame.new(x, 0.8, 0),
			Color = Color3.fromRGB(60, 50, 80),
			Material = Enum.Material.Metal,
			Parent = model,
		})
	end
	model.Parent = parent
end

local function buildFlowerBed(parent, cf, width, rng)
	part({
		Size = Vector3.new(width, 0.8, 3),
		CFrame = cf * CFrame.new(0, 0.4, 0),
		Color = Color3.fromRGB(110, 76, 56),
		Material = Enum.Material.Ground,
		Parent = parent,
	})
	local count = math.floor(width / 1.4)
	for i = 1, count do
		local x = -width / 2 + (i - 0.5) * (width / count)
		local z = rng:NextNumber(-0.8, 0.8)
		part({
			Size = Vector3.new(0.2, 1.2, 0.2),
			CFrame = cf * CFrame.new(x, 1.2, z),
			Color = Color3.fromRGB(80, 170, 80),
			CanCollide = false,
			Parent = parent,
		})
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = cf * CFrame.new(x, 1.9, z),
			Color = RAINBOW[rng:NextInteger(1, #RAINBOW)],
			CanCollide = false,
			Parent = parent,
		})
	end
end

local function buildPlant(parent, cf, scale)
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4 * scale, 2.4 * scale, 2.4 * scale),
		CFrame = cylinderUp(cf * CFrame.new(0, 1.2 * scale, 0)),
		Color = Color3.fromRGB(220, 120, 90),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	for i = 1, 3 do
		local angle = i * 2.1
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 2.6, 2.6) * scale,
			CFrame = cf
				* CFrame.new(math.cos(angle) * 0.6 * scale, (3 + i * 0.8) * scale, math.sin(angle) * 0.6 * scale),
			Color = Color3.fromRGB(80 + i * 15, 180 + i * 10, 100),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = parent,
		})
	end
end

local function buildFountain(parent)
	local model = Instance.new("Model")
	model.Name = "Fountain"
	local base = CFrame.new(0, 0, 0)
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 26, 26),
		CFrame = cylinderUp(base * CFrame.new(0, 1.2, 0)),
		Color = CREAM,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 23, 23),
		CFrame = cylinderUp(base * CFrame.new(0, 2.3, 0)),
		Color = Color3.fromRGB(110, 200, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CanCollide = false,
		Parent = model,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 3, 3),
		CFrame = cylinderUp(base * CFrame.new(0, 5, 0)),
		Color = CREAM,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 11, 11),
		CFrame = cylinderUp(base * CFrame.new(0, 9, 0)),
		Color = CREAM,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 9.6, 9.6),
		CFrame = cylinderUp(base * CFrame.new(0, 9.5, 0)),
		Color = Color3.fromRGB(110, 200, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CanCollide = false,
		Parent = model,
	})

	-- Escultura de pincel gigante sobre la fuente.
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(7, 1.2, 1.2),
		CFrame = cylinderUp(base * CFrame.new(0, 13, 0)),
		Color = Color3.fromRGB(236, 72, 128),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 1.5, 1.5),
		CFrame = cylinderUp(base * CFrame.new(0, 16.8, 0)),
		Color = GOLD,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local tip = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		CFrame = base * CFrame.new(0, 18.2, 0),
		Color = Color3.fromRGB(124, 92, 255),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	addLight(tip, "PointLight", { Range = 22, Brightness = 1.5, Color = Color3.fromRGB(190, 160, 255) })

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Rate = 12
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 220)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 160)),
	})
	sparkles.Parent = tip
	model.Parent = parent
end

-- Marcos de la galería ---------------------------------------------------------
local function buildFrame(parent, cf, name)
	local frame = Instance.new("Model")
	frame.Name = name
	part({
		Size = Vector3.new(7.4, 7.4, 0.5),
		CFrame = cf,
		Color = GOLD,
		Material = Enum.Material.Metal,
		Reflectance = 0.05,
		Parent = frame,
	})
	local canvas = part({
		Name = "Canvas",
		Size = Vector3.new(6.2, 6.2, 0.2),
		CFrame = cf * CFrame.new(0, 0, -0.3),
		Color = CREAM,
		Parent = frame,
	})
	canvas:SetAttribute("Cells", "")
	local plaque = part({
		Name = "Plaque",
		Size = Vector3.new(3.6, 0.9, 0.2),
		CFrame = cf * CFrame.new(0, -4.3, -0.1),
		Color = Color3.fromRGB(50, 40, 70),
		Parent = frame,
	})
	local plaqueLabel = surfaceText(plaque, Enum.NormalId.Front, "", { pps = 50, color = GOLD })
	plaqueLabel.Name = "PlaqueText"
	local lamp = part({
		Size = Vector3.new(2.4, 0.4, 0.6),
		CFrame = cf * CFrame.new(0, 4.4, -0.8),
		Color = Color3.fromRGB(50, 40, 70),
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = frame,
	})
	addLight(lamp, "SpotLight", {
		Face = Enum.NormalId.Bottom,
		Angle = 70,
		Range = 10,
		Brightness = 2.2,
		Color = Color3.fromRGB(255, 236, 210),
	})
	frame.Parent = parent
	return canvas, plaqueLabel
end

local function buildEasel(parent, cf)
	local model = Instance.new("Model")
	model.Name = "Easel"
	for _, x in ipairs({ -1.8, 1.8 }) do
		part({
			Size = Vector3.new(0.4, 10, 0.4),
			CFrame = cf * CFrame.new(x, 5, 0) * CFrame.Angles(math.rad(-8), 0, math.rad(x > 0 and 8 or -8)),
			Color = WOOD,
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	part({
		Size = Vector3.new(0.4, 9, 0.4),
		CFrame = cf * CFrame.new(0, 4.5, 1.4) * CFrame.Angles(math.rad(14), 0, 0),
		Color = WOOD,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	part({
		Size = Vector3.new(6, 0.4, 0.9),
		CFrame = cf * CFrame.new(0, 3.9, -0.5),
		Color = WOOD,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local canvas = part({
		Name = "Canvas",
		Size = Vector3.new(5.6, 5.6, 0.25),
		CFrame = cf * CFrame.new(0, 6.95, -0.35) * CFrame.Angles(math.rad(-8), 0, 0),
		Color = CREAM,
		Parent = model,
	})
	canvas:SetAttribute("Cells", "")
	-- Paleta de pintor apoyada.
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 2.6, 2.6),
		CFrame = cf * CFrame.new(2.6, 4.2, -0.6) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(230, 190, 140),
		Parent = model,
	})
	for i, color in ipairs(RAINBOW) do
		local angle = i * 0.9
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.45, 0.45, 0.45),
			CFrame = cf * CFrame.new(2.6 + math.cos(angle) * 0.8, 4.2 + math.sin(angle) * 0.8, -0.75),
			Color = color,
			CanCollide = false,
			Parent = model,
		})
	end
	model.Parent = parent
	return canvas
end

-- Decoraciones que aparecen al subir la mejora "Decoración".
local DECOR_BUILDERS = {
	function(folder, L)
		buildPlant(folder, L(-7.5, 0, -21.5), 1.1)
		buildPlant(folder, L(7.5, 0, -21.5), 1.1)
	end,
	function(folder, L)
		part({
			Size = Vector3.new(5, 0.12, 22),
			CFrame = L(0, 1.06, -8),
			Color = Color3.fromRGB(200, 40, 70),
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = folder,
		})
		for _, x in ipairs({ -2.6, 2.6 }) do
			part({
				Size = Vector3.new(0.25, 0.14, 22),
				CFrame = L(x, 1.07, -8),
				Color = GOLD,
				Material = Enum.Material.Fabric,
				CanCollide = false,
				Parent = folder,
			})
		end
	end,
	function(folder, L)
		part({
			Size = Vector3.new(3, 3, 3),
			CFrame = L(-17, 2.5, -12),
			Color = CREAM,
			Material = Enum.Material.Marble,
			Parent = folder,
		})
		local shapes = { Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Ball }
		for i, shape in ipairs(shapes) do
			local s = 2.4 - i * 0.4
			part({
				Shape = shape,
				Size = Vector3.new(s, s, s),
				CFrame = L(-17, 3.5 + i * 1.7, -12) * CFrame.Angles(i, i * 0.7, 0),
				Color = RAINBOW[i * 2],
				Material = Enum.Material.Glass,
				Transparency = 0.15,
				CanCollide = false,
				Parent = folder,
			})
		end
	end,
	function(folder, L)
		for i = 0, 22 do
			local x = -22 + i * 2
			local bulb = part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.7, 0.7, 0.7),
				CFrame = L(x, 11.9 - math.sin(i * 0.55) ^ 2 * 0.6, -23.4),
				Color = RAINBOW[i % #RAINBOW + 1],
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
			if i % 4 == 0 then
				addLight(bulb, "PointLight", { Range = 8, Brightness = 0.8, Color = bulb.Color })
			end
		end
	end,
	function(folder, L)
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 5, 5),
			CFrame = cylinderUp(L(0, 16.5, 9)),
			Color = GOLD,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = folder,
		})
		part({
			Size = Vector3.new(0.2, 2.5, 0.2),
			CFrame = L(0, 17.9, 9),
			Color = GOLD,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = folder,
		})
		for i = 1, 8 do
			local angle = i / 8 * math.pi * 2
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.8, 0.8, 0.8),
				CFrame = L(math.cos(angle) * 2.5, 16.1, 9 + math.sin(angle) * 2.5),
				Color = Color3.fromRGB(220, 240, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
		end
		local core = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = L(0, 15.6, 9),
			Color = Color3.fromRGB(200, 230, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.2,
			CanCollide = false,
			Parent = folder,
		})
		addLight(core, "PointLight", { Range = 20, Brightness = 1.2, Color = Color3.fromRGB(230, 240, 255) })
	end,
	function(folder, L)
		local index = 0
		for step = 0, 16 do
			local angle = math.pi * step / 16
			index += 1
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.4, 1.4, 1.4),
				CFrame = L(math.cos(angle) * 6.2, 7 + math.sin(angle) * 5.6, -19.9),
				Color = RAINBOW[index % #RAINBOW + 1],
				Material = Enum.Material.SmoothPlastic,
				Reflectance = 0.15,
				CanCollide = false,
				Parent = folder,
			})
		end
		for _, x in ipairs({ -6.2, 6.2 }) do
			for y = 1.7, 6.5, 1.3 do
				index += 1
				part({
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.4, 1.4, 1.4),
					CFrame = L(x, y, -19.9),
					Color = RAINBOW[index % #RAINBOW + 1],
					Reflectance = 0.15,
					CanCollide = false,
					Parent = folder,
				})
			end
		end
	end,
}
WorldBuilder.DECOR_LEVELS = #DECOR_BUILDERS

-- Galería de un jugador -----------------------------------------------------------
local function buildPlot(parent, index, plotCF, rng)
	local wallColor = WALL_COLORS[index]
	local accent = ACCENT_COLORS[index]
	local function L(x, y, z)
		return plotCF * CFrame.new(x, y, z)
	end

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("Index", index)
	model:SetAttribute("OwnerUserId", 0)

	local shop = Instance.new("Model")
	shop.Name = "Shop"
	shop.Parent = model

	-- Suelo, alfombra y camino hasta la plaza.
	part({
		Name = "Floor",
		Size = Vector3.new(46, 1, 38),
		CFrame = L(0, 0.5, 0),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
		Parent = shop,
	})
	part({
		Size = Vector3.new(18, 0.1, 11),
		CFrame = L(0, 1.05, -9),
		Color = accent:Lerp(Color3.new(1, 1, 1), 0.55),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = shop,
	})
	part({
		Size = Vector3.new(16.6, 0.12, 9.6),
		CFrame = L(0, 1.06, -9),
		Color = accent:Lerp(Color3.new(1, 1, 1), 0.25),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = shop,
	})
	local pathLength = PLOT_RADIUS - PLAZA_RADIUS - 19
	part({
		Size = Vector3.new(10, 0.4, pathLength),
		CFrame = L(0, 0.2, -19 - pathLength / 2),
		Color = Color3.fromRGB(230, 214, 190),
		Material = Enum.Material.Cobblestone,
		Parent = shop,
	})
	part({
		Size = Vector3.new(8, 0.15, 3),
		CFrame = L(0, 1.07, -16.6),
		Color = accent,
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = shop,
	})

	-- Paredes.
	part({ Size = Vector3.new(46, 18, 1), CFrame = L(0, 10, 18.5), Color = wallColor, Parent = shop })
	part({ Size = Vector3.new(1, 18, 38), CFrame = L(-22.5, 10, 0), Color = wallColor, Parent = shop })
	part({ Size = Vector3.new(1, 18, 38), CFrame = L(22.5, 10, 0), Color = wallColor, Parent = shop })
	for _, side in ipairs({ -1, 1 }) do
		local cx = side * 14
		part({ Size = Vector3.new(18, 3, 1), CFrame = L(cx, 2.5, -18.5), Color = wallColor, Parent = shop })
		part({ Size = Vector3.new(18, 6, 1), CFrame = L(cx, 16, -18.5), Color = wallColor, Parent = shop })
		part({
			Size = Vector3.new(18, 9, 0.3),
			CFrame = L(cx, 8.5, -18.5),
			Color = Color3.fromRGB(200, 235, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.65,
			Parent = shop,
		})
		part({ Size = Vector3.new(0.4, 9, 0.6), CFrame = L(cx, 8.5, -18.5), Color = CREAM, Parent = shop })
		part({ Size = Vector3.new(18, 0.4, 0.6), CFrame = L(cx, 8.5, -18.5), Color = CREAM, Parent = shop })
	end
	part({ Size = Vector3.new(10, 6, 1), CFrame = L(0, 16, -18.5), Color = wallColor, Parent = shop })
	-- Molduras.
	for _, z in ipairs({ -18.5, 18.5 }) do
		part({ Size = Vector3.new(46.4, 0.8, 1.4), CFrame = L(0, 19, z), Color = CREAM, Parent = shop })
		part({ Size = Vector3.new(46.4, 0.6, 1.3), CFrame = L(0, 1.3, z), Color = CREAM, Parent = shop })
	end
	for _, x in ipairs({ -22.5, 22.5 }) do
		part({ Size = Vector3.new(1.4, 0.8, 38), CFrame = L(x, 19, 0), Color = CREAM, Parent = shop })
	end
	for _, x in ipairs({ -5.4, 5.4, -22.8, 22.8 }) do
		part({ Size = Vector3.new(1, 18, 1.4), CFrame = L(x, 10, -18.6), Color = CREAM, Parent = shop })
	end

	-- Techo y letrero.
	part({ Size = Vector3.new(48, 1.2, 40), CFrame = L(0, 19.9, 0), Color = Color3.fromRGB(70, 60, 90), Parent = shop })
	part({
		Size = Vector3.new(26, 5.4, 0.8),
		CFrame = L(0, 23.2, -18.7),
		Color = Color3.fromRGB(50, 40, 70),
		Parent = shop,
	})
	local signPart = part({
		Name = "Sign",
		Size = Vector3.new(24.8, 4.4, 0.3),
		CFrame = L(0, 23.2, -19.2),
		Color = Color3.fromRGB(60, 48, 84),
		Parent = shop,
	})
	local signLabel = surfaceText(signPart, Enum.NormalId.Front, "Galería libre", {
		pps = 30,
		color = Color3.fromRGB(255, 244, 220),
		stroke = accent,
		strokeThickness = 4,
	})
	signLabel.Name = "SignText"
	for _, data in ipairs({
		{ Vector3.new(26, 0.35, 0.35), CFrame.new(0, 2.85, 0) },
		{ Vector3.new(26, 0.35, 0.35), CFrame.new(0, -2.85, 0) },
		{ Vector3.new(0.35, 6, 0.35), CFrame.new(13, 0, 0) },
		{ Vector3.new(0.35, 6, 0.35), CFrame.new(-13, 0, 0) },
	}) do
		local neon = part({
			Size = data[1],
			CFrame = L(0, 23.2, -19.2) * data[2],
			Color = accent,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = shop,
		})
		neon.Name = "SignNeon"
	end
	addLight(
		signPart,
		"SurfaceLight",
		{ Face = Enum.NormalId.Front, Range = 10, Brightness = 1.2, Color = accent, Angle = 80 }
	)

	-- Toldo de rayas sobre las ventanas (lonas inclinadas con faldón).
	for side = -1, 1, 2 do
		for i = 0, 3 do
			local x = side * (5.75 + 2.25 + i * 4.5)
			local stripe = (i % 2 == 0) and accent or Color3.new(1, 1, 1)
			part({
				Size = Vector3.new(4.5, 0.3, 4.8),
				CFrame = L(x, 14.2, -20.8) * CFrame.Angles(math.rad(-28), 0, 0),
				Color = stripe,
				Material = Enum.Material.Fabric,
				CanCollide = false,
				Parent = shop,
			})
			part({
				Size = Vector3.new(4.5, 0.9, 0.2),
				CFrame = L(x, 12.75, -22.9),
				Color = stripe,
				Material = Enum.Material.Fabric,
				CanCollide = false,
				Parent = shop,
			})
		end
	end

	-- Mostrador.
	part({
		Size = Vector3.new(14, 4, 3),
		CFrame = L(0, 3, 4),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
		Parent = shop,
	})
	part({ Size = Vector3.new(14.2, 0.6, 0.2), CFrame = L(0, 4.3, 2.45), Color = accent, Parent = shop })
	part({
		Size = Vector3.new(15, 0.5, 3.8),
		CFrame = L(0, 5.25, 4),
		Color = CREAM,
		Material = Enum.Material.Marble,
		Parent = shop,
	})
	part({
		Size = Vector3.new(2.2, 1.4, 1.8),
		CFrame = L(4.5, 6.2, 4.2),
		Color = Color3.fromRGB(70, 60, 90),
		Parent = shop,
	})
	part({
		Size = Vector3.new(1.8, 0.9, 0.2),
		CFrame = L(4.5, 7.2, 4.6) * CFrame.Angles(math.rad(-20), 0, 0),
		Color = Color3.fromRGB(120, 255, 190),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = shop,
	})
	for i = 1, 5 do
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 0.8, 0.8),
			CFrame = cylinderUp(L(-5.5 + i * 0.9, 6.1, 4)),
			Color = RAINBOW[i],
			Parent = shop,
		})
	end

	-- Estantería con botes de pintura.
	part({
		Size = Vector3.new(8, 0.4, 2),
		CFrame = L(-17.5, 6, 17.2),
		Color = WOOD,
		Material = Enum.Material.Wood,
		Parent = shop,
	})
	part({
		Size = Vector3.new(8, 0.4, 2),
		CFrame = L(-17.5, 3, 17.2),
		Color = WOOD,
		Material = Enum.Material.Wood,
		Parent = shop,
	})
	for i = 1, 6 do
		for row = 0, 1 do
			part({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.4, 1.1, 1.1),
				CFrame = cylinderUp(L(-21 + i * 1.15, 3.9 + row * 3, 17.2)),
				Color = RAINBOW[(i + row * 3) % #RAINBOW + 1],
				Parent = shop,
			})
		end
	end

	-- Lámparas colgantes.
	for _, pos in ipairs({ Vector3.new(-12, 0, -2), Vector3.new(12, 0, -2), Vector3.new(0, 0, -10) }) do
		part({
			Size = Vector3.new(0.15, 3, 0.15),
			CFrame = L(pos.X, 17.8, pos.Z),
			Color = Color3.fromRGB(40, 30, 50),
			CanCollide = false,
			Parent = shop,
		})
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 2.6, 2.6),
			CFrame = cylinderUp(L(pos.X, 16.2, pos.Z)),
			Color = accent,
			CanCollide = false,
			Parent = shop,
		})
		local bulb = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.3, 1.3, 1.3),
			CFrame = L(pos.X, 15.6, pos.Z),
			Color = Color3.fromRGB(255, 230, 180),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = shop,
		})
		addLight(
			bulb,
			"PointLight",
			{ Range = 22, Brightness = 1.2, Color = Color3.fromRGB(255, 220, 180), Shadows = true }
		)
	end

	-- Plantas interiores.
	buildPlant(shop, L(19.5, 1, 15.5), 1)
	buildPlant(shop, L(-19.5, 1, -15.5), 0.9)
	buildPlant(shop, L(19.5, 1, -15.5), 0.9)

	-- Puestos de espera con cojines.
	local spots = {}
	for i, x in ipairs({ -12, -6, 0, 6, 12 }) do
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 3.2, 3.2),
			CFrame = cylinderUp(L(x, 1.1, -3.5)),
			Color = (i % 2 == 0) and accent or CREAM,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = shop,
		})
		spots[i] = L(x, 1, -3.5)
	end

	-- Galería en las paredes.
	local gallery = Instance.new("Folder")
	gallery.Name = "Gallery"
	gallery.Parent = model
	local frameCFrames = {
		L(-12, 11, 17.9),
		L(0, 11.5, 17.9),
		L(12, 11, 17.9),
		L(-21.9, 11, 8) * CFrame.Angles(0, -math.pi / 2, 0),
		L(-21.9, 11, -6) * CFrame.Angles(0, -math.pi / 2, 0),
		L(21.9, 11, 8) * CFrame.Angles(0, math.pi / 2, 0),
		L(21.9, 11, -6) * CFrame.Angles(0, math.pi / 2, 0),
	}
	local canvases, plaques = {}, {}
	for i = 1, Config.GALLERY_SIZE do
		canvases[i], plaques[i] = buildFrame(gallery, frameCFrames[i], "Frame" .. i)
	end
	local easelCanvas = buildEasel(shop, L(13, 1, 11) * CFrame.Angles(0, math.rad(-25), 0))

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model

	local customers = Instance.new("Folder")
	customers.Name = "Customers"
	customers.Parent = model

	-- Exterior: jardineras junto a la entrada.
	buildFlowerBed(shop, L(-14, 0, -24.5), 16, rng)
	buildFlowerBed(shop, L(14, 0, -24.5), 16, rng)

	model.Parent = parent

	return {
		index = index,
		model = model,
		cframe = plotCF,
		spots = spots,
		entrance = L(0, 0.4, -24),
		inside = L(0, 1, -12),
		street = L(0, 0.4, -(PLOT_RADIUS - PLAZA_RADIUS) + 4),
		ownerSpawn = L(0, 4, 9),
		signLabel = signLabel,
		canvases = canvases,
		plaques = plaques,
		easelCanvas = easelCanvas,
		decorFolder = decor,
		customersFolder = customers,
		decorBuilt = 0,
		L = L,
	}
end

-- Construye las decoraciones hasta el nivel indicado (o las quita si baja).
function WorldBuilder.setDecorLevel(plot, level)
	if level < plot.decorBuilt then
		plot.decorFolder:ClearAllChildren()
		plot.decorBuilt = 0
	end
	for i = plot.decorBuilt + 1, math.min(level, #DECOR_BUILDERS) do
		local folder = Instance.new("Folder")
		folder.Name = "Decor" .. i
		DECOR_BUILDERS[i](folder, plot.L)
		folder.Parent = plot.decorFolder
		plot.decorBuilt = i
	end
end

function WorldBuilder.build()
	setupLighting()

	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = Workspace

	local rng = Random.new(2024)

	part({
		Name = "Ground",
		Size = Vector3.new(800, 4, 800),
		CFrame = CFrame.new(0, -2, 0),
		Color = Color3.fromRGB(120, 200, 110),
		Material = Enum.Material.Grass,
		Parent = world,
	})
	part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, PLAZA_RADIUS * 2, PLAZA_RADIUS * 2),
		CFrame = cylinderUp(CFrame.new(0, 0.2, 0)),
		Color = Color3.fromRGB(236, 222, 200),
		Material = Enum.Material.Cobblestone,
		Parent = world,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.45, 40, 40),
		CFrame = cylinderUp(CFrame.new(0, 0.22, 0)),
		Color = Color3.fromRGB(214, 196, 240),
		Material = Enum.Material.Pavement,
		Parent = world,
	})
	buildFountain(world)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(26, 0.6, 0)
	spawn.Color = Color3.fromRGB(255, 196, 214)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = world

	-- Jardineras redondas alrededor de la fuente, entre los caminos.
	for i = 0, Config.MAX_PLOTS - 1 do
		local angle = (i + 0.5) / Config.MAX_PLOTS * math.pi * 2
		local center = CFrame.new(math.cos(angle) * 30, 0, math.sin(angle) * 30)
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 9, 9),
			CFrame = cylinderUp(center * CFrame.new(0, 0.8, 0)),
			Color = CREAM,
			Material = Enum.Material.Marble,
			Parent = world,
		})
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 8, 8),
			CFrame = cylinderUp(center * CFrame.new(0, 1.5, 0)),
			Color = Color3.fromRGB(110, 76, 56),
			Material = Enum.Material.Ground,
			Parent = world,
		})
		for f = 1, 10 do
			local a = f / 10 * math.pi * 2
			local r = (f % 2 == 0) and 2.6 or 1.4
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.3, 1.3, 1.3),
				CFrame = center * CFrame.new(math.cos(a) * r, 2.3 + (f % 3) * 0.3, math.sin(a) * r),
				Color = RAINBOW[(i + f) % #RAINBOW + 1],
				CanCollide = false,
				Parent = world,
			})
		end
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.4, 3.4, 3.4),
			CFrame = center * CFrame.new(0, 3.2, 0),
			Color = Color3.fromRGB(110, 200, 110),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = world,
		})
	end

	for i = 0, 11 do
		local angle = (i + 0.5) / 12 * math.pi * 2
		local pos = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (PLAZA_RADIUS - 4)
		buildLampPost(world, CFrame.new(pos))
		if i % 2 == 0 then
			buildBench(world, CFrame.lookAt(pos * 0.82, Vector3.new(0, 0, 0)))
		end
	end

	-- Árboles entre galerías y alrededor del mundo.
	for i = 0, Config.MAX_PLOTS - 1 do
		local angle = (i + 0.5) / Config.MAX_PLOTS * math.pi * 2
		for _, radius in ipairs({ 86, 118, 150 }) do
			local jitter = Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
			local pos = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius + jitter
			buildTree(world, CFrame.new(pos), rng:NextNumber(0.9, 1.3), rng)
		end
	end
	for i = 1, 40 do
		local angle = i / 40 * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local radius = rng:NextNumber(185, 240)
		buildTree(world, CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), rng:NextNumber(1, 1.6), rng)
	end

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace

	local plots = {}
	for i = 1, Config.MAX_PLOTS do
		local angle = (i - 1) / Config.MAX_PLOTS * math.pi * 2
		local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * PLOT_RADIUS
		local plotCF = CFrame.lookAt(position, Vector3.new(0, 0, 0))
		plots[i] = buildPlot(plotsFolder, i, plotCF, rng)
	end
	return plots
end

return WorldBuilder
