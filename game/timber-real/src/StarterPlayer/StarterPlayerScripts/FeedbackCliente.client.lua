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
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.ConfiguracaoTimber)
local Net = require(ReplicatedStorage.Net)
local Assets = require(ReplicatedStorage:WaitForChild("Catalogo"):WaitForChild("Assets"))
local GolpeLocal = require(script.Parent.GolpeLocal)

local cfg = Config.Feedback
local jogador = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- último golpe local: o CorteResolvido não carrega ponto, então guardamos aqui.
local ultimoPonto: Vector3? = nil
local popAtual: { label: TextLabel?, expira: number }? = nil

-- ─────────────────────────────────────────────────────────────
-- Preload dos SFX (se algum falhar, engole e segue — jogo nunca quebra)
-- ─────────────────────────────────────────────────────────────
task.spawn(function()
	local alvos = {}
	for _, chave in ipairs({ "SFX_HIT_MADEIRA_1", "SFX_HIT_MADEIRA_2", "SFX_LASCA_MADEIRA" }) do
		local rbx = Assets.Rbx(chave)
		if rbx then
			table.insert(alvos, rbx)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(alvos)
	end)
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
	p.Speed = NumberRange.new(cfg.SERRAGEM_VELOCIDADE * 0.6, cfg.SERRAGEM_VELOCIDADE)
	p.SpreadAngle = Vector2.new(28, 28)
	p.EmissionDirection = Enum.NormalId.Front
	p.Acceleration = Vector3.new(0, -18, 0) -- serragem cai
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-120, 120)
	-- // polish: textura de serragem via lab-factory-assets. Sem Texture = default.
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
-- Número pop — sobe e some via Tween. Debris + teto pra não vazar GUI.
-- ─────────────────────────────────────────────────────────────
local popsAtivos = 0

local function novaPop(ponto: Vector3, texto: string): TextLabel?
	if popsAtivos >= cfg.POP_MAX_SIMULTANEOS then
		return nil
	end
	popsAtivos += 1

	local base = ancora(ponto)

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 96, 0, 42)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	bb.Adornee = base
	bb.Parent = base

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(236, 224, 190)
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(40, 26, 14)
	label.TextScaled = true
	label.Text = texto
	label.Parent = bb

	local info = TweenInfo.new(cfg.POP_DURACAO_S, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(base, info, { Position = ponto + Vector3.new(0, cfg.POP_SUBIDA_STUDS, 0) })
		:Play()
	TweenService:Create(
		label,
		TweenInfo.new(cfg.POP_DURACAO_S, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()

	Debris:AddItem(base, cfg.POP_DURACAO_S + 0.05)
	task.delay(cfg.POP_DURACAO_S + 0.05, function()
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
-- Som — no ponto, com cooldown mínimo. Falha de load = silêncio, nunca crash.
-- ─────────────────────────────────────────────────────────────
local somProximo = 0

local function tocar(ponto: Vector3, chave: string, volume: number?)
	local agora = os.clock()
	if agora < somProximo then
		return
	end
	somProximo = agora + cfg.SOM_COOLDOWN_S

	local rbx = Assets.Rbx(chave)
	if not rbx then
		return
	end

	pcall(function()
		local base = ancora(ponto)
		local som = Instance.new("Sound")
		som.SoundId = rbx
		som.Volume = volume or cfg.SOM_VOLUME
		som.RollOffMinDistance = 8
		som.RollOffMaxDistance = 90
		som.Parent = base
		som:Play()
		Debris:AddItem(base, 3)
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

	serragem(ponto, normal, cfg.SERRAGEM_PARTICULAS)
	tremer()

	alternarSom = 1 - alternarSom
	tocar(ponto, if alternarSom == 0 then "SFX_HIT_MADEIRA_1" else "SFX_HIT_MADEIRA_2")

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
		local texto = string.format("+%.1f", r.volume or 0)
		local atual = popAtual
		if atual and atual.label and atual.label.Parent and os.clock() < atual.expira then
			atual.label.Text = texto -- vira o volume real, no lugar
		elseif ultimoPonto then
			novaPop(ultimoPonto, texto) -- pop já sumiu: um fresco com o número
		end

		-- servidor confirmou cacos: um segundo respingo de serragem + estalo
		if (r.cacos or 0) > 0 and ultimoPonto then
			serragem(ultimoPonto, Vector3.yAxis, math.min(10, (r.cacos or 0) * 2))
			tocar(ultimoPonto, "SFX_LASCA_MADEIRA")
		end
	elseif r.erro then
		-- golpe recusado: apaga o número otimista e dá só um "tick" sutil
		local atual = popAtual
		if atual and atual.label and atual.label.Parent then
			atual.label.Text = ""
		end
		tocar(ultimoPonto or camera.CFrame.Position, "SFX_HIT_MADEIRA_2", 0.18)
	end
end)

-- limpa o bind se o jogador sair (defensivo; a VM geralmente já vai embora)
Players.PlayerRemoving:Connect(function(saindo)
	if saindo == jogador then
		pcall(function()
			RunService:UnbindFromRenderStep("TimberShake")
		end)
	end
end)
