--!strict
--[[
	BoiServidor.lua v3
	---------------------------------------------------------------
	Fixes:
	- TODOS os Parts do boi ANCHORED (nao cai pelo mapa)
	- Sem PisoCurral (Terrain cobre)
	- HRP alinhado com terreno: HRP.Y = CURRAL_CENTRO.Y + 2 -> legs no Terrain top
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Net)
local Config = require(ReplicatedStorage.ConfiguracaoFazenda)
local Catalogo = require(ReplicatedStorage.Catalogo)
local RngPesado = require(ReplicatedStorage.Util.RngPesado)

local M = {}

local rng = Random.new()
local bois: {[number]: Model} = {}
local proxId = 0
local curralRef: Instance? = nil
local notificadorAbate: ((boi: Model, player: Player?) -> ())? = nil

local function novoId(): number
	proxId += 1
	return proxId
end

local function sortearRaca(): number
	return RngPesado.SortearChave(Catalogo.Boi, rng) or 1
end

-- criarParte agora com Anchored=true (nao usa Weld — Model:PivotTo mantem tudo junto)
local function criarParte(pai: Model, nome: string, tamanho: Vector3, cframeRelHRP: CFrame, cor: Color3, material: Enum.Material?): Part
	local hrp = pai:FindFirstChild("HumanoidRootPart") :: BasePart
	local p = Instance.new("Part")
	p.Name = nome
	p.Size = tamanho
	p.Color = cor
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Anchored = true
	p.CFrame = hrp.CFrame * cframeRelHRP
	p.Parent = pai
	return p
end

local function aplicarEscala(boi: Model, racaId: number, xpFrac: number)
	local raca = Catalogo.Boi[racaId]
	local escala = raca.escalaBezerro + (raca.escalaAdulto - raca.escalaBezerro) * math.clamp(xpFrac, 0, 1)
	boi:ScaleTo(escala)
end

local function aleatorioNoCurral(): Vector3
	local raio = Config.CURRAL_RAIO
	local ang = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(0, raio)
	return Config.CURRAL_CENTRO + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
end

local function calcularEstado(xp: number, xpMax: number): string
	local f = xp / xpMax
	if f >= 1.0 then return "PRONTO" end
	if f >= 0.5 then return "ADULTO" end
	return "BEZERRO"
end

local function corMaisEscura(cor: Color3, fator: number): Color3
	return Color3.new(cor.R * (1 - fator), cor.G * (1 - fator), cor.B * (1 - fator))
end

local function spawnar(): Model?
	if not curralRef then return nil end
	local id = novoId()
	local racaId = sortearRaca()
	local raca = Catalogo.Boi[racaId]

	local boi = Instance.new("Model")
	boi.Name = string.format("Boi_%d_%s", id, raca.nome)
	boi:SetAttribute("BoiId", id)
	boi:SetAttribute("RacaId", racaId)
	boi:SetAttribute("XP", 0)
	boi:SetAttribute("XPMax", raca.xpMax)
	boi:SetAttribute("Estado", "BEZERRO")

	local corBase = raca.cor
	local corEscura = corMaisEscura(corBase, 0.35)

	-- HRP no ponto onde as pernas TOCAM o Terrain
	-- Terrain top = Y=0. Legs bottom deve estar em Y=0. Legs center at HRP.Y-2, size Y=2 -> bottom at HRP.Y-3.
	-- HRP.Y = 3 -> legs bottom = 0 (colado no chao). Como CURRAL_CENTRO.Y=1, adiciono 2 pra chegar em 3.
	local pos = aleatorioNoCurral()
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(3, 2.5, 5.5)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.Anchored = true
	hrp.Position = Vector3.new(pos.X, 3, pos.Z)
	hrp.Parent = boi
	boi.PrimaryPart = hrp

	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.MaxHealth = 1000
	humanoid.Health = 1000
	humanoid.Parent = boi

	-- Anatomia
	criarParte(boi, "Corpo", Vector3.new(2.8, 2.2, 4.5),
		CFrame.new(0, 0, 0), corBase, Enum.Material.SmoothPlastic)
	local pernaTam = Vector3.new(0.7, 2, 0.7)
	for _, dx in {-1, 1} do
		for _, dz in {-1.5, 1.5} do
			criarParte(boi, "Perna", pernaTam,
				CFrame.new(dx, -2, dz), corEscura, Enum.Material.SmoothPlastic)
		end
	end
	criarParte(boi, "Cabeca", Vector3.new(2, 1.8, 2),
		CFrame.new(0, 0.4, -3.2), corBase, Enum.Material.SmoothPlastic)
	criarParte(boi, "Rabo", Vector3.new(0.3, 0.3, 1.6),
		CFrame.new(0, 0.3, 3), corEscura, Enum.Material.SmoothPlastic)
	criarParte(boi, "OrelhaE", Vector3.new(0.6, 0.2, 0.9),
		CFrame.new(-1.1, 1.3, -3.2), corEscura, Enum.Material.SmoothPlastic)
	criarParte(boi, "OrelhaD", Vector3.new(0.6, 0.2, 0.9),
		CFrame.new(1.1, 1.3, -3.2), corEscura, Enum.Material.SmoothPlastic)
	local chifreCor = Color3.fromRGB(220, 200, 160)
	criarParte(boi, "ChifreE", Vector3.new(0.3, 0.9, 0.3),
		CFrame.new(-0.7, 1.6, -3.4), chifreCor, Enum.Material.SmoothPlastic)
	criarParte(boi, "ChifreD", Vector3.new(0.3, 0.9, 0.3),
		CFrame.new(0.7, 1.6, -3.4), chifreCor, Enum.Material.SmoothPlastic)

	boi.Parent = curralRef
	aplicarEscala(boi, racaId, 0)
	bois[id] = boi

	-- BillboardGui em cima do boi mostrando raca + XP
	local bill = Instance.new("BillboardGui")
	bill.Adornee = hrp
	bill.Size = UDim2.new(0, 140, 0, 30)
	bill.StudsOffset = Vector3.new(0, 3.5, 0)
	bill.AlwaysOnTop = true
	bill.Parent = hrp
	local txt = Instance.new("TextLabel")
	txt.Name = "Info"
	txt.BackgroundTransparency = 1
	txt.Size = UDim2.new(1, 0, 1, 0)
	txt.Text = raca.nome .. " 0%"
	txt.Font = Enum.Font.GothamBold
	txt.TextColor3 = Color3.fromRGB(255, 240, 180)
	txt.TextStrokeTransparency = 0
	txt.TextScaled = true
	txt.Parent = bill

	Net.BoiSpawnado:FireAllClients({
		boiId = id, racaId = racaId, posicao = hrp.Position,
	})
	return boi
end

function M.MontarCurral(fazenda: Instance)
	local curral = fazenda:FindFirstChild("Curral")
	if not curral then
		curral = Instance.new("Folder")
		curral.Name = "Curral"
		curral.Parent = fazenda
	end
	curralRef = curral

	-- Cerca do curral (postes)
	local raio = Config.CURRAL_RAIO + 3
	local nPostes = 18
	for i = 0, nPostes - 1 do
		local ang = (i / nPostes) * math.pi * 2
		local poste = Instance.new("Part")
		poste.Name = "PosteCurral"
		poste.Anchored = true
		poste.Size = Vector3.new(0.3, 3, 0.3)
		poste.Position = Config.CURRAL_CENTRO + Vector3.new(math.cos(ang) * raio, 0.5, math.sin(ang) * raio)
		poste.Color = Color3.fromRGB(90, 60, 30)
		poste.Material = Enum.Material.Wood
		poste.Parent = curral
	end

	-- Cocho OCO
	local cochoModel = Instance.new("Model")
	cochoModel.Name = "Cocho"
	cochoModel.Parent = curral

	local corMadeira = Color3.fromRGB(110, 75, 40)
	local corRacao = Color3.fromRGB(120, 200, 70)
	local cpos = Config.COCHO_POSICAO
	local cLarg, cAlt, cProf = 9, 1.8, 3.5

	local function paredeCocho(nome, size, offset)
		local p = Instance.new("Part")
		p.Name = nome
		p.Anchored = true
		p.CanCollide = true
		p.Material = Enum.Material.Wood
		p.Color = corMadeira
		p.Size = size
		p.Position = cpos + offset
		p.Parent = cochoModel
		return p
	end

	local fundo = paredeCocho("Fundo",
		Vector3.new(cLarg, 0.3, cProf),
		Vector3.new(0, -cAlt / 2, 0))
	fundo:SetAttribute("Cocho", true)
	paredeCocho("ParedeE", Vector3.new(0.3, cAlt, cProf), Vector3.new(-cLarg / 2, 0, 0))
	paredeCocho("ParedeD", Vector3.new(0.3, cAlt, cProf), Vector3.new( cLarg / 2, 0, 0))
	paredeCocho("ParedeFrente", Vector3.new(cLarg, cAlt, 0.3), Vector3.new(0, 0, -cProf / 2))
	paredeCocho("ParedeTras", Vector3.new(cLarg, cAlt, 0.3), Vector3.new(0, 0, cProf / 2))

	-- Racao DENTRO do cocho
	local racao = Instance.new("Part")
	racao.Name = "Racao"
	racao.Anchored = true
	racao.CanCollide = false
	racao.Size = Vector3.new(cLarg - 0.8, 0.5, cProf - 0.8)
	racao.Position = cpos + Vector3.new(0, -cAlt / 2 + 0.4, 0)
	racao.Color = corRacao
	racao.Material = Enum.Material.Grass
	racao.Parent = cochoModel

	-- ProximityPrompt no cocho
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PromptDescarregar"
	prompt.ActionText = "Descarregar Capim"
	prompt.ObjectText = "Cocho"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.COCHO_RAIO_DESCARGA
	prompt.RequiresLineOfSight = false
	prompt.Parent = fundo

	prompt.Triggered:Connect(function(_player)
		Net.DescarregarCarrocao:FireServer()
	end)

	-- Placa "COCHO"
	local bill = Instance.new("BillboardGui")
	bill.Size = UDim2.new(0, 220, 0, 44)
	bill.StudsOffset = Vector3.new(0, 3, 0)
	bill.AlwaysOnTop = true
	bill.Adornee = fundo
	bill.Parent = fundo
	local placaTxt = Instance.new("TextLabel")
	placaTxt.BackgroundTransparency = 1
	placaTxt.Size = UDim2.new(1, 0, 1, 0)
	placaTxt.Text = "COCHO (F)"
	placaTxt.Font = Enum.Font.GothamBlack
	placaTxt.TextColor3 = Color3.fromRGB(255, 220, 120)
	placaTxt.TextStrokeTransparency = 0
	placaTxt.TextScaled = true
	placaTxt.Parent = bill

	for _ = 1, Config.BOI_QUANTIDADE_NO_CURRAL do
		spawnar()
	end
	print(string.format("[BoiServidor v3] curral montado: %d bois em %s",
		Config.BOI_QUANTIDADE_NO_CURRAL, tostring(Config.CURRAL_CENTRO)))
end

local function atualizarPlaqueta(boi: Model)
	local hrp = boi.PrimaryPart
	if not hrp then return end
	local bill = hrp:FindFirstChildOfClass("BillboardGui")
	if not bill then return end
	local txt = bill:FindFirstChild("Info") :: TextLabel
	if not txt then return end
	local racaId = boi:GetAttribute("RacaId") :: number
	local raca = Catalogo.Boi[racaId]
	local xp = boi:GetAttribute("XP") :: number
	local xpMax = boi:GetAttribute("XPMax") :: number
	local estado = boi:GetAttribute("Estado")
	local pct = math.floor((xp / xpMax) * 100)
	txt.Text = string.format("%s %s %d%%", raca.nome, estado, pct)
	if estado == "PRONTO" then
		txt.TextColor3 = Color3.fromRGB(80, 255, 100)
	else
		txt.TextColor3 = Color3.fromRGB(255, 240, 180)
	end
end

function M.DistribuirXP(distribuicao: {[number]: number}): number
	local boisAlimentaveis = {}
	for _, boi in bois do
		if boi:GetAttribute("Estado") ~= "PRONTO" then
			table.insert(boisAlimentaveis, boi)
		end
	end
	if #boisAlimentaveis == 0 then return 0 end

	local xpTotal = 0
	for tipoId, qtd in distribuicao do
		local tipo = Catalogo.Capim[tipoId]
		if tipo then xpTotal += tipo.xpMultiplier * qtd end
	end
	if xpTotal <= 0 then return 0 end

	local porBoi = xpTotal / #boisAlimentaveis
	for _, boi in boisAlimentaveis do
		local xp = (boi:GetAttribute("XP") :: number) + porBoi
		local xpMax = boi:GetAttribute("XPMax") :: number
		if xp > xpMax then xp = xpMax end
		boi:SetAttribute("XP", xp)
		local racaId = boi:GetAttribute("RacaId") :: number
		aplicarEscala(boi, racaId, xp / xpMax)
		local novoEstado = calcularEstado(xp, xpMax)
		local antes = boi:GetAttribute("Estado")
		boi:SetAttribute("Estado", novoEstado)
		atualizarPlaqueta(boi)
		Net.BoiXPMudou:FireAllClients({
			boiId = boi:GetAttribute("BoiId"), xp = xp, xpMax = xpMax, nivel = novoEstado,
		})
		if novoEstado == "PRONTO" and antes ~= "PRONTO" then
			Net.BoiPronto:FireAllClients({boiId = boi:GetAttribute("BoiId")})
		end
	end
	return xpTotal
end

function M.TocarBoi(player: Player, boiId: number, forca: number)
	local boi = bois[boiId]
	if not boi or not boi.PrimaryPart then return end
	local char = player.Character
	if not char or not char.PrimaryPart then return end
	if (char.PrimaryPart.Position - boi.PrimaryPart.Position).Magnitude > Config.RELHO_RAIO_ALCANCE then return end
	if boi:GetAttribute("Estado") ~= "PRONTO" then return end

	local destino = Config.ABATEDOR_ENTRADA
	local dir = (Vector3.new(destino.X, 0, destino.Z)
		- Vector3.new(boi.PrimaryPart.Position.X, 0, boi.PrimaryPart.Position.Z))
	if dir.Magnitude < 0.01 then return end
	dir = dir.Unit
	local novaPos = boi.PrimaryPart.Position + dir * forca
	novaPos = Vector3.new(novaPos.X, 3, novaPos.Z) -- mantem Y=3
	boi:PivotTo(CFrame.new(novaPos))
	Net.BoiMovido:FireAllClients({boiId = boiId, novaPosicao = novaPos})

	if (Vector3.new(novaPos.X, 0, novaPos.Z) - Vector3.new(Config.ABATEDOR_ENTRADA.X, 0, Config.ABATEDOR_ENTRADA.Z)).Magnitude < 5 then
		if notificadorAbate then notificadorAbate(boi, player) end
	end
end

function M.RemoverBoi(boiId: number)
	local boi = bois[boiId]
	if not boi then return end
	bois[boiId] = nil
	boi:Destroy()
	Net.BoiAbatido:FireAllClients({boiId = boiId})
	task.delay(Config.BOI_INTERVALO_RESPAWN_SEG, function()
		spawnar()
	end)
end

function M.SetNotificadorAbate(fn: (boi: Model, player: Player?) -> ())
	notificadorAbate = fn
end

function M.Iniciar()
	Net.RelhoTocar.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then return end
		local boiId = payload.boiId
		if typeof(boiId) ~= "number" then return end
		local forca = Catalogo.Relho[1].forcaPorToque
		M.TocarBoi(player, boiId, forca)
	end)
end

return M
