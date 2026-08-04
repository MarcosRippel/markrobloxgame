--!strict
--[[
	AnomaliaServidor.lua  (ModuleScript em ServerScriptService.Server)
	---------------------------------------------------------------
	Loop principal do jogo. Estados:

	  AGUARDANDO   <-- entre turnos, esperando INTERVALO_TURNO_SEG
	  ATIVO        <-- anomaly spawnada, jogador tem DURACAO_TURNO_SEG p/ reportar
	  ENCERRANDO   <-- avaliando reports e zerando estado

	Ate o mapa e os assets entrarem, "spawnar anomaly" so registra o tipo escolhido
	e replica via Net.AnomaliaAtiva. Quando os templates em ReplicatedStorage.Anomalias
	estiverem prontos, este modulo clona o template e parenta em Workspace.Hospital.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Net)
local Config = require(ReplicatedStorage.ConfiguracaoAnomalias)

local M = {}

local estadoAtual: "AGUARDANDO" | "ATIVO" | "ENCERRANDO" = "AGUARDANDO"
local numTurno = 0
local anomaliaAtivaId: number? = nil
local jaReportou: {[Player]: boolean} = {}
local scoreJogador: {[Player]: number} = {}
local rng = Random.new()

local function broadcastEstado(restanteSeg: number?)
	Net.EstadoTurno:FireAllClients({
		estado = estadoAtual,
		numTurno = numTurno,
		restanteSeg = restanteSeg or 0,
	})
end

local function sortearTipo(): number
	local ids = {}
	for id in Config.Tipos do
		table.insert(ids, id)
	end
	return ids[rng:NextInteger(1, #ids)]
end

local function spawnAnomalia()
	numTurno += 1
	estadoAtual = "ATIVO"
	anomaliaAtivaId = sortearTipo()
	table.clear(jaReportou)

	local tipo = Config.Tipos[anomaliaAtivaId :: number]
	print(string.format("[ANOMALIA] turno=%d tipo=%s (%d) — %s",
		numTurno, tipo.nome, tipo.id, tipo.descricao))

	-- TODO: clonar template de ReplicatedStorage.Anomalias[tipo.nome] e parentar em Workspace.Hospital
	-- TODO: instalar o efeito visual real (LightFlicker nas luzes, ExtraPart aleatorio, etc.)

	Net.AnomaliaAtiva:FireAllClients({tipoId = anomaliaAtivaId, descricao = tipo.descricao})
end

local function avaliarReport(player: Player, tipoIdPalpite: number)
	if estadoAtual ~= "ATIVO" then return end
	if jaReportou[player] then return end
	if anomaliaAtivaId == nil then return end

	jaReportou[player] = true

	local tipoAtivo = Config.Tipos[anomaliaAtivaId]
	if not tipoAtivo then return end

	local acerto = (tipoIdPalpite == anomaliaAtivaId)
	local delta = acerto and tipoAtivo.scoreAcerto or tipoAtivo.penalidadeErro
	scoreJogador[player] = (scoreJogador[player] or 0) + delta

	Net.FeedbackReport:FireClient(player, {
		acerto = acerto,
		pontos = delta,
		scoreTotal = scoreJogador[player],
		msg = acerto and "Reportado." or "Reporte errado.",
	})
end

local function encerrarTurno()
	estadoAtual = "ENCERRANDO"
	-- Penaliza quem nao reportou
	if anomaliaAtivaId ~= nil then
		for _, player in Players:GetPlayers() do
			if not jaReportou[player] then
				scoreJogador[player] = (scoreJogador[player] or 0) + Config.PENALIDADE_NAO_REPORTOU
				Net.FeedbackReport:FireClient(player, {
					acerto = false,
					pontos = Config.PENALIDADE_NAO_REPORTOU,
					scoreTotal = scoreJogador[player],
					msg = "Voce nao reportou a anomaly do turno.",
				})
			end
		end
	end
	anomaliaAtivaId = nil
	estadoAtual = "AGUARDANDO"
end

local function loop()
	while true do
		-- AGUARDANDO
		broadcastEstado(Config.INTERVALO_TURNO_SEG)
		task.wait(Config.INTERVALO_TURNO_SEG)

		-- ATIVO
		spawnAnomalia()
		for restante = Config.DURACAO_TURNO_SEG, 1, -1 do
			broadcastEstado(restante)
			task.wait(1)
		end

		-- ENCERRANDO
		encerrarTurno()
		broadcastEstado(0)
	end
end

function M.Iniciar()
	-- Net.ReportarAnomalia: cliente reporta um tipoId
	Net.ReportarAnomalia.OnServerEvent:Connect(function(player, tipoIdPalpite)
		if typeof(tipoIdPalpite) ~= "number" then return end
		avaliarReport(player, tipoIdPalpite)
	end)

	-- Init score quando entra; cleanup quando sai
	Players.PlayerAdded:Connect(function(p)
		scoreJogador[p] = 0
	end)
	Players.PlayerRemoving:Connect(function(p)
		scoreJogador[p] = nil
		jaReportou[p] = nil
	end)
	for _, p in Players:GetPlayers() do
		scoreJogador[p] = 0
	end

	task.spawn(loop)
	print("[AnomaliaServidor] loop iniciado")
end

return M
