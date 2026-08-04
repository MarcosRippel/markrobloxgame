--!strict
--[[
	ConfiguracaoAnomalias.lua  (ModuleScript em ReplicatedStorage)
	---------------------------------------------------------------
	Tunaveis globais do ciclo de anomaly.

	Mudar valores aqui afeta server e client (ambos require disso).
]]

export type TipoAnomalia = {
	id: number,
	nome: string,
	descricao: string,
	scoreAcerto: number,
	penalidadeErro: number,
}

local C = {}

-- ===== Timing =====
C.INTERVALO_TURNO_SEG = 60          -- a cada N seg, comeca novo turno
C.DURACAO_TURNO_SEG = 45            -- jogador tem N seg pra reportar
C.MAX_ANOMALIAS_SIMULTANEAS = 1     -- por turno (subir quando o jogo crescer)

-- ===== Tipos de anomaly =====
-- id = identificador estavel pra Remote payload; NAO REORDENAR sem versionar.
C.Tipos = {
	[1] = {
		id = 1,
		nome = "ExtraPart",
		descricao = "Apareceu um objeto que nao deveria estar la",
		scoreAcerto = 100,
		penalidadeErro = -30,
	},
	[2] = {
		id = 2,
		nome = "ItemSumiu",
		descricao = "Algo deveria estar la, mas sumiu",
		scoreAcerto = 100,
		penalidadeErro = -30,
	},
	[3] = {
		id = 3,
		nome = "Doppelganger",
		descricao = "Dois NPCs ou objetos identicos onde so deveria ter um",
		scoreAcerto = 150,
		penalidadeErro = -40,
	},
	[4] = {
		id = 4,
		nome = "LightFlicker",
		descricao = "Luzes piscando ou ambiente alterado",
		scoreAcerto = 80,
		penalidadeErro = -20,
	},
} :: {[number]: TipoAnomalia}

C.PENALIDADE_NAO_REPORTOU = -50

return C
