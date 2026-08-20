--[[
	CenarioVisual — céu, atmosfera, RELEVO e uma floresta em camadas de verdade.

	Objetivo (reclamação do usuário: "aos fundos não tem cenário, só um céu"):
	fazer o jogador se sentir DENTRO de uma floresta com horizonte vivo. Anéis de
	árvores de BACKDROP no horizonte + colinas e montanhas de Terrain quebrando a
	linha do horizonte + atmosfera com profundidade.

	IMPORTANTE (mapa maior + árvores cortáveis por proximidade): o CAMPO de árvores
	CORTÁVEIS (ArvoreServidor.semearMundo) ocupa o raio ≤ RAIO_CAMPO (240) em volta do
	spawn. Este script só constrói o BACKDROP ALÉM disso (raio ≥ 270) — puro cenário,
	CanQuery=false, nunca promovido. Assim nenhuma árvore "morta" aparece no meio das
	cortáveis. NÃO mexe no chão/grama (Terrain 1000×1000 topo y=0 é do BootServidor).

	Templates de árvore vêm dos Models VENDORIZADOS em ReplicatedStorage.Modelos
	(.rbxm curado sincronizado pelo Rojo). Regra da casa (igual ArvoreServidor): pega
	o template UMA vez → CLONA por instância. Nada de InsertService:LoadAsset — asset
	de terceiro não carrega em jogo não publicado, então a floresta caía toda no
	pinheiro procedural. Se um modelo faltar em Modelos, cai no procedural pra o anel
	nunca ficar vazio (warn, nunca crash).

	Idempotente: re-run apaga o mundo anterior (Folder + regiões de Terrain) e
	reconstrói — não empilha floresta nem montanha. Constantes LOCAIS.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Terrain = Workspace.Terrain

-- ─────────────────────────────────────────────────────────────
-- Parâmetros do mundo (LOCAIS, tunáveis ao vivo)
-- ─────────────────────────────────────────────────────────────
local CENTRO = Vector3.new(0, 0, -14) -- centro aprox. da clareira (mesmo Config.Mundo.CENTRO)
local CHAO_Y = 0 -- topo do chão (BootServidor põe Terrain com topo em y=0)
local NOME_FOLDER = "CenarioMundo" -- folder-raiz de tudo que este script cria
local ORCAMENTO_PARTES = 1800 -- teto de parts do cenário (mira <2000; StreamingEnabled cobre o resto)

-- Anéis de BACKDROP: só ALÉM do campo cortável (raio ≥ 270; RAIO_CAMPO do mundo é 240).
-- Tudo "barata" (low-poly/pinheiro) — é horizonte, não árvore de perto. Densos pra
-- fechar a linha do horizonte no mapa grande (1000×1000).
local ANEIS = {
	{ nome = "borda", raioMin = 270, raioMax = 360, qtd = 96, ricas = false },
	{ nome = "horizonte", raioMin = 360, raioMax = 480, qtd = 130, ricas = false },
}
local ESCALA_MIN, ESCALA_MAX = 0.9, 1.6 -- jitter de tamanho pra não parecer grid

-- Montanhas (Terrain): posições FIXAS e determinísticas pra o re-run limpar
-- exatamente o que encheu (Air no mesmo lugar antes de Fill). Empurradas pro novo
-- horizonte do mapa 1000×1000 (raio ~430-480, proporcional ao mapa maior).
local MONTANHAS = {
	{ x = 0, z = -470, raio = 92, altura = 150, neve = true },
	{ x = -440, z = 110, raio = 80, altura = 124, neve = true },
	{ x = 420, z = 170, raio = 76, altura = 110, neve = false },
	{ x = 150, z = 470, raio = 70, altura = 96, neve = false },
}
local RAIO_COLINAS = 390 -- anel de colinas suaves no horizonte, entre as montanhas
local QTD_COLINAS = 22

-- ─────────────────────────────────────────────────────────────
-- 1) Lighting + Atmosfera de floresta (profundidade no longe)
-- ─────────────────────────────────────────────────────────────
local function ajustarLighting()
	Lighting.ClockTime = 14.2 -- meio da tarde: sombras boas, sol alto
	Lighting.GeographicLatitude = 12
	Lighting.ExposureCompensation = 0.15
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ShadowSoftness = 0.35
	Lighting.GlobalShadows = true

	-- céu: skybox padrão do Roblox (dia azul), sem ID custom não verificado.
	local ceu = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	ceu.Name = "CeuFloresta"
	ceu.SunAngularSize = 12
	ceu.MoonAngularSize = 11
	ceu.StarCount = 1200
	ceu.CelestialBodiesShown = true
	ceu.Parent = Lighting

	-- atmosfera mais densa que a onda anterior: fog esverdeado/azulado no longe
	-- "afasta" as camadas de árvores e esconde a borda do Terrain. Dá a sensação
	-- de floresta profunda sem custo de render.
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Name = "AtmosferaFloresta"
	atm.Density = 0.42 -- + denso pra o horizonte "desmaiar" em bruma
	atm.Offset = 0.25
	atm.Color = Color3.fromRGB(188, 200, 178) -- bruma levemente esverdeada perto do chão
	atm.Decay = Color3.fromRGB(92, 116, 120) -- longe puxa pro azul-esverdeado (mata da profundidade)
	atm.Glare = 0.15
	atm.Haze = 2.4
	atm.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Name = "BloomFloresta"
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.25
	bloom.Parent = Lighting

	local raios = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	raios.Name = "RaiosFloresta"
	raios.Intensity = 0.06
	raios.Spread = 0.6
	raios.Parent = Lighting
end

-- ─────────────────────────────────────────────────────────────
-- 2) Relevo — colinas + montanhas de Terrain no horizonte
-- ─────────────────────────────────────────────────────────────

-- Enche uma esfera de Terrain limpando antes (Air) pra ser idempotente.
-- FIX A1 (fosso): o clear de Air usa o MESMO raio do fill (era `raio+4`). Com a margem
-- de +4, a casca entre `raio` e `raio+4` ficava de Air; onde ela cruzava o bloco de
-- grama (BootServidor FillBlock y −20..0) virava uma VALA ANULAR de ~4 studs em volta
-- de cada colina/montanha — o jogador caía e não pulava fora (parede 20 > pulo 7).
-- Clear == fill (mesmo centro/raio) → o material sempre reenche tudo que foi limpo,
-- SEM casca de Air sobrando, INDEPENDENTE de a grama do Boot rodar antes ou depois.
-- Idempotente pros mesmos constantes (posições/raios são fixos e determinísticos).
local function bolaTerrain(centro: Vector3, raio: number, material: Enum.Material)
	Terrain:FillBall(centro, raio, Enum.Material.Air) -- limpa exatamente o que este fill vai reencher
	Terrain:FillBall(centro, raio, material)
end

local function ergerMontanha(m)
	-- pico grosso feito de esferas empilhadas e afinando: silhueta irregular sem
	-- custo de parts. Base enterrada (centro abaixo de CHAO_Y) pra só o pico surgir.
	local passos = 4
	for i = 0, passos - 1 do
		local f = i / (passos - 1)
		local raio = m.raio * (1 - f * 0.62)
		local y = CHAO_Y - m.raio * 0.5 + m.altura * f
		bolaTerrain(Vector3.new(m.x, y, m.z), raio, Enum.Material.Rock)
	end
	if m.neve then
		-- capuz de neve no topo
		local topo = CHAO_Y - m.raio * 0.5 + m.altura
		bolaTerrain(Vector3.new(m.x, topo, m.z), m.raio * 0.26, Enum.Material.Snow)
	end
end

local function ergerRelevo()
	for _, m in ipairs(MONTANHAS) do
		ergerMontanha(m)
	end
	-- anel de colinas baixas entre as montanhas: domos meio enterrados de Ground,
	-- posição determinística (idempotente com o Air-clear do bolaTerrain).
	for i = 0, QTD_COLINAS - 1 do
		local ang = i / QTD_COLINAS * math.pi * 2
		local raioAnel = RAIO_COLINAS + (i % 3) * 8 -- leve variação de distância
		local x = CENTRO.X + math.cos(ang) * raioAnel
		local z = CENTRO.Z + math.sin(ang) * raioAnel
		local raio = 22 + (i % 4) * 5
		bolaTerrain(Vector3.new(x, CHAO_Y - raio * 0.62, z), raio, Enum.Material.Ground)
	end
end

-- ─────────────────────────────────────────────────────────────
-- 3) Floresta em camadas
-- ─────────────────────────────────────────────────────────────

-- Modelos VENDORIZADOS (nomes dos .rbxm em ReplicatedStorage.Modelos) e sua faixa:
-- "rica" = perto (realista, com mesh); "barata" = anéis distantes (pinheiro/low-poly).
local VENDORIZADOS = {
	{ instancia = "ArvoreRealista", barata = false }, -- MODELO_ARVORE_REALISTA (6020696518)
	{ instancia = "PineTree", barata = true }, -- MODELO_PINE_TREE (183435411)
	{ instancia = "LowpolyTree", barata = true }, -- MODELO_LOWPOLY_TREE (4893246329)
}

local function contarPartes(inst: Instance): number
	local n = 0
	if inst:IsA("BasePart") then
		n += 1
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- Prepara um template pra clonar: ancora, tira colisão/consulta das folhas, mata
-- scripts de terceiro. Fica GUARDADO (unparented) — clonamos por instância.
local function prepararTemplate(inst: Instance)
	if inst:IsA("BasePart") then
		inst.Anchored = true
		inst.CanCollide = false
		inst.CanQuery = false
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false -- folhas não bloqueiam raycast do corte
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy() -- não rodamos código de model de terceiro
		end
	end
end

-- Clona 1× cada modelo vendorizado e devolve os templates categorizados em
-- ricas/baratas. O .rbxm em Modelos pode ser um Model, um Folder-container (pack
-- com árvores dentro) ou um BasePart — resolvemos o alvo clonável em qualquer caso.
local function carregarTemplates()
	local pasta = ReplicatedStorage:FindFirstChild("Modelos")
	local ricas, baratas = {}, {}
	local falhas: { string } = {}

	for _, spec in ipairs(VENDORIZADOS) do
		local fonte = pasta and pasta:FindFirstChild(spec.instancia)
		local ok, clone = pcall(function()
			return fonte and fonte:Clone()
		end)
		if ok and clone then
			-- se o topo já é um Model/BasePart com geometria, usa ele; senão desce
			-- pro primeiro Model/BasePart filho (caso container Folder).
			local alvo: Instance? = clone
			if not (clone:IsA("BasePart")) and contarPartes(clone) > 0 and not clone:IsA("Model") then
				alvo = clone:FindFirstChildWhichIsA("Model") or clone:FindFirstChildWhichIsA("BasePart")
			end
			if alvo and contarPartes(alvo) > 0 then
				if alvo ~= clone then
					alvo.Parent = nil -- extrai o alvo; descarta o resto do container
					clone:Destroy()
				else
					alvo.Parent = nil
				end
				alvo.Name = "Tmpl_" .. spec.instancia
				prepararTemplate(alvo)
				local balde = spec.barata and baratas or ricas
				table.insert(balde, alvo)
			else
				if clone then
					clone:Destroy()
				end
				table.insert(falhas, spec.instancia)
			end
		else
			table.insert(falhas, spec.instancia)
		end
	end
	return ricas, baratas, falhas
end

-- Pinheiro procedural (fallback): tronco + 3 esferas de copa. Diâmetro uniforme
-- (Ball renderiza pelo MENOR eixo — Size não-uniforme viraria bolinha magra).
local function arvoreProcedural(): Model
	local modelo = Instance.new("Model")
	modelo.Name = "ArvoreProc"
	local altura = 9

	local tronco = Instance.new("Part")
	tronco.Name = "Tronco"
	tronco.Shape = Enum.PartType.Cylinder
	tronco.Size = Vector3.new(altura * 0.45, 0.9, 0.9)
	tronco.CFrame = CFrame.new(0, altura * 0.45 / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	tronco.Anchored = true
	tronco.CanCollide = false
	tronco.CanQuery = false
	tronco.Material = Enum.Material.Wood
	tronco.Color = Color3.fromRGB(96, 68, 44)
	tronco.Parent = modelo

	local base = altura * 0.4
	for i = 1, 3 do
		local cone = Instance.new("Part")
		cone.Name = "Copa" .. i
		local diametro = 5.2 * (1 - (i - 1) * 0.22)
		cone.Size = Vector3.new(diametro, diametro, diametro)
		cone.Shape = Enum.PartType.Ball
		cone.CFrame = CFrame.new(0, base + (i - 1) * 2.1, 0)
		cone.Anchored = true
		cone.CanCollide = false
		cone.CanQuery = false
		cone.Material = Enum.Material.Grass
		cone.Color = Color3.fromRGB(48, 104 - i * 6, 42)
		cone.Parent = modelo
	end
	modelo.PrimaryPart = tronco
	return modelo
end

-- Assenta um clone no chão em (x,z) com giro/escala, base tocando CHAO_Y.
local function assentar(clone: Instance, x: number, z: number, escala: number)
	local giro = CFrame.Angles(0, math.random() * math.pi * 2, 0)
	if clone:IsA("Model") then
		local modelo = clone :: Model
		modelo:ScaleTo(escala)
		modelo:PivotTo(CFrame.new(x, 0, z) * giro)
		local cf, tam = modelo:GetBoundingBox()
		local baseAtual = cf.Position.Y - tam.Y / 2
		modelo:PivotTo(CFrame.new(0, CHAO_Y - baseAtual, 0) * modelo:GetPivot())
	elseif clone:IsA("BasePart") then
		local parte = clone :: BasePart
		parte.Size = parte.Size * escala
		parte.CFrame = CFrame.new(x, CHAO_Y + parte.Size.Y / 2, z) * giro
	end
end

local function espalharFloresta()
	local pasta = Instance.new("Folder")
	pasta.Name = NOME_FOLDER
	pasta.Parent = Workspace

	local ricas, baratas, falhas = carregarTemplates()
	local temProc = (#ricas == 0 and #baratas == 0)

	-- part-count por template (contado 1×), pra respeitar o orçamento sem medir
	-- cada clone.
	local custo: { [Instance]: number } = {}
	for _, t in ipairs(ricas) do
		custo[t] = contarPartes(t)
	end
	for _, t in ipairs(baratas) do
		custo[t] = contarPartes(t)
	end

	local partesUsadas = 0
	local plantadas, procedurais, cortadasPorOrcamento = 0, 0, 0
	local porAnel: { [string]: number } = {}

	for _, anel in ipairs(ANEIS) do
		porAnel[anel.nome] = 0
		-- anel médio pode usar ricas; os distantes só baratas (mais leves).
		local pool = (anel.ricas and #ricas > 0) and ricas or baratas
		if #pool == 0 then
			pool = (#baratas > 0) and baratas or ricas
		end

		for i = 1, anel.qtd do
			local ang = (i - 1) / anel.qtd * math.pi * 2 + (math.random() - 0.5) * 0.5
			local raio = anel.raioMin + math.random() * (anel.raioMax - anel.raioMin)
			local x = CENTRO.X + math.cos(ang) * raio
			local z = CENTRO.Z + math.sin(ang) * raio
			local escala = ESCALA_MIN + math.random() * (ESCALA_MAX - ESCALA_MIN)

			local clone: Instance
			local peso: number
			if #pool > 0 then
				local tmpl = pool[math.random(1, #pool)]
				peso = custo[tmpl] or 1
				if partesUsadas + peso > ORCAMENTO_PARTES then
					cortadasPorOrcamento += 1
					continue -- estourou o teto: pula (registrado no log, sem corte silencioso)
				end
				clone = tmpl:Clone()
			else
				clone = arvoreProcedural()
				peso = contarPartes(clone)
				if partesUsadas + peso > ORCAMENTO_PARTES then
					clone:Destroy()
					cortadasPorOrcamento += 1
					continue
				end
				procedurais += 1
			end

			assentar(clone, x, z, escala)
			clone.Parent = pasta
			partesUsadas += peso
			plantadas += 1
			porAnel[anel.nome] += 1
		end
	end

	print(
		string.format(
			"[timber-real] CenarioVisual: backdrop em camadas — borda=%d, horizonte=%d (%d árvores, ~%d parts). Templates: %d ricas + %d baratas%s. Cortadas por orçamento(%d): %d. Falhas LoadAsset: %s.",
			porAnel["borda"] or 0,
			porAnel["horizonte"] or 0,
			plantadas,
			partesUsadas,
			#ricas,
			#baratas,
			temProc and " (fallback procedural: nenhum LoadAsset ok)" or "",
			ORCAMENTO_PARTES,
			cortadasPorOrcamento,
			#falhas > 0 and table.concat(falhas, ", ") or "nenhuma"
		)
	)
	if procedurais > 0 then
		print(
			string.format(
				"[timber-real] CenarioVisual: %d árvore(s) procedural(is) usadas (templates indisponíveis).",
				procedurais
			)
		)
	end
end

-- ─────────────────────────────────────────────────────────────
-- Execução — idempotente: apaga o mundo anterior antes de reconstruir.
-- ─────────────────────────────────────────────────────────────
local antigo = Workspace:FindFirstChild(NOME_FOLDER)
if antigo then
	antigo:Destroy() -- re-run não duplica floresta
end

ajustarLighting()
ergerRelevo() -- bolaTerrain limpa (Air) antes de encher → re-run não empilha montanha
espalharFloresta()
