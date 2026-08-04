--!strict
--[[
	AnomaliaCliente.client.lua  (LocalScript em StarterPlayerScripts)
	---------------------------------------------------------------
	UI minima por ora: HUD com status do turno e um botao "Reportar" que abre
	uma lista dos tipos conhecidos pro jogador escolher.

	Quando o Terminal real existir, esta UI vai ser substituida por uma
	abertura via ProximityPrompt no Terminal.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local Config = require(ReplicatedStorage.ConfiguracaoAnomalias)

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

-- ============================================================
-- HUD
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "HUDAnomalia"
gui.ResetOnSpawn = false
gui.Parent = pg

local hud = Instance.new("Frame")
hud.Name = "HUD"
hud.Size = UDim2.new(0, 320, 0, 80)
hud.Position = UDim2.new(0.5, -160, 0, 16)
hud.AnchorPoint = Vector2.new(0, 0)
hud.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
hud.BackgroundTransparency = 0.15
hud.BorderSizePixel = 0
hud.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hud

local statusLbl = Instance.new("TextLabel")
statusLbl.Name = "Status"
statusLbl.BackgroundTransparency = 1
statusLbl.Size = UDim2.new(1, -16, 0, 32)
statusLbl.Position = UDim2.new(0, 8, 0, 6)
statusLbl.TextColor3 = Color3.fromRGB(230, 230, 240)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextSize = 16
statusLbl.Text = "aguardando turno..."
statusLbl.Parent = hud

local scoreLbl = Instance.new("TextLabel")
scoreLbl.Name = "Score"
scoreLbl.BackgroundTransparency = 1
scoreLbl.Size = UDim2.new(1, -16, 0, 24)
scoreLbl.Position = UDim2.new(0, 8, 0, 40)
scoreLbl.TextColor3 = Color3.fromRGB(160, 200, 255)
scoreLbl.TextXAlignment = Enum.TextXAlignment.Left
scoreLbl.Font = Enum.Font.Gotham
scoreLbl.TextSize = 14
scoreLbl.Text = "score: 0"
scoreLbl.Parent = hud

-- ============================================================
-- Painel de report (lista de tipos)
-- ============================================================
local painel = Instance.new("Frame")
painel.Name = "PainelReport"
painel.Size = UDim2.new(0, 320, 0, 0) -- altura calculada pelo UIListLayout
painel.AutomaticSize = Enum.AutomaticSize.Y
painel.Position = UDim2.new(0.5, -160, 0, 110)
painel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
painel.BackgroundTransparency = 0.1
painel.BorderSizePixel = 0
painel.Visible = false
painel.Parent = gui

local corner2 = Instance.new("UICorner")
corner2.CornerRadius = UDim.new(0, 10)
corner2.Parent = painel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = painel

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = painel

local titulo = Instance.new("TextLabel")
titulo.BackgroundTransparency = 1
titulo.Size = UDim2.new(1, 0, 0, 22)
titulo.TextColor3 = Color3.fromRGB(255, 200, 100)
titulo.Font = Enum.Font.GothamBold
titulo.TextSize = 14
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.Text = "Qual a anomaly?"
titulo.LayoutOrder = 0
titulo.Parent = painel

-- Ordena por id pra ordem estavel
local ids = {}
for id in Config.Tipos do table.insert(ids, id) end
table.sort(ids)

for ordem, id in ipairs(ids) do
	local tipo = Config.Tipos[id]
	local btn = Instance.new("TextButton")
	btn.Name = "Btn_" .. tipo.nome
	btn.Size = UDim2.new(1, 0, 0, 42)
	btn.LayoutOrder = ordem
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	btn.AutoButtonColor = true
	btn.BorderSizePixel = 0
	btn.TextColor3 = Color3.fromRGB(240, 240, 245)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	btn.TextWrapped = true
	btn.Text = string.format("[%d] %s\n%s", tipo.id, tipo.nome, tipo.descricao)
	btn.Parent = painel
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn

	btn.MouseButton1Click:Connect(function()
		Net.ReportarAnomalia:FireServer(tipo.id)
		painel.Visible = false
	end)
end

-- ============================================================
-- Estado: liga/desliga painel conforme turno
-- ============================================================
local turnoAtivo = false

Net.EstadoTurno.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then return end
	local est = data.estado
	local restante = data.restanteSeg or 0
	if est == "ATIVO" then
		turnoAtivo = true
		statusLbl.Text = string.format("ATIVO — turno %d (%ds)", data.numTurno or 0, restante)
		statusLbl.TextColor3 = Color3.fromRGB(255, 120, 120)
		painel.Visible = true
	elseif est == "AGUARDANDO" then
		turnoAtivo = false
		statusLbl.Text = string.format("aguardando (%ds)...", restante)
		statusLbl.TextColor3 = Color3.fromRGB(230, 230, 240)
		painel.Visible = false
	else
		statusLbl.Text = est or "?"
		painel.Visible = false
	end
end)

Net.FeedbackReport.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then return end
	scoreLbl.Text = string.format("score: %d  (ultimo: %+d — %s)",
		data.scoreTotal or 0, data.pontos or 0, tostring(data.msg or ""))
	scoreLbl.TextColor3 = data.acerto and Color3.fromRGB(120, 220, 140) or Color3.fromRGB(255, 140, 140)
end)

Net.AnomaliaAtiva.OnClientEvent:Connect(function(_data)
	-- por ora a UI nao revela o tipo — jogador tem que deduzir do mundo.
	-- depois que o mapa existir, removemos esse remote (so server-side).
end)

print("[AnomaliaCliente] HUD pronta")
