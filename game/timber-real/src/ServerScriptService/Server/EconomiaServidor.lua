--[[
	EconomiaServidor — o corte vira DINHEIRO (SPEC § 4).

	Server-authoritative: o servidor é quem calcula o $ (o cliente nunca manda valor,
	só recebe pra exibir). Fórmula única:

	    $ = volume removido × valorMultiplicador da espécie × multQualidade × VALOR_BASE

	  • volume       — massa removida no golpe (ou a massa da tora inteira ao tombar),
	                   medida pelo CortadorServidor (GeometryService).
	  • valorEspecie — Catalogo.Especies.valorDe(nome): Pinho ×1 … Árvore de Ouro ×400.
	  • qualidade    — Config.Economia.QUALIDADE: golpe normal = LASCA (×0,4);
	                   derrubar a árvore inteira = TORA LIMPA (×2,0), o grande prêmio.

	Saldo por Player vive em MEMÓRIA (M1). Persistência (DataStore) é M2 — não aqui.
	Cada crédito avisa SÓ o autor via Net.EconomiaAtualizada (o HUD dele exibe o $).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.ConfiguracaoTimber)
local Especies = require(ReplicatedStorage.Catalogo.Especies)
local Net = require(ReplicatedStorage.Net)

local EconomiaServidor = {}

-- saldo em memória por Player. [Player] = número. M1 não persiste (isso é M2).
local saldo = {}

-- multiplicador de qualidade do resíduo (Config.Economia.QUALIDADE). Desconhecido
-- cai em LASCA (o caso do golpe normal), nunca em nil.
function EconomiaServidor.multQualidade(qualidade)
	local tabela = Config.Economia.QUALIDADE
	local m = qualidade and tabela[qualidade]
	return if typeof(m) == "number" then m else tabela.lasca
end

-- FÓRMULA (SPEC § 4). Pura: recebe (volume, valorEspecie, multQualidade) → $.
-- Volume não-positivo (nada removido) rende 0 — sem $ negativo, sem NaN.
function EconomiaServidor.calcular(volume, valorEspecie, multQualidade)
	if typeof(volume) ~= "number" or volume <= 0 then
		return 0
	end
	valorEspecie = if typeof(valorEspecie) == "number" then valorEspecie else 1
	multQualidade = if typeof(multQualidade) == "number" then multQualidade else 1
	return volume * valorEspecie * multQualidade * Config.Economia.VALOR_BASE
end

-- saldo atual do jogador (0 se nunca ganhou nada).
function EconomiaServidor.total(jogador)
	return saldo[jogador] or 0
end

-- avisa o AUTOR (FireClient, só ele) que o $ mudou. typeof no jogador pra nunca
-- estourar num Player já saído.
function EconomiaServidor.avisar(jogador, payload)
	if Net.EconomiaAtualizada and typeof(jogador) == "Instance" then
		Net.EconomiaAtualizada:FireClient(jogador, payload)
	end
end

-- soma o ganho ao saldo e devolve (ganho, novoTotal). Nunca credita negativo.
local function creditar(jogador, ganho)
	ganho = math.max(0, ganho)
	local total = (saldo[jogador] or 0) + ganho
	saldo[jogador] = total
	return ganho, total
end

-- credita o $ de um GOLPE: volume removido do resíduo `qualidade` (normal = lasca).
-- Devolve { dinheiro = ganho do golpe, totalDinheiro = saldo }.
function EconomiaServidor.creditarGolpe(jogador, volume, especieNome, qualidade)
	local ganho = EconomiaServidor.calcular(
		volume,
		Especies.valorDe(especieNome),
		EconomiaServidor.multQualidade(qualidade)
	)
	local dinheiro, total = creditar(jogador, ganho)
	EconomiaServidor.avisar(jogador, {
		tipo = "golpe",
		dinheiro = dinheiro,
		totalDinheiro = total,
		especie = especieNome,
		qualidade = qualidade,
	})
	return { dinheiro = dinheiro, totalDinheiro = total }
end

-- credita o BÔNUS de TORA LIMPA (×2,0) ao autor quando a árvore tomba INTEIRA.
-- volume = massa da tora remanescente no momento do tombamento.
function EconomiaServidor.creditarTora(jogador, volume, especieNome)
	local ganho = EconomiaServidor.calcular(
		volume,
		Especies.valorDe(especieNome),
		Config.Economia.QUALIDADE.toraLimpa
	)
	local dinheiro, total = creditar(jogador, ganho)
	EconomiaServidor.avisar(jogador, {
		tipo = "tora",
		dinheiro = dinheiro,
		totalDinheiro = total,
		especie = especieNome,
		qualidade = "toraLimpa",
	})
	return { dinheiro = dinheiro, totalDinheiro = total }
end

-- limpa o saldo quando o jogador sai (M1 é em memória; sem isso vazaria a tabela).
-- Chamado pelo CortadorServidor.esquecerJogador (o BootServidor já o aciona no
-- PlayerRemoving), pra não precisar tocar no BootServidor (fora do escopo).
function EconomiaServidor.esquecerJogador(jogador)
	saldo[jogador] = nil
end

return EconomiaServidor
