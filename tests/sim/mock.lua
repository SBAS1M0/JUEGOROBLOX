-- Minimal Roblox runtime mock validated against the real reflection database.
local DB = dofile(SIM_DIR .. "/rbxdb.lua")
local M = { errors = {}, warnings = {}, time = 0 }

local function fail(msg)
	error(msg, 3)
end

---------------------------------------------------------------- datatypes
local function mkType(name)
	local mt = { __type = name }
	mt.__index = mt
	return mt
end

local V3 = mkType("Vector3")
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__index = function(s, k)
	if k == "Magnitude" then
		return math.sqrt(s.X * s.X + s.Y * s.Y + s.Z * s.Z)
	elseif k == "Unit" then
		local m = math.sqrt(s.X * s.X + s.Y * s.Y + s.Z * s.Z)
		if m == 0 then
			return v3(0 / 0, 0 / 0, 0 / 0)
		end
		return v3(s.X / m, s.Y / m, s.Z / m)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif k == "Cross" then
		return function(a, b)
			return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return a + (b - a) * t
		end
	end
	fail(tostring(k) .. " is not a valid member of Vector3")
end
local function isType(v, name)
	local mt = getmetatable(v)
	return type(mt) == "table" and mt.__type == name
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return string.format("%g, %g, %g", a.X, a.Y, a.Z)
end
local Vector3 = {
	new = function(x, y, z)
		for _, n in ipairs({ x or 0, y or 0, z or 0 }) do
			if type(n) ~= "number" then
				fail("Vector3.new expects numbers")
			end
		end
		return v3(x, y, z)
	end,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
}

local V2 = mkType("Vector2")
local function v2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2.__index = function(s, k)
	if k == "Magnitude" then
		return math.sqrt(s.X * s.X + s.Y * s.Y)
	end
	fail(tostring(k) .. " is not a valid member of Vector2")
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
local Vector2 = {
	new = function(x, y)
		return v2(x, y)
	end,
	zero = v2(0, 0),
}

-- CFrame: position + 3x3 rotation (rows)
local CF = mkType("CFrame")
local function cf(p, r)
	return setmetatable({ p = p, r = r or { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } } }, CF)
end
local function matmul(a, b)
	local r = {}
	for i = 1, 3 do
		r[i] = {}
		for j = 1, 3 do
			r[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
	end
	return r
end
local function matvec(a, v)
	return v3(
		a[1][1] * v.X + a[1][2] * v.Y + a[1][3] * v.Z,
		a[2][1] * v.X + a[2][2] * v.Y + a[2][3] * v.Z,
		a[3][1] * v.X + a[3][2] * v.Y + a[3][3] * v.Z
	)
end
local function transpose(a)
	return {
		{ a[1][1], a[2][1], a[3][1] },
		{ a[1][2], a[2][2], a[3][2] },
		{ a[1][3], a[2][3], a[3][3] },
	}
end
CF.__index = function(s, k)
	if k == "Position" then
		return s.p
	elseif k == "X" then
		return s.p.X
	elseif k == "Y" then
		return s.p.Y
	elseif k == "Z" then
		return s.p.Z
	elseif k == "LookVector" then
		return v3(-s.r[1][3], -s.r[2][3], -s.r[3][3])
	elseif k == "RightVector" then
		return v3(s.r[1][1], s.r[2][1], s.r[3][1])
	elseif k == "UpVector" then
		return v3(s.r[1][2], s.r[2][2], s.r[3][2])
	elseif k == "Rotation" then
		return cf(v3(0, 0, 0), s.r)
	elseif k == "Inverse" then
		return function(c)
			local rt = transpose(c.r)
			return cf(-matvec(rt, c.p), rt)
		end
	elseif k == "PointToWorldSpace" then
		return function(c, v)
			return c * v
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return cf(a.p + (b.p - a.p) * t, t < 0.5 and a.r or b.r)
		end
	end
	fail(tostring(k) .. " is not a valid member of CFrame")
end
CF.__mul = function(a, b)
	if isType(b, "Vector3") then
		return a.p + matvec(a.r, b)
	end
	if not isType(b, "CFrame") then
		fail("CFrame * expects CFrame or Vector3, got " .. tostring(b))
	end
	return cf(a.p + matvec(a.r, b.p), matmul(a.r, b.r))
end
CF.__add = function(a, b)
	return cf(a.p + b, a.r)
end
CF.__sub = function(a, b)
	return cf(a.p - b, a.r)
end
local function rotX(t)
	local c, s = math.cos(t), math.sin(t)
	return { { 1, 0, 0 }, { 0, c, -s }, { 0, s, c } }
end
local function rotY(t)
	local c, s = math.cos(t), math.sin(t)
	return { { c, 0, s }, { 0, 1, 0 }, { -s, 0, c } }
end
local function rotZ(t)
	local c, s = math.cos(t), math.sin(t)
	return { { c, -s, 0 }, { s, c, 0 }, { 0, 0, 1 } }
end
local CFrame = {}
function CFrame.new(x, y, z, ...)
	if select("#", ...) > 0 then
		fail("CFrame.new with matrix not mocked")
	end
	if isType(x, "Vector3") then
		if y ~= nil then
			return CFrame.lookAt(x, y)
		end
		return cf(x)
	end
	if x ~= nil and type(x) ~= "number" then
		fail("CFrame.new bad arg")
	end
	return cf(v3(x or 0, y or 0, z or 0))
end
function CFrame.Angles(rx, ry, rz)
	return cf(v3(), matmul(matmul(rotX(rx), rotY(ry)), rotZ(rz)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.lookAt(eye, target, up)
	if not (isType(eye, "Vector3") and isType(target, "Vector3")) then
		fail("CFrame.lookAt expects Vector3s")
	end
	up = up or v3(0, 1, 0)
	local look = (target - eye).Unit
	local right = look:Cross(up).Unit
	local up2 = right:Cross(look)
	local back = -look
	return cf(eye, {
		{ right.X, up2.X, back.X },
		{ right.Y, up2.Y, back.Y },
		{ right.Z, up2.Z, back.Z },
	})
end
CFrame.identity = cf(v3())

local C3 = mkType("Color3")
local function c3(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, C3)
end
C3.__index = function(s, k)
	if k == "Lerp" then
		return function(a, b, t)
			if not isType(b, "Color3") then
				fail("Color3:Lerp expects Color3")
			end
			return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
		end
	end
	fail(tostring(k) .. " is not a valid member of Color3")
end
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
local Color3 = {
	new = function(r, g, b)
		return c3(r or 0, g or 0, b or 0)
	end,
	fromRGB = function(r, g, b)
		for _, n in ipairs({ r, g, b }) do
			if type(n) ~= "number" then
				fail("Color3.fromRGB expects numbers")
			end
		end
		return c3(r / 255, g / 255, b / 255)
	end,
}

local UD = mkType("UDim")
local function udim(s, o)
	return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD)
end
UD.__index = function(_, k)
	fail(tostring(k) .. " is not a valid member of UDim")
end
local UDim = {
	new = function(s, o)
		return udim(s, o)
	end,
}
local UD2 = mkType("UDim2")
local function udim2(xs, xo, ys, yo)
	for _, n in ipairs({ xs or 0, xo or 0, ys or 0, yo or 0 }) do
		if type(n) ~= "number" then
			fail("UDim2 expects numbers")
		end
	end
	return setmetatable({ X = udim(xs, xo), Y = udim(ys, yo) }, UD2)
end
UD2.__index = function(s, k)
	if k == "Width" then
		return s.X
	elseif k == "Height" then
		return s.Y
	end
	fail(tostring(k) .. " is not a valid member of UDim2")
end
UD2.__add = function(a, b)
	return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UD2.__eq = function(a, b)
	return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset
end
local UDim2 = {
	new = function(xs, xo, ys, yo)
		if isType(xs, "UDim") then
			return udim2(xs.Scale, xs.Offset, xo.Scale, xo.Offset)
		end
		return udim2(xs, xo, ys, yo)
	end,
	fromScale = function(x, y)
		return udim2(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		return udim2(0, x, 0, y)
	end,
}

local function simpleType(name, ctor)
	local mt = mkType(name)
	return {
		new = function(...)
			return setmetatable(ctor(...), mt)
		end,
	}, mt
end
local TweenInfo = simpleType("TweenInfo", function(t, style, dir, rep, rev, delay)
	if type(t) ~= "number" then
		fail("TweenInfo time must be number")
	end
	return { Time = t, EasingStyle = style, EasingDirection = dir }
end)
local NumberSequenceKeypoint = simpleType("NumberSequenceKeypoint", function(t, v)
	assert(type(t) == "number" and type(v) == "number", "NumberSequenceKeypoint args")
	return { Time = t, Value = v }
end)
local NumberSequence = simpleType("NumberSequence", function(a, b)
	if type(a) == "table" then
		assert(#a >= 2, "NumberSequence needs >= 2 keypoints")
		assert(a[1].Time == 0 and a[#a].Time == 1, "NumberSequence must start at 0 and end at 1")
		return { Keypoints = a }
	end
	assert(type(a) == "number", "NumberSequence arg")
	return { Keypoints = { a, b or a } }
end)
local ColorSequenceKeypoint = simpleType("ColorSequenceKeypoint", function(t, c)
	assert(type(t) == "number" and isType(c, "Color3"), "ColorSequenceKeypoint args")
	return { Time = t, Value = c }
end)
local ColorSequence = simpleType("ColorSequence", function(a, b)
	if isType(a, "Color3") then
		assert(b == nil or isType(b, "Color3"), "ColorSequence second arg")
		return { Keypoints = { a, b or a } }
	end
	assert(type(a) == "table" and #a >= 2, "ColorSequence keypoints")
	assert(a[1].Time == 0 and a[#a].Time == 1, "ColorSequence must start at 0 and end at 1")
	return { Keypoints = a }
end)
local NumberRange = simpleType("NumberRange", function(a, b)
	assert(type(a) == "number", "NumberRange arg")
	b = b or a
	assert(b >= a, "NumberRange max < min")
	return { Min = a, Max = b }
end)

local RandomMT = mkType("Random")
RandomMT.__index = {
	NextNumber = function(self, a, b)
		a, b = a or 0, b or 1
		return a + math.random() * (b - a)
	end,
	NextInteger = function(self, a, b)
		assert(math.type(a) == "integer" or a == math.floor(a), "NextInteger needs ints")
		assert(b >= a, "NextInteger empty interval " .. a .. ".." .. b)
		return math.random(math.floor(a), math.floor(b))
	end,
}
local Random = {
	new = function(seed)
		return setmetatable({}, RandomMT)
	end,
}

---------------------------------------------------------------- enums
local EnumItemMT = mkType("EnumItem")
EnumItemMT.__index = function(_, k)
	fail(tostring(k) .. " is not a valid member of EnumItem")
end
EnumItemMT.__tostring = function(e)
	return "Enum." .. e.EnumType .. "." .. e.Name
end
local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		local items = DB.enums[enumName]
		if not items then
			fail("Enum." .. tostring(enumName) .. " does not exist")
		end
		if not enumCache[enumName] then
			enumCache[enumName] = setmetatable({}, {
				__index = function(t, itemName)
					local v = items[itemName]
					if v == nil then
						fail(tostring(itemName) .. " is not a valid EnumItem of Enum." .. enumName)
					end
					local item = setmetatable({ Name = itemName, Value = v, EnumType = enumName }, EnumItemMT)
					rawset(t, itemName, item)
					return item
				end,
			})
		end
		return enumCache[enumName]
	end,
})

local function typeofValue(v)
	local mt = getmetatable(v)
	if type(mt) == "table" and mt.__type then
		return mt.__type
	end
	if type(v) == "table" and rawget(v, "__instance") then
		return "Instance"
	end
	return type(v)
end

---------------------------------------------------------------- scheduler
local threads = {} -- {co, wake, args}
M.threads = threads
local function report(err, co)
	local trace = debug.traceback(co, tostring(err))
	table.insert(M.errors, trace)
	print("!!! SCRIPT ERROR: " .. trace)
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		report(err, co)
	end
	return ok
end
M.resume = resume

local task = {}
function task.spawn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	table.insert(threads, { co = co, wake = M.time, args = table.pack(...) })
	return co
end
function task.delay(t, f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	table.insert(threads, { co = co, wake = M.time + (t or 0), args = table.pack(...) })
	return co
end
function task.wait(t)
	local co, main = coroutine.running()
	if main then
		fail("task.wait called outside coroutine")
	end
	t = t or 0
	table.insert(threads, { co = co, wake = M.time + t, args = table.pack() })
	coroutine.yield()
	return t
end
M.task = task

---------------------------------------------------------------- signals
local SignalMT = mkType("RBXScriptSignal")
local ConnMT = mkType("RBXScriptConnection")
ConnMT.__index = {
	Disconnect = function(c)
		c.Connected = false
	end,
}
local function newSignal(name)
	local s = setmetatable({ name = name, conns = {}, waiting = {} }, SignalMT)
	return s
end
SignalMT.__index = {
	Connect = function(self, f)
		if type(f) ~= "function" then
			fail("Connect expects a function")
		end
		local c = setmetatable({ f = f, Connected = true }, ConnMT)
		table.insert(self.conns, c)
		return c
	end,
	Once = function(self, f)
		local c
		c = self:Connect(function(...)
			c:Disconnect()
			f(...)
		end)
		return c
	end,
	Wait = function(self)
		local co = coroutine.running()
		table.insert(self.waiting, co)
		return coroutine.yield()
	end,
	Fire = function(self, ...)
		local list = {}
		for _, c in ipairs(self.conns) do
			if c.Connected then
				table.insert(list, c)
			end
		end
		for _, c in ipairs(list) do
			if c.Connected then
				task.spawn(c.f, ...)
			end
		end
		local waiting = self.waiting
		self.waiting = {}
		for _, co in ipairs(waiting) do
			resume(co, ...)
		end
	end,
}
M.newSignal = newSignal

---------------------------------------------------------------- instances
local classes = DB.classes
local function findProp(className, prop)
	local c = classes[className]
	while c do
		local p = c.props[prop]
		if p then
			return p
		end
		c = c.super and classes[c.super]
	end
	return nil
end
local function isA(className, base)
	local name = className
	while name do
		if name == base then
			return true
		end
		local c = classes[name]
		name = c and c.super
	end
	return false
end

local InstanceMT = { __type = "Instance" }
local Methods = {}
local Events = {
	Instance = { "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "AttributeChanged", "Changed", "Destroying" },
	GuiButton = { "Activated", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "MouseButton2Click" },
	GuiObject = { "InputBegan", "InputChanged", "InputEnded", "MouseEnter", "MouseLeave" },
	ProximityPrompt = { "Triggered", "TriggerEnded", "PromptShown", "PromptHidden" },
	RemoteEvent = { "OnServerEvent", "OnClientEvent" },
	Players = { "PlayerAdded", "PlayerRemoving" },
	Player = { "CharacterAdded", "CharacterRemoving" },
	RunService = { "Heartbeat", "RenderStepped", "Stepped" },
	UserInputService = { "InputBegan", "InputChanged", "InputEnded" },
	Tween = { "Completed" },
	BindableEvent = { "Event" },
	Humanoid = { "Died", "MoveToFinished", "Running" },
	AnimationTrack = { "Stopped", "Ended" },
}
local CallbackProps = { RemoteFunction = { OnServerInvoke = true, OnClientInvoke = true } }

local allInstances = setmetatable({}, { __mode = "k" })
M.counts = {}

local function newInstance(className, skipCheck)
	local c = classes[className]
	if not c then
		fail("Unable to create an Instance of type \"" .. tostring(className) .. "\"")
	end
	if not skipCheck then
		for _, t in ipairs(c.tags) do
			if t == "NotCreatable" or t == "Service" then
				fail("Unable to create an Instance of type \"" .. className .. "\" (" .. t .. ")")
			end
		end
	end
	local inst = setmetatable({
		__instance = true,
		ClassName = className,
		props = { Name = className },
		children = {},
		attrs = {},
		events = {},
		propSignals = {},
		attrSignals = {},
		parent = nil,
	}, InstanceMT)
	M.counts[className] = (M.counts[className] or 0) + 1
	allInstances[inst] = true
	return inst
end
M.newInstance = newInstance

local function getEvent(inst, name)
	local ev = inst.events[name]
	if ev then
		return ev
	end
	local cls = inst.ClassName
	for base, list in pairs(Events) do
		if isA(cls, base) then
			for _, e in ipairs(list) do
				if e == name then
					ev = newSignal(name)
					inst.events[name] = ev
					return ev
				end
			end
		end
	end
	return nil
end
M.getEvent = getEvent

local CLASS_DEFAULTS = dofile(SIM_DIR .. "/defaults.lua")
local function defaultFor(p, inst, prop)
	local cd = CLASS_DEFAULTS[inst.ClassName]
	local d = p.d
	if cd and cd[prop] ~= nil then
		d = cd[prop]
	end
	if prop == "AbsoluteSize" then
		return v2(512, 512)
	elseif prop == "AbsolutePosition" then
		return v2(0, 0)
	elseif prop == "ViewportSize" then
		return v2(VW or 1280, VH or 720)
	end
	if type(d) == "table" then
		if d.enum then
			local enumName = p.t:sub(6)
			for name, v in pairs(DB.enums[enumName] or {}) do
				if v == d.enum then
					return Enum[enumName][name]
				end
			end
		elseif d.v3 then
			return v3(d.v3[1], d.v3[2], d.v3[3])
		elseif d.v2 then
			return v2(d.v2[1], d.v2[2])
		elseif d.c3 then
			return c3(d.c3[1], d.c3[2], d.c3[3])
		end
	elseif d ~= nil then
		return d
	end
	local t = p.t
	if t == "Bool" then
		return false
	elseif t == "Float32" or t == "Float64" or t == "Int32" or t == "Int64" then
		return 0
	elseif t == "String" or t == "Content" or t == "ContentId" then
		return ""
	elseif t == "Vector3" then
		return v3()
	elseif t == "Vector2" then
		return v2()
	elseif t == "CFrame" then
		return cf(v3())
	elseif t == "Color3" or t == "Color3uint8" then
		return c3(0.6, 0.6, 0.6)
	elseif t == "UDim2" then
		return udim2(0, 0, 0, 0)
	elseif t == "UDim" then
		return udim(0, 0)
	end
	return nil
end

local function checkType(inst, prop, p, value)
	local t = p.t
	local tv = typeofValue(value)
	local function bad()
		fail(string.format("Invalid value for %s.%s (expected %s, got %s)", inst.ClassName, prop, t, tv))
	end
	if t:sub(1, 5) == "Enum:" then
		local enumName = t:sub(6)
		if tv == "EnumItem" then
			if value.EnumType ~= enumName then
				bad()
			end
		elseif tv == "number" or tv == "string" then
			-- Roblox converts these
		else
			bad()
		end
	elseif t == "Bool" then
		if tv ~= "boolean" then
			bad()
		end
	elseif t == "Float32" or t == "Float64" or t == "Int32" or t == "Int64" then
		if tv ~= "number" then
			bad()
		end
		if value ~= value then
			fail("NaN assigned to " .. inst.ClassName .. "." .. prop)
		end
	elseif t == "String" or t == "ContentId" or t == "Content" then
		if tv ~= "string" and not (tv == "number" and t == "String") then
			bad()
		end
	elseif t == "Color3uint8" then
		if tv ~= "Color3" then
			bad()
		end
	elseif t == "Ref" then
		if value ~= nil and tv ~= "Instance" then
			bad()
		end
	elseif
		t == "Vector3"
		or t == "Vector2"
		or t == "CFrame"
		or t == "Color3"
		or t == "UDim"
		or t == "UDim2"
		or t == "NumberSequence"
		or t == "ColorSequence"
		or t == "NumberRange"
	then
		if t == "NumberSequence" and tv == "number" then
			return
		end
		if t == "ColorSequence" and tv == "Color3" then
			return
		end
		if tv ~= t then
			bad()
		end
		if t == "Vector3" and (value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z) then
			fail("NaN Vector3 assigned to " .. inst.ClassName .. "." .. prop)
		end
		if t == "CFrame" and (value.p.X ~= value.p.X or value.p.Y ~= value.p.Y or value.p.Z ~= value.p.Z) then
			fail("NaN CFrame assigned to " .. inst.ClassName .. "." .. prop)
		end
	end
end
M.checkType = checkType

local function descendants(inst, out)
	for _, child in ipairs(inst.children) do
		table.insert(out, child)
		descendants(child, out)
	end
	return out
end

local function fireAncestry(inst, parent)
	local ev = inst.events.AncestryChanged
	if ev then
		ev:Fire(inst, parent)
	end
	for _, child in ipairs(inst.children) do
		fireAncestry(child, parent)
	end
end

local function setParent(inst, newParent)
	if newParent ~= nil and typeofValue(newParent) ~= "Instance" then
		fail("Parent must be an Instance")
	end
	if inst.destroyed then
		fail("The Parent property of " .. inst.props.Name .. " is locked")
	end
	if newParent == inst then
		fail("Attempt to set parent to self")
	end
	local old = inst.parent
	if old == newParent then
		return
	end
	if old then
		for i, child in ipairs(old.children) do
			if child == inst then
				table.remove(old.children, i)
				break
			end
		end
		local ev = old.events.ChildRemoved
		if ev then
			ev:Fire(inst)
		end
	end
	inst.parent = newParent
	if newParent then
		table.insert(newParent.children, inst)
		local ev = newParent.events.ChildAdded
		if ev then
			ev:Fire(inst)
		end
		local list = { inst }
		descendants(inst, list)
		local anc = newParent
		while anc do
			local dev = anc.events.DescendantAdded
			if dev then
				for _, d in ipairs(list) do
					dev:Fire(d)
				end
			end
			anc = anc.parent
		end
	end
	fireAncestry(inst, newParent)
end

local function firePropChanged(inst, prop)
	local s = inst.propSignals[prop]
	if s then
		s:Fire()
	end
	local ch = inst.events.Changed
	if ch then
		ch:Fire(prop)
	end
end

local INTERNAL = { parent = true, destroyed = true, allowWrite = true, sourcePath = true, mockModule = true, target = true, propsNil = true, moveToken = true, welds = true }
InstanceMT.__index = function(inst, key)
	if INTERNAL[key] then
		return nil
	end
	if key == "Parent" then
		return inst.parent
	elseif key == "ClassName" then
		return rawget(inst, "ClassName")
	end
	local m = Methods[key]
	if m then
		local holder = m
		if type(holder) == "table" then
			for base, f in pairs(holder) do
				if isA(inst.ClassName, base) then
					return f
				end
			end
		else
			return holder
		end
	end
	local p = findProp(inst.ClassName, key)
	if p then
		if p.acc == "None" then
			fail(key .. " is not a valid member of " .. inst.ClassName .. " (not scriptable)")
		end
		local v = inst.props[key]
		if v == nil and inst.propsNil and inst.propsNil[key] then
			return nil
		end
		if v == nil then
			v = defaultFor(p, inst, key)
		end
		return v
	end
	local ev = getEvent(inst, key)
	if ev then
		return ev
	end
	local cb = CallbackProps[inst.ClassName]
	if cb and cb[key] then
		return inst.props[key]
	end
	for _, child in ipairs(inst.children) do
		if child.props.Name == key then
			return child
		end
	end
	fail(tostring(key) .. " is not a valid member of " .. inst.ClassName .. " \"" .. tostring(inst.props.Name) .. "\"")
end

InstanceMT.__newindex = function(inst, key, value)
	if INTERNAL[key] then
		rawset(inst, key, value)
		return
	end
	if key == "Parent" then
		setParent(inst, value)
		return
	end
	local cb = CallbackProps[inst.ClassName]
	if cb and cb[key] then
		inst.props[key] = value
		return
	end
	local p = findProp(inst.ClassName, key)
	if not p then
		fail(tostring(key) .. " is not a valid member of " .. inst.ClassName)
	end
	if p.ro and not inst.allowWrite then
		fail("Unable to assign property " .. key .. ". Property is read only (" .. p.acc .. ") on " .. inst.ClassName)
	end
	checkType(inst, key, p, value)
	if p.t:sub(1, 5) == "Enum:" and type(value) ~= "table" then
		local enumName = p.t:sub(6)
		if type(value) == "string" then
			value = Enum[enumName][value]
		else
			for name, v in pairs(DB.enums[enumName]) do
				if v == value then
					value = Enum[enumName][name]
				end
			end
		end
	end
	if value == nil then
		inst.propsNil = inst.propsNil or {}
		inst.propsNil[key] = true
	elseif inst.propsNil then
		inst.propsNil[key] = nil
	end
	inst.props[key] = value
	if key == "Position" and isA(inst.ClassName, "BasePart") then
		local old = inst.props.CFrame or cf(v3())
		inst.props.CFrame = cf(value, old.r)
	elseif key == "CFrame" and isA(inst.ClassName, "BasePart") then
		inst.props.Position = value.p
		local welds = rawget(inst, "welds")
		if welds then
			for _, w in ipairs(welds) do
				w.part.CFrame = value * w.offset
			end
		end
	end
	if key == "Part1" and inst.ClassName == "WeldConstraint" then
		local p0 = inst.props.Part0
		if p0 and value then
			local welds = rawget(p0, "welds") or {}
			rawset(p0, "welds", welds)
			table.insert(welds, { part = value, offset = p0.CFrame:Inverse() * value.CFrame })
		end
	end
	firePropChanged(inst, key)
end
InstanceMT.__tostring = function(inst)
	return inst.props.Name
end

local function method(classBase, name, f)
	Methods[name] = Methods[name] or {}
	Methods[name][classBase] = f
end

method("Instance", "FindFirstChild", function(self, name, recursive)
	for _, c in ipairs(self.children) do
		if c.props.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(descendants(self, {})) do
			if c.props.Name == name then
				return c
			end
		end
	end
	return nil
end)
method("Instance", "FindFirstChildOfClass", function(self, cls)
	for _, c in ipairs(self.children) do
		if c.ClassName == cls then
			return c
		end
	end
	return nil
end)
method("Instance", "FindFirstChildWhichIsA", function(self, cls)
	for _, c in ipairs(self.children) do
		if isA(c.ClassName, cls) then
			return c
		end
	end
	return nil
end)
method("Instance", "WaitForChild", function(self, name, timeout)
	local start = M.time
	while true do
		for _, c in ipairs(self.children) do
			if c.props.Name == name then
				return c
			end
		end
		if timeout and M.time - start >= timeout then
			return nil
		end
		if not timeout and M.time - start > 5 then
			table.insert(M.warnings, "Infinite yield possible on " .. tostring(self.props.Name) .. ":WaitForChild(\"" .. name .. "\")")
			if M.time - start > 30 then
				fail("WaitForChild never resolved: " .. name)
			end
		end
		task.wait(1 / 30)
	end
end)
method("Instance", "GetChildren", function(self)
	return { table.unpack(self.children) }
end)
method("Instance", "GetDescendants", function(self)
	return descendants(self, {})
end)
method("Instance", "IsA", function(self, cls)
	if not classes[cls] then
		fail("IsA: unknown class " .. tostring(cls))
	end
	return isA(self.ClassName, cls)
end)
method("Instance", "IsDescendantOf", function(self, other)
	local p = self.parent
	while p do
		if p == other then
			return true
		end
		p = p.parent
	end
	return false
end)
method("Instance", "GetFullName", function(self)
	local names = {}
	local p = self
	while p and p.ClassName ~= "DataModel" do
		table.insert(names, 1, p.props.Name)
		p = p.parent
	end
	return table.concat(names, ".")
end)
method("Instance", "Destroy", function(self)
	local ev = self.events.Destroying
	if ev then
		ev:Fire()
	end
	for _, c in ipairs({ table.unpack(self.children) }) do
		c:Destroy()
	end
	setParent(self, nil)
	self.destroyed = true
	for _, s in pairs(self.events) do
		for _, c in ipairs(s.conns) do
			c.Connected = false
		end
	end
	for _, s in pairs(self.propSignals) do
		for _, c in ipairs(s.conns) do
			c.Connected = false
		end
	end
	for _, s in pairs(self.attrSignals) do
		for _, c in ipairs(s.conns) do
			c.Connected = false
		end
	end
end)
method("Instance", "ClearAllChildren", function(self)
	for _, c in ipairs({ table.unpack(self.children) }) do
		c:Destroy()
	end
end)
local ATTR_TYPES = {
	string = true,
	number = true,
	boolean = true,
	Vector3 = true,
	Vector2 = true,
	Color3 = true,
	UDim = true,
	UDim2 = true,
	CFrame = true,
	NumberRange = true,
	BrickColor = true,
	EnumItem = true,
}
method("Instance", "SetAttribute", function(self, name, value)
	if type(name) ~= "string" then
		fail("SetAttribute name must be string")
	end
	if value ~= nil and not ATTR_TYPES[typeofValue(value)] then
		fail("SetAttribute: type not supported: " .. typeofValue(value) .. " for " .. name)
	end
	if type(value) == "string" and #value > 100000 then
		fail("attribute too long")
	end
	if self.attrs[name] == value then
		return
	end
	self.attrs[name] = value
	local s = self.attrSignals[name]
	if s then
		s:Fire()
	end
	local ev = self.events.AttributeChanged
	if ev then
		ev:Fire(name)
	end
end)
method("Instance", "GetAttribute", function(self, name)
	return self.attrs[name]
end)
method("Instance", "GetAttributes", function(self)
	local t = {}
	for k, v in pairs(self.attrs) do
		t[k] = v
	end
	return t
end)
method("Instance", "GetAttributeChangedSignal", function(self, name)
	self.attrSignals[name] = self.attrSignals[name] or newSignal("Attr" .. name)
	return self.attrSignals[name]
end)
method("Instance", "GetPropertyChangedSignal", function(self, name)
	if not findProp(self.ClassName, name) then
		fail("GetPropertyChangedSignal: " .. name .. " is not a valid property of " .. self.ClassName)
	end
	self.propSignals[name] = self.propSignals[name] or newSignal("Prop" .. name)
	return self.propSignals[name]
end)

local function modelParts(model)
	local parts = {}
	for _, d in ipairs(descendants(model, {})) do
		if isA(d.ClassName, "BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end
method("Model", "GetPivot", function(self)
	local primary = self.props.PrimaryPart
	if primary then
		return primary.CFrame
	end
	if self.props.WorldPivot then
		return self.props.WorldPivot
	end
	local parts = modelParts(self)
	return parts[1] and parts[1].CFrame or cf(v3())
end)
method("Model", "PivotTo", function(self, target)
	if not isType(target, "CFrame") then
		fail("PivotTo expects CFrame")
	end
	local pivot = self:GetPivot()
	local inv = pivot:Inverse()
	for _, part in ipairs(modelParts(self)) do
		part.CFrame = target * (inv * part.CFrame)
	end
	if self.props.WorldPivot and not self.props.PrimaryPart then
		self.props.WorldPivot = target
	end
end)
method("BasePart", "PivotTo", function(self, target)
	self.CFrame = target
end)
method("ParticleEmitter", "Emit", function(self, n)
	if type(n) ~= "number" then
		fail("Emit expects number")
	end
end)

M.InstanceMT = InstanceMT
M.method = method
M.isA = isA
M.descendants = descendants
M.v2 = v2
M.v3 = v3

M.globals = {
	Vector3 = Vector3,
	Vector2 = Vector2,
	CFrame = CFrame,
	Color3 = Color3,
	UDim = UDim,
	UDim2 = UDim2,
	TweenInfo = TweenInfo,
	NumberSequence = NumberSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint,
	ColorSequence = ColorSequence,
	ColorSequenceKeypoint = ColorSequenceKeypoint,
	NumberRange = NumberRange,
	Random = Random,
	Enum = Enum,
	task = task,
	typeof = typeofValue,
	Instance = {
		new = function(className, parent)
			local inst = newInstance(className)
			if parent then
				inst.Parent = parent
			end
			return inst
		end,
	},
}
return M
