--[[
	BalancoCliente — o SWING do machado.

	Problema que resolve: hoje o "golpe" é só a mãozinha do mouse clicando; o
	machado fica parado. Aqui, no mesmo Activated que o GestoCliente usa pra
	mandar o corte, animamos o Tool.Grip num arco rápido de descida — o MACHADO
	desce golpeando e volta pro repouso.

	Por que via Grip: o Handle está soldado à mão pelo RightGrip weld, cujo C0 é o
	Tool.Grip. Mexer no Grip enquanto equipado reposiciona a solda ao vivo, então
	girar o Grip = animar o machado na mão. Mexer no Handle.CFrame direto não
	adianta (a solda sobrescreve). É client-side e local: é a SENSAÇÃO do dono da
	arma que importa aqui.

	NÃO editamos o GestoCliente: só nos plugamos no MESMO evento Activated (e no
	atalho F, que o spike também usa) via conexões próprias. As constantes são
	LOCAIS (não tocamos no ConfiguracaoTimber).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local jogador = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────
-- Constantes do swing (LOCAIS, tunáveis ao vivo no Studio)
--
-- JUICE (diretriz de VFX, ver README): o golpe agora tem as 3 FASES do
-- feedback sensorial — ANTECIPAÇÃO → IMPACTO → RECUO — cada uma com seu easing,
-- em vez de um arco liso "morto". A antecipação é o wind-up que dá PESO; o impacto
-- é seco/acelerado (o frame do baque); o recuo assenta suave. Jitter por golpe
-- ("atractor estranho": golpes parecidos, nunca idênticos)
-- tira o robótico. Um punch curtíssimo no impacto (overshoot + shudder) dá o kick.
-- ─────────────────────────────────────────────────────────────
local ARCO_GRAUS = 72 -- amplitude do IMPACTO (quanto a lâmina desce pra frente)
local ARCO_JITTER_GRAUS = 6 -- ± variação do arco por golpe (vida, não-robótico)
local ANTICIP_GRAUS = 16 -- quanto o machado RECUA/sobe no wind-up (antecipação)
local ANTICIP_JITTER_GRAUS = 3 -- ± variação da antecipação por golpe

-- durações por fase (s); a duração total é a soma — o IMPACTO cai em
-- ANTECIPACAO_S+IMPACTO_S após o Activated, que é ~quando o servidor registra o golpe.
local ANTECIPACAO_S = 0.07 -- wind-up rápido pra trás/cima
local IMPACTO_S = 0.05 -- descida seca e acelerada até o tronco
local RECUO_S = 0.15 -- volta suave ao repouso
local DURACAO_S = ANTECIPACAO_S + IMPACTO_S + RECUO_S -- 0.27
local COOLDOWN_S = 0.24 -- trava pra não empilhar swings em cliques rápidos

-- punch do impacto: um overshoot curtíssimo (a lâmina "morde" e recua) + um shudder
-- de roll, decaindo em PUNCH_S. É o kick de PESO, respeitando o guard do swing.
local PUNCH_GRAUS = 7 -- overshoot além do arco no instante do baque
local PUNCH_ROLL_GRAUS = 4 -- tremidinha lateral (roll) no impacto
local PUNCH_S = 0.09 -- quanto tempo o punch leva pra sumir

-- fronteiras das fases em fração de DURACAO_S (0→1)
local FIM_ANTECIPACAO = ANTECIPACAO_S / DURACAO_S
local FIM_IMPACTO = (ANTECIPACAO_S + IMPACTO_S) / DURACAO_S

-- ─────────────────────────────────────────────────────────────
-- Constantes do swing do FACÃO (LOCAIS, tunáveis ao vivo).
--
-- O facão NÃO é o chop vertical do machado: é um golpe RÁPIDO em arco LATERAL e
-- OBLÍQUO — a lâmina cocka pra um lado (wind-up), varre horizontalmente cruzando o
-- alvo e desce um pouco no meio do caminho (corte oblíquo). Mais rápido e mais leve
-- que o machado (cooldown menor), condizente com o Config.Ferramentas.Facao (lâmina
-- fina, tira menos por golpe). Com a pose GRIP_FACAO (lâmina apontando pra FRENTE),
-- girar em torno do Z LOCAL do Handle = varredura horizontal (yaw); girar no Y LOCAL
-- = descer a ponta (a obliquidade). O sinal do lado é sorteado por golpe (esquerda↔
-- direita) pra não ficar robótico.
-- ─────────────────────────────────────────────────────────────
local ARCO_LAT_GRAUS = 96 -- amplitude do IMPACTO: quanto a lâmina varre lateralmente
local ARCO_LAT_JITTER_GRAUS = 8 -- ± variação do arco lateral por golpe
local ANTICIP_LAT_GRAUS = 30 -- quanto a lâmina cocka pro lado OPOSTO no wind-up
local ANTICIP_LAT_JITTER_GRAUS = 4 -- ± variação da antecipação por golpe
local DESCIDA_GRAUS = 20 -- quanto a PONTA desce no meio do arco (corte oblíquo)

-- durações por fase (s) — facão é MAIS RÁPIDO que o machado (total ~0.20 vs 0.27)
local ANTECIPACAO_FACAO_S = 0.05
local IMPACTO_FACAO_S = 0.04
local RECUO_FACAO_S = 0.11
local DURACAO_FACAO_S = ANTECIPACAO_FACAO_S + IMPACTO_FACAO_S + RECUO_FACAO_S -- 0.20
local COOLDOWN_FACAO_S = 0.16 -- menor que o do machado (0.24): facão martela mais rápido

-- punch do impacto (facão): overshoot lateral curtíssimo + shudder
local PUNCH_LAT_GRAUS = 9 -- overshoot além do arco lateral no baque
local PUNCH_ROLL_FACAO_GRAUS = 5 -- tremidinha (roll) no impacto
local PUNCH_FACAO_S = 0.08

-- fronteiras das fases do facão em fração de DURACAO_FACAO_S (0→1)
local FIM_ANTECIPACAO_FACAO = ANTECIPACAO_FACAO_S / DURACAO_FACAO_S
local FIM_IMPACTO_FACAO = (ANTECIPACAO_FACAO_S + IMPACTO_FACAO_S) / DURACAO_FACAO_S

-- ─────────────────────────────────────────────────────────────
-- Estado — o dono segura um machado por vez; guardamos o Grip de repouso
-- capturado no Equipped pra sempre voltar pra pose certa.
-- ─────────────────────────────────────────────────────────────
local toolAtual: Tool? = nil
local gripRepouso = CFrame.identity
local balancando = false
local ultimoBalanco = 0

-- easing por fase via TweenService:GetValue (idiomático, sem TweenService:Create pra
-- não brigar com a lógica de abort/restauração do loop manual).
local function ease(alfa: number, estilo: Enum.EasingStyle, dir: Enum.EasingDirection): number
	return TweenService:GetValue(math.clamp(alfa, 0, 1), estilo, dir)
end

--[[ Ângulo do arco no tempo `t` (0→1), com as 3 fases. Retorna também o roll do
	punch. `arco`/`anticip` são os alvos jitterados deste golpe específico. ]]
local function poseNoTempo(t: number, arco: number, anticip: number): (number, number)
	local ang: number
	if t <= FIM_ANTECIPACAO then
		-- ANTECIPAÇÃO: 0 → -anticip (recua/sobe), ease-out (arranca e assenta)
		local a = ease(t / FIM_ANTECIPACAO, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		ang = -anticip * a
	elseif t <= FIM_IMPACTO then
		-- IMPACTO: -anticip → arco, ease-IN acelerando (fica SECO no baque)
		local a = ease(
			(t - FIM_ANTECIPACAO) / (FIM_IMPACTO - FIM_ANTECIPACAO),
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		ang = -anticip + (arco + anticip) * a
	else
		-- RECUO: arco → 0, ease-out suave (assenta no repouso)
		local a = ease(
			(t - FIM_IMPACTO) / (1 - FIM_IMPACTO),
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out
		)
		ang = arco * (1 - a)
	end

	-- punch: overshoot + shudder que decaem em PUNCH_S logo após o instante do impacto
	local roll = 0
	if t >= FIM_IMPACTO then
		local decai = 1 - math.clamp((t - FIM_IMPACTO) * DURACAO_S / PUNCH_S, 0, 1)
		if decai > 0 then
			ang += math.rad(PUNCH_GRAUS) * decai -- morde além do arco e recua
			roll = math.rad(PUNCH_ROLL_GRAUS) * decai
		end
	end
	return ang, roll
end

local function animarMachado(tool: Tool)
	-- jitter por golpe (variação orgânica, caos determinístico): arco/antecipação
	-- variam ± e o shudder escolhe um lado, então nenhum golpe é idêntico.
	local arco = math.rad(ARCO_GRAUS + (math.random() - 0.5) * 2 * ARCO_JITTER_GRAUS)
	local anticip = math.rad(ANTICIP_GRAUS + (math.random() - 0.5) * 2 * ANTICIP_JITTER_GRAUS)
	local ladoRoll = if math.random() < 0.5 then -1 else 1

	local t0 = os.clock()
	while true do
		if tool.Parent == nil or toolAtual ~= tool then
			break -- desequipou/trocou no meio: aborta sem forçar Grip
		end
		local t = (os.clock() - t0) / DURACAO_S
		if t >= 1 then
			break
		end
		local ang, roll = poseNoTempo(t, arco, anticip)
		-- Chop vertical: com a pose nova (cabeça pra CIMA), o eixo LATERAL do
		-- personagem (right) é o Y LOCAL do Handle — então giramos em torno do Y
		-- local, e a cabeça desce de cima pra FRENTE (golpe de machado). Girar no
		-- X local (versão antiga) rodava em torno da cabeça = rodopio horizontal.
		-- Sinal negativo leva o gume pro LookVector, não pra trás. O roll (Z local)
		-- é o shudder curtíssimo do punch — some sozinho no fim.
		tool.Grip = gripRepouso * CFrame.Angles(0, -ang, ladoRoll * roll)
		RunService.Heartbeat:Wait()
	end
	if tool.Parent ~= nil and toolAtual == tool then
		tool.Grip = gripRepouso -- assenta de volta no repouso
	end
end

--[[ Pose do FACÃO no tempo `t` (0→1), 3 fases (antecipação → impacto → recuo).
	Retorna o ângulo LATERAL (varredura horizontal), o PITCH de descida (obliquidade)
	e o roll do punch. `arcoLat`/`anticipLat` são os alvos jitterados deste golpe. ]]
local function poseFacaoNoTempo(
	t: number,
	arcoLat: number,
	anticipLat: number
): (number, number, number)
	local lateral: number
	if t <= FIM_ANTECIPACAO_FACAO then
		-- ANTECIPAÇÃO: 0 → -anticipLat (cocka pro lado oposto), ease-out
		local a = ease(t / FIM_ANTECIPACAO_FACAO, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		lateral = -anticipLat * a
	elseif t <= FIM_IMPACTO_FACAO then
		-- IMPACTO: -anticipLat → arcoLat, ease-IN acelerando (varredura SECA)
		local a = ease(
			(t - FIM_ANTECIPACAO_FACAO) / (FIM_IMPACTO_FACAO - FIM_ANTECIPACAO_FACAO),
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		lateral = -anticipLat + (arcoLat + anticipLat) * a
	else
		-- RECUO: arcoLat → 0, ease-out suave (assenta no repouso)
		local a = ease(
			(t - FIM_IMPACTO_FACAO) / (1 - FIM_IMPACTO_FACAO),
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out
		)
		lateral = arcoLat * (1 - a)
	end

	-- descida oblíqua: a ponta cai no MEIO do arco e sobe de volta (seno = 0 nas pontas,
	-- máximo no meio) — dá o corte oblíquo em vez de horizontal seco.
	local pitch = math.rad(DESCIDA_GRAUS) * math.sin(math.clamp(t, 0, 1) * math.pi)

	-- punch: overshoot lateral + shudder que decaem logo após o impacto
	local roll = 0
	if t >= FIM_IMPACTO_FACAO then
		local decai = 1
			- math.clamp((t - FIM_IMPACTO_FACAO) * DURACAO_FACAO_S / PUNCH_FACAO_S, 0, 1)
		if decai > 0 then
			lateral += math.rad(PUNCH_LAT_GRAUS) * decai
			roll = math.rad(PUNCH_ROLL_FACAO_GRAUS) * decai
		end
	end
	return lateral, pitch, roll
end

local function animarFacao(tool: Tool)
	-- jitter por golpe; o LADO da varredura é sorteado (esquerda↔direita) pra não repetir.
	local arcoLat = math.rad(ARCO_LAT_GRAUS + (math.random() - 0.5) * 2 * ARCO_LAT_JITTER_GRAUS)
	local anticipLat =
		math.rad(ANTICIP_LAT_GRAUS + (math.random() - 0.5) * 2 * ANTICIP_LAT_JITTER_GRAUS)
	local lado = if math.random() < 0.5 then -1 else 1

	local t0 = os.clock()
	while true do
		if tool.Parent == nil or toolAtual ~= tool then
			break -- desequipou/trocou no meio: aborta sem forçar Grip
		end
		local t = (os.clock() - t0) / DURACAO_FACAO_S
		if t >= 1 then
			break
		end
		local lateral, pitch, roll = poseFacaoNoTempo(t, arcoLat, anticipLat)
		-- Varredura LATERAL: com a GRIP_FACAO (lâmina apontando pra FRENTE), o Z LOCAL
		-- do Handle é ~a vertical do personagem — girar nele varre a lâmina na
		-- horizontal (yaw). O Y LOCAL desce a PONTA (obliquidade). `lado` espelha o
		-- golpe esquerda↔direita. É o oposto do chop vertical do machado (que gira no Y).
		tool.Grip = gripRepouso * CFrame.Angles(pitch, lado * roll, lado * lateral)
		RunService.Heartbeat:Wait()
	end
	if tool.Parent ~= nil and toolAtual == tool then
		tool.Grip = gripRepouso -- assenta de volta no repouso
	end
end

--[[ Escolhe a animação conforme a Tool equipada: facão = arco lateral rápido;
	qualquer outra (machado/default) = chop vertical. ]]
local function animar(tool: Tool)
	if tool.Name == "Facao" then
		animarFacao(tool)
	else
		animarMachado(tool)
	end
end

local function balancar()
	local tool = toolAtual
	if not tool then
		return
	end
	local agora = os.clock()
	-- facão martela mais rápido → cooldown próprio, menor que o do machado.
	local cooldown = if tool.Name == "Facao" then COOLDOWN_FACAO_S else COOLDOWN_S
	if balancando or (agora - ultimoBalanco) < cooldown then
		return
	end
	balancando = true
	ultimoBalanco = agora
	task.spawn(function()
		animar(tool)
		balancando = false
	end)
end

-- ─────────────────────────────────────────────────────────────
-- Plug nos Tools: captura o Grip de repouso no Equipped e dispara o swing no
-- Activated. Guarda de idempotência: o Tool transita Backpack↔Character
-- (ChildAdded redispara) e sem isso cada re-equip empilharia conexões (leak).
-- ─────────────────────────────────────────────────────────────
local function ligarTool(inst: Instance)
	if not inst:IsA("Tool") then
		return
	end
	local tool = inst :: Tool
	if tool:GetAttribute("BalancoLigado") then
		return
	end
	tool:SetAttribute("BalancoLigado", true)

	tool.Equipped:Connect(function()
		toolAtual = tool
		gripRepouso = tool.Grip -- pose de repouso definida pelo ConstruirFerramentas
	end)

	tool.Unequipped:Connect(function()
		if toolAtual == tool then
			tool.Grip = gripRepouso
			toolAtual = nil
		end
	end)

	tool.Activated:Connect(balancar)

	-- Já-equipado no load: se o LocalScript acorda DEPOIS do machado já estar na
	-- mão (Tool é filho do Character), o Equipped já disparou e não vai redisparar
	-- — sem isto, toolAtual ficaria nil e o 1º clique não animaria o swing (o
	-- usuário veria "a mãozinha" golpeando no 1º spawn). Captura o estado na hora.
	if tool.Parent == jogador.Character then
		toolAtual = tool
		gripRepouso = tool.Grip
	end
end

local function ligarPersonagem(personagem: Instance)
	personagem.ChildAdded:Connect(ligarTool)
	for _, filho in ipairs(personagem:GetChildren()) do
		ligarTool(filho)
	end
end

if jogador.Character then
	ligarPersonagem(jogador.Character)
end
jogador.CharacterAdded:Connect(ligarPersonagem)

-- atalho F: o GestoCliente também corta no F sem precisar clicar; espelhamos o
-- swing quando há um machado equipado, pra sensação bater com o corte.
UserInputService.InputBegan:Connect(function(input, digitando)
	if digitando then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		local char = jogador.Character
		local tool = char and char:FindFirstChildOfClass("Tool")
		if tool then
			if toolAtual ~= tool then
				toolAtual = tool
				gripRepouso = tool.Grip
			end
			balancar()
		end
	end
end)
