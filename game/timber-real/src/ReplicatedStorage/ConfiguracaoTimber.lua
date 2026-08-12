--[[
	ConfiguracaoTimber — TODO número tunável do jogo mora aqui.
	Nada de constante mágica espalhada pelo código (convenção da casa).

	Escopo atual: spike M0 de viabilidade (ver README).
]]

local Config = {}

-- ─────────────────────────────────────────────────────────────
-- Orçamento de performance (SPEC § 10 — não negociável)
-- ─────────────────────────────────────────────────────────────
Config.Geometria = {
	-- doc Roblox proíbe séries rápidas de operações async
	OPERACOES_CONCORRENTES_MAX = 2,

	-- golpe que chega a menos disso do anterior (mesmo jogador) é descartado
	CADENCIA_MINIMA_S = 0.10,

	-- teto de 20k triângulos por parte resultante: consolidar antes disso
	CORTES_RETIDOS_POR_TRONCO = 12,

	-- amostras de CFrame que o cliente manda por golpe
	AMOSTRAS_GESTO_MIN = 2,
	AMOSTRAS_GESTO_MAX = 24,
}

Config.Detrito = {
	CACOS_POR_GOLPE_MAX = 8,
	CACOS_SIMULTANEOS_MAX = 120,
	VIDA_CACO_S = 25,
	-- acima disso num raio, funde a pilha num monte estático
	FUNDIR_PILHA_ACIMA_DE = 20,
	RAIO_PILHA = 6,
}

-- ─────────────────────────────────────────────────────────────
-- Ferramentas — cada uma muda a FORMA do corte, não só o dano
-- (SPEC § 2). No M0 só o machado está ligado.
-- ─────────────────────────────────────────────────────────────
Config.Ferramentas = {
	Facao = {
		nome = "Facão",
		laminaTamanho = Vector3.new(0.18, 1.6, 0.18),
		raioEstilhaco = 0.7,
		cacosPorGolpe = 4,
		alcance = 12,
		continua = false,
	},
	Machado = {
		nome = "Machado",
		laminaTamanho = Vector3.new(0.45, 2.4, 0.45),
		raioEstilhaco = 1.4,
		cacosPorGolpe = 8,
		alcance = 12,
		continua = false,
	},
	SerraManual = {
		nome = "Serra manual",
		laminaTamanho = Vector3.new(0.10, 2.8, 0.10),
		raioEstilhaco = 0.0, -- serragem é partícula, não geometria
		cacosPorGolpe = 0,
		alcance = 10,
		continua = true,
	},
	Motosserra = {
		nome = "Motosserra",
		laminaTamanho = Vector3.new(0.6, 3.2, 0.6),
		raioEstilhaco = 1.1,
		cacosPorGolpe = 6,
		alcance = 12,
		continua = true,
	},
}

Config.FerramentaPadraoM0 = "Machado"

-- ─────────────────────────────────────────────────────────────
-- Feedback R1 (juice) — client-side, imediato no ponto do golpe.
-- Diretriz de VFX (ver README): empilhar número + partícula + som + shake LEVE.
-- Anti-padrões proibidos: shake constante, som a cada frame, Rate sem cap.
-- ─────────────────────────────────────────────────────────────
Config.Feedback = {
	-- serragem (ParticleEmitter, só burst via :Emit — Rate fica 0)
	SERRAGEM_PARTICULAS = 16,
	SERRAGEM_VIDA_MIN = 0.4,
	SERRAGEM_VIDA_MAX = 0.7,
	SERRAGEM_VELOCIDADE = 9,

	-- número pop ("+madeira" → volume real quando o servidor responde)
	POP_SUBIDA_STUDS = 3,
	POP_DURACAO_S = 0.6,
	POP_MAX_SIMULTANEOS = 24, -- clicker gera spam: teto pra não vazar GUI

	-- camera shake LEVE (graus) — cooldown pra não empilhar e enjoar
	SHAKE_DURACAO_S = 0.12,
	SHAKE_AMPLITUDE_GRAUS = 0.35,
	SHAKE_COOLDOWN_S = 0.15,

	-- som de impacto — cooldown mínimo (serra/motosserra é contínua)
	SOM_COOLDOWN_S = 0.08,
	SOM_VOLUME = 0.5,
}

-- ─────────────────────────────────────────────────────────────
-- Cenário do spike
-- ─────────────────────────────────────────────────────────────
Config.M0 = {
	TRONCOS = 3,
	TRONCO_ALTURA = 12,
	TRONCO_RAIO = 1.6,
	ESPACAMENTO = 14,
	ORIGEM = Vector3.new(0, 0, -20),
	COR_TRONCO = Color3.fromRGB(104, 74, 48),
}

return Config
