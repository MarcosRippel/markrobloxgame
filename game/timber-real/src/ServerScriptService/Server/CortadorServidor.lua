--[[
	CortadorServidor — a FACHADA do corte. É o coração do jogo.

	Interface estável (SPEC § 3.3): cortar(jogador, alvo, cframes, ferramentaId).
	Por trás dela pode viver o Plano A (geometria real via GeometryService) ou o
	Plano B (tronco pré-segmentado). O M0 existe pra decidir qual dos dois.

	Plano A, em três passos:
	  1. SweepPartAsync   — o MOVIMENTO da lâmina vira um sólido de corte
	  2. SubtractAsync    — esse sólido é removido do tronco  → o corte
	  3. FragmentAsync    — voronoi localizado no ponto de impacto → as lascas

	Corte é server-authoritative: o cliente manda o gesto, nunca o resultado.
	(A doc é clara: CSG no cliente não replica pro servidor.)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.ConfiguracaoTimber)
local FilaGeometria = require(script.Parent.FilaGeometria)
local DetritoServidor = require(script.Parent.DetritoServidor)

local CortadorServidor = {}

local GeometryService
do
	local ok, servico = pcall(function()
		return game:GetService("GeometryService")
	end)
	GeometryService = ok and servico or nil
end

local ultimoGolpe = {} -- [Player] = os.clock()

local TAG_TRONCO = "TroncoCortavel"

CortadorServidor.TAG_TRONCO = TAG_TRONCO

-- ─────────────────────────────────────────────────────────────
-- Validação (anti-cheat mínimo — o servidor não confia em nada)
-- ─────────────────────────────────────────────────────────────
local function validar(jogador, alvo, cframes, ferramenta)
	if typeof(alvo) ~= "Instance" or not alvo:IsA("BasePart") then
		return false, "alvo inválido"
	end
	if not CollectionService:HasTag(alvo, TAG_TRONCO) then
		return false, "alvo não é tronco"
	end
	if typeof(cframes) ~= "table" then
		return false, "gesto inválido"
	end

	local n = #cframes
	if n < Config.Geometria.AMOSTRAS_GESTO_MIN or n > Config.Geometria.AMOSTRAS_GESTO_MAX then
		return false, string.format("gesto com %d amostras", n)
	end
	for _, cf in ipairs(cframes) do
		if typeof(cf) ~= "CFrame" then
			return false, "amostra não é CFrame"
		end
	end

	local personagem = jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return false, "sem personagem"
	end
	local distancia = (raiz.Position - alvo.Position).Magnitude
	if distancia > ferramenta.alcance + alvo.Size.Magnitude then
		return false, string.format("fora de alcance (%.1f)", distancia)
	end

	local agora = os.clock()
	local anterior = ultimoGolpe[jogador]
	if anterior and (agora - anterior) < Config.Geometria.CADENCIA_MINIMA_S then
		return false, "cadência"
	end
	ultimoGolpe[jogador] = agora

	return true
end

-- ─────────────────────────────────────────────────────────────
-- Plano A
-- ─────────────────────────────────────────────────────────────
local function criarLamina(ferramenta)
	local lamina = Instance.new("Part")
	lamina.Size = ferramenta.laminaTamanho
	lamina.Anchored = true
	lamina.CanCollide = false
	lamina.CanQuery = false
	lamina.CanTouch = false
	lamina.Transparency = 1
	return lamina
end

local function maiorCorpo(partes)
	local melhor, melhorMassa = nil, -1
	for _, parte in ipairs(partes) do
		if parte and parte:IsA("BasePart") then
			local massa = parte:GetMass()
			if massa > melhorMassa then
				melhor, melhorMassa = parte, massa
			end
		end
	end
	return melhor
end

--[[
	Retorna um relatório com o que funcionou, o que falhou e quanto custou.
	No M0 esse relatório É o produto: ele responde se o Plano A vive fora do Studio.
]]
function CortadorServidor.cortar(jogador, alvo, cframes, ferramentaId)
	local ferramenta = Config.Ferramentas[ferramentaId]
		or Config.Ferramentas[Config.FerramentaPadraoM0]

	local relatorio = {
		plano = "A",
		ferramenta = ferramenta.nome,
		sweepOk = false,
		subtractOk = false,
		fragmentOk = false,
		descartado = false,
		erro = nil,
		msSweep = 0,
		msSubtract = 0,
		msFragment = 0,
		cacos = 0,
		volumeRemovido = 0,
	}

	if not GeometryService then
		relatorio.erro = "GeometryService indisponível"
		return relatorio
	end

	local valido, motivo = validar(jogador, alvo, cframes, ferramenta)
	if not valido then
		relatorio.erro = motivo
		return relatorio
	end

	local massaAntes = alvo:GetMass()
	local contato = cframes[#cframes].Position

	-- ── 1. sweep: o gesto vira sólido ────────────────────────
	local lamina = criarLamina(ferramenta)
	local t0 = os.clock()
	local aceito, ok, sweep = FilaGeometria.executar(function()
		return GeometryService:SweepPartAsync(lamina, cframes)
	end)
	relatorio.msSweep = (os.clock() - t0) * 1000

	if not aceito then
		relatorio.descartado = true
		relatorio.erro = "fila cheia"
		lamina:Destroy()
		return relatorio
	end
	if not ok or not sweep then
		relatorio.erro = "SweepPartAsync: " .. tostring(sweep)
		lamina:Destroy()
		return relatorio
	end
	relatorio.sweepOk = true
	lamina:Destroy()

	-- ── 2. subtract: o sólido é removido do tronco ───────────
	local opcoes = {
		CollisionFidelity = Enum.CollisionFidelity.Default,
		RenderFidelity = Enum.RenderFidelity.Automatic,
		SplitApart = false, -- entalhe não deve partir o tronco em dois corpos
	}

	t0 = os.clock()
	local _, okSub, partes = FilaGeometria.executar(function()
		return GeometryService:SubtractAsync(alvo, { sweep }, opcoes)
	end)
	relatorio.msSubtract = (os.clock() - t0) * 1000
	sweep:Destroy()

	if not okSub or typeof(partes) ~= "table" then
		relatorio.erro = "SubtractAsync: " .. tostring(partes)
		return relatorio
	end

	local corpo = maiorCorpo(partes)
	if not corpo then
		relatorio.erro = "subtract não devolveu corpo"
		return relatorio
	end
	relatorio.subtractOk = true

	local paiOriginal, cframeOriginal = alvo.Parent, alvo.CFrame
	local cortes = (alvo:GetAttribute("Cortes") or 0) + 1

	for _, parte in ipairs(partes) do
		if parte ~= corpo then
			parte:Destroy()
		end
	end

	corpo.Parent = paiOriginal
	corpo.CFrame = cframeOriginal
	corpo.Anchored = true
	corpo.Color = alvo.Color
	corpo.Material = alvo.Material
	corpo.Name = alvo.Name
	corpo:SetAttribute("Cortes", cortes)
	CollectionService:AddTag(corpo, TAG_TRONCO)
	alvo:Destroy()

	-- ── 3. fragment: lascar EXATAMENTE onde bateu ────────────
	local tronco = corpo
	if ferramenta.raioEstilhaco > 0 and cortes <= Config.Geometria.CORTES_RETIDOS_POR_TRONCO then
		t0 = os.clock()
		local _, okFrag, fragmentos = FilaGeometria.executar(function()
			local sites = GeometryService:GenerateFragmentSites(corpo, {
				Origin = contato,
				Radius = ferramenta.raioEstilhaco,
			})
			return GeometryService:FragmentAsync(corpo, sites)
		end)
		relatorio.msFragment = (os.clock() - t0) * 1000

		if okFrag and typeof(fragmentos) == "table" and #fragmentos > 0 then
			relatorio.fragmentOk = true
			local soltos = 0

			for _, item in ipairs(fragmentos) do
				local pedaco = item.Instance
				if pedaco then
					if item.Index == 1 then
						-- a porção NÃO estilhaçada: continua sendo o tronco
						pedaco.Parent = paiOriginal
						pedaco.CFrame = cframeOriginal
						pedaco.Anchored = true
						pedaco.Color = corpo.Color
						pedaco.Material = corpo.Material
						pedaco.Name = corpo.Name
						pedaco:SetAttribute("Cortes", cortes)
						CollectionService:AddTag(pedaco, TAG_TRONCO)
						tronco = pedaco
					elseif soltos < ferramenta.cacosPorGolpe then
						pedaco.Color = corpo.Color
						pedaco.Material = corpo.Material
						local dir = (pedaco.Position - contato)
						dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.yAxis
						if DetritoServidor.soltar(pedaco, jogador, dir * 6 + Vector3.yAxis * 4) then
							soltos += 1
						end
					else
						pedaco:Destroy()
					end
				end
			end

			relatorio.cacos = soltos
			if tronco ~= corpo then
				corpo:Destroy()
			end
		else
			relatorio.erro = "FragmentAsync: " .. tostring(fragmentos)
		end
	end

	relatorio.volumeRemovido = math.max(0, massaAntes - tronco:GetMass())
	relatorio.tronco = tronco
	return relatorio
end

function CortadorServidor.esquecerJogador(jogador)
	ultimoGolpe[jogador] = nil
end

return CortadorServidor
