--!strict
--[[
	HUDCliente.client.lua
	---------------------------------------------------------------
	HUD basica:
	- Saldo $
	- Capacidade do carrocao (atual/max)
	- Botao "Descarregar" (envia Net.DescarregarCarrocao)
	- Status do boi mais proximo (XP, raca)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Net)
local Catalogo = require(ReplicatedStorage.Catalogo)
local Numeros = require(ReplicatedStorage.Util.Numeros)

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.Parent = pg

local function painel(nome, posY, h)
	local f = Instance.new("Frame")
	f.Name = nome
	f.Size = UDim2.new(0, 280, 0, h)
	f.Position = UDim2.new(0, 16, 0, posY)
	f.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	f.BackgroundTransparency = 0.1
	f.BorderSizePixel = 0
	f.Parent = gui
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = f
	return f
end

local function label(parent, x, y, w, h, text, size, color, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, x, 0, y)
	l.Size = UDim2.new(0, w, 0, h)
	l.Text = text
	l.TextColor3 = color or Color3.fromRGB(230, 230, 240)
	l.Font = Enum.Font.GothamBold
	l.TextSize = size or 14
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

-- Saldo
local pSaldo = painel("Saldo", 16, 60)
label(pSaldo, 12, 6, 80, 22, "$", 18, Color3.fromRGB(255, 220, 100))
local lblSaldo = label(pSaldo, 32, 6, 240, 22, "0", 18)
label(pSaldo, 12, 32, 260, 20, "saldo da fazenda", 11, Color3.fromRGB(160, 160, 180))

-- Carrocao
local pCar = painel("Carrocao", 88, 90)
label(pCar, 12, 6, 200, 20, "Carrocao", 14, Color3.fromRGB(180, 220, 255))
local lblCap = label(pCar, 12, 28, 260, 20, "0 / 50", 13)
local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, -24, 0, 6)
barBg.Position = UDim2.new(0, 12, 0, 50)
barBg.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
barBg.BorderSizePixel = 0
barBg.Parent = pCar
local barC1 = Instance.new("UICorner") barC1.CornerRadius = UDim.new(1,0) barC1.Parent = barBg
local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(120, 220, 140)
barFill.BorderSizePixel = 0
barFill.Parent = barBg
local barC2 = Instance.new("UICorner") barC2.CornerRadius = UDim.new(1,0) barC2.Parent = barFill

-- Descarga agora eh via ProximityPrompt (F no cocho); HUD so mostra a dica.
local hintDescarga = label(pCar, 12, 62, 260, 20,
	"chegue no COCHO e aperte F", 11, Color3.fromRGB(160, 200, 220))

-- Boi proximo
local pBoi = painel("Boi", 190, 62)
label(pBoi, 12, 6, 200, 20, "Boi mais proximo", 13, Color3.fromRGB(255, 200, 100))
local lblBoi = label(pBoi, 12, 26, 260, 30, "(nenhum por perto)", 12, Color3.fromRGB(220, 220, 230))

-- Estado
local capacidadeAtual, capacidadeMax = 0, 50

local function atualizarBarra()
	local frac = capacidadeMax > 0 and capacidadeAtual / capacidadeMax or 0
	barFill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
	if frac >= 1.0 then
		barFill.BackgroundColor3 = Color3.fromRGB(220, 120, 80)
	elseif frac >= 0.8 then
		barFill.BackgroundColor3 = Color3.fromRGB(220, 200, 80)
	else
		barFill.BackgroundColor3 = Color3.fromRGB(120, 220, 140)
	end
end

Net.SaldoMudou.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then return end
	lblSaldo.Text = Numeros.Formatar(data.saldo or 0)
end)

Net.CarrocaoAtualizado.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then return end
	capacidadeAtual = data.capacidadeAtual or 0
	capacidadeMax = data.capacidadeMax or 1
	lblCap.Text = string.format("%d / %d", capacidadeAtual, capacidadeMax)
	atualizarBarra()
end)

-- Procura boi mais proximo a cada 0.3s
task.spawn(function()
	while true do
		task.wait(0.3)
		local char = player.Character
		if char and char.PrimaryPart then
			local pos = char.PrimaryPart.Position
			local fazenda = Workspace:FindFirstChild("Fazenda")
			local curral = fazenda and fazenda:FindFirstChild("Curral")
			if curral then
				local maisPerto, dist = nil, math.huge
				for _, m in curral:GetChildren() do
					if m:IsA("Model") and m.PrimaryPart then
						local d = (m.PrimaryPart.Position - pos).Magnitude
						if d < dist then dist = d; maisPerto = m end
					end
				end
				if maisPerto and dist < 30 then
					local racaId = maisPerto:GetAttribute("RacaId")
					local raca = Catalogo.Boi[racaId]
					local xp = maisPerto:GetAttribute("XP") or 0
					local xpMax = maisPerto:GetAttribute("XPMax") or 100
					local estado = maisPerto:GetAttribute("Estado") or "?"
					lblBoi.Text = string.format("%s — %s — XP %d/%d",
						(raca and raca.nome or "?"), estado,
						math.floor(xp), math.floor(xpMax))
				else
					lblBoi.Text = "(nenhum por perto)"
				end
			end
		end
	end
end)

print("[HUDCliente] pronto")
