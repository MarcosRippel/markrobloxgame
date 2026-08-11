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
