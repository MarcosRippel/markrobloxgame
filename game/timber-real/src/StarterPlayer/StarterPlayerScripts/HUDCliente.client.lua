--[[
	HUDCliente — o painel de veredito do M0.

	Não é UI de jogo: é instrumento de medição. Publique o place, entre com uma
	conta comum e leia esta caixa. Ela responde se o Plano A sobrevive fora do
	Studio (SPEC § 3.2).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Net)

local jogador = Players.LocalPlayer

local tela = Instance.new("ScreenGui")
tela.Name = "TimberM0"
tela.ResetOnSpawn = false
tela.IgnoreGuiInset = true
tela.Parent = jogador:WaitForChild("PlayerGui")

local caixa = Instance.new("Frame")
caixa.Size = UDim2.new(0, 360, 0, 210)
caixa.Position = UDim2.new(0, 16, 0, 16)
caixa.BackgroundColor3 = Color3.fromRGB(16, 18, 16)
caixa.BackgroundTransparency = 0.15
caixa.BorderSizePixel = 0
caixa.Parent = tela

local canto = Instance.new("UICorner")
canto.CornerRadius = UDim.new(0, 8)
canto.Parent = caixa

local lista = Instance.new("UIListLayout")
lista.Padding = UDim.new(0, 2)
lista.SortOrder = Enum.SortOrder.LayoutOrder
lista.Parent = caixa

local preenchimento = Instance.new("UIPadding")
preenchimento.PaddingTop = UDim.new(0, 10)
preenchimento.PaddingLeft = UDim.new(0, 12)
preenchimento.PaddingRight = UDim.new(0, 12)
preenchimento.Parent = caixa

local ordem = 0
local function linha(tamanho, cor, negrito)
	ordem += 1
	local texto = Instance.new("TextLabel")
	texto.Size = UDim2.new(1, 0, 0, tamanho + 6)
	texto.BackgroundTransparency = 1
	texto.TextXAlignment = Enum.TextXAlignment.Left
	texto.TextSize = tamanho
	texto.TextColor3 = cor
	texto.Font = if negrito then Enum.Font.GothamBold else Enum.Font.Gotham
	texto.TextTruncate = Enum.TextTruncate.AtEnd
	texto.LayoutOrder = ordem
	texto.Text = ""
	texto.Parent = caixa
	return texto
end

local BRANCO = Color3.fromRGB(235, 235, 230)
local CINZA = Color3.fromRGB(150, 155, 148)

local titulo = linha(15, Color3.fromRGB(196, 232, 150), true)
local veredito = linha(17, BRANCO, true)
local apis = linha(14, BRANCO)
local tempos = linha(13, CINZA)
local carga = linha(13, CINZA)
local fps = linha(13, CINZA)
local erro = linha(12, Color3.fromRGB(240, 150, 140))
local ajuda = linha(12, CINZA)

titulo.Text = "DESMATAMENTO · SPIKE M0"
veredito.Text = "conectando…"
ajuda.Text = "Clique num tronco (ou tecle F) para dar um golpe."

local function pintarVeredito(texto)
	if string.find(texto, "PLANO A") then
		veredito.TextColor3 = Color3.fromRGB(150, 240, 160)
	elseif string.find(texto, "PLANO B") then
		veredito.TextColor3 = Color3.fromRGB(245, 140, 130)
	elseif string.find(texto, "PARCIAL") then
		veredito.TextColor3 = Color3.fromRGB(245, 210, 120)
	else
		veredito.TextColor3 = BRANCO
	end
end

local function marca(ok)
	return if ok then "OK" else "--"
end

Net.DiagnosticoAtualizado.OnClientEvent:Connect(function(s)
	if typeof(s) ~= "table" then
		return
	end

	titulo.Text = "DESMATAMENTO · SPIKE M0 · " .. tostring(s.ambiente)
	veredito.Text = tostring(s.veredito)
	pintarVeredito(veredito.Text)

	apis.Text = string.format(
		"sweep %s (%d)   subtract %s (%d)   fragment %s (%d)",
		marca(s.sweepOk > 0),
		s.sweepOk,
		marca(s.subtractOk > 0),
		s.subtractOk,
		marca(s.fragmentOk > 0),
		s.fragmentOk
	)
	tempos.Text = string.format(
		"latência  sweep %.0fms · subtract %.0fms · fragment %.0fms",
		s.msSweep,
		s.msSubtract,
		s.msFragment
	)
	carga.Text = string.format(
		"golpes %d · descartados %d · cacos no chão %d",
		s.golpes,
		s.descartados,
		s.cacosVivos
	)
	erro.Text = if s.ultimoErro and s.ultimoErro ~= "—"
		then "último erro: " .. s.ultimoErro
		else ""
end)

-- FPS local: o outro número que o M0 precisa medir
local quadros, acumulado = 0, 0
RunService.RenderStepped:Connect(function(dt)
	quadros += 1
	acumulado += dt
	if acumulado >= 0.5 then
		fps.Text = string.format("FPS %d", math.floor(quadros / acumulado + 0.5))
		quadros, acumulado = 0, 0
	end
end)

Net.CorteResolvido.OnClientEvent:Connect(function(r)
	if typeof(r) == "table" and r.ok then
		ajuda.Text =
			string.format("último corte: volume %.2f · %d cacos", r.volume or 0, r.cacos or 0)
	elseif typeof(r) == "table" and r.erro then
		ajuda.Text = "golpe recusado: " .. tostring(r.erro)
	end
end)
