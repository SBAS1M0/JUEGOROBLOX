-- Serializes GUI trees and parts to JSON for visual previews.
local D = {}
local function esc(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		if c == "\n" then return "\\n" end
		if c == '"' then return '\\"' end
		if c == "\\" then return "\\\\" end
		return ""
	end) .. '"'
end
local function enc(v, typeofFn)
	local t = typeofFn(v)
	if v == nil then return "null"
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "0" end
		return string.format("%.4f", v)
	elseif t == "boolean" then return tostring(v)
	elseif t == "string" then return esc(v)
	elseif t == "Color3" then return string.format("[%d,%d,%d]", math.floor(v.R * 255 + .5), math.floor(v.G * 255 + .5), math.floor(v.B * 255 + .5))
	elseif t == "UDim2" then return string.format("[%.4f,%.4f,%.4f,%.4f]", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
	elseif t == "UDim" then return string.format("[%.4f,%.4f]", v.Scale, v.Offset)
	elseif t == "Vector2" then return string.format("[%.4f,%.4f]", v.X, v.Y)
	elseif t == "Vector3" then return string.format("[%.4f,%.4f,%.4f]", v.X, v.Y, v.Z)
	elseif t == "EnumItem" then return esc(v.Name)
	elseif t == "ColorSequence" then
		local parts = {}
		for _, k in ipairs(v.Keypoints) do
			local c = (typeofFn(k) == "Color3") and k or k.Value
			table.insert(parts, enc(c, typeofFn))
		end
		return "[" .. table.concat(parts, ",") .. "]"
	elseif t == "CFrame" then
		local r = v.r
		return string.format("[%.4f,%.4f,%.4f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f]", v.p.X, v.p.Y, v.p.Z,
			r[1][1], r[1][2], r[1][3], r[2][1], r[2][2], r[2][3], r[3][1], r[3][2], r[3][3])
	end
	return "null"
end
local GUI_PROPS = { "Size", "Position", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "Visible", "Text",
	"TextColor3", "TextScaled", "TextXAlignment", "TextYAlignment", "Font", "ZIndex", "LayoutOrder", "Rotation", "Enabled",
	"CornerRadius", "Color", "Thickness", "Transparency", "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight",
	"FillDirection", "Padding", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "CellSize", "CellPadding",
	"AspectRatio", "MaxSize", "Scale", "MaxTextSize", "ClipsDescendants", "TextWrapped", "TextTransparency", "ApplyStrokeMode", "TextSize" }
function D.gui(inst, typeofFn)
	local fields = { '"c":' .. esc(inst.ClassName), '"n":' .. esc(inst.props.Name) }
	for _, p in ipairs(GUI_PROPS) do
		local ok, val = pcall(function() return inst[p] end)
		if ok and val ~= nil and type(val) ~= "function" and typeofFn(val) ~= "Instance" and typeofFn(val) ~= "RBXScriptSignal" then
			table.insert(fields, esc(p) .. ":" .. enc(val, typeofFn))
		end
	end
	local kids = {}
	for _, c in ipairs(inst.children) do
		table.insert(kids, D.gui(c, typeofFn))
	end
	table.insert(fields, '"k":[' .. table.concat(kids, ",") .. "]")
	return "{" .. table.concat(fields, ",") .. "}"
end
function D.parts(root, typeofFn, isA, out)
	out = out or {}
	for _, c in ipairs(root.children) do
		if isA(c.ClassName, "BasePart") then
			local tr = c.Transparency
			if tr < 0.98 then
				table.insert(out, string.format('{"c":%s,"s":%s,"cf":%s,"col":%s,"t":%s,"m":%s,"shape":%s,"mesh":%s}',
					esc(c.ClassName), enc(c.Size, typeofFn), enc(c.CFrame, typeofFn), enc(c.Color, typeofFn), enc(tr, typeofFn),
					esc(c.Material and c.Material.Name or "Plastic"), c.ClassName == "Part" and esc(c.Shape and c.Shape.Name or "Block") or '"Block"',
					c:FindFirstChildOfClass("SpecialMesh") and '"Sphere"' or "null"))
			end
		end
		D.parts(c, typeofFn, isA, out)
	end
	return out
end
function D.write(path, s)
	local f = io.open(path, "w"); f:write(s); f:close()
end
return D
