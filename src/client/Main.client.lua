-- Punto de entrada del cliente: conecta la interfaz con el servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local UI = script.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local HUD = require(UI.HUD)
local Studio = require(UI.Studio)
local Shop = require(UI.Shop)
local Results = require(UI.Results)
local World = require(script.Parent:WaitForChild("World"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local app = {
	state = nil,
	remotes = {},
	patienceColor = World.patienceColor,
	orderPreview = World.orderPreview,
}
for _, name in ipairs({
	"GetState",
	"StateChanged",
	"Notify",
	"OpenOrder",
	"StartPainting",
	"StopPainting",
	"SubmitPainting",
	"BuyUpgrade",
	"ClaimDaily",
	"GoHome",
}) do
	app.remotes[name] = remotes:WaitForChild(name)
end

function app.notify(text, kind)
	HUD.notify(text, kind)
end

function app.openShop()
	Shop.open()
end

function app.showHelp()
	Results.showHelp()
end

function app.openStudio(model)
	if Studio.isOpen() then
		return
	end
	Studio.open(model)
end

function app.showResults(result, template, art)
	Results.show(result, template, art)
end

local claiming = false
function app.claimDaily()
	if claiming then
		return
	end
	if not (app.state and app.state.dailyReady) then
		app.notify(
			"Tu próximo regalo llega en " .. Theme.formatTime(app.state and app.state.dailyWait or 0) .. " ⏰",
			"info"
		)
		return
	end
	claiming = true
	local ok, success, amount = pcall(function()
		return app.remotes.ClaimDaily:InvokeServer()
	end)
	claiming = false
	if ok and success then
		Theme.playSound("success", 1.1)
		app.notify("🎁 ¡Regalo diario! +" .. Theme.formatNumber(amount) .. " monedas", "gold")
	end
end

local function applyState(state)
	if type(state) ~= "table" then
		return
	end
	local first = app.state == nil
	app.state = state
	HUD.applyState(state)
	Shop.refresh()
	if first and state.sold == 0 then
		task.delay(1.5, Results.showHelp)
	end
end

-- Quita la mochila (no se usa) y prepara la interfaz.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

HUD.init(app)
Studio.init(app)
Shop.init(app)
Results.init()
Studio.start()
World.start()

app.remotes.StateChanged.OnClientEvent:Connect(applyState)
app.remotes.Notify.OnClientEvent:Connect(function(text, kind)
	app.notify(text, kind)
end)
app.remotes.OpenOrder.OnClientEvent:Connect(function(orderId)
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local customers = plot:FindFirstChild("Customers")
		if customers then
			for _, model in ipairs(customers:GetChildren()) do
				if model:GetAttribute("OrderId") == orderId then
					app.openStudio(model)
					return
				end
			end
		end
	end
end)

task.spawn(function()
	local ok, state = pcall(function()
		return app.remotes.GetState:InvokeServer()
	end)
	if ok and state and not app.state then
		applyState(state)
	end
end)

player.CharacterAdded:Connect(function()
	if Studio.isOpen() then
		Studio.close(true)
	end
end)
