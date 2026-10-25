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
	plaster = rgb(250, 242, 230),
	plasterShade = rgb(236, 224, 208),
	trim = rgb(255, 252, 246),
	stone = rgb(196, 186, 172),
	roof = rgb(178, 96, 78),
	roofRidge = rgb(140, 70, 58),
	galleryFloor = rgb(176, 122, 82),
	workshopFloor = rgb(226, 204, 170),
	wainscot = rgb(122, 92, 150),
	galleryAccent = rgb(236, 92, 140),
	workshopAccent = rgb(40, 180, 160),
	wood = rgb(196, 140, 96),
	darkWood = rgb(110, 72, 48),
	gold = rgb(240, 190, 70),
	brass = rgb(214, 170, 90),
	cream = rgb(255, 248, 236),
	glass = rgb(200, 232, 255),
	leaf = rgb(96, 176, 90),
	hedge = rgb(70, 140, 76),
	path = rgb(228, 214, 190),
	asphalt = rgb(70, 72, 82),
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
	Lighting.Ambient = rgb(118, 108, 128)
	Lighting.OutdoorAmbient = rgb(150, 145, 165)
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
	atmosphere.Color = rgb(206, 196, 236)
	atmosphere.Decay = rgb(150, 130, 190)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.5
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.16
	color.Contrast = 0.07
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
		clouds.Color = rgb(255, 250, 255)
		clouds.Parent = terrain
	end
end

-- Elementos reutilizables ------------------------------------------------------------------
local function buildTree(parent, cf, scale, rng, pink)
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
	local base = pink and rgb(255, 172, 204) or COLORS.leaf
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
	local dark = rgb(54, 50, 70)
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 2.2, 2.2),
		CFrame = cylinderUp(cf * CFrame.new(0, 0.4, 0)),
		Color = dark,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(11, 0.6, 0.6),
		CFrame = cylinderUp(cf * CFrame.new(0, 6, 0)),
		Color = dark,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	part({
		Size = Vector3.new(1.8, 0.3, 1.8),
		CFrame = cf * CFrame.new(0, 11.6, 0),
		Color = dark,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	part({
		Size = Vector3.new(1.4, 1.8, 1.4),
		CFrame = cf * CFrame.new(0, 12.7, 0),
		Color = rgb(255, 236, 196),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CanCollide = false,
		Parent = parent,
	})
	local bulb = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9, 0.9, 0.9),
		CFrame = cf * CFrame.new(0, 12.7, 0),
		Color = rgb(255, 226, 170),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	part({
		Class = "WedgePart",
		Size = Vector3.new(2, 0.6, 1),
		CFrame = cf * CFrame.new(0, 13.9, -0.5),
		Color = dark,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	part({
		Class = "WedgePart",
		Size = Vector3.new(2, 0.6, 1),
		CFrame = cf * CFrame.new(0, 13.9, 0.5) * CFrame.Angles(0, math.pi, 0),
		Color = dark,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	addLight(bulb, "PointLight", { Range = 16, Brightness = 1.2, Color = rgb(255, 214, 160), Shadows = false })
end

local function buildBench(parent, cf)
	local slats = rgb(176, 120, 80)
	local metal = rgb(54, 50, 70)
	for i = 0, 2 do
		part({
			Size = Vector3.new(6, 0.3, 0.6),
			CFrame = cf * CFrame.new(0, 1.9, -0.7 + i * 0.7),
			Color = slats,
			Material = Enum.Material.Wood,
			Parent = parent,
		})
	end
	for i = 0, 1 do
		part({
			Size = Vector3.new(6, 0.5, 0.25),
			CFrame = cf * CFrame.new(0, 2.7 + i * 0.7, 1.05) * CFrame.Angles(math.rad(-10), 0, 0),
			Color = slats,
			Material = Enum.Material.Wood,
			Parent = parent,
		})
	end
	for _, x in ipairs({ -2.6, 2.6 }) do
		part({
			Size = Vector3.new(0.3, 1.8, 2.2),
			CFrame = cf * CFrame.new(x, 0.9, 0),
			Color = metal,
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		part({
			Size = Vector3.new(0.3, 1.6, 0.3),
			CFrame = cf * CFrame.new(x, 2.9, 1.1),
			Color = metal,
			Material = Enum.Material.Metal,
			Parent = parent,
		})
	end
end

local function buildFlowerBed(parent, cf, width, depth, rng)
	part({
		Size = Vector3.new(width + 0.8, 1, depth + 0.8),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = COLORS.stone,
		Material = Enum.Material.Limestone,
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
			Color = RAINBOW[rng:NextInteger(1, #RAINBOW)],
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
		Color = rgb(226, 132, 100),
		Material = Enum.Material.Plaster,
		Parent = parent,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4 * scale, 2.9 * scale, 2.9 * scale),
		CFrame = cylinderUp(cf * CFrame.new(0, 2.6 * scale, 0)),
		Color = rgb(206, 112, 84),
		Material = Enum.Material.Plaster,
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
	local stone = rgb(240, 236, 228)
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 15, 15),
		CFrame = cylinderUp(cf * CFrame.new(0, 1, 0)),
		Color = stone,
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 13, 13),
		CFrame = cylinderUp(cf * CFrame.new(0, 1.85, 0)),
		Color = rgb(110, 200, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CanCollide = false,
		Parent = parent,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5, 2.2, 2.2),
		CFrame = cylinderUp(cf * CFrame.new(0, 4, 0)),
		Color = stone,
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 7, 7),
		CFrame = cylinderUp(cf * CFrame.new(0, 6.6, 0)),
		Color = stone,
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, 6, 6),
		CFrame = cylinderUp(cf * CFrame.new(0, 7, 0)),
		Color = rgb(110, 200, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CanCollide = false,
		Parent = parent,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.6, 1.2, 1.2),
		CFrame = cylinderUp(cf * CFrame.new(0, 8.3, 0)),
		Color = stone,
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	local top = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 1.6, 1.6),
		CFrame = cf * CFrame.new(0, 10, 0),
		Color = rgb(120, 210, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CanCollide = false,
		Parent = parent,
	})
	local water = Instance.new("ParticleEmitter")
	water.Rate = 30
	water.Lifetime = NumberRange.new(0.8, 1.1)
	water.Speed = NumberRange.new(6, 8)
	water.SpreadAngle = Vector2.new(25, 25)
	water.Acceleration = Vector3.new(0, -18, 0)
	water.LightEmission = 0.3
	water.Transparency = NumberSequence.new(0.3, 1)
	water.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.15) })
	water.Color = ColorSequence.new(rgb(200, 240, 255), rgb(140, 210, 255))
	water.EmissionDirection = Enum.NormalId.Top
	water.Parent = top
end

-- Cuadro enmarcado de la galería.
local function buildFrame(parent, cf, name)
	local frame = Instance.new("Model")
	frame.Name = name
	part({
		Size = Vector3.new(8.2, 8.2, 0.5),
		CFrame = cf,
		Color = COLORS.gold,
		Material = Enum.Material.Metal,
		Reflectance = 0.08,
		Parent = frame,
	})
	part({
		Size = Vector3.new(7.4, 7.4, 0.2),
		CFrame = cf * CFrame.new(0, 0, -0.3),
		Color = rgb(250, 248, 242),
		Parent = frame,
	})
	local canvas = part({
		Name = "Canvas",
		Size = Vector3.new(6.2, 6.2, 0.2),
		CFrame = cf * CFrame.new(0, 0, -0.42),
		Color = COLORS.cream,
		Parent = frame,
	})
	local plaque = part({
		Name = "Plaque",
		Size = Vector3.new(4.8, 0.9, 0.15),
		CFrame = cf * CFrame.new(0, -4.8, -0.1),
		Color = rgb(44, 38, 58),
		Material = Enum.Material.Metal,
		Parent = frame,
	})
	local plaqueLabel = surfaceText(
		plaque,
		Enum.NormalId.Front,
		"",
		{ pps = 60, color = COLORS.gold, font = Enum.Font.BuilderSansBold }
	)
	plaqueLabel.Name = "PlaqueText"
	part({
		Size = Vector3.new(3.4, 0.25, 0.25),
		CFrame = cf * CFrame.new(0, 4.7, -0.6),
		Color = COLORS.brass,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = frame,
	})
	local lamp = part({
		Size = Vector3.new(3, 0.35, 0.5),
		CFrame = cf * CFrame.new(0, 4.95, -1),
		Color = COLORS.brass,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = frame,
	})
	addLight(
		lamp,
		"SpotLight",
		{ Face = Enum.NormalId.Bottom, Angle = 75, Range = 11, Brightness = 2.4, Color = rgb(255, 238, 214) }
	)
	frame.Parent = parent
	return canvas, plaqueLabel
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

-- Marco blanco alrededor de una ventana o puerta en una pared paralela a X.
local function trimX(parent, L, z, a, b, y0, y1, depth, withSill)
	local t = 0.7
	part({
		Size = Vector3.new(b - a + t * 2, t, depth),
		CFrame = L((a + b) / 2, y1 + t / 2, z),
		Color = COLORS.trim,
		Parent = parent,
	})
	part({
		Size = Vector3.new(t, y1 - y0, depth),
		CFrame = L(a - t / 2, (y0 + y1) / 2, z),
		Color = COLORS.trim,
		Parent = parent,
	})
	part({
		Size = Vector3.new(t, y1 - y0, depth),
		CFrame = L(b + t / 2, (y0 + y1) / 2, z),
		Color = COLORS.trim,
		Parent = parent,
	})
	if withSill then
		part({
			Size = Vector3.new(b - a + t * 3, 0.5, depth + 0.6),
			CFrame = L((a + b) / 2, y0 - 0.25, z),
			Color = COLORS.trim,
			Parent = parent,
		})
	end
end

local function windowX(parent, L, z, a, b, y0, y1, mullions)
	part({
		Size = Vector3.new(b - a, y1 - y0, 0.3),
		CFrame = L((a + b) / 2, (y0 + y1) / 2, z),
		Color = COLORS.glass,
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		Parent = parent,
	})
	for i = 1, mullions do
		local x = a + (b - a) * i / (mullions + 1)
		part({
			Size = Vector3.new(0.35, y1 - y0, 0.5),
			CFrame = L(x, (y0 + y1) / 2, z),
			Color = COLORS.trim,
			CanCollide = false,
			Parent = parent,
		})
	end
	part({
		Size = Vector3.new(b - a, 0.35, 0.5),
		CFrame = L((a + b) / 2, y0 + (y1 - y0) * 0.62, z),
		Color = COLORS.trim,
		CanCollide = false,
		Parent = parent,
	})
end

-- Decoraciones que aparecen con la mejora "Decoración" ----------------------------------------
local DECOR_BUILDERS = {
	function(folder, L)
		buildPlant(folder, L(-33, 0.3, -24), 1.1)
		buildPlant(folder, L(-11, 0.3, -24), 1.1)
	end,
	function(folder, L)
		part({
			Size = Vector3.new(5, 0.12, 20),
			CFrame = L(-22, FLOOR + 0.27, -8),
			Color = rgb(196, 36, 64),
			Material = Enum.Material.Carpet,
			CanCollide = false,
			Parent = folder,
		})
		for _, x in ipairs({ -24.6, -19.4 }) do
			part({
				Size = Vector3.new(0.25, 0.14, 20),
				CFrame = L(x, FLOOR + 0.28, -8),
				Color = COLORS.gold,
				Material = Enum.Material.Fabric,
				CanCollide = false,
				Parent = folder,
			})
		end
		part({
			Size = Vector3.new(5, 0.12, 22),
			CFrame = L(-22, 0.36, -36),
			Color = rgb(196, 36, 64),
			Material = Enum.Material.Carpet,
			CanCollide = false,
			Parent = folder,
		})
	end,
	function(folder, L)
		part({
			Size = Vector3.new(4, 3, 4),
			CFrame = L(30, 1.8, -36),
			Color = rgb(240, 236, 228),
			Material = Enum.Material.Marble,
			Parent = folder,
		})
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(9, 1.2, 1.2),
			CFrame = cylinderUp(L(30.6, 7.8, -36) * CFrame.Angles(0, 0, math.rad(-12))),
			Color = COLORS.galleryAccent,
			Parent = folder,
		})
		local tip = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 2.6, 2.6),
			CFrame = L(31.6, 13, -36),
			Color = rgb(150, 110, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Rate = 8
		sparkles.Lifetime = NumberRange.new(1.5, 2.5)
		sparkles.Speed = NumberRange.new(1, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Color = ColorSequence.new(rgb(255, 160, 220), rgb(160, 220, 255))
		sparkles.Parent = tip
	end,
	function(folder, L)
		for i = 0, 38 do
			local x = -40 + i * 2
			local bulb = part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.7, 0.7, 0.7),
				CFrame = L(x, 20.4 - math.sin(i * 0.5) ^ 2 * 0.7, -19.2),
				Color = RAINBOW[i % #RAINBOW + 1],
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
			if i % 6 == 0 then
				addLight(bulb, "PointLight", { Range = 8, Brightness = 0.7, Color = bulb.Color })
			end
		end
	end,
	function(folder, L)
		local c = L(-22, 0, 2)
		part({
			Size = Vector3.new(0.2, 3, 0.2),
			CFrame = c * CFrame.new(0, CEILING - 1.5, 0),
			Color = COLORS.gold,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = folder,
		})
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 6, 6),
			CFrame = cylinderUp(c * CFrame.new(0, CEILING - 3.2, 0)),
			Color = COLORS.gold,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = folder,
		})
		for i = 1, 10 do
			local angle = i / 10 * math.pi * 2
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.8, 0.8, 0.8),
				CFrame = c * CFrame.new(math.cos(angle) * 3, CEILING - 3.6, math.sin(angle) * 3),
				Color = rgb(230, 244, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
		end
		local core = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 1.6, 1.6),
			CFrame = c * CFrame.new(0, CEILING - 4.2, 0),
			Color = rgb(210, 236, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.2,
			CanCollide = false,
			Parent = folder,
		})
		addLight(core, "PointLight", { Range = 26, Brightness = 1.2, Color = rgb(236, 244, 255) })
	end,
	function(folder, L)
		local index = 0
		for step = 0, 16 do
			local angle = math.pi * step / 16
			index += 1
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.5, 1.5, 1.5),
				CFrame = L(-22 + math.cos(angle) * 6.6, 9 + math.sin(angle) * 6, -24.6),
				Color = RAINBOW[index % #RAINBOW + 1],
				Reflectance = 0.15,
				CanCollide = false,
				Parent = folder,
			})
		end
		for _, x in ipairs({ -28.6, -15.4 }) do
			for y = 1.6, 8.6, 1.4 do
				index += 1
				part({
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.5, 1.5, 1.5),
					CFrame = L(x, y, -24.6),
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

-- Edificio -----------------------------------------------------------------------------------
local function buildBuilding(model, L)
	local building = Instance.new("Model")
	building.Name = "Building"
	local plaster = Enum.Material.Plaster

	-- Cimientos y suelos.
	part({
		Size = Vector3.new(80, FLOOR, 40),
		CFrame = L(-2, FLOOR / 2, 0),
		Color = COLORS.stone,
		Material = Enum.Material.Limestone,
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
		Material = Enum.Material.WoodPlanks,
		Parent = building,
	})

	-- Fachada delantera: puerta de la galería, escaparates, ventanal y puerta del taller.
	local frontOpenings = {
		{ -27, -17, FLOOR, FLOOR + 12 },
		{ -37, -30, FLOOR + 4, FLOOR + 14 },
		{ -14, -7, FLOOR + 4, FLOOR + 14 },
		{ 1, 20, FLOOR + 4, FLOOR + 14 },
		{ 25, 31, FLOOR, FLOOR + 11 },
	}
	wall(building, L, "x", -17.5, -40, 36, FLOOR, CEILING, 1, frontOpenings, COLORS.plaster, plaster)
	-- Zócalo de piedra exterior (se corta en las puertas).
	wall(
		building,
		L,
		"x",
		-18.2,
		-40.4,
		36.4,
		FLOOR,
		FLOOR + 3,
		0.5,
		{ { -27, -17, 0, 99 }, { 25, 31, 0, 99 } },
		COLORS.stone,
		Enum.Material.Limestone
	)
	for _, o in ipairs(frontOpenings) do
		trimX(building, L, -18.1, o[1], o[2], o[3], o[4], 0.6, o[3] > FLOOR)
	end
	windowX(building, L, -17.5, -37, -30, FLOOR + 4, FLOOR + 14, 1)
	windowX(building, L, -17.5, -14, -7, FLOOR + 4, FLOOR + 14, 1)
	windowX(building, L, -17.5, 1, 20, FLOOR + 4, FLOOR + 14, 3)

	-- Paredes laterales, trasera y tabique entre galería y taller (con puerta).
	wall(
		building,
		L,
		"x",
		17.5,
		-40,
		36,
		FLOOR,
		CEILING,
		1,
		{ { -2, 10, FLOOR + 6, FLOOR + 14 } },
		COLORS.plaster,
		plaster
	)
	windowX(building, L, 17.5, -2, 10, FLOOR + 6, FLOOR + 14, 1)
	wall(building, L, "z", -39.5, -17, 17, FLOOR, CEILING, 1, {}, COLORS.plaster, plaster)
	wall(building, L, "z", 35.5, -17, 17, FLOOR, CEILING, 1, {}, COLORS.plaster, plaster)
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
	part({
		Size = Vector3.new(1.4, 0.7, 10.4),
		CFrame = L(-4.5, FLOOR + 12.35, -10.5),
		Color = COLORS.trim,
		Parent = building,
	})

	-- Pared de ladrillo del taller (interior).
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
		rgb(196, 112, 86),
		Enum.Material.Brick
	)

	-- Zócalos interiores de la galería (madera pintada) con moldura.
	local wainscotH = 5
	for _, data in ipairs({
		{ Vector3.new(34, wainscotH, 0.3), L(-22, FLOOR + wainscotH / 2, 16.85), Vector3.new(34, 0.4, 0.6) },
		{ Vector3.new(0.3, wainscotH, 34), L(-38.85, FLOOR + wainscotH / 2, 0), Vector3.new(0.6, 0.4, 34) },
		{ Vector3.new(0.3, wainscotH, 21), L(-5.15, FLOOR + wainscotH / 2, 6.5), Vector3.new(0.6, 0.4, 21) },
	}) do
		part({
			Size = data[1],
			CFrame = data[2],
			Color = COLORS.wainscot,
			Material = Enum.Material.Wood,
			Parent = building,
		})
		part({
			Size = data[3],
			CFrame = data[2] * CFrame.new(0, wainscotH / 2 + 0.2, 0),
			Color = COLORS.trim,
			Parent = building,
		})
	end
	-- Techos interiores, cornisa y pilastras de las esquinas.
	part({
		Size = Vector3.new(76, 0.4, 36),
		CFrame = L(-2, CEILING + 0.2, 0),
		Color = rgb(255, 254, 250),
		Material = plaster,
		Parent = building,
	})
	for _, z in ipairs({ -18.4, 18.4 }) do
		part({
			Size = Vector3.new(78, 1.2, 1),
			CFrame = L(-2, CEILING - 0.6, z),
			Color = COLORS.trim,
			Parent = building,
		})
	end
	for _, x in ipairs({ -40.4, 36.4 }) do
		part({ Size = Vector3.new(1, 1.2, 38), CFrame = L(x, CEILING - 0.6, 0), Color = COLORS.trim, Parent = building })
		for _, z in ipairs({ -18, 18 }) do
			part({
				Size = Vector3.new(1.6, CEILING - FLOOR, 1.6),
				CFrame = L(x, (FLOOR + CEILING) / 2, z),
				Color = COLORS.trim,
				Parent = building,
			})
		end
	end

	-- Tejado a dos aguas con tejas de arcilla.
	local roofH = 10
	part({
		Class = "WedgePart",
		Size = Vector3.new(82, roofH, 21),
		CFrame = L(-2, CEILING + 0.4 + roofH / 2, -10.5),
		Color = COLORS.roof,
		Material = Enum.Material.ClayRoofTiles,
		Parent = building,
	})
	part({
		Class = "WedgePart",
		Size = Vector3.new(82, roofH, 21),
		CFrame = L(-2, CEILING + 0.4 + roofH / 2, 10.5) * CFrame.Angles(0, math.pi, 0),
		Color = COLORS.roof,
		Material = Enum.Material.ClayRoofTiles,
		Parent = building,
	})
	part({
		Size = Vector3.new(82.4, 0.8, 1.6),
		CFrame = L(-2, CEILING + 0.6 + roofH, 0),
		Color = COLORS.roofRidge,
		Material = Enum.Material.ClayRoofTiles,
		Parent = building,
	})
	-- Chimenea del taller.
	part({
		Size = Vector3.new(4, 12, 4),
		CFrame = L(26, CEILING + 8, 8),
		Color = rgb(180, 100, 80),
		Material = Enum.Material.Brick,
		Parent = building,
	})
	part({
		Size = Vector3.new(4.8, 0.8, 4.8),
		CFrame = L(26, CEILING + 14.2, 8),
		Color = COLORS.stone,
		Material = Enum.Material.Limestone,
		Parent = building,
	})

	-- Entrada de la galería: columnas, marquesina y letrero.
	for _, x in ipairs({ -29, -15 }) do
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(14, 1.8, 1.8),
			CFrame = cylinderUp(L(x, FLOOR + 7, -21.5)),
			Color = rgb(250, 248, 244),
			Material = Enum.Material.Marble,
			Parent = building,
		})
		part({
			Size = Vector3.new(2.6, 0.8, 2.6),
			CFrame = L(x, FLOOR + 0.4, -21.5),
			Color = rgb(250, 248, 244),
			Material = Enum.Material.Marble,
			Parent = building,
		})
		part({
			Size = Vector3.new(2.6, 0.8, 2.6),
			CFrame = L(x, FLOOR + 13.6, -21.5),
			Color = rgb(250, 248, 244),
			Material = Enum.Material.Marble,
			Parent = building,
		})
	end
	part({
		Size = Vector3.new(17, 1, 6.5),
		CFrame = L(-22, FLOOR + 14.5, -20.75),
		Color = COLORS.trim,
		Parent = building,
	})
	part({
		Size = Vector3.new(15.6, 3.2, 0.3),
		CFrame = L(-22, FLOOR + 16.4, -23.4),
		Color = COLORS.gold,
		Material = Enum.Material.Metal,
		Parent = building,
	})
	local gallerySign = part({
		Size = Vector3.new(15, 2.6, 0.4),
		CFrame = L(-22, FLOOR + 16.4, -23.6),
		Color = COLORS.galleryAccent,
		Parent = building,
	})
	surfaceText(
		gallerySign,
		Enum.NormalId.Front,
		"GALERÍA",
		{ pps = 30, color = rgb(255, 255, 255), font = Enum.Font.BuilderSansExtraBold }
	)

	-- Toldo del taller.
	for i = 0, 4 do
		local stripe = (i % 2 == 0) and COLORS.workshopAccent or rgb(255, 255, 255)
		part({
			Size = Vector3.new(4.2, 0.3, 4.6),
			CFrame = L(2.6 + i * 4.2, FLOOR + 15.2, -19.9) * CFrame.Angles(math.rad(-26), 0, 0),
			Color = stripe,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = building,
		})
		part({
			Size = Vector3.new(4.2, 0.9, 0.2),
			CFrame = L(2.6 + i * 4.2, FLOOR + 13.75, -22),
			Color = stripe,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = building,
		})
	end
	local workshopSign = part({
		Size = Vector3.new(12, 2.4, 0.4),
		CFrame = L(10.5, FLOOR + 17.4, -18.4),
		Color = COLORS.workshopAccent,
		Parent = building,
	})
	surfaceText(
		workshopSign,
		Enum.NormalId.Front,
		"TALLER",
		{ pps = 30, color = rgb(255, 255, 255), font = Enum.Font.BuilderSansExtraBold }
	)

	-- Letrero grande con el nombre del dueño sobre el tejado.
	part({
		Size = Vector3.new(34, 6, 0.8),
		CFrame = L(-2, CEILING + 4, -19.6),
		Color = rgb(52, 44, 72),
		Parent = building,
	})
	local ownerSign = part({
		Name = "OwnerSign",
		Size = Vector3.new(33, 5.2, 0.3),
		CFrame = L(-2, CEILING + 4, -20.1),
		Color = rgb(60, 50, 84),
		Parent = building,
	})
	local ownerLabel = surfaceText(
		ownerSign,
		Enum.NormalId.Front,
		"Galería",
		{ pps = 26, color = rgb(255, 246, 226), stroke = COLORS.galleryAccent, strokeThickness = 3 }
	)
	for _, data in ipairs({
		{ Vector3.new(34.4, 0.35, 0.35), CFrame.new(0, 3.1, 0) },
		{ Vector3.new(34.4, 0.35, 0.35), CFrame.new(0, -3.1, 0) },
		{ Vector3.new(0.35, 6.5, 0.35), CFrame.new(17.1, 0, 0) },
		{ Vector3.new(0.35, 6.5, 0.35), CFrame.new(-17.1, 0, 0) },
	}) do
		part({
			Size = data[1],
			CFrame = L(-2, CEILING + 4, -20.2) * data[2],
			Color = COLORS.galleryAccent,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = building,
		})
	end

	-- Rampas de acceso.
	part({
		Class = "WedgePart",
		Size = Vector3.new(10, FLOOR, 6),
		CFrame = L(-22, FLOOR / 2, -21),
		Color = COLORS.stone,
		Material = Enum.Material.Limestone,
		Parent = building,
	})
	part({
		Class = "WedgePart",
		Size = Vector3.new(6, FLOOR, 5),
		CFrame = L(28, FLOOR / 2, -20.5),
		Color = COLORS.stone,
		Material = Enum.Material.Limestone,
		Parent = building,
	})

	-- Jardineras bajo los escaparates.
	for _, a in ipairs({ { -37, -30 }, { -14, -7 }, { 1, 20 } }) do
		local cx = (a[1] + a[2]) / 2
		local w = a[2] - a[1]
		part({
			Size = Vector3.new(w, 1.2, 1.6),
			CFrame = L(cx, FLOOR + 3.2, -19),
			Color = COLORS.darkWood,
			Material = Enum.Material.Wood,
			Parent = building,
		})
		for i = 0, math.floor(w / 1.2) - 1 do
			local x = a[1] + 0.6 + i * 1.2
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.1, 1.1, 1.1),
				CFrame = L(x, FLOOR + 4.1, -19),
				Color = (i % 3 == 0) and COLORS.leaf or RAINBOW[i % #RAINBOW + 1],
				CanCollide = false,
				Parent = building,
			})
		end
	end

	building.Parent = model
	return ownerLabel
end

-- Interior de la galería ----------------------------------------------------------------------
local function buildGalleryInterior(model, L)
	local folder = Instance.new("Model")
	folder.Name = "GalleryInterior"

	-- Alfombra central y banco.
	part({
		Size = Vector3.new(18, 0.1, 12),
		CFrame = L(-22, FLOOR + 0.25, 2),
		Color = rgb(236, 220, 240),
		Material = Enum.Material.Carpet,
		CanCollide = false,
		Parent = folder,
	})
	part({
		Size = Vector3.new(16.6, 0.12, 10.6),
		CFrame = L(-22, FLOOR + 0.27, 2),
		Color = rgb(212, 186, 226),
		Material = Enum.Material.Carpet,
		CanCollide = false,
		Parent = folder,
	})
	local velvet = rgb(150, 70, 110)
	part({
		Size = Vector3.new(7, 1.6, 2.6),
		CFrame = L(-31, FLOOR + 1.2, -12),
		Color = velvet,
		Material = Enum.Material.Fabric,
		Parent = folder,
	})
	for _, x in ipairs({ -34, -28 }) do
		part({
			Size = Vector3.new(0.5, 0.6, 2.2),
			CFrame = L(x, FLOOR + 0.3, -12),
			Color = COLORS.darkWood,
			Parent = folder,
		})
	end

	-- Recepción con caja registradora.
	part({
		Size = Vector3.new(7, 4, 3),
		CFrame = L(-10, FLOOR + 2, -13),
		Color = rgb(248, 244, 238),
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	part({
		Size = Vector3.new(7.4, 0.4, 3.4),
		CFrame = L(-10, FLOOR + 4.2, -13),
		Color = COLORS.darkWood,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	part({
		Size = Vector3.new(7.1, 0.5, 0.15),
		CFrame = L(-10, FLOOR + 3.3, -14.55),
		Color = COLORS.gold,
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	part({
		Size = Vector3.new(2, 1.2, 1.6),
		CFrame = L(-8.4, FLOOR + 5, -12.8),
		Color = rgb(60, 52, 80),
		Parent = folder,
	})
	part({
		Size = Vector3.new(1.6, 0.8, 0.15),
		CFrame = L(-8.4, FLOOR + 5.9, -13.4) * CFrame.Angles(math.rad(20), 0, 0),
		Color = rgb(120, 255, 190),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = folder,
	})

	-- Escultura sobre pedestal.
	part({
		Size = Vector3.new(3, 4, 3),
		CFrame = L(-36, FLOOR + 2, -14),
		Color = rgb(248, 246, 240),
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		CFrame = L(-36, FLOOR + 5.3, -14),
		Color = rgb(120, 200, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Parent = folder,
	})
	part({
		Size = Vector3.new(1.4, 1.4, 1.4),
		CFrame = L(-36, FLOOR + 7, -14) * CFrame.Angles(0.6, 0.6, 0),
		Color = rgb(255, 140, 190),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Parent = folder,
	})

	-- Plantas en las esquinas.
	buildPlant(folder, L(-36.5, FLOOR, 14.5), 1)
	buildPlant(folder, L(-7.5, FLOOR, 14.5), 1)

	-- Lámparas colgantes.
	for _, pos in ipairs({ Vector3.new(-31, 0, -3), Vector3.new(-13, 0, -3), Vector3.new(-22, 0, -11) }) do
		part({
			Size = Vector3.new(0.15, 3, 0.15),
			CFrame = L(pos.X, CEILING - 1.5, pos.Z),
			Color = rgb(40, 30, 50),
			CanCollide = false,
			Parent = folder,
		})
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 3, 3),
			CFrame = cylinderUp(L(pos.X, CEILING - 3.4, pos.Z)),
			Color = COLORS.galleryAccent,
			CanCollide = false,
			Parent = folder,
		})
		local bulb = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = L(pos.X, CEILING - 4.1, pos.Z),
			Color = rgb(255, 232, 186),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
		addLight(bulb, "PointLight", { Range = 24, Brightness = 1.15, Color = rgb(255, 224, 186), Shadows = true })
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
		Color = rgb(236, 72, 120),
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
		Color = rgb(236, 72, 120),
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
	part({
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
		Color = rgb(170, 140, 220),
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
	machine.Parent = workshop
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 11, 11),
		CFrame = cylinderUp(mc * CFrame.new(0, 0.26, 0)),
		Color = rgb(252, 214, 228),
		Material = Enum.Material.Carpet,
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

	-- Plaza de adoquines frente al edificio y camino hasta la verja.
	part({
		Size = Vector3.new(86, 0.3, 28),
		CFrame = L(-2, 0.15, -34),
		Color = COLORS.path,
		Material = Enum.Material.Cobblestone,
		Parent = grounds,
	})
	part({
		Size = Vector3.new(88, 0.32, 1.2),
		CFrame = L(-2, 0.16, -48.4),
		Color = COLORS.stone,
		Material = Enum.Material.Limestone,
		Parent = grounds,
	})
	part({
		Size = Vector3.new(8, 0.3, 56),
		CFrame = L(-22, 0.15, -76),
		Color = COLORS.path,
		Material = Enum.Material.Cobblestone,
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
			Size = Vector3.new(3, 9, 3),
			CFrame = L(x, 4.5, -half),
			Color = rgb(196, 112, 86),
			Material = Enum.Material.Brick,
			Parent = grounds,
		})
		part({
			Size = Vector3.new(3.6, 0.8, 3.6),
			CFrame = L(x, 9.4, -half),
			Color = COLORS.stone,
			Material = Enum.Material.Limestone,
			Parent = grounds,
		})
		local lantern = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 1.6, 1.6),
			CFrame = L(x, 10.6, -half),
			Color = rgb(255, 230, 180),
			Material = Enum.Material.Neon,
			Parent = grounds,
		})
		addLight(lantern, "PointLight", { Range = 14, Brightness = 1, Color = rgb(255, 220, 170) })
	end
	part({ Size = Vector3.new(16, 2.4, 0.6), CFrame = L(-22, 12.2, -half), Color = rgb(60, 50, 84), Parent = grounds })
	local gateSign = part({
		Size = Vector3.new(15, 1.9, 0.2),
		CFrame = L(-22, 12.2, -half - 0.35),
		Color = rgb(60, 50, 84),
		Parent = grounds,
	})
	local gateLabel = surfaceText(
		gateSign,
		Enum.NormalId.Front,
		"Galería",
		{ pps = 24, color = rgb(255, 238, 200), font = Enum.Font.BuilderSansExtraBold }
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
		Color = COLORS.galleryAccent,
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
	local canvases, plaques, standPoints = {}, {}, {}
	for i = 1, Config.GALLERY_SIZE do
		canvases[i], plaques[i] = buildFrame(gallery, frameCFrames[i], "Frame" .. i)
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
		ownerSpawn = CFrame.lookAt(origin + Vector3.new(-2, 3.5, -44), origin + Vector3.new(-2, 3.5, 0)),
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
