--[[
	ConstruirFerramentas — dá corpo ao Machado.

	Decisão de pipeline de arte: blockout em CÓDIGO agora (o repo é puro Luau, sem
	rbxmx e SEM ID público confiável de machado — Catalogo/Assets.lua marca o
	MODELO_MACHADO como NÃO VERIFICADO). O jogador precisa VER um machado na mão
	ao equipar; então montamos um blockout bem-feito (cabo + cabeça com lâmina),
	nada de InsertService pra ferramenta.

	Estratégia mais robusta: montar o Handle+cabeça DENTRO do template que já mora
	no StarterPack. O Roblox distribui o StarterPack pro Backpack de cada player no
	spawn, então basta o template ter o Handle uma vez, no boot, antes de qualquer
	player nascer — todo mundo recebe a cópia com machado. Sem risco de Tool
	duplicado (que aconteceria se a gente também desse um no PlayerAdded).

	// polish: trocar o blockout por mesh quando houver ID curado.
]]

local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")

-- ─────────────────────────────────────────────────────────────
-- Paleta / dimensões do blockout (LOCAIS — não mexemos no ConfiguracaoTimber)
-- ─────────────────────────────────────────────────────────────
local COR_CABO = Color3.fromRGB(120, 82, 52) -- madeira do cabo
local COR_METAL = Color3.fromRGB(88, 92, 98) -- corpo da cabeça (ferro escuro)
local COR_GUME = Color3.fromRGB(205, 210, 216) -- fio da lâmina (aço claro)

local COMPRIMENTO_CABO = 2.7
local RAIO_CABO = 0.12

-- Facão: cabo CURTO + lâmina LARGA e CHATA (metal claro). Cores próprias pra ler
-- na hora como ferramenta DIFERENTE do machado (cabo de couro escuro, aço claro).
local COR_CABO_FACAO = Color3.fromRGB(70, 50, 38) -- cabo de couro/madeira escura
local COR_LAMINA_FACAO = Color3.fromRGB(150, 156, 164) -- aço mais claro que o ferro do machado
local COMPRIMENTO_CABO_FACAO = 1.15 -- cabo curto (facão é punho curto + lâmina longa)
local RAIO_CABO_FACAO = 0.11
local COMPRIMENTO_LAMINA_FACAO = 2.2 -- lâmina longa que abre pra frente do cabo

-- Grip base: pose CLÁSSICA de machado — cabo na mão, cabeça de ferro pra CIMA,
-- gume pra FRENTE do personagem.
--
-- Eixos do Handle (cabo Cylinder na origem): +X = topo/cabeça (comprimento no X),
-- -X = pomo, +Z = face do gume. A mão do personagem, segurando Tool, tem o frame
-- ~180° virado no X em relação ao corpo (o UP da mão aponta pra BAIXO do char).
-- Por isso o Rz(+90) da versão antiga jogava a cabeça pra BAIXO (bug reportado):
-- com Rz(-90) o +X (cabeça) sobe pro UP do personagem e o +Z (gume) fica no
-- LookVector (frente). O leve Rx(-18) inclina a cabeça pra frente = pose pronta
-- pra golpear.
--
-- Posição: Y NEGATIVO ergue o cabo relativo à mão → a mão segura a METADE DE
-- BAIXO do cabo (não o topo). Números tunáveis no Studio ao vivo (rojo replica).
-- O BalancoCliente captura este Grip no Equipped e faz o swing por cima dele.
local GRIP_BASE = CFrame.new(0, -0.55, 0.05) * CFrame.Angles(math.rad(-18), 0, math.rad(-90))

-- Grip do FACÃO: pose diferente do machado. O machado aponta a cabeça pra CIMA
-- (chop vertical); o facão aponta a LÂMINA pra FRENTE e levemente pra BAIXO —
-- pose de quem vai dar um golpe LATERAL/oblíquo (o BalancoCliente varre no eixo
-- vertical/yaw a partir daqui).
--
-- Derivação (mesmos eixos do Handle: +X = ponta da lâmina, +Z = fio/gume):
--   • Rz(-90) alinha com a mão como no machado (o UP da mão aponta pra baixo do char);
--   • Rx(-108) (em vez do -18 do machado) rotaciona a ferramenta de modo que o +X
--     (comprimento da lâmina) deixe de apontar pra CIMA e passe a apontar pra FRENTE
--     (LookVector), com o fio +Z apontando pra BAIXO — pronto pra corte oblíquo;
--   • Ry(-15) inclina a PONTA um pouco pra baixo (oblíquo, não horizontal seco).
-- Números tunáveis no Studio ao vivo (rojo replica).
local GRIP_FACAO = CFrame.new(0, -0.3, 0.12)
	* CFrame.Angles(math.rad(-108), math.rad(-15), math.rad(-90))

--[[
	Cria uma parte já configurada como peça de blockout (sem colisão, sem massa)
	e solda no Handle. Recebe o CFrame RELATIVO ao Handle (que fica na origem).
]]
local function pecaSoldada(
	handle: BasePart,
	classe: string,
	nome: string,
	tamanho: Vector3,
	cframeRel: CFrame,
	cor: Color3,
	material: Enum.Material
): BasePart
	local p = Instance.new(classe)
	p.Name = nome
	p.Size = tamanho
	p.Color = cor
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false -- não atrapalha o raycast do gesto
	p.Massless = true
	p.CFrame = handle.CFrame * cframeRel

	local solda = Instance.new("WeldConstraint")
	solda.Part0 = handle
	solda.Part1 = p
	solda.Parent = p

	p.Parent = handle
	return p
end

--[[
	Monta o Handle (cabo de madeira) e solda a cabeça de machado com lâmina no
	topo. Devolve o Handle já com tudo grudado — pronto pra virar filho do Tool.

	Convenções de eixo (Handle na origem):
	  • cabo = Cylinder, comprimento no eixo X local → topo em +X.
	  • lâmina aponta pro +Z local (vira "frente" depois do Grip).
]]
local function construirCorpoMachado(): BasePart
	local topo = COMPRIMENTO_CABO / 2

	-- cabo = o Handle. Cylinder no Roblox tem o eixo em X: o comprimento vai no X.
	local cabo = Instance.new("Part")
	cabo.Name = "Handle"
	cabo.Shape = Enum.PartType.Cylinder
	cabo.Size = Vector3.new(COMPRIMENTO_CABO, RAIO_CABO * 2, RAIO_CABO * 2)
	cabo.Material = Enum.Material.Wood
	cabo.Color = COR_CABO
	cabo.CanCollide = false
	cabo.CanQuery = false
	cabo.CFrame = CFrame.new()

	-- pomo/base do cabo: engrossa a ponta de baixo pra mão ter onde "segurar".
	pecaSoldada(
		cabo,
		"Part",
		"Pomo",
		Vector3.new(0.34, 0.26, 0.26),
		CFrame.new(-topo + 0.1, 0, 0),
		COR_CABO,
		Enum.Material.Wood
	)

	-- olho: bloco de metal por onde o cabo "atravessa" (corpo da cabeça).
	pecaSoldada(
		cabo,
		"Part",
		"Olho",
		Vector3.new(0.62, 0.66, 0.6),
		CFrame.new(topo - 0.1, 0, 0),
		COR_METAL,
		Enum.Material.Metal
	)

	-- poll (traseira da cabeça): contrapeso, dá a silhueta certa do machado.
	pecaSoldada(
		cabo,
		"Part",
		"Poll",
		Vector3.new(0.52, 0.5, 0.42),
		CFrame.new(topo - 0.1, 0, -0.42),
		COR_METAL,
		Enum.Material.Metal
	)

	-- pá/lâmina: chapa fina e alta que abre pra frente (+Z). É a "bochecha" do fio.
	pecaSoldada(
		cabo,
		"Part",
		"Lamina",
		Vector3.new(1.24, 0.16, 0.62),
		CFrame.new(topo - 0.05, 0, 0.5),
		COR_METAL,
		Enum.Material.Metal
	)

	-- gume: fio flarado (mais alto que a pá → "chifres" do machado) e claro,
	-- pra ler como corte afiado no blockout.
	pecaSoldada(
		cabo,
		"Part",
		"Gume",
		Vector3.new(1.46, 0.07, 0.13),
		CFrame.new(topo - 0.02, 0, 0.86),
		COR_GUME,
		Enum.Material.SmoothPlastic
	)

	return cabo
end

--[[
	Monta o Handle (cabo curto) e solda a LÂMINA larga e chata do facão. A silhueta
	é o oposto do machado: pouco cabo, muita lâmina reta que abre pro +X (frente,
	depois do Grip). Devolve o Handle já com tudo grudado.

	Convenções de eixo (Handle na origem, iguais às do machado):
	  • cabo = Cylinder, comprimento no eixo X local → ponta da lâmina em +X.
	  • fio/gume aponta pro +Z local (vira "frente/baixo" depois do GRIP_FACAO).
]]
local function construirCorpoFacao(): BasePart
	local topo = COMPRIMENTO_CABO_FACAO / 2
	local bl = COMPRIMENTO_LAMINA_FACAO

	-- cabo = o Handle. Cylinder curto (punho do facão).
	local cabo = Instance.new("Part")
	cabo.Name = "Handle"
	cabo.Shape = Enum.PartType.Cylinder
	cabo.Size = Vector3.new(COMPRIMENTO_CABO_FACAO, RAIO_CABO_FACAO * 2, RAIO_CABO_FACAO * 2)
	cabo.Material = Enum.Material.Wood
	cabo.Color = COR_CABO_FACAO
	cabo.CanCollide = false
	cabo.CanQuery = false
	cabo.CFrame = CFrame.new()

	-- pomo: leve engrossada no fim do cabo pra mão ter apoio.
	pecaSoldada(
		cabo,
		"Part",
		"Pomo",
		Vector3.new(0.24, 0.28, 0.28),
		CFrame.new(-topo + 0.06, 0, 0),
		COR_CABO_FACAO,
		Enum.Material.Wood
	)

	-- bocal/guarda: bloquinho de metal na junção cabo→lâmina (dá o "ombro" do facão).
	pecaSoldada(
		cabo,
		"Part",
		"Bocal",
		Vector3.new(0.22, 0.36, 0.36),
		CFrame.new(topo, 0, 0),
		COR_LAMINA_FACAO,
		Enum.Material.Metal
	)

	-- lâmina: chapa LARGA, chata e longa. Fina no Y (espessura), larga no Z (do dorso
	-- ao fio), comprida no X. Deslocada pro +Z pra o fio ficar à frente do eixo do cabo.
	pecaSoldada(
		cabo,
		"Part",
		"Lamina",
		Vector3.new(bl, 0.09, 0.52),
		CFrame.new(topo + bl / 2 - 0.05, 0, 0.16),
		COR_LAMINA_FACAO,
		Enum.Material.Metal
	)

	-- flare da ponta: facão engrossa perto da ponta (peso pra frente). Bloco curto
	-- e um pouco mais largo no fim da lâmina.
	pecaSoldada(
		cabo,
		"Part",
		"Ponta",
		Vector3.new(0.42, 0.09, 0.64),
		CFrame.new(topo + bl - 0.18, 0, 0.22),
		COR_LAMINA_FACAO,
		Enum.Material.Metal
	)

	-- gume: fio fino e claro na borda dianteira (+Z), correndo o comprimento da lâmina.
	pecaSoldada(
		cabo,
		"Part",
		"Gume",
		Vector3.new(bl + 0.2, 0.05, 0.12),
		CFrame.new(topo + bl / 2 - 0.02, 0, 0.46),
		COR_GUME,
		Enum.Material.SmoothPlastic
	)

	return cabo
end

--[[
	Garante que um Tool tenha Handle+cabeça e responda a Activated com Handle.
	Idempotente: se já tiver Handle, só reafirma flags e Grip (o build serve ao
	vivo — reaplicar o Grip mantém a pose certa sem duplicar geometria).
]]
local function darCorpo(tool: Tool)
	tool.RequiresHandle = true
	if tool:FindFirstChild("Handle") then
		tool.Grip = GRIP_BASE
		return
	end
	local corpo = construirCorpoMachado()
	corpo.Parent = tool
	tool.Grip = GRIP_BASE
end

--[[
	Igual ao darCorpo, mas pro FACÃO: corpo de facão + GRIP_FACAO (pose lateral).
	Idempotente do mesmo jeito — reaplica só o Grip se já tiver Handle.
]]
local function darCorpoFacao(tool: Tool)
	tool.RequiresHandle = true
	if tool:FindFirstChild("Handle") then
		tool.Grip = GRIP_FACAO
		return
	end
	local corpo = construirCorpoFacao()
	corpo.Parent = tool
	tool.Grip = GRIP_FACAO
end

-- 1) os templates do StarterPack (fonte que o Roblox clona pro Backpack no spawn).
--    O jogador nasce com Machado E Facão no Backpack — cada Tool ganha o corpo certo.
local machadoTemplate = StarterPack:FindFirstChild("Machado")
if machadoTemplate and machadoTemplate:IsA("Tool") then
	darCorpo(machadoTemplate)
end

local facaoTemplate = StarterPack:FindFirstChild("Facao")
if facaoTemplate and facaoTemplate:IsA("Tool") then
	darCorpoFacao(facaoTemplate)
end

-- 2) fallback: se algum lugar clonar as ferramentas de outra fonte no futuro, deixa
--    templates prontos no ServerStorage pra reaproveitar (não usados no M0/M1, mas
--    evitam reescrever o construtor). Sem custo se ninguém pegar.
do
	local guardado = Instance.new("Tool")
	guardado.Name = "Machado"
	guardado.RequiresHandle = true
	guardado.CanBeDropped = false
	guardado.ToolTip = "Clique num tronco para golpear"
	darCorpo(guardado)
	guardado.Parent = ServerStorage

	local guardadoFacao = Instance.new("Tool")
	guardadoFacao.Name = "Facao"
	guardadoFacao.RequiresHandle = true
	guardadoFacao.CanBeDropped = false
	guardadoFacao.ToolTip = "Facão — golpe rápido em arco lateral"
	darCorpoFacao(guardadoFacao)
	guardadoFacao.Parent = ServerStorage
end
