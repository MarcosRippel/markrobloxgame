--[[
	GestoCliente — grava o MOVIMENTO da lâmina e manda pro servidor.

	O cliente não corta nada: ele descreve o gesto. Quem resolve geometria e
	economia é o servidor (a doc é explícita que CSG no cliente não replica).

	O gesto é uma lista de CFrames — é exatamente o que SweepPartAsync consome
	pra transformar movimento em sólido.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.ConfiguracaoTimber)
local Net = require(ReplicatedStorage.Net)
local GolpeLocal = require(script.Parent.GolpeLocal)

local TAG_TRONCO = Config.Tags.TRONCO

local jogador = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = jogador:GetMouse()

local FERRAMENTA_PADRAO = Config.FerramentaPadraoM0

local AMOSTRAS = 10
local DURACAO_GOLPE = 0.22

local cortando = false

--[[
	Descobre QUAL ferramenta o jogador tem equipada e devolve (id, config). A Tool
	equipada é filha do Character e seu Name bate com a chave em Config.Ferramentas
	("Machado" ou "Facao"). Assim o servidor aplica a GEOMETRIA certa (lâmina fina do
	facão × lâmina grossa do machado) sem o cliente cortar nada. Sem Tool válida
	equipada (ex.: atalho F sem equipar), cai na ferramenta padrão do M0.
]]
local function resolverFerramenta(): (string, any)
	local personagem = jogador.Character
	local tool = personagem and personagem:FindFirstChildOfClass("Tool")
	if tool then
		local cfg = Config.Ferramentas[tool.Name]
		if cfg then
			return tool.Name, cfg
		end
	end
	return FERRAMENTA_PADRAO, Config.Ferramentas[FERRAMENTA_PADRAO]
end

local function mirar(cfgFerramenta)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		jogador.Character,
		workspace:FindFirstChild("Floresta") and workspace.Floresta:FindFirstChild("Detritos"),
	}

	local origem = camera.CFrame.Position
	local direcao = (mouse.Hit.Position - origem)
	if direcao.Magnitude < 0.01 then
		return nil
	end
	return workspace:Raycast(origem, direcao.Unit * (cfgFerramenta.alcance + 20), params)
end

--[[
	Monta o arco do golpe: a lâmina entra no tronco, atravessa uma fatia e sai.
	O arco é construído em torno da normal da superfície atingida — é isso que
	faz o corte acontecer ONDE o jogador mirou.
]]
local function montarArco(resultado, cfgFerramenta)
	local ponto = resultado.Position
	local normal = resultado.Normal

	local eixoLateral = normal:Cross(Vector3.yAxis)
	if eixoLateral.Magnitude < 0.01 then
		eixoLateral = Vector3.xAxis
	end
	eixoLateral = eixoLateral.Unit

	local profundidade = cfgFerramenta.laminaTamanho.X * 1.6
	local largura = cfgFerramenta.laminaTamanho.Y * 0.9

	local cframes = {}
	for i = 1, AMOSTRAS do
		local t = (i - 1) / (AMOSTRAS - 1) -- 0 → 1
		-- entra, mergulha e sai: seno dá o mergulho
		local avanco = (t - 0.5) * 2 * largura
		local mergulho = math.sin(t * math.pi) * profundidade

		local posicao = ponto + eixoLateral * avanco - normal * (mergulho - profundidade * 0.15)

		table.insert(cframes, CFrame.lookAt(posicao, posicao + normal))
	end
	return cframes
end

--[[
	resolverTronco — do que o clique acertou, devolve o TRONCO cortável (taggeado).
	O próprio hit se já for o tronco/tora; senão sobe pelos Models ancestrais (a folha
	fica sob Arvore.Copa) e acha o tronco taggeado que é filho DIRETO do Model da árvore.
	Assim o clique em QUALQUER parte da árvore (folha, galho, tronco) vira golpe na
	madeira. Muda em crescimento (sem tag) resolve pra nil → sem golpe, sem juice falso.
]]
local function resolverTronco(inst: Instance?): BasePart?
	if not inst then
		return nil
	end
	if inst:IsA("BasePart") and CollectionService:HasTag(inst, TAG_TRONCO) then
		return inst
	end
	local modelo = inst:FindFirstAncestorOfClass("Model")
	while modelo do
		for _, filho in ipairs(modelo:GetChildren()) do
			if filho:IsA("BasePart") and CollectionService:HasTag(filho, TAG_TRONCO) then
				return filho
			end
		end
		modelo = modelo:FindFirstAncestorOfClass("Model")
	end
	return nil
end

--[[
	pontoNoTronco — ponto/normal do impacto NA MADEIRA. Se o clique já foi no tronco,
	usa direto. Se foi na copa (folha lá no alto), re-mira só o tronco (RaycastParams
	Include) pra o arco cair no tronco — senão o SweepPartAsync varreria o vazio da copa
	e nada seria cortado. Devolve nil se não há linha de visão pro tronco.
]]
local function pontoNoTronco(resultado, tronco: BasePart): (Vector3?, Vector3?)
	if resultado.Instance == tronco then
		return resultado.Position, resultado.Normal
	end
	local origem = camera.CFrame.Position
	local ao = tronco.Position - origem
	if ao.Magnitude < 0.01 then
		return nil, nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { tronco }
	local rt = workspace:Raycast(origem, ao.Unit * (ao.Magnitude + tronco.Size.Magnitude), params)
	if rt then
		return rt.Position, rt.Normal
	end
	return nil, nil
end

local function golpear()
	if cortando then
		return
	end
	-- lê a ferramenta EQUIPADA agora → id + config; o servidor usa o id pra escolher
	-- a geometria (facão corta fino/raso, machado grosso/fundo).
	local ferramentaId, cfgFerramenta = resolverFerramenta()
	local resultado = mirar(cfgFerramenta)
	if not resultado or not resultado.Instance then
		return
	end
	if not resultado.Instance:IsDescendantOf(workspace:FindFirstChild("Floresta") or workspace) then
		return
	end
	-- clicou em qualquer parte da árvore → resolve o tronco ADULTO (taggeado). A muda
	-- em crescimento não tem tag → nil → sem golpe (não toca juice/pop otimista que o
	-- servidor recusaria: pro jogador parecia "bati e não valeu").
	local tronco = resolverTronco(resultado.Instance)
	if not tronco then
		return
	end
	-- o arco tem que cair na MADEIRA, não na folha que foi clicada
	local ponto, normal = pontoNoTronco(resultado, tronco)
	if not ponto or not normal then
		return
	end

	cortando = true

	-- juice IMEDIATO no ponto do tronco — não espera o servidor (SPEC risco #4).
	GolpeLocal.emitir({
		ponto = ponto,
		normal = normal,
		ferramenta = ferramentaId,
	})

	Net.GolpeAplicado:FireServer(
		tronco,
		montarArco({ Position = ponto, Normal = normal }, cfgFerramenta),
		ferramentaId
	)

	task.delay(DURACAO_GOLPE, function()
		cortando = false
	end)
end

-- clique com a ferramenta equipada
local function ligarFerramenta(ferramentaInstancia)
	if ferramentaInstancia:IsA("Tool") then
		-- o Tool transita Backpack↔Character (ChildAdded redispara): sem esta
		-- guarda, cada re-equip empilharia mais um Connect em Activated (leak).
		if ferramentaInstancia:GetAttribute("GolpeLigado") then
			return
		end
		ferramentaInstancia:SetAttribute("GolpeLigado", true)
		ferramentaInstancia.Activated:Connect(golpear)
	end
end

local function ligarPersonagem(personagem)
	personagem.ChildAdded:Connect(ligarFerramenta)
	for _, filho in ipairs(personagem:GetChildren()) do
		ligarFerramenta(filho)
	end
end

if jogador.Character then
	ligarPersonagem(jogador.Character)
end
jogador.CharacterAdded:Connect(ligarPersonagem)

-- atalho de teclado pro spike (não precisa equipar nada)
UserInputService.InputBegan:Connect(function(input, digitando)
	if digitando then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		golpear()
	end
end)
