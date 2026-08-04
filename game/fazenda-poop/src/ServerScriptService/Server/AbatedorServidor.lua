--!strict
--[[
	AbatedorServidor.lua v3
	---------------------------------------------------------------
	Fixes:
	- Piso alinhado com Terrain (top em Y=1)
	- Walls posicionadas relativo ao piso (nao ao centro)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Net)
local Config = require(ReplicatedStorage.ConfiguracaoFazenda)
local Catalogo = require(ReplicatedStorage.Catalogo)

local M = {}
local rng = Random.new()
local economia
local boiServidor

function M.SetEconomia(e) economia = e end
function M.SetBoiServidor(b) boiServidor = b end

function M.MontarAbatedor(fazenda: Instance)
	local pasta = fazenda:FindFirstChild("Abatedor")
	if not pasta then
		pasta = Instance.new("Folder")
		pasta.Name = "Abatedor"
		pasta.Parent = fazenda
	end

	local corTijolo = Color3.fromRGB(140, 60, 55)
	local corTelhado = Color3.fromRGB(80, 40, 35)
	local corChao = Color3.fromRGB(120, 110, 100)

	local centroXZ = (Config.ABATEDOR_ENTRADA + Config.ABATEDOR_SAIDA) / 2
	local largura = 18
	local prof = 12
	local wallH = 8
	local pisoCenterY = 0.5   -- top em Y=1

	-- Piso
	local piso = Instance.new("Part")
	piso.Name = "Piso"
	piso.Anchored = true
	piso.Size = Vector3.new(largura, 1, prof)
	piso.Position = Vector3.new(centroXZ.X, pisoCenterY, centroXZ.Z)
	piso.Color = corChao
	piso.Material = Enum.Material.Concrete
	piso.Parent = pasta

	local wallCenterY = pisoCenterY + 0.5 + wallH / 2  -- 1 + 4 = 5

	-- ParedeEsq (X mais baixo) — bloqueia lado do curral (entrada tem que ter portal aberto)
	local paredeEsq = Instance.new("Part")
	paredeEsq.Name = "ParedeEsq"
	paredeEsq.Anchored = true
	paredeEsq.Size = Vector3.new(2, wallH, prof)
	paredeEsq.Position = Vector3.new(centroXZ.X - largura / 2 - 1, wallCenterY, centroXZ.Z)
	paredeEsq.Color = corTijolo
	paredeEsq.Material = Enum.Material.Brick
	paredeEsq.Parent = pasta

	local paredeDir = Instance.new("Part")
	paredeDir.Name = "ParedeDir"
	paredeDir.Anchored = true
	paredeDir.Size = Vector3.new(2, wallH, prof)
	paredeDir.Position = Vector3.new(centroXZ.X + largura / 2 + 1, wallCenterY, centroXZ.Z)
	paredeDir.Color = corTijolo
	paredeDir.Material = Enum.Material.Brick
	paredeDir.Parent = pasta

	-- Parede frente/tras (norte/sul)
	local paredeFrente = Instance.new("Part")
	paredeFrente.Name = "ParedeFrente"
	paredeFrente.Anchored = true
	paredeFrente.Size = Vector3.new(largura + 4, wallH, 1)
	paredeFrente.Position = Vector3.new(centroXZ.X, wallCenterY, centroXZ.Z + prof / 2)
	paredeFrente.Color = corTijolo
	paredeFrente.Material = Enum.Material.Brick
	paredeFrente.Parent = pasta
	local paredeTras = paredeFrente:Clone()
	paredeTras.Name = "ParedeTras"
	paredeTras.Position = Vector3.new(centroXZ.X, wallCenterY, centroXZ.Z - prof / 2)
	paredeTras.Parent = pasta

	-- Telhado: 2 wedges
	local roofY = wallCenterY + wallH / 2 + 1.5
	local w1 = Instance.new("WedgePart")
	w1.Name = "TelhadoE"
	w1.Anchored = true
	w1.Size = Vector3.new((largura + 4) / 2, 3, prof + 4)
	w1.Color = corTelhado
	w1.Material = Enum.Material.Slate
	w1.CFrame = CFrame.new(Vector3.new(centroXZ.X - (largura + 4) / 4, roofY, centroXZ.Z))
		* CFrame.Angles(0, math.rad(180), 0)
	w1.Parent = pasta

	local w2 = Instance.new("WedgePart")
	w2.Name = "TelhadoD"
	w2.Anchored = true
	w2.Size = Vector3.new((largura + 4) / 2, 3, prof + 4)
	w2.Color = corTelhado
	w2.Material = Enum.Material.Slate
	w2.CFrame = CFrame.new(Vector3.new(centroXZ.X + (largura + 4) / 4, roofY, centroXZ.Z))
	w2.Parent = pasta

	-- Portais entrada (vermelho) e saida (verde) — na direcao do X
	local entrada = Instance.new("Part")
	entrada.Name = "Entrada"
	entrada.Anchored = true
	entrada.Size = Vector3.new(4, 6, 4)
	entrada.Position = Config.ABATEDOR_ENTRADA
	entrada.Color = Color3.fromRGB(230, 40, 40)
	entrada.Material = Enum.Material.Neon
	entrada.Transparency = 0.35
	entrada.CanCollide = false
	entrada.Parent = pasta

	local saida = Instance.new("Part")
	saida.Name = "Saida"
	saida.Anchored = true
	saida.Size = Vector3.new(4, 6, 4)
	saida.Position = Config.ABATEDOR_SAIDA
	saida.Color = Color3.fromRGB(60, 220, 130)
	saida.Material = Enum.Material.Neon
	saida.Transparency = 0.35
	saida.CanCollide = false
	saida.Parent = pasta

	-- Placa "ABATEDOR" flutuante
	local ancora = Instance.new("Part")
	ancora.Anchored = true
	ancora.CanCollide = false
	ancora.Transparency = 1
	ancora.Size = Vector3.new(1, 1, 1)
	ancora.Position = Vector3.new(centroXZ.X, roofY + 5, centroXZ.Z)
	ancora.Parent = pasta

	local bill = Instance.new("BillboardGui")
	bill.Adornee = ancora
	bill.Size = UDim2.new(0, 400, 0, 90)
	bill.AlwaysOnTop = true
	bill.Parent = ancora
	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency = 1
	txt.Size = UDim2.new(1, 0, 1, 0)
	txt.Text = "ABATEDOR"
	txt.Font = Enum.Font.GothamBlack
	txt.TextColor3 = Color3.fromRGB(255, 200, 80)
	txt.TextStrokeTransparency = 0
	txt.TextStrokeColor3 = Color3.fromRGB(60, 20, 20)
	txt.TextScaled = true
	txt.Parent = bill

	print(string.format("[AbatedorServidor v3] montado em %s", tostring(centroXZ)))
end

local function spawnBifeVisual(posicao: Vector3, valor: number, dono: Player?)
	local bife = Instance.new("Part")
	bife.Name = "Bife"
	bife.Anchored = true
	bife.CanCollide = false
	bife.Size = Vector3.new(1.4, 0.5, 1)
	bife.Color = Color3.fromRGB(170, 40, 55)
	bife.Material = Enum.Material.SmoothPlastic
	bife.Position = posicao + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
	bife.Parent = Workspace

	local gordura = Instance.new("Part")
	gordura.Anchored = true
	gordura.CanCollide = false
	gordura.Size = Vector3.new(1.4, 0.15, 1)
	gordura.Color = Color3.fromRGB(240, 220, 200)
	gordura.Material = Enum.Material.SmoothPlastic
	gordura.CFrame = bife.CFrame * CFrame.new(0, 0.32, 0)
	gordura.Parent = bife
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bife
	weld.Part1 = gordura
	weld.Parent = gordura

	local bill = Instance.new("BillboardGui")
	bill.Adornee = bife
	bill.Size = UDim2.new(0, 100, 0, 30)
	bill.StudsOffset = Vector3.new(0, 2, 0)
	bill.AlwaysOnTop = true
	bill.Parent = bife
	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency = 1
	txt.Size = UDim2.new(1, 0, 1, 0)
	txt.Text = string.format("+$%d", valor)
	txt.Font = Enum.Font.GothamBold
	txt.TextColor3 = Color3.fromRGB(255, 230, 100)
	txt.TextStrokeTransparency = 0
	txt.TextScaled = true
	txt.Parent = bill

	local alvo = bife.Position + Vector3.new(0, rng:NextNumber(2, 4), 0)
	local tweenInicio = os.clock()
	local poffEm = rng:NextNumber(Config.BIFE_TEMPO_ATE_POFF_SEG.minimo, Config.BIFE_TEMPO_ATE_POFF_SEG.maximo)

	task.spawn(function()
		while bife.Parent and os.clock() - tweenInicio < poffEm do
			local t = (os.clock() - tweenInicio) / poffEm
			bife.Position = bife.Position:Lerp(alvo, math.min(1, t * 0.05))
			task.wait()
		end
		if bife.Parent then
			bife:Destroy()
			if dono and economia then economia.Adicionar(dono, valor) end
		end
	end)
	Debris:AddItem(bife, poffEm + 0.5)
end

local function processarBoi(boi: Model, player: Player?)
	local racaId = boi:GetAttribute("RacaId") :: number
	local xp = boi:GetAttribute("XP") :: number
	local xpMax = boi:GetAttribute("XPMax") :: number
	local raca = Catalogo.Boi[racaId]

	local xpFrac = math.clamp(xp / xpMax, 0.5, 1.0)
	local qtdBase = math.ceil(Config.BIFE_QUANTIDADE_BASE * raca.multiplicadorBife * xpFrac)
	local qtdBifes = qtdBase + rng:NextInteger(0, 2)

	local bifes = {}
	for _ = 1, qtdBifes do
		local valor = math.floor(raca.valorBifeBase * raca.multiplicadorBife * xpFrac * rng:NextNumber(0.8, 1.3))
		table.insert(bifes, {valor = valor})
	end

	Net.AbatedorProcessou:FireAllClients({
		boiId = boi:GetAttribute("BoiId"),
		bifes = bifes, racaId = racaId,
		atorPlayerName = player and player.Name or "?",
	})

	for _, b in bifes do
		spawnBifeVisual(Config.ABATEDOR_SAIDA + Vector3.new(0, 3, 0), b.valor, player)
	end

	if boiServidor then
		task.wait(Config.ABATEDOR_TEMPO_PROCESSAMENTO_SEG)
		boiServidor.RemoverBoi(boi:GetAttribute("BoiId"))
	end
end

function M.OnBoiChegouNoAbatedor(boi: Model, player: Player?)
	task.spawn(processarBoi, boi, player)
end

return M
