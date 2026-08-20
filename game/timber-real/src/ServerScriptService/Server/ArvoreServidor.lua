--[[
	ArvoreServidor — a árvore como Model: tronco cortável (cilindro watertight,
	mesma Size/tag de sempre — o corte por GeometryService continua igual) + copa
	decorativa (folhas) por cima, mais o tombamento e o ciclo TOCO → BROTOS.

	v2 (SPEC § 2.5.6): este módulo NÃO é mais dono do mundo. O campo global de sites
	e o gerenciador de promoção por proximidade (semearMundo / iniciarGerenciador /
	promover / rebaixar / construirProxy / posicoesSites) foram RETIRADOS — eram a
	causa comum dos bugs 1-4 do § 0.5. Quem semeia árvore agora é o LoteServidor, um
	lote fixo por jogador; aqui ficou só o CICLO DE VIDA de UMA árvore.

	Responsável por:
	  • nascer(id, pai, opts)  — monta o Model (tronco + copa) numa POSIÇÃO arbitrária
	  • aoCortar(...)          — chamado pelo CortadorServidor após cada corte; decide se
	                             passou do limiar e manda tombar
	  • tombar(...)            — desancora tronco+copa, empurra leve pro lado do entalhe
	                             e deixa a FÍSICA derrubar (SPEC § 2). Vira "tora" e
	                             dispara Net.ImpactoSolo no ASSENTAMENTO (SPEC § 2.6)
	  • iniciarCicloToco(...)  — toco ancorado → brotos → uma muda cresce e vira cortável,
	                             SEMPRE no mesmo folder-pai (o Slot do lote). Autônomo:
	                             não precisa de gerenciador nenhum pra fechar o loop.

	O tronco é TROCADO por um novo Part a cada corte (o CortadorServidor recria o
	corpo). Por isso a massa inicial e as flags (Tombou/Tora) moram no MODEL, que
	sobrevive aos cortes — nunca no Part do tronco.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.ConfiguracaoTimber)
local Net = require(ReplicatedStorage.Net)
local Especies = require(ReplicatedStorage.Catalogo.Especies)
local DropBreathing = require(ReplicatedStorage.Math.DropBreathing)

local ArvoreServidor = {}

local TAG_TRONCO = Config.Tags.TRONCO

-- ─────────────────────────────────────────────────────────────
-- Modelo VENDORIZADO: clona o .rbxm curado de ReplicatedStorage.Modelos.<nome>
-- (Rojo sincroniza). Substitui o antigo InsertService:LoadAsset — asset de terceiro
-- não carrega em jogo não publicado, então a copa caía sempre no procedural.
-- Opcional — se não achar, a copa cai no procedural. Nunca quebra o boot.
-- ─────────────────────────────────────────────────────────────
local function clonarModeloVendorizado(nome: string): Instance?
	local pasta = ReplicatedStorage:FindFirstChild("Modelos")
	local fonte = pasta and pasta:FindFirstChild(nome)
	if not fonte then
		return nil
	end
	local ok, clone = pcall(function()
		return fonte:Clone()
	end)
	if not ok or typeof(clone) ~= "Instance" then
		return nil
	end
	return clone
end

local function coletarPartes(raiz: Instance): { BasePart }
	local partes = {}
	for _, d in ipairs(raiz:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(partes, d)
		end
	end
	return partes
end

-- copa real pode vir com Scripts de terceiro — some com eles (segurança + brief)
local function removerScripts(raiz: Instance)
	for _, d in ipairs(raiz:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
end

-- toda peça de folha: decorativa, sem colisão e sem massa. Fica CLICÁVEL de
-- propósito (CanQuery=true): a copa real cobre a árvore, então o clique quase sempre
-- cai numa folha — precisa registrar um hit pra o GestoCliente SUBIR até o tronco
-- taggeado e golpear a madeira. Com CanQuery=false o raio atravessava a copa e batia
-- no chão → clique perdido → "árvore incortável" (a regressão do 8d725f8).
-- CanCollide=false continua: folha não bloqueia o corpo nem o tombamento.
local function configurarFolha(parte: BasePart)
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = true -- clicável: o gesto sobe daqui pro tronco (ver GestoCliente)
	parte.CanTouch = false
	parte.Massless = true
	parte.CastShadow = true
end

-- ─────────────────────────────────────────────────────────────
-- Construção do tronco (o cilindro cortável). Agora em POSIÇÃO ARBITRÁRIA (posXZ):
-- o LoteServidor põe uma árvore por Slot do lote, em posição arbitrária. A escala da
-- espécie (gigantes) é aplicada depois por ScaleTo no Model inteiro.
-- ─────────────────────────────────────────────────────────────
local function construirTronco(especie, posXZ: Vector3)
	local m0 = Config.M0
	local x, z = posXZ.X, posXZ.Z

	local tronco = Instance.new("Part")
	tronco.Name = "Tronco"
	tronco.Shape = Enum.PartType.Cylinder
	-- cilindro no Roblox tem o eixo em X: girar 90° em Z o deixa de pé
	tronco.Size = Vector3.new(m0.TRONCO_ALTURA, m0.TRONCO_RAIO * 2, m0.TRONCO_RAIO * 2)
	tronco.CFrame = CFrame.new(x, m0.TRONCO_ALTURA / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	tronco.Anchored = true
	tronco.Color = especie.corTronco
	tronco.Material = Enum.Material.Wood
	tronco:SetAttribute("Cortes", 0)

	-- a TAG (cortável) só é adicionada quando a árvore vira adulta (tornarAdulto),
	-- pra a muda em crescimento não ser cortável e bugar o GeometryService.
	return tronco
end

-- ─────────────────────────────────────────────────────────────
-- Copa real (folhas de verdade) — carrega o MODELO curado UMA vez no boot,
-- normaliza (só a coroa de UMA árvore do pack, escala pro diâmetro alvo, base na
-- origem) e guarda como TEMPLATE em ServerStorage. Cada árvore só CLONA o template
-- (sem web call recorrente, sem hitch, copas consistentes).
-- ─────────────────────────────────────────────────────────────
local templateCopa: Model? = nil -- coroa normalizada, base do bbox na origem
local templateTentado = false -- já tentou carregar? (não repete o LoadAsset)

local function garantirTemplateCopa(): Model?
	if templateTentado then
		return templateCopa
	end
	templateTentado = true

	-- clona o modelo vendorizado (copa) de ReplicatedStorage.Modelos. Container = o
	-- Folder/Model com as árvores do pack dentro (mesma forma que o antigo LoadAsset).
	local container = clonarModeloVendorizado(Config.Copa.MODELO_INSTANCIA)
	if not container then
		warn(
			"[timber] copa: modelo '"
				.. tostring(Config.Copa.MODELO_INSTANCIA)
				.. "' ausente em ReplicatedStorage.Modelos — caindo na copa procedural"
		)
		return nil
	end

	removerScripts(container)

	-- FIX: escolhe a coroa de UMA árvore do pack — o FILHO Model com mais BaseParts.
	-- (Antes, `melhor` começava com o total do container, então nenhum filho ganhava
	-- e o PACK INTEIRO virava "copa". Agora só cai no container se nenhum filho servir.)
	local escolha: Instance? = nil
	local melhor = 0
	for _, filho in ipairs(container:GetChildren()) do
		if filho:IsA("Model") then
			local n = #coletarPartes(filho)
			if n > melhor then
				escolha, melhor = filho, n
			end
		end
	end
	if not escolha and #coletarPartes(container) > 0 then
		escolha = container
	end
	if not escolha or not escolha:IsA("Model") then
		container:Destroy()
		return nil
	end

	-- escala pro diâmetro alvo (a maior extensão horizontal vira DIAMETRO_ALVO)
	local _, tamanho = escolha:GetBoundingBox()
	local extHoriz = math.max(tamanho.X, tamanho.Z, 0.01)
	local escala = math.clamp(Config.Copa.DIAMETRO_ALVO / extHoriz, 0.02, 50)
	pcall(function()
		escolha:ScaleTo(escala)
	end)

	-- normaliza: bottom-center do bbox na ORIGEM. Assim cada clone só TRANSLADA
	-- pra posição da sua árvore (sem re-escalar nem GetBoundingBox por árvore).
	local bbCF, bbSize = escolha:GetBoundingBox()
	local baixoCentro =
		Vector3.new(bbCF.Position.X, bbCF.Position.Y - bbSize.Y / 2, bbCF.Position.Z)

	local guardado = Instance.new("Model")
	guardado.Name = "TemplateCopa"
	for _, parte in ipairs(coletarPartes(escolha)) do
		configurarFolha(parte)
		parte.Position = parte.Position - baixoCentro
		parte.Parent = guardado
	end
	container:Destroy()

	if #coletarPartes(guardado) == 0 then
		guardado:Destroy()
		return nil
	end
	guardado.Parent = ServerStorage
	templateCopa = guardado
	return templateCopa
end

-- clona o template na posição da árvore e tinge conforme a espécie. Ouro = dourado
-- Neon (jackpot); demais = lerp leve (mantém a textura real puxando a cor da espécie).
local function copaModeloReal(copa: Model, baseY: number, centroXZ: Vector3, especie): boolean
	local template = garantirTemplateCopa()
	if not template then
		return false
	end

	-- template está com bottom-center na origem: só translada pro topo do tronco
	-- (afundando SOBREPOR pra fechar o gap).
	local desloca = Vector3.new(centroXZ.X, baseY - Config.Copa.SOBREPOR, centroXZ.Z)

	for _, original in ipairs(coletarPartes(template)) do
		local parte = original:Clone()
		parte.Position = original.Position + desloca
		configurarFolha(parte)
		if especie.ouro then
			parte.Color = especie.corCopa
			parte.Material = Enum.Material.Neon
		else
			parte.Color = original.Color:Lerp(especie.corCopa, 0.45)
		end
		parte.Parent = copa
	end
	return true
end

-- ─────────────────────────────────────────────────────────────
-- Copa procedural (fallback) — aglomerado de esferas verdes em 2 camadas, com
-- variação de cor/tamanho. Não é a copa real, mas é bem mais cheia que 1 camada.
-- ─────────────────────────────────────────────────────────────
local function esferaFolha(copa: Model, nome: string, pos: Vector3, diametro: number, cor: Color3)
	local bola = Instance.new("Part")
	bola.Name = nome
	bola.Shape = Enum.PartType.Ball
	bola.Size = Vector3.new(diametro, diametro, diametro)
	bola.Position = pos
	bola.Color = cor
	bola.Material = Config.Copa.MATERIAL
	configurarFolha(bola)
	bola.Parent = copa
end

local function copaProcedural(copa: Model, baseY: number, centroXZ: Vector3, corCopa: Color3)
	local copaCfg = Config.Copa
	local corClara = corCopa:Lerp(Color3.fromRGB(255, 255, 255), 0.35) -- variação clara da espécie

	-- 2 camadas: anel largo embaixo + anel menor em cima → volume de copa
	local camadas = {
		{ y = baseY + copaCfg.RAIO * 0.7, disp = copaCfg.DISPERSAO, escala = 1.0 },
		{ y = baseY + copaCfg.RAIO * 1.7, disp = copaCfg.DISPERSAO * 0.6, escala = 0.82 },
	}
	for c, camada in ipairs(camadas) do
		for i = 1, copaCfg.BOLAS do
			local ang = (i / copaCfg.BOLAS) * math.pi * 2 + c * 0.4
			local raioBola = copaCfg.RAIO * camada.escala * (0.72 + math.random() * 0.4)
			local offX = math.cos(ang) * camada.disp * (0.5 + math.random() * 0.6)
			local offZ = math.sin(ang) * camada.disp * (0.5 + math.random() * 0.6)
			local offY = (math.random() - 0.5) * copaCfg.RAIO * 0.5
			esferaFolha(
				copa,
				"Folhas" .. c .. "_" .. i,
				Vector3.new(centroXZ.X + offX, camada.y + offY, centroXZ.Z + offZ),
				raioBola * 2,
				corCopa:Lerp(corClara, math.random() * 0.6)
			)
		end
	end
	-- coroa central pra fechar o topo
	esferaFolha(
		copa,
		"FolhasTopo",
		Vector3.new(centroXZ.X, baseY + copaCfg.RAIO * 2.2, centroXZ.Z),
		copaCfg.RAIO * 2.0,
		corCopa
	)
end

-- ─────────────────────────────────────────────────────────────
-- construirCopa — hub (pivot do wobble) + copa real (ou procedural no fallback).
-- As folhas ficam CLICÁVEIS (CanQuery=true): o clique nelas sobe pro tronco taggeado
-- (GestoCliente.resolverTronco) e o golpe é re-mirado na madeira. Só o hub invisível
-- fica CanQuery=false (não precisa ser alvo). Fica ANCORADA em pé; no tombar é soldada
-- ao tronco e desancorada, pra cair junto.
-- ─────────────────────────────────────────────────────────────
local function construirCopa(topoY, centroXZ, especie)
	local copaCfg = Config.Copa

	local copa = Instance.new("Model")
	copa.Name = "Copa"

	local baseY = topoY + copaCfg.ALTURA_OFFSET

	-- hub invisível na BASE da copa: é o PrimaryPart/pivot. O wobble do cliente
	-- pivota aqui, então a copa balança em cima da base plantada.
	local hub = Instance.new("Part")
	hub.Name = "CopaHub"
	hub.Shape = Enum.PartType.Ball
	hub.Size = Vector3.new(0.4, 0.4, 0.4)
	hub.Position = Vector3.new(centroXZ.X, baseY, centroXZ.Z)
	hub.Transparency = 1
	hub.CanCollide = false
	hub.CanQuery = false
	hub.CanTouch = false
	hub.Massless = true
	hub.Anchored = true
	hub.Parent = copa
	copa.PrimaryPart = hub

	local usouReal = false
	if copaCfg.USAR_MODELO_REAL then
		local ok, res = pcall(function()
			return copaModeloReal(copa, baseY, centroXZ, especie)
		end)
		usouReal = ok and res == true
	end

	if not usouReal then
		copaProcedural(copa, baseY, centroXZ, especie.corCopa)
	end

	-- diagnóstico (QA/validação): de onde veio a copa desta árvore.
	copa:SetAttribute("Fonte", usouReal and "modelo" or "procedural")

	return copa
end

-- ─────────────────────────────────────────────────────────────
-- Adulto / brilho de Ouro / crescimento
-- ─────────────────────────────────────────────────────────────
-- vira cortável: só o adulto ganha a TAG (a muda em crescimento não é alvo).
local function tornarAdulto(arvore: Model, tronco: BasePart)
	if tronco.Parent then
		CollectionService:AddTag(tronco, TAG_TRONCO)
	end
	arvore:SetAttribute("Adulto", true)
end

-- Árvore de Ouro: Highlight dourado (o "JACKPOT" visível de longe)
local function aplicarBrilhoOuro(arvore: Model)
	local brilho = Instance.new("Highlight")
	brilho.Name = "BrilhoOuro"
	brilho.FillColor = Color3.fromRGB(255, 214, 90)
	brilho.FillTransparency = 0.55
	brilho.OutlineColor = Color3.fromRGB(255, 244, 180)
	brilho.OutlineTransparency = 0
	brilho.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	brilho.Adornee = arvore
	brilho.Parent = arvore
end

-- planta a base do Model no chão (fundo do bbox em y=0, o topo do terreno),
-- preservando XZ. Usado após escalar a gigante e a cada passo do crescimento.
local function plantarBase(arvore: Model)
	local bbCF, bbSize = arvore:GetBoundingBox()
	local fundo = bbCF.Position.Y - bbSize.Y / 2
	arvore:PivotTo(arvore:GetPivot() + Vector3.new(0, -fundo, 0)) -- chão em y=0
end

-- crescimento visível: nasce muda (escala ESCALA_INICIAL) e cresce até escalaAlvo
-- (1 = base; gigantes vão além, ex.: Sequoia 4,5×) em DURACAO_CRESCIMENTO_S, mantendo
-- a BASE plantada no chão. Vira adulto (ganha a tag) no fim e chama aoAdulto (o ciclo
-- do toco usa isso pra fechar EmCiclo e sumir com o toco).
local function crescer(arvore: Model, tronco: BasePart, escalaAlvo: number, aoAdulto)
	local reb = Config.Rebrote
	local inicial = reb.ESCALA_INICIAL

	pcall(function()
		arvore:ScaleTo(inicial)
		plantarBase(arvore)
	end)

	-- passo FIXO (task.wait), não por frame: ~25 passos em 2,5s em vez de ~150
	-- ScaleTo+GetBoundingBox/s replicando o Model inteiro por muda.
	task.spawn(function()
		local passos = math.max(1, math.floor(reb.DURACAO_CRESCIMENTO_S / reb.PASSO_CRESCIMENTO_S))
		for i = 1, passos do
			if not arvore.Parent or not tronco.Parent then
				return
			end
			local k = i / passos -- 0 → 1
			local ease = 1 - (1 - k) * (1 - k) -- ease-out
			local s = inicial + (escalaAlvo - inicial) * ease
			pcall(function()
				arvore:ScaleTo(s)
				plantarBase(arvore)
			end)
			task.wait(reb.PASSO_CRESCIMENTO_S)
		end
		if arvore.Parent and tronco.Parent then
			pcall(function()
				arvore:ScaleTo(escalaAlvo)
				plantarBase(arvore)
			end)
			tornarAdulto(arvore, tronco)
			if aoAdulto then
				aoAdulto(arvore)
			end
		end
	end)
end

-- ─────────────────────────────────────────────────────────────
-- nascer(id, pai, opts) — monta a árvore inteira numa posição e devolve o Model.
--   opts.especie  : Especie a usar (default = sorteio por peso do Catalogo)
--   opts.posicao  : Vector3 base XZ (y ignorado; base assenta em y=0). Default = ORIGEM
--   (id)          : v2 = o índice do SLOT dentro do lote; vira o nome do Model e o
--                   atributo "Slot" que o ciclo do toco usa pra renascer no lugar
--   opts.crescer  : se true, nasce muda e cresce (rebrote); default = adulto na hora
--   opts.aoAdulto : callback(arvore) quando a árvore fica adulta (ciclo do toco)
-- ─────────────────────────────────────────────────────────────
function ArvoreServidor.nascer(id, pai, opts)
	opts = opts or {}
	local especie = opts.especie or Especies.sortear()
	local pos = opts.posicao or Config.M0.ORIGEM

	local arvore = Instance.new("Model")
	arvore.Name = "Arvore" .. tostring(id)

	local tronco = construirTronco(especie, pos)
	tronco.Parent = arvore
	arvore.PrimaryPart = tronco

	local topoY = tronco.Position.Y + Config.M0.TRONCO_ALTURA / 2
	local copa = construirCopa(topoY, tronco.Position, especie)
	copa.Parent = arvore

	-- escala da espécie (gigantes). MassaInicial é a massa NO TAMANHO CHEIO já escalado:
	-- ScaleTo multiplica cada dimensão por esc → volume/massa × esc³. Guardar assim faz
	-- o limiar dos 93% valer igual pra Pinho pequeno e pra Sequoia gigante.
	local esc = especie.escala or 1

	-- estado vive no MODEL (sobrevive à troca do Part do tronco a cada corte)
	arvore:SetAttribute("MassaInicial", tronco:GetMass() * esc ^ 3) -- massa do TAMANHO CHEIO
	arvore:SetAttribute("Tombou", false)
	arvore:SetAttribute("Tora", false)
	arvore:SetAttribute("Slot", id) -- pro ciclo do toco renascer no mesmo lugar
	arvore:SetAttribute("Especie", especie.nome)
	arvore:SetAttribute("Multiplicador", especie.valorMultiplicador) -- $ futuro (M2)
	arvore:SetAttribute("Ouro", especie.ouro)
	arvore:SetAttribute("Escala", esc)
	arvore:SetAttribute("BaseXZ", Vector3.new(pos.X, 0, pos.Z)) -- pro toco brotar no lugar exato

	if especie.ouro then
		aplicarBrilhoOuro(arvore)
	end

	arvore.Parent = pai

	if opts.crescer then
		crescer(arvore, tronco, esc, opts.aoAdulto) -- muda → adulto gigante (ganha a tag) ao terminar
	else
		-- spawn do lote: já ADULTA e cortável. Escala a árvore inteira (tronco + copa) e
		-- replanta a base no chão. ScaleTo em pcall pra uma escala ruim nunca derrubar o spawn.
		if esc ~= 1 then
			pcall(function()
				arvore:ScaleTo(esc)
				plantarBase(arvore)
			end)
		end
		tornarAdulto(arvore, tronco) -- boot inicial: já adulto e cortável
		if opts.aoAdulto then
			opts.aoAdulto(arvore)
		end
	end

	return arvore
end

-- ─────────────────────────────────────────────────────────────
-- Direção da queda: horizontal, do centro do tronco pro ponto do último golpe
-- (o entalhe). A árvore cai pro lado do entalhe; a física resolve o resto.
-- ─────────────────────────────────────────────────────────────
local function direcaoQueda(tronco, contato)
	local dir = contato - tronco.Position
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.05 then
		-- sem lado claro: escolhe um horizontal qualquer, física decide
		local a = math.random() * math.pi * 2
		return Vector3.new(math.cos(a), 0, math.sin(a))
	end
	return dir.Unit
end

-- ─────────────────────────────────────────────────────────────
-- Ciclo TOCO → BROTOS (substitui o rebrote antigo de muda nascendo inteira no slot).
-- ─────────────────────────────────────────────────────────────
-- índice do mapa logístico que avança 1 por rebrote: o DropBreathing "respira" o
-- intervalo do broto em vez do math.random uniforme (metrônomo). SPEC §5.
local brotoFrame = 0

local function intervaloBroto(): number
	local toco = Config.Toco
	-- JITTER continua sendo a AMPLITUDE (±35%); o mapa logístico dá a SEQUÊNCIA —
	-- determinística e "respirada", nunca a mesma cadência, mas dentro do envelope.
	brotoFrame += 1
	local jit = 1 + DropBreathing.JitterNormalizado(brotoFrame) * toco.JITTER -- ∈ [1-JITTER, 1+JITTER]
	return math.max(0.5, toco.INTERVALO_BROTO_S * jit)
end

-- TOCO: cepo baixo ancorado no lugar da árvore, cor/material da espécie, com um disco
-- fino de anéis no topo. NÃO é cortável (sem tag, CanQuery=false).
local function construirToco(pai: Instance, baseXZ: Vector3, especie): Model
	local tocoCfg = Config.Toco
	local raio = Config.M0.TRONCO_RAIO * (especie.escala or 1) * tocoCfg.RAIO_FATOR

	local toco = Instance.new("Model")
	toco.Name = "Toco"

	local cepo = Instance.new("Part")
	cepo.Name = "Cepo"
	cepo.Shape = Enum.PartType.Cylinder
	cepo.Size = Vector3.new(tocoCfg.ALTURA, raio * 2, raio * 2)
	cepo.CFrame = CFrame.new(baseXZ.X, tocoCfg.ALTURA / 2, baseXZ.Z)
		* CFrame.Angles(0, 0, math.rad(90))
	cepo.Anchored = true
	cepo.CanCollide = true -- cepo sólido no chão
	cepo.CanQuery = false -- não intercepta o raio do corte (não é alvo)
	cepo.CanTouch = false
	cepo.Material = Enum.Material.Wood
	cepo.Color = especie.corTronco
	cepo.Parent = toco
	toco.PrimaryPart = cepo

	if tocoCfg.ANEIS then
		local aneis = Instance.new("Part")
		aneis.Name = "Aneis"
		aneis.Shape = Enum.PartType.Cylinder
		aneis.Size = Vector3.new(0.12, raio * 2 * 0.96, raio * 2 * 0.96)
		aneis.CFrame = CFrame.new(baseXZ.X, tocoCfg.ALTURA + 0.05, baseXZ.Z)
			* CFrame.Angles(0, 0, math.rad(90))
		aneis.Anchored = true
		aneis.CanCollide = false
		aneis.CanQuery = false
		aneis.CanTouch = false
		aneis.Material = Enum.Material.Wood
		aneis.Color = especie.corTronco:Lerp(Color3.fromRGB(232, 210, 170), tocoCfg.COR_ANEIS_LERP)
		aneis.Parent = toco
	end

	toco.Parent = pai
	return toco
end

-- BROTOS: 1-3 mudinhas decorativas (haste marrom fina + copa mini verde) saindo do
-- topo do toco. Puramente visual — some quando a árvore de verdade começa a crescer.
local function construirBrotos(pai: Instance, baseXZ: Vector3, especie, qtd: number): { Model }
	local tocoCfg = Config.Toco
	local raioToco = Config.M0.TRONCO_RAIO * (especie.escala or 1) * tocoCfg.RAIO_FATOR
	local brotos = {}

	for i = 1, qtd do
		local ang = (i - 1) / qtd * math.pi * 2 + math.random() * 0.6
		local off = raioToco
			* tocoCfg.BROTO_ESPALHA
			* (qtd > 1 and (0.4 + math.random() * 0.6) or 0)
		local bx = baseXZ.X + math.cos(ang) * off
		local bz = baseXZ.Z + math.sin(ang) * off
		local h = tocoCfg.BROTO_ALTURA * (0.7 + math.random() * 0.5)

		local broto = Instance.new("Model")
		broto.Name = "Broto" .. i

		local haste = Instance.new("Part")
		haste.Name = "Haste"
		haste.Shape = Enum.PartType.Cylinder
		haste.Size = Vector3.new(h, 0.28, 0.28)
		haste.CFrame = CFrame.new(bx, tocoCfg.ALTURA + h / 2, bz)
			* CFrame.Angles(0, 0, math.rad(90))
		haste.Anchored = true
		haste.CanCollide = false
		haste.CanQuery = false
		haste.CanTouch = false
		haste.Material = Enum.Material.Wood
		haste.Color = especie.corTronco
		haste.Parent = broto

		local folha = Instance.new("Part")
		folha.Name = "Folha"
		folha.Shape = Enum.PartType.Ball
		folha.Size = Vector3.new(1.2, 1.2, 1.2)
		folha.Position = Vector3.new(bx, tocoCfg.ALTURA + h + 0.3, bz)
		folha.Anchored = true
		folha.CanCollide = false
		folha.CanQuery = false
		folha.CanTouch = false
		folha.Massless = true
		folha.Material = Config.Copa.MATERIAL
		folha.Color = especie.corCopa:Lerp(Color3.fromRGB(150, 220, 120), 0.35)
		folha.Parent = broto

		broto.Parent = pai
		table.insert(brotos, broto)
	end
	return brotos
end

-- agenda o ciclo: a árvore acabou de tombar (vira Tora, some daqui a TORA_VIDA_S).
-- No lugar nasce um TOCO; depois do intervalo brotam mudinhas; uma cresce até adulta
-- e VOLTA a ser cortável — SEMPRE no mesmo folder-pai (v2: o Slot do lote; antes era
-- o Site do mundo). O ciclo é AUTÔNOMO: ninguém precisa orquestrar o rebrote de fora.
-- O folder pai fica marcado EmCiclo o tempo todo (leitura de estado pra quem quiser
-- saber se o slot está ocupado pelo toco/brotos — ex.: persistência no M2).
function ArvoreServidor.iniciarCicloToco(arvore: Model)
	local folder = arvore.Parent
	if typeof(folder) ~= "Instance" then
		return
	end
	local slot = arvore:GetAttribute("Slot") or 0
	local baseXZ = arvore:GetAttribute("BaseXZ")
	if typeof(baseXZ) ~= "Vector3" then
		local pivot = arvore:GetPivot().Position
		baseXZ = Vector3.new(pivot.X, 0, pivot.Z)
	end
	local especie = Especies.porNome(arvore:GetAttribute("Especie")) or Especies.sortear()

	folder:SetAttribute("EmCiclo", true)

	-- a árvore tombada vira Tora e some sozinha (Debris). O toco a substitui na base.
	arvore.Name = "Tora" .. tostring(slot)
	Debris:AddItem(arvore, Config.Rebrote.TORA_VIDA_S)

	local toco = construirToco(folder, baseXZ, especie)

	task.delay(intervaloBroto(), function()
		if not folder or not folder.Parent then
			return
		end
		local qtd = math.random(Config.Toco.BROTOS_MIN, Config.Toco.BROTOS_MAX)
		local brotos = construirBrotos(folder, baseXZ, especie, qtd)

		task.delay(Config.Toco.ESPERA_CRESCER_S, function()
			if not folder or not folder.Parent then
				return
			end
			for _, b in ipairs(brotos) do
				if b and b.Parent then
					b:Destroy()
				end
			end
			-- uma muda cresce de verdade (escala 0.08 → cheia) e vira cortável.
			ArvoreServidor.nascer(slot, folder, {
				especie = especie,
				posicao = baseXZ,
				crescer = true,
				aoAdulto = function()
					folder:SetAttribute("EmCiclo", false)
					if Config.Toco.SUMIR_TOCO and toco and toco.Parent then
						toco:Destroy()
					end
				end,
			})
		end)
	end)
end

-- ─────────────────────────────────────────────────────────────
-- tombar — desancora, empurra leve pro lado do entalhe, física derruba.
-- ─────────────────────────────────────────────────────────────
function ArvoreServidor.tombar(arvore, tronco, contato, autor)
	if typeof(arvore) ~= "Instance" or not arvore:IsA("Model") then
		return
	end
	if arvore:GetAttribute("Tombou") then
		return -- trava: nunca tomba duas vezes
	end
	if not tronco or not tronco.Parent then
		return
	end
	arvore:SetAttribute("Tombou", true)

	-- FIX A2 (lado servidor): posição replicável da queda. `dados.arvore` (Instance)
	-- chega nil pro cliente sem o Model streamado (StreamingEnabled); um Vector3 SEMPRE
	-- replica. Captura ANTES do impulso (física só anda no próximo step) = o lugar de
	-- onde a árvore começou a cair. A camada de animação consome `dados.posicao`+`dados.autor`.
	local posQueda = arvore:GetPivot().Position

	local tomb = Config.Tombamento
	local dir = direcaoQueda(tronco, contato)

	-- solda a copa ao tronco ATUAL (pós-cortes) e desancora tudo, pra cair junto
	local copa = arvore:FindFirstChild("Copa")
	if copa then
		for _, parte in ipairs(copa:GetDescendants()) do
			if parte:IsA("BasePart") then
				local solda = Instance.new("WeldConstraint")
				solda.Part0 = tronco
				solda.Part1 = parte
				solda.Parent = tronco
				parte.Anchored = false
			end
		end
	end
	tronco.Anchored = false

	-- empurrão no TOPO (alavanca) + torque de ajuda; tudo × massa pra escalar bem
	local massa = tronco.AssemblyMass
	local topo = tronco.Position + Vector3.new(0, Config.M0.TRONCO_ALTURA * tomb.ALTURA_EMPURRAO, 0)
	tronco:ApplyImpulseAtPosition(dir * tomb.IMPULSO * massa, topo)
	-- eixo horizontal perpendicular à direção → tomba PRA FRENTE, na direção dir
	local eixoTorque = Vector3.yAxis:Cross(dir)
	if eixoTorque.Magnitude > 0.01 then
		tronco:ApplyAngularImpulse(eixoTorque.Unit * tomb.TORQUE * massa)
	end

	Net.TroncoTombou:FireAllClients({
		arvore = arvore, -- mantido (compat): quem tem o Model streamado ainda usa
		posicao = posQueda, -- A2: Vector3 sempre replica (fallback quando arvore=nil no cliente)
		direcao = dir,
		qualidade = tronco:GetAttribute("Cortes") or 0,
		autor = autor, -- quem derrubou: só ele credita o bônus de TORA no HUD
	})

	-- assentou? vira tora deitada. Detecta velocidade baixa DEPOIS de ter se
	-- movido (senão o 1º tick pega o impulso ainda "frio" e marca cedo demais).
	task.spawn(function()
		local prazo = os.clock() + tomb.TEMPO_MAX_ASSENTAR_S
		local moveu = false
		while os.clock() < prazo do
			task.wait(0.25)
			if not tronco.Parent then
				break
			end
			local v = tronco.AssemblyLinearVelocity.Magnitude
			if v >= tomb.VEL_ASSENTAR then
				moveu = true
			elseif moveu then
				break -- estava caindo e agora parou → assentou como tora
			end
		end
		if arvore.Parent then
			arvore:SetAttribute("Tora", true)
		end
		if tronco and tronco.Parent then
			tronco:SetAttribute("Tora", true)
		end

		-- IMPACTO NO CHÃO (SPEC § 2.6): o áudio segue a FÍSICA. Este ponto é o
		-- assentamento de verdade — o loop acima só sai daqui quando a tora parou
		-- (ou quando o TEMPO_MAX_ASSENTAR_S estourou / o tronco sumiu). Um FireAllClients
		-- só, nos três caminhos, pro cliente nunca ficar sem fechamento nem tocar
		-- o CRASH duas vezes. O TroncoTombou lá em cima continua sendo o INÍCIO da queda.
		do
			-- o CortadorServidor TROCA o Part do tronco a cada corte (inclusive numa
			-- tora recortada enquanto cai): pega o tronco VIVO pelo PrimaryPart do Model,
			-- e só cai no `tronco` original se ele ainda estiver na árvore.
			local troncoVivo: BasePart? = nil
			if tronco and tronco.Parent then
				troncoVivo = tronco
			elseif arvore.Parent and arvore.PrimaryPart then
				troncoVivo = arvore.PrimaryPart
			end

			local posImpacto = posQueda -- fallback: de onde ela começou a cair
			if arvore.Parent then
				local okPivot, pivot = pcall(function()
					return arvore:GetPivot().Position
				end)
				if okPivot and typeof(pivot) == "Vector3" then
					posImpacto = pivot
				end
			elseif troncoVivo then
				posImpacto = troncoVivo.Position
			end

			Net.ImpactoSolo:FireAllClients({
				posicao = posImpacto,
				autor = autor,
				especie = arvore:GetAttribute("Especie"),
				qualidade = (troncoVivo and troncoVivo:GetAttribute("Cortes")) or 0,
			})
		end
		-- copa numa tora deitada não agrega e, se o jogador recortar a tora, o swap
		-- do CortadorServidor mataria as soldas e a copa afundaria pelo chão. Decisão
		-- (a mais limpa): a copa cai junto durante o tombo — soldada — e é REMOVIDA
		-- assim que a tora assenta. Sem copa órfã, sem solda pra recolar a cada corte.
		if copa and copa.Parent then
			copa:Destroy()
		end
		-- fecha o loop: toco no lugar → brotos → nova árvore cortável no MESMO Slot do lote
		if arvore.Parent then
			ArvoreServidor.iniciarCicloToco(arvore)
		end
	end)
end

-- ─────────────────────────────────────────────────────────────
-- aoCortar — o CortadorServidor chama depois de resolver cada corte. Decide se a
-- geometria remanescente passou do limiar estrutural e, se sim, manda tombar.
-- ─────────────────────────────────────────────────────────────
function ArvoreServidor.aoCortar(tronco, contato, autor)
	if not tronco or not tronco.Parent then
		return
	end
	local arvore = tronco.Parent
	if typeof(arvore) ~= "Instance" or not arvore:IsA("Model") then
		return -- tronco solto (compat): sem Model = sem tombamento
	end
	if arvore:GetAttribute("Tombou") then
		-- recorte na tora ainda caindo: o swap do Cortador mata as soldas da copa.
		-- Remove a copa na hora pra ela não afundar pelo chão até o assentamento.
		local copa = arvore:FindFirstChild("Copa")
		if copa then
			copa:Destroy()
		end
		return
	end

	local massaInicial = arvore:GetAttribute("MassaInicial")
	if typeof(massaInicial) ~= "number" or massaInicial <= 0 then
		return
	end

	local massaAtual = tronco:GetMass()
	if massaAtual <= massaInicial * Config.Tombamento.LIMIAR_MASSA then
		ArvoreServidor.tombar(arvore, tronco, contato, autor)
	end
end

return ArvoreServidor
