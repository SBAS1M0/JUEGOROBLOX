-- Dibuja un lienzo de 16x16 dentro de un Frame usando pocas piezas:
-- las celdas seguidas del mismo color de una fila se unen en un solo rectángulo.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)

local PixelArt = {}

function PixelArt.render(container, cells, emptyColor)
	local old = container:FindFirstChild("Pixels")
	if old then
		old:Destroy()
	end
	if type(cells) ~= "string" or #cells ~= Config.CELLS then
		return
	end
	local grid = Config.GRID
	local holder = Instance.new("Frame")
	holder.Name = "Pixels"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = container.ZIndex

	for row = 0, grid - 1 do
		local col = 0
		while col < grid do
			local key = string.sub(cells, row * grid + col + 1, row * grid + col + 1)
			local runEnd = col
			while runEnd + 1 < grid and string.sub(cells, row * grid + runEnd + 2, row * grid + runEnd + 2) == key do
				runEnd += 1
			end
			local color = key == Palette.EMPTY and (emptyColor or Palette.EmptyColor) or Palette.colorOf(key)
			local pixel = Instance.new("Frame")
			pixel.BorderSizePixel = 0
			pixel.BackgroundColor3 = color
			-- Un pelín más grande para que no se vean rendijas entre filas.
			pixel.Position = UDim2.fromScale(col / grid, row / grid)
			pixel.Size = UDim2.new((runEnd - col + 1) / grid, 1, 1 / grid, 1)
			pixel.ZIndex = container.ZIndex
			pixel.Parent = holder
			col = runEnd + 1
		end
	end
	holder.Parent = container
end

return PixelArt
