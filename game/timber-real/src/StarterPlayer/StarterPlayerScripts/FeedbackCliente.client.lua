--[[
	FeedbackCliente — a camada R1 de "juice" do corte, TODA client-side e IMEDIATA.

	Empilha (diretriz de VFX, ver README): serragem (partícula) + número pop + som + camera
	shake LEVE. Dispara no PONTO do raycast que o GestoCliente já tem, sem esperar
	o servidor (SPEC risco #4 — mata o golpe borrachudo). Quando o resultado real
	chega (CorteResolvido), o número pop vira o volume de verdade.

	Regras duras: Rate CAPADO na partícula, cooldown no som e no shake, teto de
	pops simultâneos. Mobile-safe. Nada aqui altera o M0 (diagnóstico/veredito):
	é só feedback sensorial e visual.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.ConfiguracaoTimber)
local Net = require(ReplicatedStorage.Net)
local Assets = require(ReplicatedStorage:WaitForChild("Catalogo"):WaitForChild("Assets"))
local GolpeLocal = require(script.Parent.GolpeLocal)

local cfg = Config.Feedback
local jogador = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ─────────────────────────────────────────────────────────────
-- VFX de impacto ADICIONAIS (constantes LOCAIS — não mexo no ConfiguracaoTimber,
-- outra tarefa pode estar nele). Empilham no golpe seguindo a diretriz de VFX:
-- além da serragem, uma nuvem curta de POEIRA/pó de madeira + um FLASH/scratch
-- seco no ponto de contato. No tombamento, um baque de poeira MAIOR na base.
-- Tudo :Emit (Rate=0, cap) + Debris, client-side, mobile-safe.
-- ─────────────────────────────────────────────────────────────
local POEIRA_PARTICULAS = 6 -- pó de madeira por golpe (cap)
local POEIRA_VIDA = NumberRange.new(0.35, 0.7)
local POEIRA_COR = ColorSequence.new(Color3.fromRGB(150, 120, 86), Color3.fromRGB(120, 96, 66))
local FLASH_PARTICULAS = 3 -- fagulhas claras do "scratch" do gume mordendo
local FLASH_VIDA = NumberRange.new(0.05, 0.1)
local BASE_POEIRA_PARTICULAS = 18 -- clímax: puff grande e rasteiro na base da tora

-- formata madeira: 1.2k / 3.4M pra números grandes, decimal pros pequenos (não há
-- Util/Numeros no projeto). Mesma regra usada no HUDCliente.
local function formatarMadeira(n: number): string
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

-- último golpe local: o CorteResolvido não carrega ponto, então guardamos aqui.
local ultimoPonto: Vector3? = nil
local popAtual: { label: TextLabel?, expira: number }? = nil

-- ─────────────────────────────────────────────────────────────
-- Preload dos SFX (se algum falhar, engole e segue — jogo nunca quebra)
-- ─────────────────────────────────────────────────────────────
task.spawn(function()
	-- PreloadAsync exige um array de Instances, NÃO de strings rbxassetid://
	-- (senão o engine lança "Unable to cast value to Object" e o pcall come tudo,
	-- deixando o 1º golpe mudo). Criamos Sounds temporários só pro preload.
	local alvos = {}
	-- inclui o SFX_QUEDA_ARVORE (clímax, tocado no ImpactoSolo): sem preload, o 1º
	-- "Timber!" entraria com delay de load — e delay de load num som que DEVE bater
	-- junto com a física é exatamente o bug que o § 2.6 manda matar. Os demais são
	-- impacto/lasca do golpe a golpe (o rangido do início da queda reusa a lasca).
	for _, chave in ipairs({
		"SFX_HIT_MADEIRA_1",
		"SFX_HIT_MADEIRA_2",
		"SFX_LASCA_MADEIRA",
		"SFX_QUEDA_ARVORE",
	}) do
		local rbx = Assets.Rbx(chave)
		if rbx then
			local som = Instance.new("Sound")
			som.SoundId = rbx
			table.insert(alvos, som)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(alvos)
	end)
	-- as instances só serviam pro preload; o cache do asset fica no engine
	for _, som in ipairs(alvos) do
		som:Destroy()
	end
end)

-- ─────────────────────────────────────────────────────────────
-- Helper: um Part âncora invisível e descartável no mundo
-- ─────────────────────────────────────────────────────────────
local function ancora(ponto: Vector3): BasePart
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Position = ponto
	p.Parent = workspace
	return p
end

-- ─────────────────────────────────────────────────────────────
-- Serragem — ParticleEmitter em burst, jogado pra fora da superfície
-- ─────────────────────────────────────────────────────────────
local function serragem(ponto: Vector3, normal: Vector3, quantidade: number)
	local emissor = ancora(ponto)
	-- olhar na direção da normal: a face Front (LookVector) aponta pra fora.
	emissor.CFrame = CFrame.lookAt(ponto, ponto + normal)

	local p = Instance.new("ParticleEmitter")
	p.Rate = 0 -- CAP: nada contínuo, só o :Emit(n) abaixo
	p.Lifetime = NumberRange.new(cfg.SERRAGEM_VIDA_MIN, cfg.SERRAGEM_VIDA_MAX)
	p.Speed = NumberRange.new(cfg.SERRAGEM_VELOCIDADE * 0.7, cfg.SERRAGEM_VELOCIDADE * 1.15)
	-- DIRECIONAL: leque largo na horizontal, apertado na vertical → a serragem
	-- esguicha AO LONGO da linha do corte (não um cone isotrópico). Lê como "o gume
	-- rasgou a fibra", que é o que a diretriz de VFX pede pro impacto ter direção.
	p.SpreadAngle = Vector2.new(52, 16)
	p.EmissionDirection = Enum.NormalId.Front
	p.Acceleration = Vector3.new(0, -18, 0) -- serragem cai
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-120, 120)
	-- // polish: textura de serragem curada. Sem Texture = default.
	p.Color = ColorSequence.new(Color3.fromRGB(120, 82, 52), Color3.fromRGB(96, 66, 40))
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.Parent = emissor
	p:Emit(quantidade)

	Debris:AddItem(emissor, 1)
end

-- ─────────────────────────────────────────────────────────────
-- POEIRA — nuvem curta de pó de madeira que se abre e assenta no impacto. Mais
-- lenta e maior que a serragem, sai da face do corte (normal) e paira antes de
-- cair. É a "massa" do impacto (empilhar camadas de partícula).
-- ─────────────────────────────────────────────────────────────
local function poeira(ponto: Vector3, normal: Vector3)
	local base = ancora(ponto)
	base.CFrame = CFrame.lookAt(ponto, ponto + normal)

	local p = Instance.new("ParticleEmitter")
	p.Rate = 0 -- CAP: só :Emit
	p.Lifetime = POEIRA_VIDA
	p.Speed = NumberRange.new(1, 4)
	p.SpreadAngle = Vector2.new(70, 40)
	p.EmissionDirection = Enum.NormalId.Front
	p.Acceleration = Vector3.new(0, -3, 0) -- pó paira e cai devagar
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-40, 40)
	p.LightEmission = 0.1
	p.Color = POEIRA_COR
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 1.3), -- expande: nuvem se abrindo
	})
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.Parent = base
	p:Emit(POEIRA_PARTICULAS)

	Debris:AddItem(base, 1)
end

-- ─────────────────────────────────────────────────────────────
-- FLASH/scratch — o beliscão seco do gume mordendo: fagulhas claras rápidas +
-- um PointLight curtíssimo (flash de luz pra impacto). Marca o
-- FRAME do baque; some em ~0.1s pra não virar luz constante (anti-padrão).
-- ─────────────────────────────────────────────────────────────
local function flash(ponto: Vector3, normal: Vector3)
	local base = ancora(ponto)
	base.CFrame = CFrame.lookAt(ponto, ponto + normal)

	local p = Instance.new("ParticleEmitter")
	p.Rate = 0 -- CAP: só :Emit
	p.Lifetime = FLASH_VIDA
	p.Speed = NumberRange.new(6, 12)
	p.SpreadAngle = Vector2.new(40, 40)
	p.EmissionDirection = Enum.NormalId.Front
	p.LightEmission = 1
	p.Color = ColorSequence.new(Color3.fromRGB(255, 244, 214))
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(1, 0),
	})
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.Parent = base
	p:Emit(FLASH_PARTICULAS)

	-- flash de luz seco; fade em ~0.09s via tween e Debris limpa a âncora
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 236, 196)
	luz.Range = 7
	luz.Brightness = 2.2
	luz.Parent = base
	TweenService:Create(
		luz,
		TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	):Play()

	Debris:AddItem(base, 0.2)
end

-- ─────────────────────────────────────────────────────────────
-- POEIRA DE BASE — o baque do clímax (tombamento): um anel rasteiro de pó grande
-- que esparrama e assenta na base da tora. Só no TroncoTombou, uma vez por queda.
-- ─────────────────────────────────────────────────────────────
local function poeiraBase(ponto: Vector3)
	local base = ancora(ponto)

	local p = Instance.new("ParticleEmitter")
	p.Rate = 0 -- CAP: só :Emit
	p.Lifetime = NumberRange.new(0.6, 1.2)
	p.Speed = NumberRange.new(3, 9)
	p.SpreadAngle = Vector2.new(180, 25) -- anel rasteiro (esparrama no chão)
	p.EmissionDirection = Enum.NormalId.Top
	p.Acceleration = Vector3.new(0, -4, 0)
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-60, 60)
	p.Color = POEIRA_COR
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 2.2),
		NumberSequenceKeypoint.new(1, 3.4), -- expande grande
	})
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.Parent = base
	p:Emit(BASE_POEIRA_PARTICULAS)

	Debris:AddItem(base, 1.6)
end

-- ─────────────────────────────────────────────────────────────
-- Número pop — sobe e some via Tween. Debris + teto pra não vazar GUI.
-- ─────────────────────────────────────────────────────────────
local popsAtivos = 0

-- opcoes (todas opcionais): cor, escala (× tamanho), duracao, subida. Sem elas usa
-- o pop padrão "+madeira". Com elas vira o pop grande dourado de TORA.
type OpcoesPop = { cor: Color3?, escala: number?, duracao: number?, subida: number? }

local function novaPop(ponto: Vector3, texto: string, opcoes: OpcoesPop?): TextLabel?
	if popsAtivos >= cfg.POP_MAX_SIMULTANEOS then
		return nil
	end
	popsAtivos += 1

	local o = opcoes or {}
	local escala = o.escala or 1
	local duracao = o.duracao or cfg.POP_DURACAO_S
	local subida = o.subida or cfg.POP_SUBIDA_STUDS

	local base = ancora(ponto)

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, math.floor(96 * escala), 0, math.floor(42 * escala))
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 160
	bb.Adornee = base
	bb.Parent = base

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = o.cor or Color3.fromRGB(236, 224, 190)
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(40, 26, 14)
	label.TextScaled = true
	label.Text = texto
	label.Parent = bb

	local info = TweenInfo.new(duracao, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(base, info, { Position = ponto + Vector3.new(0, subida, 0) }):Play()
	TweenService:Create(
		label,
		TweenInfo.new(duracao, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()

	Debris:AddItem(base, duracao + 0.05)
	task.delay(duracao + 0.05, function()
		popsAtivos -= 1
	end)

	return label
end

-- ─────────────────────────────────────────────────────────────
-- Camera shake LEVE — offset aplicado DEPOIS da câmera (RenderPriority.Camera+1),
-- decai em ~0.12s, com cooldown pra não empilhar.
-- ─────────────────────────────────────────────────────────────
local shakeAte = 0
local shakeProxima = 0

local function tremer()
	local agora = os.clock()
	if agora < shakeProxima then
		return
	end
	shakeProxima = agora + cfg.SHAKE_COOLDOWN_S
	shakeAte = agora + cfg.SHAKE_DURACAO_S
end

RunService:BindToRenderStep("TimberShake", Enum.RenderPriority.Camera.Value + 1, function()
	local agora = os.clock()
	if agora >= shakeAte then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local restante = (shakeAte - agora) / cfg.SHAKE_DURACAO_S -- 1 → 0
	local amp = math.rad(cfg.SHAKE_AMPLITUDE_GRAUS) * restante
	local rx = (math.random() - 0.5) * 2 * amp
	local ry = (math.random() - 0.5) * 2 * amp
	cam.CFrame = cam.CFrame * CFrame.Angles(rx, ry, 0)
end)

-- ─────────────────────────────────────────────────────────────
-- FOV PUNCH (clímax do tombamento) — um "soco" de câmera:
-- kick rápido no FieldOfView (+8°) e volta suave (settle). Dá peso/impacto à queda.
--
-- Robustez: a contribuição é ADITIVA e RELATIVA. Cada frame tiramos a nossa parcela
-- antiga do FOV e somamos a nova (delta). Assim NUNCA guardamos um "FOV base" que
-- possa envelhecer: qualquer mudança externa de FOV (zoom, estado especial) é
-- preservada, e ao terminar restauramos EXATAMENTE o FOV que o resto do jogo deixou —
-- inclusive se outro punch vier no meio (o bookkeeping do delta re-rampa sozinho).
-- Cooldown ≈ duração total pra não empilhar. Fora da janela não tocamos no FOV.
-- ─────────────────────────────────────────────────────────────
local FOV_PUNCH_GRAUS = 8 -- amplitude do kick (dentro dos 6~10° do brief)
local FOV_PUNCH_SUBIDA_S = 0.08 -- sobe rápido (o baque)
local FOV_PUNCH_VOLTA_S = 0.25 -- assenta suave (settle)
local FOV_PUNCH_TOTAL_S = FOV_PUNCH_SUBIDA_S + FOV_PUNCH_VOLTA_S
local FOV_PUNCH_COOLDOWN_S = 0.35
local fovPunchInicio = 0 -- 0 = nunca disparado
local fovPunchProxima = 0
local fovOffsetAplicado = 0 -- quanto NÓS somamos ao FOV por último

local function fovPunch()
	local agora = os.clock()
	if agora < fovPunchProxima then
		return -- cooldown: não empilha
	end
	fovPunchProxima = agora + FOV_PUNCH_COOLDOWN_S
	fovPunchInicio = agora -- (re)inicia a linha do tempo do punch
end

RunService:BindToRenderStep("TimberFovPunch", Enum.RenderPriority.Camera.Value + 1, function()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local alvo = 0
	local t = os.clock() - fovPunchInicio
	if fovPunchInicio > 0 and t >= 0 and t < FOV_PUNCH_TOTAL_S then
		if t < FOV_PUNCH_SUBIDA_S then
			-- 0 → GRAUS, ease-out (soco rápido)
			local k = t / FOV_PUNCH_SUBIDA_S
			alvo = FOV_PUNCH_GRAUS * (1 - (1 - k) * (1 - k))
		else
			-- GRAUS → 0, ease-out (assenta: começa rápido, termina devagar)
			local k = (t - FOV_PUNCH_SUBIDA_S) / FOV_PUNCH_VOLTA_S
			alvo = FOV_PUNCH_GRAUS * (1 - k) * (1 - k)
		end
	end
	-- aplica só o DELTA da nossa contribuição → preserva qualquer FOV externo e
	-- restaura exato quando alvo volta a 0 (aí paramos de escrever no FOV).
	if alvo ~= fovOffsetAplicado then
		cam.FieldOfView = cam.FieldOfView - fovOffsetAplicado + alvo
		fovOffsetAplicado = alvo
	end
end)

-- ─────────────────────────────────────────────────────────────
-- Som — no ponto, com cooldown mínimo. Falha de load = silêncio, nunca crash.
-- ─────────────────────────────────────────────────────────────
-- cooldown SEPARADO por canal: a lasca (chega no CorteResolvido, <80ms após o
-- hit local) não pode ser engolida pelo cooldown do hit. Cada canal tem o seu.
local somProximo: { [string]: number } = {}

local function tocar(ponto: Vector3, chave: string, canal: string, volume: number?, pitch: number?)
	local agora = os.clock()
	if agora < (somProximo[canal] or 0) then
		return
	end
	somProximo[canal] = agora + cfg.SOM_COOLDOWN_S

	local rbx = Assets.Rbx(chave)
	if not rbx then
		return
	end

	pcall(function()
		local base = ancora(ponto)
		local som = Instance.new("Sound")
		som.SoundId = rbx
		som.Volume = volume or cfg.SOM_VOLUME
		som.PlaybackSpeed = pitch or 1 -- pitch: PlaybackSpeed (Pitch é depreciado)
		som.RollOffMinDistance = 8
		som.RollOffMaxDistance = 90
		som.Parent = base
		som:Play()
		Debris:AddItem(base, 4)
	end)
end

-- pitch aleatório de impacto dentro da faixa configurada (0.9–1.1)
local function pitchImpacto(): number
	return cfg.SOM_PITCH_MIN + math.random() * (cfg.SOM_PITCH_MAX - cfg.SOM_PITCH_MIN)
end

-- ─────────────────────────────────────────────────────────────
-- Shake da ÁRVORE (R1 SPEC § 14) — a cada golpe a copa faz um wobble rotacional
-- LEVE e amortecido, pivotando na base (a base fica plantada, a copa balança).
-- Client-side: o servidor deixa a copa ancorada e parada entre cortes, então o
-- PivotTo local segura sem brigar com replicação. Por golpe, com cooldown.
-- ─────────────────────────────────────────────────────────────
local TAG_TRONCO = Config.Tags.TRONCO
local copaProxima: { [Instance]: number } = {} -- cooldown por copa
local copaOcupada: { [Instance]: boolean } = {} -- wobble em curso por copa
local copaVigiada: { [Instance]: boolean } = {} -- já conectada ao Destroying?

-- limpa as entradas quando a copa é destruída (ex.: tora assentou, ou respawn no
-- M2). Sem isso, os mapas seguravam Models mortos pra sempre (vazamento).
local function vigiarCopa(copa: Instance)
	if copaVigiada[copa] then
		return
	end
	copaVigiada[copa] = true
	copa.Destroying:Once(function()
		copaProxima[copa] = nil
		copaOcupada[copa] = nil
		copaVigiada[copa] = nil
	end)
end

-- acha a árvore (Model) cujo tronco tá mais perto do ponto do golpe
local function arvoreDoPonto(ponto: Vector3): (Model?, BasePart?)
	local melhor: BasePart? = nil
	local melhorDist: number? = nil
	for _, parte in ipairs(CollectionService:GetTagged(TAG_TRONCO)) do
		if parte:IsA("BasePart") then
			local d = (parte.Position - ponto).Magnitude
			if not melhorDist or d < melhorDist then
				melhor, melhorDist = parte, d
			end
		end
	end
	if melhor and melhorDist and melhorDist <= cfg.ARVORE_SHAKE_RAIO_BUSCA then
		return melhor:FindFirstAncestorWhichIsA("Model"), melhor
	end
	return nil, nil
end

-- burst leve de folhas caindo (opcional, cosmético) no centro da copa
local function folhasCaindo(copa: Model)
	local hub = copa.PrimaryPart
	if not hub then
		return
	end
	local base = ancora(hub.Position + Vector3.new(0, Config.Copa.RAIO, 0))
	local p = Instance.new("ParticleEmitter")
	p.Rate = 0 -- CAP: só o :Emit abaixo
	p.Lifetime = NumberRange.new(0.8, 1.4)
	p.Speed = NumberRange.new(0.5, 2)
	p.SpreadAngle = Vector2.new(60, 60)
	p.Acceleration = Vector3.new(0, -6, 0) -- folha cai devagar
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-90, 90)
	p.Color = ColorSequence.new(Color3.fromRGB(72, 142, 52), Color3.fromRGB(46, 104, 38))
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.Parent = base
	p:Emit(4)
	Debris:AddItem(base, 1.6)
end

local function sacudirArvore(ponto: Vector3)
	local arvore, tronco = arvoreDoPonto(ponto)
	if not arvore or not tronco then
		return
	end
	if arvore:GetAttribute("Tombou") then
		return -- já caindo/caída: não sacode
	end
	local copa = arvore:FindFirstChild("Copa")
	if not copa or not copa:IsA("Model") or not copa.PrimaryPart then
		return
	end
	vigiarCopa(copa)

	local agora = os.clock()
	if agora < (copaProxima[copa] or 0) then
		return
	end
	copaProxima[copa] = agora + cfg.ARVORE_SHAKE_COOLDOWN_S
	if copaOcupada[copa] then
		return
	end
	copaOcupada[copa] = true

	-- a copa inclina na direção do golpe (tronco → ponto)
	local dirH = Vector3.new(ponto.X - tronco.Position.X, 0, ponto.Z - tronco.Position.Z)
	if dirH.Magnitude < 0.05 then
		dirH = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
	end
	local eixo = Vector3.yAxis:Cross(dirH) -- eixo em torno do qual a copa inclina
	if eixo.Magnitude < 0.01 then
		eixo = Vector3.xAxis
	end
	eixo = eixo.Unit

	local repouso = copa:GetPivot()
	local pos = repouso.Position
	local rotRepouso = repouso - pos -- CFrame só-rotação (posição na origem)

	folhasCaindo(copa)

	task.spawn(function()
		local amp = math.rad(cfg.ARVORE_SHAKE_GRAUS)
		local dur = cfg.ARVORE_SHAKE_DURACAO_S
		local osc = cfg.ARVORE_SHAKE_OSCILACOES
		local t = 0
		while t < dur do
			if not copa.Parent or not copa.PrimaryPart or arvore:GetAttribute("Tombou") then
				break
			end
			local k = t / dur -- 0 → 1
			local ang = amp * (1 - k) * math.sin(k * osc * math.pi * 2) -- amortecido
			pcall(function()
				copa:PivotTo(CFrame.new(pos) * CFrame.fromAxisAngle(eixo, ang) * rotRepouso)
			end)
			t += RunService.Heartbeat:Wait()
		end
		-- assenta de volta no repouso, se ainda de pé
		if copa.Parent and copa.PrimaryPart and not arvore:GetAttribute("Tombou") then
			pcall(function()
				copa:PivotTo(CFrame.new(pos) * rotRepouso)
			end)
		end
		copaOcupada[copa] = nil
	end)
end

-- ─────────────────────────────────────────────────────────────
-- Golpe LOCAL — dispara tudo na hora, sem esperar o servidor
-- ─────────────────────────────────────────────────────────────
local alternarSom = 0

GolpeLocal.conectar(function(golpe)
	local ponto = golpe.ponto
	local normal = golpe.normal
	ultimoPonto = ponto

	-- empilha as camadas do impacto: serragem direcional + poeira +
	-- flash + tremor de câmera, todas no MESMO frame do baque.
	serragem(ponto, normal, cfg.SERRAGEM_PARTICULAS)
	poeira(ponto, normal)
	flash(ponto, normal)
	tremer()
	sacudirArvore(ponto)

	alternarSom = 1 - alternarSom
	tocar(
		ponto,
		if alternarSom == 0 then "SFX_HIT_MADEIRA_1" else "SFX_HIT_MADEIRA_2",
		"hit",
		cfg.SOM_VOLUME,
		pitchImpacto()
	)

	popAtual = {
		label = novaPop(ponto, "+madeira"),
		expira = os.clock() + cfg.POP_DURACAO_S,
	}
end)

-- ─────────────────────────────────────────────────────────────
-- Resultado do servidor — refina o feedback já mostrado
-- ─────────────────────────────────────────────────────────────
Net.CorteResolvido.OnClientEvent:Connect(function(r)
	if typeof(r) ~= "table" then
		return
	end

	if r.ok then
		local texto = "+" .. formatarMadeira(r.volume or 0)
		-- NOTA(M0): race cosmetica conhecida — com 2 golpes em voo o volume pode
		-- cair no pop errado. Fix futuro: seq no payload. Deferido (juice, sem crash).
		local atual = popAtual
		if atual and atual.label and atual.label.Parent and os.clock() < atual.expira then
			atual.label.Text = texto -- vira o volume real, no lugar
		elseif ultimoPonto then
			novaPop(ultimoPonto, texto) -- pop já sumiu: um fresco com o número
		end

		-- servidor confirmou cacos: um segundo respingo de serragem + estalo (mais baixo)
		if (r.cacos or 0) > 0 and ultimoPonto then
			serragem(ultimoPonto, Vector3.yAxis, math.min(10, (r.cacos or 0) * 2))
			tocar(ultimoPonto, "SFX_LASCA_MADEIRA", "lasca", cfg.SOM_VOLUME_LASCA, pitchImpacto())
		end
	elseif r.erro then
		-- golpe recusado: apaga o número otimista e dá só um "tick" sutil
		local atual = popAtual
		if atual and atual.label and atual.label.Parent then
			atual.label.Text = ""
		end
		-- canal próprio: o tick não pode ser engolido pelo cooldown do hit local.
		tocar(ultimoPonto or camera.CFrame.Position, "SFX_HIT_MADEIRA_2", "tick", 0.18)
	end
end)

-- ─────────────────────────────────────────────────────────────
-- QUEDA em DOIS tempos (SPEC § 2.6) — o áudio segue a FÍSICA:
--   • TroncoTombou → INÍCIO da queda (a árvore perdeu a estrutura e começa a tombar):
--     só um rangido/estalo LEVE. Nada de CRASH, poeira grande ou shake aqui — a
--     árvore ainda está de pé, e era esse o desalinhamento reclamado no v1.
--   • ImpactoSolo  → ASSENTAMENTO no chão (o servidor detectou a tora parar): AQUI
--     vai o clímax inteiro — CRASH grave, poeira rasteira, thud duplo de câmera,
--     FOV punch e o pop dourado "TORA!".
-- O CRASH mora num evento SÓ; nunca nos dois.
-- ─────────────────────────────────────────────────────────────

-- ponto do evento: prioriza `dados.posicao` (Vector3 SEMPRE replica). O `dados.arvore`
-- (Instance) chega nil no cliente sem o Model streamado (StreamingEnabled) — com lotes
-- distantes isso virou o caso COMUM, não a exceção. Fallback final: o último golpe local.
local function pontoDoEvento(dados): Vector3
	if typeof(dados.posicao) == "Vector3" then
		return dados.posicao
	end
	local arvore = dados.arvore
	if typeof(arvore) == "Instance" and arvore:IsA("Model") then
		local ok, pivot = pcall(function()
			return arvore:GetPivot().Position
		end)
		if ok and typeof(pivot) == "Vector3" then
			return pivot
		end
	end
	return ultimoPonto or camera.CFrame.Position
end

-- INÍCIO da queda: rangido leve e posicional. Toca pra todo mundo (é som de mundo,
-- com rolloff curto — quem está a 900 studs, no próprio lote, não ouve nada).
if Net.TroncoTombou then
	Net.TroncoTombou.OnClientEvent:Connect(function(dados)
		if typeof(dados) ~= "table" then
			return
		end
		tocar(
			pontoDoEvento(dados),
			"SFX_LASCA_MADEIRA",
			"rangido",
			cfg.SOM_VOLUME_RANGIDO,
			cfg.SOM_PITCH_RANGIDO
		)
	end)
end

-- IMPACTO NO CHÃO: o CLÍMAX — pico de dopamina do loop.
if Net.ImpactoSolo then
	Net.ImpactoSolo.OnClientEvent:Connect(function(dados)
		if typeof(dados) ~= "table" then
			return
		end
		local ponto = pontoDoEvento(dados)

		-- efeitos de MUNDO (posicionais, atenuados por distância): a poeira da base e
		-- o baque grave acontecem no lugar da tora, pra quem estiver perto ver/ouvir.
		poeiraBase(ponto)
		-- SFX_QUEDA_ARVORE ("Tree Fall") do catálogo, no volume do clímax e com pitch
		-- NATURAL (1.0): o asset dedicado já tem o peso da queda, não precisa arrastar.
		tocar(ponto, "SFX_QUEDA_ARVORE", "queda", cfg.SOM_VOLUME_QUEDA, 1)

		-- efeitos de CÂMERA e a recompensa são só de quem DERRUBOU (gate A2): sacudir a
		-- tela de quem não cortou nada é ruído, não recompensa.
		if dados.autor ~= jogador then
			return
		end

		tremer()
		task.delay(0.2, tremer)
		fovPunch()

		novaPop(ponto + Vector3.new(0, 6, 0), "TORA! +" .. formatarMadeira(cfg.TORA_BONUS), {
			cor = cfg.POP_TORA_COR,
			escala = cfg.POP_TORA_ESCALA,
			duracao = cfg.POP_TORA_DURACAO_S,
			subida = cfg.POP_TORA_SUBIDA_STUDS,
		})
	end)
end

-- limpa o bind se o jogador sair (defensivo; a VM geralmente já vai embora)
Players.PlayerRemoving:Connect(function(saindo)
	if saindo == jogador then
		pcall(function()
			RunService:UnbindFromRenderStep("TimberShake")
			RunService:UnbindFromRenderStep("TimberFovPunch")
		end)
	end
end)
