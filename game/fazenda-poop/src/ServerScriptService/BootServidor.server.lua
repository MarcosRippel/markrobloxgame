--!strict
--[[
	BootServidor.server.lua
	---------------------------------------------------------------
	Entrypoint do servidor. Baseline: TERRENO em Y=0, tudo referenciado nisso.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Net)
Net.InicializarServidor()

local Config = require(ReplicatedStorage.ConfiguracaoFazenda)

-- 1) Limpa o Baseplate + SpawnLocation padrao que o Roblox coloca
for _, c in Workspace:GetChildren() do
	if c:IsA("BasePart") and (c.Name == "Baseplate") then
		c:Destroy()
	end
	if c:IsA("SpawnLocation") then
		c:Destroy()
	end
end

-- 2) Pinta Terrain: Ground gigante + Grass no campo, top em Y=0
local terrain = Workspace.Terrain
local ok = pcall(function()
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(95, 170, 65))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(140, 105, 70))
end)

-- Ground: 500x4x500 abaixo do zero (top em Y=0)
local groundRegion = Region3.new(
	Vector3.new(-250, -4, -250),
	Vector3.new(250, 0, 250)
):ExpandToGrid(4)
terrain:FillRegion(groundRegion, 4, Enum.Material.Ground)

-- Grass sobre o campo (tambem top em Y=0, sobrescreve o Ground na regiao)
local nX, nZ = Config.CAMPO_TAMANHO_X, Config.CAMPO_TAMANHO_Z
local esp = Config.TUFO_ESPACAMENTO
local largura = nX * esp + 12
local prof = nZ * esp + 12
local gCenter = Config.CAMPO_CENTRO_OFFSET
local grassRegion = Region3.new(
	gCenter + Vector3.new(-largura/2, -4, -prof/2),
	gCenter + Vector3.new( largura/2,  0,  prof/2)
):ExpandToGrid(4)
terrain:FillRegion(grassRegion, 4, Enum.Material.Grass)

-- 3) Fazenda folder (organizacao)
local fazenda = Workspace:FindFirstChild("Fazenda")
if not fazenda then
	fazenda = Instance.new("Folder")
	fazenda.Name = "Fazenda"
	fazenda.Parent = Workspace
end

-- 4) SpawnLocation exatamente ao lado do trator
local spawnFolder = fazenda:FindFirstChild("Spawn") or (function()
	local f = Instance.new("Folder")
	f.Name = "Spawn"
	f.Parent = fazenda
	return f
end)()

if not spawnFolder:FindFirstChildOfClass("SpawnLocation") then
	local sp = Instance.new("SpawnLocation")
	sp.Name = "SpawnPadrao"
	sp.Size = Vector3.new(6, 1, 6)
	sp.Position = Config.TRATOR_POSICAO_INICIAL + Vector3.new(5, -0.5, 3)
	sp.Anchored = true
	sp.Neutral = true
	sp.Material = Enum.Material.Neon
	sp.Color = Color3.fromRGB(80, 200, 120)
	sp.Parent = spawnFolder

	-- Placa de instrucoes
	local ancora = Instance.new("Part")
	ancora.Anchored = true
	ancora.CanCollide = false
	ancora.Transparency = 1
	ancora.Size = Vector3.new(1, 1, 1)
	ancora.Position = sp.Position + Vector3.new(0, 5, 0)
	ancora.Parent = spawnFolder
	local bill = Instance.new("BillboardGui")
	bill.Adornee = ancora
	bill.Size = UDim2.new(0, 400, 0, 90)
	bill.AlwaysOnTop = true
	bill.Parent = ancora
	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency = 1
	txt.Size = UDim2.new(1, 0, 1, 0)
	txt.Text = "1. Entra no TRATOR (F)\n2. Corta capim -> Cocho (F pra Descarregar)\n3. Boi PRONTO? Relho + F -> Abatedor"
	txt.Font = Enum.Font.GothamBlack
	txt.TextColor3 = Color3.fromRGB(255, 240, 180)
	txt.TextStrokeTransparency = 0
	txt.TextScaled = true
	txt.Parent = bill
end

-- 5) Modulos
local CapimServidor = require(ServerScriptService.Server.CapimServidor)
local BoiServidor = require(ServerScriptService.Server.BoiServidor)
local AbatedorServidor = require(ServerScriptService.Server.AbatedorServidor)
local EconomiaServidor = require(ServerScriptService.Server.EconomiaServidor)
local TratorServidor = require(ServerScriptService.Server.TratorServidor)

AbatedorServidor.SetBoiServidor(BoiServidor)
AbatedorServidor.SetEconomia(EconomiaServidor)
TratorServidor.SetCapimServidor(CapimServidor)
TratorServidor.SetEconomia(EconomiaServidor)
BoiServidor.SetNotificadorAbate(AbatedorServidor.OnBoiChegouNoAbatedor)

CapimServidor.MontarCampo(fazenda)
BoiServidor.MontarCurral(fazenda)
AbatedorServidor.MontarAbatedor(fazenda)
TratorServidor.MontarTrator(fazenda)

CapimServidor.Iniciar()
BoiServidor.Iniciar()
EconomiaServidor.Iniciar(BoiServidor)
TratorServidor.Iniciar()

print("[BootServidor] FazendaPoop v0.3 online — layout compacto + Terrain alinhado")
