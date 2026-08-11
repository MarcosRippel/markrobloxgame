--[[
	BootServidor — orquestração do spike M0.

	Monta a clareira sozinho (nada precisa ser construído à mão no Studio),
	liga a rede e responde aos golpes.

	Ver README (M0).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.ConfiguracaoTimber)
local Net = require(ReplicatedStorage.Net)

local CortadorServidor = require(script.Parent.Server.CortadorServidor)
local DetritoServidor = require(script.Parent.Server.DetritoServidor)
local DiagnosticoServidor = require(script.Parent.Server.DiagnosticoServidor)

-- ─────────────────────────────────────────────────────────────
-- Cenário
-- ─────────────────────────────────────────────────────────────
local raiz = Instance.new("Folder")
raiz.Name = "Floresta"
raiz.Parent = workspace

DetritoServidor.iniciar(raiz)

local troncos = Instance.new("Folder")
troncos.Name = "Troncos"
troncos.Parent = raiz

local function nascerTronco(indice)
	local m0 = Config.M0

	local tronco = Instance.new("Part")
	tronco.Name = "Tronco" .. indice
	tronco.Shape = Enum.PartType.Cylinder
	-- cilindro no Roblox tem o eixo em X: girar 90° em Z o deixa de pé
	tronco.Size = Vector3.new(m0.TRONCO_ALTURA, m0.TRONCO_RAIO * 2, m0.TRONCO_RAIO * 2)
	tronco.CFrame = CFrame.new(
		m0.ORIGEM + Vector3.new((indice - 2) * m0.ESPACAMENTO, m0.TRONCO_ALTURA / 2, 0)
	) * CFrame.Angles(0, 0, math.rad(90))
	tronco.Anchored = true
	tronco.Color = m0.COR_TRONCO
	tronco.Material = Enum.Material.Wood
	tronco:SetAttribute("Cortes", 0)
	tronco.Parent = troncos

	CollectionService:AddTag(tronco, CortadorServidor.TAG_TRONCO)
	return tronco
end

for i = 1, Config.M0.TRONCOS do
	nascerTronco(i)
end

-- chão, caso o place não tenha baseplate
if not workspace:FindFirstChild("Baseplate") and not workspace:FindFirstChild("Chao") then
	local chao = Instance.new("Part")
	chao.Name = "Chao"
	chao.Size = Vector3.new(200, 2, 200)
	chao.Position = Vector3.new(0, -1, 0)
	chao.Anchored = true
	chao.Color = Color3.fromRGB(78, 108, 62)
	chao.Material = Enum.Material.Grass
	chao.Parent = workspace
end

-- ─────────────────────────────────────────────────────────────
-- Rede
-- ─────────────────────────────────────────────────────────────
Net.GolpeAplicado.OnServerEvent:Connect(function(jogador, alvo, cframes, ferramentaId)
	if typeof(ferramentaId) ~= "string" then
		ferramentaId = Config.FerramentaPadraoM0
	end

	local relatorio = CortadorServidor.cortar(jogador, alvo, cframes, ferramentaId)
	DiagnosticoServidor.registrar(relatorio)

	Net.CorteResolvido:FireClient(jogador, {
		ok = relatorio.subtractOk,
		volume = relatorio.volumeRemovido,
		cacos = relatorio.cacos,
		erro = relatorio.erro,
	})
end)

Players.PlayerRemoving:Connect(function(jogador)
	CortadorServidor.esquecerJogador(jogador)
end)

Players.PlayerAdded:Connect(function()
	task.wait(2)
	DiagnosticoServidor.transmitir()
end)

-- ─────────────────────────────────────────────────────────────
-- Relatório periódico no output do servidor
-- ─────────────────────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(15)
		DiagnosticoServidor.imprimir()
	end
end)

DiagnosticoServidor.imprimir()
print(
	"[timber-real] spike M0 no ar — "
		.. Config.M0.TRONCOS
		.. " troncos. Equipe o Machado e clique num tronco."
)
