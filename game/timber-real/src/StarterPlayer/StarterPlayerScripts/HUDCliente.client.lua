--[[
	HUDCliente — o painel de veredito do M0.

	Não é UI de jogo: é instrumento de medição. Publique o place, entre com uma
	conta comum e leia esta caixa. Ela responde se o Plano A sobrevive fora do
	Studio (SPEC § 3.2).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Net)
local Config = require(ReplicatedStorage.ConfiguracaoTimber)

local jogador = Players.LocalPlayer

-- abrevia número: 1.2k / 3.4M (sem Util/Numeros no projeto). Igual ao FeedbackCliente.
local function abreviar(n: number): string
	n = n or 0
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fk", n / 1e3)
	elseif n >= 100 then
		return string.format("%d", math.floor(n + 0.5))
	end
	return string.format("%.1f", n)
end

-- $ com prefixo (o número do jogo vem do servidor; aqui só formata pra exibir).
local function formatarDinheiro(n: number): string
	return "$" .. abreviar(n)
end

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

-- ─────────────────────────────────────────────────────────────
-- Painel de DINHEIRO ($) — canto superior direito, em DESTAQUE (SPEC § 4). O $ é
-- SERVER-AUTHORITATIVE: chega pronto no Net.EconomiaAtualizada (totalDinheiro) e o
-- HUD só exibe — o cliente nunca calcula valor. Tickzinho de escala quando sobe.
-- A MADEIRA (volume) vira sub-info client-side (proxy do quanto se cortou), sem $.
-- ─────────────────────────────────────────────────────────────
local painel = Instance.new("Frame")
painel.Name = "Dinheiro"
painel.AnchorPoint = Vector2.new(1, 0)
painel.Size = UDim2.new(0, 220, 0, 76)
painel.Position = UDim2.new(1, -16, 0, 16)
painel.BackgroundColor3 = Color3.fromRGB(26, 24, 16)
painel.BackgroundTransparency = 0.12
painel.BorderSizePixel = 0
painel.Parent = tela

local painelCanto = Instance.new("UICorner")
painelCanto.CornerRadius = UDim.new(0, 10)
painelCanto.Parent = painel

-- UIScale animado pra dar o "tick" quando o $ aumenta
local escala = Instance.new("UIScale")
escala.Scale = 1
escala.Parent = painel

local traco = Instance.new("UIStroke")
traco.Color = Color3.fromRGB(232, 196, 96) -- dourado: é DINHEIRO
traco.Transparency = 0.35
traco.Thickness = 1.5
traco.Parent = painel

local rotulo = Instance.new("TextLabel")
rotulo.Size = UDim2.new(1, -16, 0, 16)
rotulo.Position = UDim2.new(0, 12, 0, 8)
rotulo.BackgroundTransparency = 1
rotulo.TextXAlignment = Enum.TextXAlignment.Left
rotulo.Font = Enum.Font.GothamMedium
rotulo.TextSize = 12
rotulo.TextColor3 = Color3.fromRGB(236, 206, 120)
rotulo.Text = "💰 DINHEIRO"
rotulo.Parent = painel

local valor = Instance.new("TextLabel")
valor.Size = UDim2.new(1, -16, 0, 28)
valor.Position = UDim2.new(0, 12, 0, 24)
valor.BackgroundTransparency = 1
valor.TextXAlignment = Enum.TextXAlignment.Left
valor.Font = Enum.Font.GothamBold
valor.TextSize = 26
valor.TextColor3 = Color3.fromRGB(255, 236, 170)
valor.Text = "$0"
valor.Parent = painel

-- sub-info: madeira acumulada (volume), client-side. É contexto, não o número-herói.
local subMadeira = Instance.new("TextLabel")
subMadeira.Size = UDim2.new(1, -16, 0, 14)
subMadeira.Position = UDim2.new(0, 12, 0, 54)
subMadeira.BackgroundTransparency = 1
subMadeira.TextXAlignment = Enum.TextXAlignment.Left
subMadeira.Font = Enum.Font.Gotham
subMadeira.TextSize = 12
subMadeira.TextColor3 = Color3.fromRGB(150, 200, 120)
subMadeira.Text = "🪵 0 madeira"
subMadeira.Parent = painel

local pico = Config.Feedback.HUD_TICK_ESCALA
local dur = Config.Feedback.HUD_TICK_DURACAO_S

local infoTick = TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function tick()
	escala.Scale = pico
	TweenService:Create(escala, infoTick, { Scale = 1 }):Play()
end

-- DINHEIRO — server-authoritative: o servidor manda o totalDinheiro, o HUD só pinta.
Net.EconomiaAtualizada.OnClientEvent:Connect(function(dados)
	if typeof(dados) ~= "table" then
		return
	end
	local total = dados.totalDinheiro
	if typeof(total) ~= "number" then
		return
	end
	valor.Text = formatarDinheiro(total)
	tick() -- pulso do painel a cada $ que entra (golpe ou tora)
end)

-- MADEIRA (sub-info) — client-side, acumula os `volume` de cada CorteResolvido + o
-- bônus de TORA no tombamento. É só contexto visual; o $ oficial vem do servidor.
local totalMadeira = 0
local function somarMadeira(quanto: number)
	if typeof(quanto) ~= "number" or quanto <= 0 then
		return
	end
	totalMadeira += quanto
	subMadeira.Text = "🪵 " .. abreviar(totalMadeira) .. " madeira"
end

Net.CorteResolvido.OnClientEvent:Connect(function(r)
	if typeof(r) == "table" and r.ok then
		somarMadeira(r.volume or 0)
	end
end)

if Net.TroncoTombou then
	Net.TroncoTombou.OnClientEvent:Connect(function(dados)
		-- TroncoTombou é FireAllClients: só o AUTOR credita o bônus de TORA, senão
		-- todo mundo somaria +250 quando qualquer um derruba uma árvore.
		if typeof(dados) == "table" and dados.autor == jogador then
			somarMadeira(Config.Feedback.TORA_BONUS)
		end
	end)
end
