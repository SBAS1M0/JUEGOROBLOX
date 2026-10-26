-- Construye el terreno privado de cada jugador: galería y taller conectados,
-- jardín, estanque, fuente, calle y bosque alrededor. Todo por código, sin
-- assets externos. Cada jugador tiene su propio terreno, lejos de los demás.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local WorldBuilder = {}

local LOT_SPACING = 3000
local FLOOR = 2
local CEILING = 22

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local COLORS = {
	plaster = rgb(244, 243, 239),
	plasterShade = rgb(234, 233, 229),
	trim = rgb(226, 226, 222),
	stone = rgb(196, 196, 192),
	galleryFloor = rgb(206, 172, 132),
	workshopFloor = rgb(184, 184, 180),
	brick = rgb(236, 234, 228),
	charcoal = rgb(44, 48, 56),
	cladding = rgb(168, 120, 80),
	claddingDark = rgb(110, 76, 50),
	wood = rgb(190, 146, 104),
	darkWood = rgb(96, 70, 50),
	gold = rgb(214, 172, 96),
	brass = rgb(196, 160, 100),
	cream = rgb(250, 248, 242),
	glass = rgb(196, 220, 236),
	leaf = rgb(96, 160, 84),
	hedge = rgb(66, 124, 70),
	path = rgb(214, 212, 206),
	asphalt = rgb(70, 72, 80),
	workshopAccent = rgb(40, 150, 140),
}
local FLOWERS = {
	rgb(250, 250, 246),
	rgb(255, 214, 92),
	rgb(150, 132, 220),
	rgb(110, 150, 230),
}
local RAINBOW = {
	rgb(255, 90, 110),
	rgb(255, 170, 60),
	rgb(255, 225, 80),
	rgb(110, 220, 120),
	rgb(90, 170, 255),
	rgb(180, 120, 255),
}

-- Utilidades ---------------------------------------------------------------------------
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
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.Parent = label
	if props.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.stroke
		stroke.Thickness = props.strokeThickness or 3
		stroke.Parent = label
	end
	return label
end

local function prompt(parent, action, object, distance)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = distance or 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

-- Ambiente global -----------------------------------------------------------------------
local lightingReady = false
local function setupLighting()
	if lightingReady then
		return
	end
	lightingReady = true
	Lighting.ClockTime = 14.8
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3
	Lighting.Ambient = rgb(112, 114, 120)
	Lighting.OutdoorAmbient = rgb(142, 146, 154)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Color = rgb(200, 212, 226)
	atmosphere.Decay = rgb(110, 124, 146)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.5
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.06
	color.Contrast = 0.06
	color.Brightness = 0.02
	color.TintColor = rgb(255, 250, 244)
	color.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Spread = 0.7
	rays.Parent = Lighting
	local depth = Instance.new("DepthOfFieldEffect")
	depth.FarIntensity = 0.12
	depth.FocusDistance = 120
	depth.InFocusRadius = 140
	depth.NearIntensity = 0
	depth.Parent = Lighting

	local terrain = Workspace.Terrain
	terrain.WaterColor = rgb(80, 170, 200)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.08
	terrain.WaterReflectance = 0.4
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.6
		clouds.Color = rgb(250, 252, 255)
		clouds.Parent = terrain
	end
end

-- Elementos reutilizables ------------------------------------------------------------------
local function buildTree(parent, cf, scale, rng, autumn)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local trunkHeight = 9 * scale
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkHeight, 1.8 * scale, 1.8 * scale),
		CFrame = cylinderUp(cf * CFrame.new(0, trunkHeight / 2, 0)),
		Color = rgb(112, 76, 56),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2 * scale, 2.8 * scale, 2.8 * scale),
		CFrame = cylinderUp(cf * CFrame.new(0, 0.5 * scale, 0)),
		Color = rgb(98, 66, 48),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local base = autumn and rgb(214, 150, 70) or COLORS.leaf
	for i = 1, 5 do
		local size = (5.5 + rng:NextNumber() * 3) * scale
		local offset = Vector3.new(
			rng:NextNumber(-2.4, 2.4),
			trunkHeight + rng:NextNumber(-1, 3),
			rng:NextNumber(-2.4, 2.4)
		) * scale
		if i == 1 then
			offset = Vector3.new(0, trunkHeight + 2 * scale, 0)
			size = 8 * scale
		end
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			CFrame = cf * CFrame.new(offset),
			Color = base:Lerp(rgb(255, 255, 255), rng:NextNumber() * 0.15)
				:Lerp(rgb(30, 80, 40), rng:NextNumber() * 0.15),
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
			Parent = model,
		})
	end
	model.Parent = parent
end

local function buildBush(parent, cf, scale, color)
	for i = 1, 3 do
		local angle = i * 2.1
		local size = (2.6 + i * 0.3) * scale
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			CFrame = cf * CFrame.new(math.cos(angle) * 0.9 * scale, size * 0.35, math.sin(angle) * 0.9 * scale),
			Color = color or COLORS.leaf:Lerp(rgb(30, 90, 40), i * 0.08),
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
			Parent = parent,
		})
	end
end

local function buildLampPost(parent, cf)
	-- Farola moderna: poste fino y cabezal plano.
	part({
		Size = Vector3.new(1.4, 0.4, 1.4),
		CFrame = cf * CFrame.new(0, 0.2, 0),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	part({
		Size = Vector3.new(0.45, 12, 0.45),
		CFrame = cf * CFrame.new(0, 6.2, 0),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	part({
		Size = Vector3.new(2.6, 0.35, 0.9),
		CFrame = cf * CFrame.new(0.9, 12.3, 0),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	local lens = part({
		Size = Vector3.new(2, 0.1, 0.6),
		CFrame = cf * CFrame.new(1, 12.1, 0),
		Color = rgb(255, 236, 206),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	addLight(lens, "SpotLight", {
		Face = Enum.NormalId.Bottom,
		Angle = 80,
		Range = 18,
		Brightness = 1.2,
		Color = rgb(255, 226, 190),
		Shadows = false,
	})
end

local function buildBench(parent, cf)
	-- Banco de roble sobre dos bloques de hormigón.
	for _, x in ipairs({ -2.3, 2.3 }) do
		part({
			Size = Vector3.new(1.2, 1.7, 2.2),
			CFrame = cf * CFrame.new(x, 0.85, 0),
			Color = COLORS.stone,
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
	end
	for i = 0, 3 do
		part({
			Size = Vector3.new(6.4, 0.35, 0.5),
			CFrame = cf * CFrame.new(0, 1.85, -0.84 + i * 0.56),
			Color = COLORS.wood,
			Material = Enum.Material.Wood,
			Parent = parent,
		})
	end
end

local function buildFlowerBed(parent, cf, width, depth, rng)
	part({
		Size = Vector3.new(width + 0.8, 1, depth + 0.8),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = COLORS.stone,
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
	part({
		Size = Vector3.new(width, 0.3, depth),
		CFrame = cf * CFrame.new(0, 1.05, 0),
		Color = rgb(96, 66, 50),
		Material = Enum.Material.Ground,
		Parent = parent,
	})
	local count = math.floor(width * depth / 2.2)
	for _ = 1, count do
		local x = rng:NextNumber(-width / 2 + 0.6, width / 2 - 0.6)
		local z = rng:NextNumber(-depth / 2 + 0.6, depth / 2 - 0.6)
		local h = rng:NextNumber(0.8, 1.6)
		part({
			Size = Vector3.new(0.18, h, 0.18),
			CFrame = cf * CFrame.new(x, 1.2 + h / 2, z),
			Color = rgb(80, 160, 80),
			CanCollide = false,
			CastShadow = false,
			Parent = parent,
		})
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.8, 0.8, 0.8),
			CFrame = cf * CFrame.new(x, 1.3 + h, z),
			Color = FLOWERS[rng:NextInteger(1, #FLOWERS)],
			CanCollide = false,
			CastShadow = false,
			Parent = parent,
		})
	end
end

local function buildPlant(parent, cf, scale)
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.6 * scale, 2.6 * scale, 2.6 * scale),
		CFrame = cylinderUp(cf * CFrame.new(0, 1.3 * scale, 0)),
		Color = rgb(222, 220, 214),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4 * scale, 2.9 * scale, 2.9 * scale),
		CFrame = cylinderUp(cf * CFrame.new(0, 2.6 * scale, 0)),
		Color = rgb(206, 204, 198),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
	for i = 1, 4 do
		local angle = i * 1.7
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 2.6, 2.6) * scale,
			CFrame = cf
				* CFrame.new(math.cos(angle) * 0.7 * scale, (3.2 + i * 0.7) * scale, math.sin(angle) * 0.7 * scale),
			Color = rgb(80 + i * 12, 172 + i * 8, 96),
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
			Parent = parent,
		})
	end
end

local function buildFountain(parent, cf)
	-- Estanque rectangular de hormigón con tres surtidores bajos.
	local edge = COLORS.stone
	part({
		Size = Vector3.new(18, 1.2, 10),
		CFrame = cf * CFrame.new(0, 0.6, 0),
		Color = edge,
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
	part({
		Size = Vector3.new(16.6, 0.2, 8.6),
		CFrame = cf * CFrame.new(0, 1.15, 0),
		Color = rgb(96, 150, 180),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Reflectance = 0.2,
		CanCollide = false,
		Parent = parent,
	})
	for _, x in ipairs({ -5, 0, 5 }) do
		local jet = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 0.6, 0.6),
			CFrame = cylinderUp(cf * CFrame.new(x, 1.3, 0)),
			Color = COLORS.charcoal,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = parent,
		})
		local water = Instance.new("ParticleEmitter")
		water.Rate = 24
		water.Lifetime = NumberRange.new(0.6, 0.8)
		water.Speed = NumberRange.new(5, 6)
		water.SpreadAngle = Vector2.new(6, 6)
		water.Acceleration = Vector3.new(0, -20, 0)
		water.LightEmission = 0.2
		water.Transparency = NumberSequence.new(0.35, 1)
		water.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.12) })
		water.Color = ColorSequence.new(rgb(220, 240, 255), rgb(170, 210, 240))
		water.EmissionDirection = Enum.NormalId.Top
		water.Parent = jet
	end
end

-- Cuadro enmarcado de la galería: marco negro fino, paspartú blanco y foco.
local function buildFrame(parent, cf, name)
	local frame = Instance.new("Model")
	frame.Name = name
	part({
		Size = Vector3.new(8, 8, 0.4),
		CFrame = cf,
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = frame,
	})
	part({
		Size = Vector3.new(7.5, 7.5, 0.2),
		CFrame = cf * CFrame.new(0, 0, -0.25),
		Color = rgb(250, 250, 248),
		Parent = frame,
	})
	local canvas = part({
		Name = "Canvas",
		Size = Vector3.new(6.2, 6.2, 0.2),
		CFrame = cf * CFrame.new(0, 0, -0.38),
		Color = COLORS.cream,
		Parent = frame,
	})
	local plaque = part({
		Name = "Plaque",
		Size = Vector3.new(4.6, 0.8, 0.12),
		CFrame = cf * CFrame.new(0, -4.7, -0.1),
		Color = rgb(250, 250, 248),
		Parent = frame,
	})
	local plaqueLabel = surfaceText(
		plaque,
		Enum.NormalId.Front,
		"",
		{ pps = 60, color = COLORS.charcoal, font = Enum.Font.BuilderSansBold }
	)
	plaqueLabel.Name = "PlaqueText"
	part({
		Size = Vector3.new(0.2, 0.2, 1),
		CFrame = cf * CFrame.new(0, 4.6, -0.6),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = frame,
	})
	local lamp = part({
		Size = Vector3.new(2.6, 0.3, 0.4),
		CFrame = cf * CFrame.new(0, 4.8, -1.1),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = frame,
	})
	addLight(
		lamp,
		"SpotLight",
		{ Face = Enum.NormalId.Bottom, Angle = 75, Range = 11, Brightness = 2.2, Color = rgb(255, 242, 224) }
	)
	-- Avisos para colgar y descolgar (solo uno activo a la vez).
	local hang = prompt(canvas, "Colgar cuadro", "Marco libre", 10)
	hang.Name = "HangPrompt"
	hang.Enabled = false
	local take = prompt(canvas, "Descolgar", "Cuadro expuesto", 10)
	take.Name = "TakePrompt"
	take.HoldDuration = 0.4
	take.Enabled = false
	frame.Parent = parent
	return canvas, plaqueLabel, hang, take
end

local function buildEasel(parent, cf, scale)
	scale = scale or 1
	local model = Instance.new("Model")
	model.Name = "Easel"
	for _, x in ipairs({ -1.9, 1.9 }) do
		part({
			Size = Vector3.new(0.45, 11, 0.45) * scale,
			CFrame = cf
				* CFrame.new(x * scale, 5.5 * scale, 0)
				* CFrame.Angles(math.rad(-8), 0, math.rad(x > 0 and 8 or -8)),
			Color = COLORS.wood,
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	part({
		Size = Vector3.new(0.45, 10, 0.45) * scale,
		CFrame = cf * CFrame.new(0, 5 * scale, 1.6 * scale) * CFrame.Angles(math.rad(14), 0, 0),
		Color = COLORS.wood,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	part({
		Size = Vector3.new(6.4, 0.45, 1) * scale,
		CFrame = cf * CFrame.new(0, 4.2 * scale, -0.55 * scale),
		Color = COLORS.wood,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	part({
		Size = Vector3.new(6.4, 6.4, 0.3) * scale,
		CFrame = cf * CFrame.new(0, 7.75 * scale, -0.3 * scale) * CFrame.Angles(math.rad(-8), 0, 0),
		Color = rgb(236, 226, 206),
		Parent = model,
	})
	local canvas = part({
		Name = "Canvas",
		Size = Vector3.new(6, 6, 0.2) * scale,
		CFrame = cf * CFrame.new(0, 7.75 * scale, -0.5 * scale) * CFrame.Angles(math.rad(-8), 0, 0),
		Color = COLORS.cream,
		Parent = model,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 2.8, 2.8) * scale,
		CFrame = cf * CFrame.new(3 * scale, 4.6 * scale, -0.8 * scale) * CFrame.Angles(0, math.rad(90), 0),
		Color = rgb(230, 190, 140),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	for i, color in ipairs(RAINBOW) do
		local angle = i * 0.9
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.5, 0.5, 0.5) * scale,
			CFrame = cf * CFrame.new(
				(3 + math.cos(angle) * 0.85) * scale,
				(4.6 + math.sin(angle) * 0.85) * scale,
				-0.95 * scale
			),
			Color = color,
			CanCollide = false,
			Parent = model,
		})
	end
	model.Parent = parent
	return canvas
end

-- Paredes con huecos -------------------------------------------------------------------------
-- openings: { { a, b, y0, y1 } } (a < b sobre el eje de la pared).
local function wall(parent, L, axis, fixed, from, to, y0, y1, thickness, openings, color, material)
	table.sort(openings, function(p, q)
		return p[1] < q[1]
	end)
	local function piece(a, b, ya, yb)
		if b - a < 0.01 or yb - ya < 0.01 then
			return
		end
		local size, cf
		if axis == "x" then
			size = Vector3.new(b - a, yb - ya, thickness)
			cf = L((a + b) / 2, (ya + yb) / 2, fixed)
		else
			size = Vector3.new(thickness, yb - ya, b - a)
			cf = L(fixed, (ya + yb) / 2, (a + b) / 2)
		end
		part({ Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.Plaster, Parent = parent })
	end
	local cursor = from
	for _, o in ipairs(openings) do
		piece(cursor, o[1], y0, y1)
		piece(o[1], o[2], y0, math.max(y0, o[3]))
		piece(o[1], o[2], math.min(y1, o[4]), y1)
		cursor = o[2]
	end
	piece(cursor, to, y0, y1)
end

-- Decoraciones que aparecen con la mejora "Decoración" ----------------------------------------
local function topiary(parent, cf, height)
	part({
		Size = Vector3.new(3, 2.4, 3),
		CFrame = cf * CFrame.new(0, 1.2, 0),
		Color = COLORS.charcoal,
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
	for i = 0, 2 do
		local size = (2.6 - i * 0.6) * height / 6
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size * 1.3, size * 1.6, size * 1.3),
			CFrame = cf * CFrame.new(0, 3 + i * height / 4, 0),
			Color = COLORS.hedge:Lerp(COLORS.leaf, i * 0.15),
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
			Parent = parent,
		})
	end
end

local DECOR_BUILDERS = {
	-- 1. Árboles en maceta junto a la entrada.
	function(folder, L)
		topiary(folder, L(-30.5, 0.3, -25), 7)
		topiary(folder, L(-13.5, 0.3, -25), 7)
	end,
	-- 2. Alfombra de entrada y pasillo en gris oscuro.
	function(folder, L)
		part({
			Size = Vector3.new(5, 0.12, 20),
			CFrame = L(-22, FLOOR + 0.27, -8),
			Color = rgb(70, 74, 84),
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = folder,
		})
		part({
			Size = Vector3.new(5, 0.12, 22),
			CFrame = L(-22, 0.36, -36),
			Color = rgb(70, 74, 84),
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = folder,
		})
	end,
	-- 3. Escultura de acero en la plaza.
	function(folder, L)
		part({
			Size = Vector3.new(4, 1.2, 4),
			CFrame = L(30, 0.9, -36),
			Color = COLORS.stone,
			Material = Enum.Material.Concrete,
			Parent = folder,
		})
		-- Arco de acero hecho con tramos tangentes a una circunferencia.
		local radius = 5
		for i = 0, 14 do
			local angle = math.pi * (i + 0.5) / 15
			part({
				Size = Vector3.new(0.8, 1.15, 0.8),
				CFrame = L(30 + math.cos(angle) * radius, 1.5 + math.sin(angle) * radius, -36)
					* CFrame.Angles(0, 0, angle),
				Color = COLORS.charcoal,
				Material = Enum.Material.Metal,
				Parent = folder,
			})
		end
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.4, 2.4, 2.4),
			CFrame = L(30, 2.7, -36),
			Color = rgb(236, 236, 232),
			Material = Enum.Material.Marble,
			Parent = folder,
		})
	end,
	-- 4. Guirnalda de luces cálidas en la fachada.
	function(folder, L)
		for i = 0, 38 do
			local x = -40 + i * 2
			local bulb = part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.6, 0.6, 0.6),
				CFrame = L(x, 19.6 - math.sin(i * 0.5) ^ 2 * 0.7, -19),
				Color = rgb(255, 226, 170),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
			if i % 6 == 0 then
				addLight(bulb, "PointLight", { Range = 8, Brightness = 0.6, Color = rgb(255, 214, 160) })
			end
		end
	end,
	-- 5. Lámpara lineal sobre la sala de la galería.
	function(folder, L)
		local c = L(-22, 0, 2)
		for _, x in ipairs({ -7, 7 }) do
			part({
				Size = Vector3.new(0.1, 3, 0.1),
				CFrame = c * CFrame.new(x, CEILING - 1.5, 0),
				Color = COLORS.charcoal,
				CanCollide = false,
				Parent = folder,
			})
		end
		part({
			Size = Vector3.new(16, 0.5, 1),
			CFrame = c * CFrame.new(0, CEILING - 3.2, 0),
			Color = COLORS.charcoal,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = folder,
		})
		local strip = part({
			Size = Vector3.new(15.4, 0.1, 0.6),
			CFrame = c * CFrame.new(0, CEILING - 3.5, 0),
			Color = rgb(255, 240, 220),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
		addLight(strip, "PointLight", { Range = 26, Brightness = 1.1, Color = rgb(255, 238, 216) })
	end,
	-- 6. Focos que iluminan la fachada y el jardín de noche.
	function(folder, L)
		local spots = {
			{ -46, 0.3, -10, Enum.NormalId.Top },
			{ 42, 0.3, -10, Enum.NormalId.Top },
			{ -46, 0.3, 10, Enum.NormalId.Top },
			{ 42, 0.3, 10, Enum.NormalId.Top },
		}
		for _, x in ipairs({ -36, -8, 4, 18, 34 }) do
			table.insert(spots, { x, FLOOR, -19.4, Enum.NormalId.Top })
		end
		for _, data in ipairs(spots) do
			local spot = part({
				Size = Vector3.new(0.8, 0.5, 0.8),
				CFrame = L(data[1], data[2] + 0.25, data[3]),
				Color = COLORS.charcoal,
				Material = Enum.Material.Metal,
				CanCollide = false,
				Parent = folder,
			})
			addLight(spot, "SpotLight", {
				Face = data[4],
				Angle = 40,
				Range = 18,
				Brightness = 1.2,
				Color = rgb(255, 236, 210),
			})
		end
	end,
}
WorldBuilder.DECOR_LEVELS = #DECOR_BUILDERS

-- Edificio -----------------------------------------------------------------------------------
-- Dos volúmenes modernos: la galería (blanca, con pretil) y el taller (forrado
-- de madera, con un alero oscuro). Grandes cristaleras con perfiles negros.

-- Cristalera con perfiles negros en una pared paralela a X.
local function glazing(parent, L, z, a, b, y0, y1, panes)
	part({
		Size = Vector3.new(b - a, y1 - y0, 0.25),
		CFrame = L((a + b) / 2, (y0 + y1) / 2, z),
		Color = COLORS.glass,
		Material = Enum.Material.Glass,
		Transparency = 0.6,
		Parent = parent,
	})
	local t = 0.3
	for i = 0, panes do
		local x = a + (b - a) * i / panes
		part({
			Size = Vector3.new(t, y1 - y0, 0.45),
			CFrame = L(x, (y0 + y1) / 2, z),
			Color = COLORS.charcoal,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = parent,
		})
	end
	for _, y in ipairs({ y0 + t / 2, y1 - t / 2 }) do
		part({
			Size = Vector3.new(b - a, t, 0.45),
			CFrame = L((a + b) / 2, y, z),
			Color = COLORS.charcoal,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = parent,
		})
	end
end

-- Marco negro alrededor de una puerta en una pared paralela a X.
local function doorFrame(parent, L, z, a, b, y0, y1)
	local t = 0.4
	part({
		Size = Vector3.new(b - a + t * 2, t, 0.6),
		CFrame = L((a + b) / 2, y1 + t / 2, z),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	for _, x in ipairs({ a - t / 2, b + t / 2 }) do
		part({
			Size = Vector3.new(t, y1 - y0, 0.6),
			CFrame = L(x, (y0 + y1) / 2, z),
			Color = COLORS.charcoal,
			Material = Enum.Material.Metal,
			Parent = parent,
		})
	end
end

-- Revestimiento de listones verticales de madera sobre una pared.
-- axis "x": pared paralela a X en z = fixed; axis "z": paralela a Z en x = fixed.
local function cladding(parent, L, axis, fixed, from, to, y0, y1, openings, outward)
	wall(parent, L, axis, fixed, from, to, y0, y1, 0.3, openings, COLORS.cladding, Enum.Material.Wood)
	local function inOpening(u, y)
		for _, o in ipairs(openings) do
			if u > o[1] - 0.2 and u < o[2] + 0.2 and y > o[3] and y < o[4] then
				return o
			end
		end
		return nil
	end
	local offset = outward * 0.2
	for u = from + 1, to - 1, 1.6 do
		-- Una ranura oscura por listón, cortada por los huecos.
		local segments = {}
		local start = y0
		for _, o in ipairs(openings) do
			if u > o[1] - 0.2 and u < o[2] + 0.2 then
				table.insert(segments, { start, math.max(start, o[3]) })
				start = math.min(y1, o[4])
			end
		end
		table.insert(segments, { start, y1 })
		for _, seg in ipairs(segments) do
			local h = seg[2] - seg[1]
			if h > 0.3 and not inOpening(u, (seg[1] + seg[2]) / 2) then
				local size = axis == "x" and Vector3.new(0.14, h, 0.1) or Vector3.new(0.1, h, 0.14)
				local cf = axis == "x" and L(u, (seg[1] + seg[2]) / 2, fixed + offset)
					or L(fixed + offset, (seg[1] + seg[2]) / 2, u)
				part({
					Size = size,
					CFrame = cf,
					Color = COLORS.claddingDark,
					Material = Enum.Material.Wood,
					CanCollide = false,
					CastShadow = false,
					Parent = parent,
				})
			end
		end
	end
end

local function wallLight(parent, cf)
	part({
		Size = Vector3.new(0.8, 1.6, 0.8),
		CFrame = cf,
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = parent,
	})
	local lens = part({
		Size = Vector3.new(0.6, 0.1, 0.6),
		CFrame = cf * CFrame.new(0, -0.85, 0),
		Color = rgb(255, 236, 206),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	addLight(lens, "SpotLight", {
		Face = Enum.NormalId.Bottom,
		Angle = 60,
		Range = 12,
		Brightness = 1.4,
		Color = rgb(255, 228, 196),
	})
end

local function grasses(parent, cf, width, rng)
	for i = 0, math.floor(width / 0.9) do
		local x = -width / 2 + 0.45 + i * 0.9
		for k = 1, 3 do
			local h = rng:NextNumber(1, 2.2)
			part({
				Size = Vector3.new(0.12, h, 0.12),
				CFrame = cf
					* CFrame.new(x + rng:NextNumber(-0.25, 0.25), h / 2, rng:NextNumber(-0.35, 0.35))
					* CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.3, 0.3)),
				Color = rgb(122, 150, 96):Lerp(rgb(196, 182, 120), (k - 1) * 0.25),
				CanCollide = false,
				CastShadow = false,
				Parent = parent,
			})
		end
	end
end

local function buildBuilding(model, L)
	local building = Instance.new("Model")
	building.Name = "Building"
	local plaster = Enum.Material.SmoothPlastic
	local rng = Random.new(11)

	-- Zócalo de hormigón y suelos.
	part({
		Size = Vector3.new(80, FLOOR, 40),
		CFrame = L(-2, FLOOR / 2, 0),
		Color = COLORS.stone,
		Material = Enum.Material.Concrete,
		Parent = building,
	})
	part({
		Size = Vector3.new(34, 0.2, 34),
		CFrame = L(-22, FLOOR + 0.1, 0),
		Color = COLORS.galleryFloor,
		Material = Enum.Material.WoodPlanks,
		Parent = building,
	})
	part({
		Size = Vector3.new(39, 0.2, 34),
		CFrame = L(15.5, FLOOR + 0.1, 0),
		Color = COLORS.workshopFloor,
		Material = Enum.Material.Concrete,
		Parent = building,
	})

	-- Fachada: cristaleras de la galería, puerta, ventanal y puerta del taller.
	local galleryTop = CEILING + 3
	local frontOpenings = {
		{ -38, -29, FLOOR + 0.5, FLOOR + 16 },
		{ -27, -17, FLOOR, FLOOR + 12 },
		{ -15, -6, FLOOR + 0.5, FLOOR + 16 },
		{ 0, 21, FLOOR + 3, FLOOR + 15 },
		{ 25, 31, FLOOR, FLOOR + 11 },
	}
	wall(building, L, "x", -17.5, -40, -4, FLOOR, galleryTop, 1, {
		frontOpenings[1],
		frontOpenings[2],
		frontOpenings[3],
	}, COLORS.plaster, plaster)
	wall(building, L, "x", -17.5, -4, 36, FLOOR, CEILING, 1, {
		frontOpenings[4],
		frontOpenings[5],
	}, COLORS.plaster, plaster)
	cladding(building, L, "x", -18.15, -4, 36.3, FLOOR, CEILING, { frontOpenings[4], frontOpenings[5] }, -1)
	glazing(building, L, -17.5, -38, -29, FLOOR + 0.5, FLOOR + 16, 3)
	glazing(building, L, -17.5, -15, -6, FLOOR + 0.5, FLOOR + 16, 3)
	glazing(building, L, -17.5, 0, 21, FLOOR + 3, FLOOR + 15, 5)
	doorFrame(building, L, -17.6, -27, -17, FLOOR, FLOOR + 12)
	doorFrame(building, L, -18.4, 25, 31, FLOOR, FLOOR + 11)

	-- Paredes traseras y laterales (la galería sube más: pretil).
	wall(building, L, "x", 17.5, -40, -4, FLOOR, galleryTop, 1, {}, COLORS.plaster, plaster)
	wall(
		building,
		L,
		"x",
		17.5,
		-4,
		36,
		FLOOR,
		CEILING,
		1,
		{ { -2, 10, FLOOR + 6, FLOOR + 14 } },
		COLORS.plaster,
		plaster
	)
	cladding(building, L, "x", 18.15, -4, 36.3, FLOOR, CEILING, { { -2, 10, FLOOR + 6, FLOOR + 14 } }, 1)
	glazing(building, L, 17.5, -2, 10, FLOOR + 6, FLOOR + 14, 2)
	wall(building, L, "z", -39.5, -18, 18, FLOOR, galleryTop, 1, {}, COLORS.plaster, plaster)
	wall(building, L, "z", 35.5, -17, 17, FLOOR, CEILING, 1, {}, COLORS.plaster, plaster)
	cladding(building, L, "z", 36.15, -18.3, 18.3, FLOOR, CEILING, {}, 1)
	-- Tabique galería-taller con paso y pretil de la galería por encima.
	wall(
		building,
		L,
		"z",
		-4.5,
		-17,
		17,
		FLOOR,
		CEILING,
		1,
		{ { -15, -6, FLOOR, FLOOR + 12 } },
		COLORS.plasterShade,
		plaster
	)
	wall(building, L, "z", -4.5, -18, 18, CEILING, galleryTop, 1, {}, COLORS.plaster, plaster)
	-- Albardillas de los pretiles.
	for _, data in ipairs({
		{ Vector3.new(37, 0.4, 1.4), L(-22, galleryTop + 0.2, -17.5) },
		{ Vector3.new(37, 0.4, 1.4), L(-22, galleryTop + 0.2, 17.5) },
		{ Vector3.new(1.4, 0.4, 36.4), L(-39.5, galleryTop + 0.2, 0) },
		{ Vector3.new(1.4, 0.4, 36.4), L(-4.5, galleryTop + 0.2, 0) },
	}) do
		part({ Size = data[1], CFrame = data[2], Color = COLORS.trim, Material = plaster, Parent = building })
	end

	-- Pared de ladrillo pintado del taller (interior).
	wall(
		building,
		L,
		"x",
		16.85,
		-4,
		35,
		FLOOR,
		CEILING,
		0.3,
		{ { -2, 10, FLOOR + 6, FLOOR + 14 } },
		COLORS.brick,
		Enum.Material.Brick
	)

	-- Techos: interior blanco, cubierta gris y alero oscuro del taller.
	part({
		Size = Vector3.new(76, 0.4, 36),
		CFrame = L(-2, CEILING + 0.2, 0),
		Color = rgb(250, 250, 248),
		Material = plaster,
		Parent = building,
	})
	part({
		Size = Vector3.new(34, 0.3, 34),
		CFrame = L(-22, CEILING + 0.55, 0),
		Color = rgb(150, 154, 160),
		Material = Enum.Material.Concrete,
		Parent = building,
	})
	part({
		Size = Vector3.new(43, 0.9, 41),
		CFrame = L(16.5, CEILING + 0.85, -1),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = building,
	})
	-- Lucernario sobre el taller.
	part({
		Size = Vector3.new(10, 1.6, 6),
		CFrame = L(16, CEILING + 2, 4),
		Color = COLORS.glass,
		Material = Enum.Material.Glass,
		Transparency = 0.4,
		Parent = building,
	})

	-- Marquesina de la entrada de la galería con el rótulo.
	local canopy = part({
		Size = Vector3.new(16, 0.7, 6),
		CFrame = L(-22, FLOOR + 13.2, -20.5),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = building,
	})
	local fascia = part({
		Size = Vector3.new(16, 0.9, 0.2),
		CFrame = L(-22, FLOOR + 13.2, -23.6),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = building,
	})
	surfaceText(fascia, Enum.NormalId.Front, "GALERÍA", {
		pps = 40,
		color = rgb(255, 255, 255),
		font = Enum.Font.BuilderSansBold,
	})
	addLight(canopy, "SpotLight", {
		Face = Enum.NormalId.Bottom,
		Angle = 90,
		Range = 14,
		Brightness = 1.2,
		Color = rgb(255, 232, 204),
	})

	-- Rótulo con el nombre del dueño sobre la fachada blanca.
	local ownerSign = part({
		Name = "OwnerSign",
		Size = Vector3.new(32, 3.4, 0.2),
		CFrame = L(-22, CEILING + 0.6, -18.05),
		Color = COLORS.plaster,
		Material = plaster,
		Parent = building,
	})
	local ownerLabel = surfaceText(ownerSign, Enum.NormalId.Front, "Galería", {
		pps = 30,
		color = COLORS.charcoal,
		font = Enum.Font.BuilderSansExtraBold,
	})

	-- Rótulo del taller sobre el ventanal.
	local workshopSign = part({
		Size = Vector3.new(10, 1.8, 0.2),
		CFrame = L(10.5, FLOOR + 17.4, -18.4),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = building,
	})
	surfaceText(workshopSign, Enum.NormalId.Front, "TALLER", {
		pps = 34,
		color = rgb(255, 255, 255),
		font = Enum.Font.BuilderSansBold,
	})

	-- Apliques de luz en la fachada.
	for _, x in ipairs({ -39, -16, -5, 23, 33 }) do
		wallLight(building, L(x, FLOOR + 11.5, -18.6))
	end

	-- Rampas de hormigón.
	part({
		Class = "WedgePart",
		Size = Vector3.new(10, FLOOR, 6),
		CFrame = L(-22, FLOOR / 2, -21),
		Color = COLORS.stone,
		Material = Enum.Material.Concrete,
		Parent = building,
	})
	part({
		Class = "WedgePart",
		Size = Vector3.new(6, FLOOR, 5),
		CFrame = L(28, FLOOR / 2, -20.5),
		Color = COLORS.stone,
		Material = Enum.Material.Concrete,
		Parent = building,
	})

	-- Jardinera de hormigón bajo el ventanal del taller.
	part({
		Size = Vector3.new(21, 1.4, 1.8),
		CFrame = L(10.5, FLOOR + 0.7, -19.3),
		Color = COLORS.stone,
		Material = Enum.Material.Concrete,
		Parent = building,
	})
	grasses(building, L(10.5, FLOOR + 1.4, -19.3), 20, rng)

	building.Parent = model
	return ownerLabel
end

-- Interior de la galería ----------------------------------------------------------------------
local function buildGalleryInterior(model, L)
	local folder = Instance.new("Model")
	folder.Name = "GalleryInterior"

	-- Alfombra gris claro y banco de roble junto a la cristalera.
	part({
		Size = Vector3.new(16, 0.1, 10),
		CFrame = L(-22, FLOOR + 0.25, 3),
		Color = rgb(222, 222, 218),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = folder,
	})
	part({
		Size = Vector3.new(8, 0.5, 2.4),
		CFrame = L(-31, FLOOR + 1.9, -11.5),
		Color = COLORS.wood,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	for _, x in ipairs({ -34, -28 }) do
		part({
			Size = Vector3.new(0.4, 1.7, 2.2),
			CFrame = L(x, FLOOR + 0.85, -11.5),
			Color = COLORS.charcoal,
			Material = Enum.Material.Metal,
			Parent = folder,
		})
	end

	-- Mostrador de recepción blanco con tapa de roble y pantalla.
	part({
		Size = Vector3.new(7, 3.8, 2.6),
		CFrame = L(-10, FLOOR + 1.9, -13),
		Color = COLORS.plaster,
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	part({
		Size = Vector3.new(7.4, 0.3, 3),
		CFrame = L(-10, FLOOR + 3.95, -13),
		Color = COLORS.wood,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	part({
		Size = Vector3.new(1.8, 1.1, 0.12),
		CFrame = L(-8.4, FLOOR + 4.8, -12.6) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = folder,
	})

	-- Escultura abstracta sobre peana.
	part({
		Size = Vector3.new(3, 3.6, 3),
		CFrame = L(-36, FLOOR + 1.8, -14),
		Color = COLORS.plaster,
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	for i, size in ipairs({ 2.2, 1.6, 1.1 }) do
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			CFrame = L(-36 + (i - 2) * 0.25, FLOOR + 3.6 + (i - 0.5) * 1.5, -14),
			Color = i == 2 and COLORS.charcoal or rgb(214, 210, 202),
			Material = i == 2 and Enum.Material.Metal or Enum.Material.Concrete,
			Parent = folder,
		})
	end

	-- Rótulo de la sala sobre la pared del fondo.
	local sign = part({
		Size = Vector3.new(16, 1.8, 0.15),
		CFrame = L(-22, CEILING - 2.4, 16.8),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	surfaceText(sign, Enum.NormalId.Front, "SALA DE EXPOSICIÓN", {
		pps = 40,
		color = rgb(255, 255, 255),
		font = Enum.Font.BuilderSansBold,
	})

	-- Plantas en las esquinas.
	buildPlant(folder, L(-36.5, FLOOR, 14.5), 1)
	buildPlant(folder, L(-7.5, FLOOR, 14.5), 1)

	-- Raíles de focos en el techo.
	for _, x in ipairs({ -31, -13 }) do
		part({
			Size = Vector3.new(0.4, 0.3, 30),
			CFrame = L(x, CEILING - 0.2, 0),
			Color = COLORS.charcoal,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = folder,
		})
	end
	for _, pos in ipairs({ Vector3.new(-31, 0, -4), Vector3.new(-13, 0, -4), Vector3.new(-22, 0, 8) }) do
		part({
			Size = Vector3.new(0.12, 3, 0.12),
			CFrame = L(pos.X, CEILING - 1.5, pos.Z),
			Color = COLORS.charcoal,
			CanCollide = false,
			Parent = folder,
		})
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 2.4, 2.4),
			CFrame = cylinderUp(L(pos.X, CEILING - 3.6, pos.Z)),
			Color = COLORS.charcoal,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = folder,
		})
		local bulb = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 2, 2),
			CFrame = cylinderUp(L(pos.X, CEILING - 4.42, pos.Z)),
			Color = rgb(255, 238, 214),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
		addLight(bulb, "PointLight", { Range = 24, Brightness = 1.1, Color = rgb(255, 232, 206), Shadows = true })
	end
	folder.Parent = model
end

-- Taller -------------------------------------------------------------------------------------
local function buildWorkshop(model, L)
	local workshop = Instance.new("Model")
	workshop.Name = "Workshop"

	-- Máquina de colores tipo "gumball" con cúpula de cristal llena de bolas.
	local machine = Instance.new("Model")
	machine.Name = "Machine"
	local mc = L(6, FLOOR, 7) * CFrame.Angles(0, math.rad(20), 0)
	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 5.6, 5.6),
		CFrame = cylinderUp(mc * CFrame.new(0, 3, 0)),
		Color = rgb(206, 52, 56),
		Parent = machine,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 6.4, 6.4),
		CFrame = cylinderUp(mc * CFrame.new(0, 0.3, 0)),
		Color = rgb(60, 50, 80),
		Material = Enum.Material.Metal,
		Parent = machine,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 6.2, 6.2),
		CFrame = cylinderUp(mc * CFrame.new(0, 6.3, 0)),
		Color = COLORS.gold,
		Material = Enum.Material.Metal,
		Parent = machine,
	})
	local glow = part({
		Name = "Glow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.35, 5.9, 5.9),
		CFrame = cylinderUp(mc * CFrame.new(0, 4.6, 0)),
		Color = rgb(170, 170, 185),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = machine,
	})
	local dome = part({
		Name = "Dome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7.4, 7.4, 7.4),
		CFrame = mc * CFrame.new(0, 9.6, 0),
		Color = rgb(220, 240, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.62,
		CanCollide = false,
		Parent = machine,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 2.6, 2.6),
		CFrame = cylinderUp(mc * CFrame.new(0, 13.3, 0)),
		Color = COLORS.gold,
		Material = Enum.Material.Metal,
		Parent = machine,
	})
	part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.4, 1.4, 1.4),
		CFrame = mc * CFrame.new(0, 14.1, 0),
		Color = rgb(206, 52, 56),
		Parent = machine,
	})
	local balls = {}
	local ballRng = Random.new(7)
	for i = 1, 26 do
		local layer = math.floor((i - 1) / 9)
		local angle = i * 2.4
		local radius = 1 + ballRng:NextNumber() * 1.7
		local ball = part({
			Name = "Ball",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.3, 1.3, 1.3),
			CFrame = mc * CFrame.new(math.cos(angle) * radius, 7.3 + layer * 1.15, math.sin(angle) * radius),
			Color = RAINBOW[(i % #RAINBOW) + 1],
			CanCollide = false,
			Parent = machine,
		})
		table.insert(balls, ball)
	end
	-- Ranura, manivela y salida.
	part({
		Size = Vector3.new(2.4, 1.6, 0.6),
		CFrame = mc * CFrame.new(0, 3.6, -2.9),
		Color = rgb(250, 248, 244),
		Material = Enum.Material.Metal,
		Parent = machine,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 1.6, 1.6),
		CFrame = mc * CFrame.new(0, 3.6, -3.25) * CFrame.Angles(0, math.rad(90), 0),
		Color = COLORS.gold,
		Material = Enum.Material.Metal,
		Parent = machine,
	})
	part({
		Size = Vector3.new(0.3, 1.8, 0.3),
		CFrame = mc * CFrame.new(0, 3.6, -3.45) * CFrame.Angles(0, 0, math.rad(35)),
		Color = COLORS.gold,
		Material = Enum.Material.Metal,
		Parent = machine,
	})
	local dispenser = part({
		Name = "Dispenser",
		Size = Vector3.new(2, 1.4, 1.4),
		CFrame = mc * CFrame.new(0, 1.5, -3),
		Color = rgb(60, 50, 80),
		Material = Enum.Material.Metal,
		Parent = machine,
	})
	local can = part({
		Name = "Can",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.3, 1.3, 1.3),
		CFrame = mc * CFrame.new(0, 1.6, -3.5),
		Color = rgb(200, 200, 204),
		Parent = machine,
	})
	local top = part({
		Name = "Top",
		Size = Vector3.new(1, 1, 1),
		CFrame = mc * CFrame.new(0, 16.5, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = machine,
	})
	addLight(glow, "PointLight", { Range = 12, Brightness = 1.2, Color = rgb(255, 255, 255) })
	local machinePrompt = prompt(body, "Tirar color", "Máquina de colores", 12)
	-- Segundo aviso (tecla F) para encender o pausar el Auto-Rolling.
	local autoPrompt = prompt(dispenser, "Activar Auto-Rolling", "Máquina de colores", 12)
	autoPrompt.KeyboardKeyCode = Enum.KeyCode.F
	autoPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	autoPrompt.Enabled = false
	machine.Parent = workshop
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 11, 11),
		CFrame = cylinderUp(mc * CFrame.new(0, 0.26, 0)),
		Color = rgb(214, 214, 210),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = workshop,
	})

	-- Mesa de dibujo: caballete grande, taburete y mesita con pinturas.
	local easelCanvas = buildEasel(workshop, L(23, FLOOR, 6) * CFrame.Angles(0, math.rad(-10), 0), 1.2)
	local drawPart = part({
		Name = "DrawPrompt",
		Size = Vector3.new(4, 4, 2),
		CFrame = L(23, FLOOR + 4, 3.5),
		Transparency = 1,
		CanCollide = false,
		Parent = workshop,
	})
	local drawPrompt = prompt(drawPart, "Pintar un cuadro", "Mesa de dibujo", 12)
	part({
		Size = Vector3.new(14, 0.08, 10),
		CFrame = L(23, FLOOR + 0.25, 4),
		Color = rgb(238, 228, 206),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = workshop,
	})
	local splatRng = Random.new(3)
	for _ = 1, 14 do
		local d = splatRng:NextNumber(0.6, 1.6)
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.05, d, d),
			CFrame = cylinderUp(L(23 + splatRng:NextNumber(-6, 6), FLOOR + 0.3, 4 + splatRng:NextNumber(-4.5, 4.5))),
			Color = RAINBOW[splatRng:NextInteger(1, #RAINBOW)],
			CanCollide = false,
			CastShadow = false,
			Parent = workshop,
		})
	end
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 2.8, 2.8),
		CFrame = cylinderUp(L(23, FLOOR + 3, 1)),
		Color = COLORS.workshopAccent,
		Material = Enum.Material.Leather,
		Parent = workshop,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.8, 0.5, 0.5),
		CFrame = cylinderUp(L(23, FLOOR + 1.5, 1)),
		Color = rgb(60, 50, 80),
		Material = Enum.Material.Metal,
		Parent = workshop,
	})
	part({
		Size = Vector3.new(3, 0.3, 3),
		CFrame = L(30, FLOOR + 3.2, 3),
		Color = COLORS.wood,
		Material = Enum.Material.Wood,
		Parent = workshop,
	})
	part({
		Size = Vector3.new(0.3, 3.2, 0.3),
		CFrame = L(30, FLOOR + 1.6, 3),
		Color = COLORS.darkWood,
		Parent = workshop,
	})
	for i = 0, 2 do
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 0.6, 0.6),
			CFrame = cylinderUp(L(29.2 + i * 0.8, FLOOR + 3.9, 2.4)),
			Color = RAINBOW[i * 2 + 1],
			Parent = workshop,
		})
	end

	-- Banco de trabajo contra la pared de ladrillo.
	part({
		Size = Vector3.new(16, 0.6, 4),
		CFrame = L(18, FLOOR + 4, 14.4),
		Color = COLORS.wood,
		Material = Enum.Material.WoodPlanks,
		Parent = workshop,
	})
	for _, x in ipairs({ 10.6, 25.4 }) do
		part({
			Size = Vector3.new(0.6, 4, 3.4),
			CFrame = L(x, FLOOR + 2, 14.4),
			Color = COLORS.darkWood,
			Material = Enum.Material.Wood,
			Parent = workshop,
		})
	end
	for i = 0, 5 do
		local x = 11.5 + i * 2.4
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 1, 1),
			CFrame = cylinderUp(L(x, FLOOR + 5.1, 14.6)),
			Color = rgb(220, 236, 250),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			Parent = workshop,
		})
		for j = 0, 2 do
			part({
				Size = Vector3.new(0.12, 2.4, 0.12),
				CFrame = L(x - 0.2 + j * 0.2, FLOOR + 5.9, 14.6) * CFrame.Angles(0, 0, math.rad(-8 + j * 8)),
				Color = RAINBOW[(i + j) % #RAINBOW + 1],
				CanCollide = false,
				Parent = workshop,
			})
		end
	end
	for i = 0, 2 do
		part({
			Size = Vector3.new(5 - i * 0.6, 6 - i * 0.6, 0.3),
			CFrame = L(31.5, FLOOR + 3 - i * 0.3, 15.6 - i * 0.5) * CFrame.Angles(math.rad(-8), 0, 0),
			Color = rgb(244, 236, 220),
			Parent = workshop,
		})
	end

	-- Estantes con botes de pintura (muestran tus colores más raros).
	local cans = {}
	for row = 0, 2 do
		part({
			Size = Vector3.new(2.4, 0.4, 16),
			CFrame = L(34, FLOOR + 3 + row * 3.4, -2),
			Color = COLORS.wood,
			Material = Enum.Material.Wood,
			Parent = workshop,
		})
		for i = 0, 7 do
			local shelfCan = part({
				Name = "ShelfCan",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.6, 1.3, 1.3),
				CFrame = cylinderUp(L(34, FLOOR + 3.95 + row * 3.4, -8.2 + i * 1.75)),
				Color = rgb(230, 230, 236),
				Transparency = 0.7,
				Parent = workshop,
			})
			table.insert(cans, shelfCan)
		end
	end
	for _, z in ipairs({ -10.2, 6.2 }) do
		part({
			Size = Vector3.new(2.4, 10.6, 0.4),
			CFrame = L(34, FLOOR + 5.3, z),
			Color = COLORS.darkWood,
			Material = Enum.Material.Wood,
			Parent = workshop,
		})
	end

	-- Lámparas industriales y plantas.
	for _, pos in ipairs({ Vector3.new(6, 0, -4), Vector3.new(22, 0, -4), Vector3.new(14, 0, 8) }) do
		part({
			Size = Vector3.new(0.15, 3.4, 0.15),
			CFrame = L(pos.X, CEILING - 1.7, pos.Z),
			Color = rgb(40, 30, 50),
			CanCollide = false,
			Parent = workshop,
		})
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 3.2, 3.2),
			CFrame = cylinderUp(L(pos.X, CEILING - 4, pos.Z)),
			Color = rgb(52, 60, 70),
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = workshop,
		})
		local bulb = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = L(pos.X, CEILING - 4.9, pos.Z),
			Color = rgb(255, 236, 200),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = workshop,
		})
		addLight(bulb, "PointLight", { Range = 24, Brightness = 1.2, Color = rgb(255, 236, 210), Shadows = true })
	end
	buildPlant(workshop, L(-1.5, FLOOR, 14.5), 1)
	buildPlant(workshop, L(32.5, FLOOR, -14.5), 0.9)
	buildPlant(workshop, L(-1.5, FLOOR, -14.5), 0.9)

	workshop.Parent = model
	return {
		model = workshop,
		easelCanvas = easelCanvas,
		drawPrompt = drawPrompt,
		machinePrompt = machinePrompt,
		autoPrompt = autoPrompt,
		machineTop = top,
		machineCan = can,
		machineGlow = glow,
		machineBalls = balls,
		machineDome = dome,
		shelfCans = cans,
	}
end

-- Exterior: plaza, camino, jardín, calle y bosque -------------------------------------------------
local function buildGrounds(model, L, origin, rng)
	local grounds = Instance.new("Model")
	grounds.Name = "Grounds"

	-- Plaza de losas grandes frente al edificio y camino hasta la verja.
	part({
		Size = Vector3.new(86, 0.3, 28),
		CFrame = L(-2, 0.15, -34),
		Color = COLORS.path,
		Material = Enum.Material.Pavement,
		Parent = grounds,
	})
	for x = -42, 38, 6 do
		part({
			Size = Vector3.new(0.12, 0.31, 28),
			CFrame = L(x + 3, 0.16, -34),
			Color = rgb(190, 188, 182),
			CanCollide = false,
			CastShadow = false,
			Parent = grounds,
		})
	end
	part({
		Size = Vector3.new(88, 0.32, 1.2),
		CFrame = L(-2, 0.16, -48.4),
		Color = COLORS.stone,
		Material = Enum.Material.Concrete,
		Parent = grounds,
	})
	part({
		Size = Vector3.new(8, 0.3, 56),
		CFrame = L(-22, 0.15, -76),
		Color = COLORS.path,
		Material = Enum.Material.Pavement,
		Parent = grounds,
	})
	buildFountain(grounds, L(8, 0.3, -34))
	for _, pos in ipairs({ { -36, -42 }, { 24, -44 } }) do
		buildBench(grounds, L(pos[1], 0.3, pos[2]) * CFrame.Angles(0, math.pi, 0))
	end

	-- Farolas a lo largo del camino y la plaza.
	for z = -96, -54, 14 do
		buildLampPost(grounds, L(-27.5, 0.3, z))
		buildLampPost(grounds, L(-16.5, 0.3, z))
	end
	for _, x in ipairs({ -43, 39 }) do
		buildLampPost(grounds, L(x, 0.3, -46))
	end

	-- Jardineras y arbustos alrededor de la plaza.
	buildFlowerBed(grounds, L(-38, 0.3, -30), 6, 5, rng)
	buildFlowerBed(grounds, L(30, 0.3, -28), 6, 4, rng)
	for _, pos in ipairs({ { -46, -24 }, { 42, -22 }, { -46, 14 }, { 42, 14 }, { -48, -5 }, { 44, -5 } }) do
		buildBush(grounds, L(pos[1], 0, pos[2]), 1.2)
	end

	-- Seto que rodea el terreno con una verja en el camino.
	local hedgeH = 5
	local half = 104
	local function hedge(axis, fixed, a, b)
		if b - a > 0.5 then
			local center = (a + b) / 2
			local cf = axis == "z" and L(center, hedgeH / 2, fixed) or L(fixed, hedgeH / 2, center)
			local size = axis == "z" and Vector3.new(b - a, hedgeH, 3.5) or Vector3.new(3.5, hedgeH, b - a)
			part({
				Size = size,
				CFrame = cf,
				Color = COLORS.hedge,
				Material = Enum.Material.LeafyGrass,
				Parent = grounds,
			})
		end
	end
	for _, side in ipairs({ { "x", -half }, { "x", half }, { "z", -half }, { "z", half } }) do
		local axis, fixed = side[1], side[2]
		local from = -half
		while from < half do
			local to = math.min(from + 26, half)
			if axis == "z" and fixed == -half and from < -17 and to > -27 then
				hedge(axis, fixed, from, -30)
				hedge(axis, fixed, -14, to)
			else
				hedge(axis, fixed, from, to)
			end
			from = to
		end
	end
	-- Pilares de la verja con faroles y arco con el nombre.
	for _, x in ipairs({ -28.5, -15.5 }) do
		part({
			Size = Vector3.new(2.6, 10, 2.6),
			CFrame = L(x, 5, -half),
			Color = COLORS.stone,
			Material = Enum.Material.Concrete,
			Parent = grounds,
		})
		local lantern = part({
			Size = Vector3.new(2.7, 0.3, 2.7),
			CFrame = L(x, 10.15, -half),
			Color = rgb(255, 236, 206),
			Material = Enum.Material.Neon,
			Parent = grounds,
		})
		addLight(lantern, "PointLight", { Range = 14, Brightness = 0.9, Color = rgb(255, 226, 190) })
	end
	part({
		Size = Vector3.new(15.6, 2, 0.6),
		CFrame = L(-22, 11.3, -half),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = grounds,
	})
	local gateSign = part({
		Size = Vector3.new(15, 1.6, 0.2),
		CFrame = L(-22, 11.3, -half - 0.35),
		Color = COLORS.charcoal,
		Material = Enum.Material.Metal,
		Parent = grounds,
	})
	local gateLabel = surfaceText(
		gateSign,
		Enum.NormalId.Front,
		"Galería",
		{ pps = 24, color = rgb(255, 255, 255), font = Enum.Font.BuilderSansBold }
	)

	-- Calle y aceras por donde llegan los visitantes.
	part({
		Size = Vector3.new(420, 0.3, 6),
		CFrame = L(0, 0.15, -110),
		Color = rgb(214, 210, 204),
		Material = Enum.Material.Pavement,
		Parent = grounds,
	})
	part({
		Size = Vector3.new(420, 0.25, 16),
		CFrame = L(0, 0.12, -121),
		Color = COLORS.asphalt,
		Material = Enum.Material.Asphalt,
		Parent = grounds,
	})
	for x = -204, 204, 12 do
		part({
			Size = Vector3.new(5, 0.27, 0.5),
			CFrame = L(x, 0.14, -121),
			Color = rgb(250, 220, 90),
			CanCollide = false,
			Parent = grounds,
		})
	end
	part({
		Size = Vector3.new(420, 0.3, 6),
		CFrame = L(0, 0.15, -132),
		Color = rgb(214, 210, 204),
		Material = Enum.Material.Pavement,
		Parent = grounds,
	})

	-- Estanque con rocas y bancos.
	local terrain = Workspace.Terrain
	local pondCenter = origin + Vector3.new(66, 0, -66)
	terrain:FillCylinder(CFrame.new(pondCenter + Vector3.new(0, -2, 0)), 4, 15, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(pondCenter + Vector3.new(0, -2.5, 0)), 3, 15, Enum.Material.Water)
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		terrain:FillBall(
			pondCenter + Vector3.new(math.cos(angle) * 16, -0.5, math.sin(angle) * 16),
			rng:NextNumber(2, 3.2),
			Enum.Material.Rock
		)
	end
	buildBench(grounds, CFrame.new(pondCenter + Vector3.new(0, 0, 21)) * CFrame.Angles(0, math.pi, 0))
	buildBench(grounds, CFrame.new(pondCenter + Vector3.new(-21, 0, 0)) * CFrame.Angles(0, -math.pi / 2, 0))
	for i = 1, 3 do
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 2.6, 2.6),
			CFrame = cylinderUp(CFrame.new(pondCenter + Vector3.new(-6 + i * 4, -0.4, -4 + i * 2.5))),
			Color = rgb(110, 190, 100),
			CanCollide = false,
			Parent = grounds,
		})
	end

	-- Árboles dentro del terreno y bosque alrededor.
	local inside = {
		{ -78, -70 },
		{ -70, -30 },
		{ -85, 10 },
		{ -66, 50 },
		{ -30, 72 },
		{ 10, 80 },
		{ 52, 60 },
		{ 82, 30 },
		{ 88, -10 },
		{ -50, 88 },
		{ 30, -86 },
		{ 75, -95 },
		{ -60, -92 },
	}
	for i, pos in ipairs(inside) do
		buildTree(grounds, L(pos[1], 0, pos[2]), rng:NextNumber(1, 1.4), rng, i % 4 == 0)
	end
	for i = 1, 46 do
		local angle = i / 46 * math.pi * 2
		local radius = rng:NextNumber(118, 175)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		if z > -100 or z < -140 then
			buildTree(grounds, L(x, 0, z), rng:NextNumber(1.2, 1.8), rng, i % 5 == 0)
		end
	end

	grounds.Parent = model
	return gateLabel
end

-- Terreno (césped y colinas) -------------------------------------------------------------------
local function fillTerrain(origin, rng)
	local terrain = Workspace.Terrain
	terrain:FillBlock(CFrame.new(origin + Vector3.new(0, -8, 0)), Vector3.new(440, 16, 440), Enum.Material.Grass)
	for i = 1, 18 do
		local angle = i / 18 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local radius = rng:NextNumber(190, 215)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		-- Sin colinas sobre la calle.
		if z > -70 or z < -175 then
			terrain:FillBall(origin + Vector3.new(x, -10, z), rng:NextNumber(26, 40), Enum.Material.Grass)
		end
	end
end

local function clearTerrain(origin)
	Workspace.Terrain:FillBlock(
		CFrame.new(origin + Vector3.new(0, 10, 0)),
		Vector3.new(500, 80, 500),
		Enum.Material.Air
	)
end

-- API ----------------------------------------------------------------------------------------------
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

function WorldBuilder.setOwnerName(plot, name)
	plot.signLabel.Text = "Galería de " .. name
	plot.gateLabel.Text = "Galería de " .. name
end

-- Plataforma de aparición: los personajes nacen aquí un instante y el servidor
-- los lleva enseguida a su propio terreno (la pantalla de carga lo tapa).
function WorldBuilder.buildSpawn()
	setupLighting()
	if Workspace:FindFirstChild("Llegada") then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "Llegada"
	part({
		Name = "Base",
		Size = Vector3.new(60, 2, 60),
		CFrame = CFrame.new(0, 199, 0),
		Color = COLORS.cream,
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	local spawn = part({
		Class = "SpawnLocation",
		Name = "Aparicion",
		Size = Vector3.new(12, 1, 12),
		CFrame = CFrame.new(0, 200.5, 0),
		Color = COLORS.charcoal,
		Neutral = true,
		Duration = 0,
		Parent = folder,
	})
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	folder.Parent = Workspace
end

function WorldBuilder.buildLot(slot)
	setupLighting()
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		plotsFolder = Instance.new("Folder")
		plotsFolder.Name = "Plots"
		plotsFolder.Parent = Workspace
	end

	local origin = Vector3.new(slot * LOT_SPACING, 0, 0)
	local function L(x, y, z)
		return CFrame.new(origin + Vector3.new(x, y, z))
	end
	local rng = Random.new(slot * 7919 + 13)
	fillTerrain(origin, rng)

	local model = Instance.new("Model")
	model.Name = "Lot" .. slot
	model:SetAttribute("Slot", slot)
	model:SetAttribute("OwnerUserId", 0)
	model.WorldPivot = CFrame.new(origin)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	end)

	local signLabel = buildBuilding(model, L)
	buildGalleryInterior(model, L)
	local workshop = buildWorkshop(model, L)
	local gateLabel = buildGrounds(model, L, origin, rng)

	local gallery = Instance.new("Folder")
	gallery.Name = "Gallery"
	gallery.Parent = model
	local y = FLOOR + 10.5
	local frameCFrames = {
		L(-34, y, 16.6),
		L(-22, y, 16.6),
		L(-10, y, 16.6),
		L(-38.6, y, 7) * CFrame.Angles(0, -math.pi / 2, 0),
		L(-38.6, y, -5) * CFrame.Angles(0, -math.pi / 2, 0),
		L(-5.4, y, 11) * CFrame.Angles(0, math.pi / 2, 0),
		L(-5.4, y, 1) * CFrame.Angles(0, math.pi / 2, 0),
	}
	local canvases, plaques, standPoints, hangPrompts, takePrompts = {}, {}, {}, {}, {}
	for i = 1, Config.GALLERY_SIZE do
		canvases[i], plaques[i], hangPrompts[i], takePrompts[i] = buildFrame(gallery, frameCFrames[i], "Frame" .. i)
		canvases[i]:SetAttribute("Slot", i)
		-- Dónde se para un visitante para mirar el cuadro.
		local front = frameCFrames[i] * CFrame.new(0, 0, -7)
		standPoints[i] = CFrame.lookAt(
			Vector3.new(front.X, FLOOR, front.Z),
			Vector3.new(frameCFrames[i].X, FLOOR, frameCFrames[i].Z)
		)
	end

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	local visitors = Instance.new("Folder")
	visitors.Name = "Visitors"
	visitors.Parent = model

	model.Parent = plotsFolder

	return {
		index = slot,
		slot = slot,
		model = model,
		origin = origin,
		L = L,
		signLabel = signLabel,
		gateLabel = gateLabel,
		canvases = canvases,
		plaques = plaques,
		hangPrompts = hangPrompts,
		takePrompts = takePrompts,
		standPoints = standPoints,
		-- Recorrido de los visitantes: de la acera a la galería y de vuelta.
		route = {
			L(-90, 0.3, -110),
			L(-22, 0.3, -110),
			L(-22, 0.3, -80),
			L(-22, 0.3, -50),
			L(-22, 0.3, -26),
			L(-22, FLOOR, -12),
			L(-22, FLOOR, -5),
		},
		exitRoute = {
			L(-22, FLOOR, -12),
			L(-22, 0.3, -26),
			L(-22, 0.3, -50),
			L(-22, 0.3, -80),
			L(-22, 0.3, -110),
			L(90, 0.3, -110),
		},
		-- Apareces dentro del taller, entre la máquina y el caballete.
		ownerSpawn = CFrame.lookAt(
			origin + Vector3.new(15, FLOOR + 3.5, -3),
			origin + Vector3.new(15, FLOOR + 3.5, 10)
		),
		decorFolder = decor,
		visitorsFolder = visitors,
		workshop = workshop,
		decorBuilt = 0,
	}
end

function WorldBuilder.destroyLot(plot)
	plot.model:Destroy()
	clearTerrain(plot.origin)
end

return WorldBuilder
