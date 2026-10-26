-- Punto de entrada del cliente: conecta las ventanas con el servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local UI = script.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local HUD = require(UI.HUD)
local Machine = require(UI.Machine)
local DesignPicker = require(UI.DesignPicker)
local ColorPicker = require(UI.ColorPicker)
local Painter = require(UI.Painter)
local Shop = require(UI.Shop)
local Daily = require(UI.Daily)
local Tutorial = require(UI.Tutorial)
local StandPanel = require(UI.StandPanel)
local Offers = require(UI.Offers)
local Mixer = require(UI.Mixer)
local World = require(script.Parent:WaitForChild("World"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Colors = require(Shared.Colors)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local app = { state = nil, remotes = {} }
for _, name in ipairs({
	"GetState",
	"StateChanged",
	"Notify",
	"RollResult",
	"OpenDesigns",
	"UnlockDesign",
	"StartPainting",
	"CancelPainting",
	"FinishPainting",
	"BuyUpgrade",
	"ClaimDaily",
	"ClaimQuest",
	"SelectStored",
	"SkipTutorial",
	"GoHome",
	"OpenStand",
	"StandAction",
	"Offer",
	"OfferClosed",
	"RespondOffer",
	"OpenMixer",
	"MixColors",
}) do
	app.remotes[name] = remotes:WaitForChild(name)
end

-- Último cuadro empezado (para retomarlo si se cierra la ventana).
local lastPainting = nil

function app.notify(text, kind)
	HUD.notify(text, kind)
end

function app.celebrate()
	HUD.celebrate()
end

function app.openShop()
	Shop.open()
end

function app.openCollection()
	Machine.openCollection()
end

-- Ventana de color conseguido (máquina y mezclador).
function app.reveal(colorId, isNew)
	Machine.reveal(colorId, isNew)
end

function app.openDaily()
	Daily.open()
end

function app.openDesigns()
	if Painter.isOpen() then
		return
	end
	DesignPicker.open()
end

function app.openColorPicker(design)
	ColorPicker.open(design)
end

function app.openPainter(design, colors)
	lastPainting = { design = design, colors = colors }
	Painter.open(design, colors)
end

function app.resumePainting()
	if Painter.isOpen() then
		return
	end
	if lastPainting and app.state and app.state.painting == lastPainting.design.id then
		Painter.open(lastPainting.design, lastPainting.colors)
	else
		app.remotes.CancelPainting:FireServer()
	end
end

-- ¿Hay alguna ventana grande abierta? (oculta el tutorial mientras tanto)
function app.isBusy()
	return Painter.isOpen() or DesignPicker.isOpen()
end

function app.setHudVisible(visible)
	HUD.setVisible(visible)
	Machine.setVisible(visible)
end

local claimingQuest = false
function app.claimQuest(index)
	if claimingQuest then
		return
	end
	claimingQuest = true
	local ok, success, result = pcall(function()
		return app.remotes.ClaimQuest:InvokeServer(index)
	end)
	claimingQuest = false
	if ok and success and type(result) == "table" then
		Theme.playSound("success", 1.15)
		app.notify("📜 ¡Misión completada! +💵" .. Theme.formatNumber(result.reward), "gold")
		local bonus = Colors.ById[result.bonusColor or ""]
		if bonus then
			app.notify("🎉 ¡Bonus del día! Ganaste «" .. bonus.name .. "»", "gold")
			app.celebrate()
		end
	end
end

local function applyState(state)
	if type(state) ~= "table" then
		return
	end
	app.state = state
	HUD.applyState(state)
	Machine.applyState(state)
	Shop.refresh()
	DesignPicker.refresh()
	ColorPicker.refresh()
	Daily.refresh()
	StandPanel.refresh()
	Mixer.refresh()
	Tutorial.applyState()
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

HUD.init(app)
Machine.init(app)
DesignPicker.init(app)
ColorPicker.init(app)
Painter.init(app)
Shop.init(app)
Daily.init(app)
Tutorial.init(app)
StandPanel.init(app)
Offers.init(app)
Mixer.init(app)
World.start()

app.remotes.StateChanged.OnClientEvent:Connect(applyState)
app.remotes.Notify.OnClientEvent:Connect(function(text, kind)
	app.notify(text, kind)
end)
app.remotes.RollResult.OnClientEvent:Connect(function(colorId, auto)
	Machine.onRoll(colorId, auto)
end)
app.remotes.OpenDesigns.OnClientEvent:Connect(function()
	app.openDesigns()
end)
app.remotes.OpenStand.OnClientEvent:Connect(function(index)
	if not Painter.isOpen() then
		StandPanel.open(index)
	end
end)
app.remotes.OpenMixer.OnClientEvent:Connect(function()
	if not Painter.isOpen() then
		Mixer.open()
	end
end)
app.remotes.Offer.OnClientEvent:Connect(function(data)
	Offers.show(data)
end)
app.remotes.OfferClosed.OnClientEvent:Connect(function(id)
	Offers.closed(id)
end)

task.spawn(function()
	local ok, state = pcall(function()
		return app.remotes.GetState:InvokeServer()
	end)
	if ok and state and not app.state then
		applyState(state)
	end
end)
