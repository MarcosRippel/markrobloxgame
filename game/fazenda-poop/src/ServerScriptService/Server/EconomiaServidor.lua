--!strict
--[[
	EconomiaServidor.lua
	---------------------------------------------------------------
	Saldo por player (em memoria — sem persistencia ainda).
	Carrocao global do trator: capacidade compartilhada por enquanto.
	API:
	    SaldoDe(player) -> number
	    Adicionar(player, valor)
	    Debitar(player, valor) -> sucesso
	    DescarregarCarrocao(playerQueClicou)  -- tira tudo do carrocao -> XP nos bois -> log
	    EstadoCarrocao() -> {atual, max, tipos}
	    AdicionarAoCarrocao(tipoId, qtd) -> conseguiu?
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Net)
local Config = require(ReplicatedStorage.ConfiguracaoFazenda)
local Catalogo = require(ReplicatedStorage.Catalogo)

local M = {}
local saldos: {[number]: number} = {}
local boiServidor    -- preenchido por Iniciar

-- Carrocao global (V1). V2: por trator/player.
local carrocao = {
	atual = 0,
	max = Config.CARROCAO_CAPACIDADE_BASE,
	tipos = {} :: {[number]: number}, -- tipoCapimId -> qtd
}

local function broadcastCarrocao()
	Net.CarrocaoAtualizado:FireAllClients({
		capacidadeAtual = carrocao.atual,
		capacidadeMax = carrocao.max,
		tipos = carrocao.tipos,
	})
end

function M.SetCarrocaoMax(novoMax: number)
	carrocao.max = novoMax
	broadcastCarrocao()
end

function M.SaldoDe(player: Player): number
	return saldos[player.UserId] or 0
end

function M.Adicionar(player: Player, valor: number)
	if not player or not player.Parent then return end
	saldos[player.UserId] = (saldos[player.UserId] or 0) + valor
	Net.SaldoMudou:FireClient(player, {saldo = saldos[player.UserId]})
end

function M.Debitar(player: Player, valor: number): boolean
	local s = saldos[player.UserId] or 0
	if s < valor then return false end
	saldos[player.UserId] = s - valor
	Net.SaldoMudou:FireClient(player, {saldo = saldos[player.UserId]})
	return true
end

function M.AdicionarAoCarrocao(tipoId: number, qtd: number): number
	-- retorna quantas unidades realmente entraram (pode ser menos se encheu)
	if qtd <= 0 then return 0 end
	local livre = carrocao.max - carrocao.atual
	if livre <= 0 then return 0 end
	local entram = math.min(livre, qtd)
	carrocao.atual += entram
	carrocao.tipos[tipoId] = (carrocao.tipos[tipoId] or 0) + entram
	broadcastCarrocao()
	return entram
end

function M.DescarregarCarrocao(player: Player)
	-- valida proximidade do cocho
	local char = player.Character
	if not char or not char.PrimaryPart then return end
	if (char.PrimaryPart.Position - Config.COCHO_POSICAO).Magnitude > Config.COCHO_RAIO_DESCARGA then
		Net.FeedbackCompra:FireClient(player, {sucesso = false, msg = "Chega mais perto do cocho."})
		return
	end
	if carrocao.atual <= 0 then return end

	-- alimenta os bois e zera carrocao
	if boiServidor then
		boiServidor.DistribuirXP(carrocao.tipos)
	end
	carrocao.atual = 0
	carrocao.tipos = {}
	broadcastCarrocao()
end

-- ====== Upgrades ======
local CATEGORIAS = {Trator = Catalogo.Trator, Relho = Catalogo.Relho}

local function tierAtualDe(_player: Player, _cat: string): number
	-- V1: nao persiste; assume tier 1
	return 1
end

function M.ComprarUpgrade(player: Player, categoria: string, tier: number): (boolean, string)
	local cat = CATEGORIAS[categoria]
	if not cat then return false, "Categoria invalida" end
	local upgrade = cat[tier]
	if not upgrade then return false, "Tier invalido" end
	if not M.Debitar(player, upgrade.custo) then return false, "Saldo insuficiente" end

	-- aplica efeito (V1: so trator afeta carrocao_max global)
	if categoria == "Trator" then
		M.SetCarrocaoMax(upgrade.capacidadeCarrocao)
	end
	-- Relho: V2 (precisa ser per-player; por agora todos usam tier 1)
	return true, string.format("Upgrade %s tier %d aplicado", categoria, tier)
end

function M.EstadoCarrocao()
	return carrocao
end

function M.Iniciar(boiServidorRef)
	boiServidor = boiServidorRef

	Players.PlayerAdded:Connect(function(p)
		saldos[p.UserId] = Config.SALDO_INICIAL
		Net.SaldoMudou:FireClient(p, {saldo = Config.SALDO_INICIAL})
		broadcastCarrocao() -- envia estado inicial
	end)
	Players.PlayerRemoving:Connect(function(p)
		saldos[p.UserId] = nil
	end)
	for _, p in Players:GetPlayers() do
		saldos[p.UserId] = saldos[p.UserId] or Config.SALDO_INICIAL
	end

	Net.DescarregarCarrocao.OnServerEvent:Connect(function(player)
		M.DescarregarCarrocao(player)
	end)

	Net.ComprarUpgrade.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then return end
		local categoria = payload.categoria
		local tier = payload.tier
		if typeof(categoria) ~= "string" or typeof(tier) ~= "number" then return end
		local ok, msg = M.ComprarUpgrade(player, categoria, tier)
		Net.FeedbackCompra:FireClient(player, {
			sucesso = ok, msg = msg, novoSaldo = M.SaldoDe(player),
		})
	end)
end

return M
