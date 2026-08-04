--!strict
--[[
	Net.lua  (ModuleScript em ReplicatedStorage)
	---------------------------------------------------------------
	Camada central de RemoteEvents do FazendaPoop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	-- Capim
	"CapimCortado",          -- Server -> All: {tufoId, tipoId, posicao}
	"CapimRegerou",          -- Server -> All: {tufoId, tipoId}
	-- Carrocao
	"CarrocaoAtualizado",    -- Server -> Cliente dono: {capacidadeAtual, capacidadeMax, tiposCapim={[tipoId]=qtd}}
	"DescarregarCarrocao",   -- Cliente -> Server: (sem args; valida proximidade do cocho)
	-- Boi
	"BoiSpawnado",           -- Server -> All: {boiId, racaId, posicao}
	"BoiXPMudou",            -- Server -> All: {boiId, xp, xpMax, nivel}
	"BoiPronto",             -- Server -> All: {boiId}  (atingiu maturidade)
	"BoiMovido",             -- Server -> All: {boiId, novaPosicao}
	"BoiAbatido",            -- Server -> All: {boiId}
	-- Relho
	"RelhoTocar",            -- Cliente -> Server: {boiId}  (tentativa de tocar)
	-- Abatedor
	"AbatedorProcessou",     -- Server -> All: {boiId, bifes={...}}  (efeitos visuais)
	-- Economia
	"SaldoMudou",            -- Server -> Cliente: {saldo}
	"ComprarUpgrade",        -- Cliente -> Server: {categoria, tier}
	"FeedbackCompra",        -- Server -> Cliente: {sucesso, msg, novoSaldo}
}

local Net = {}

local function pastaRemotes(): Folder
	local pasta = ReplicatedStorage:FindFirstChild("Remotes")
	if not pasta then
		assert(RunService:IsServer(), "Pasta 'Remotes' ainda nao existe; servidor precisa inicializar primeiro.")
		pasta = Instance.new("Folder")
		pasta.Name = "Remotes"
		pasta.Parent = ReplicatedStorage
	end
	return pasta
end

local function obterRemote(nome: string): RemoteEvent
	local pasta = pastaRemotes()
	if RunService:IsServer() then
		local r = pasta:FindFirstChild(nome)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = nome
			r.Parent = pasta
		end
		return r :: RemoteEvent
	else
		return pasta:WaitForChild(nome, 30) :: RemoteEvent
	end
end

setmetatable(Net, {
	__index = function(_, chave: string): RemoteEvent?
		if table.find(REMOTE_NAMES, chave) then
			local r = obterRemote(chave)
			rawset(Net, chave, r)
			return r
		end
		return nil
	end,
})

function Net.InicializarServidor()
	assert(RunService:IsServer(), "InicializarServidor so pode rodar no servidor.")
	for _, nome in REMOTE_NAMES do
		obterRemote(nome)
	end
end

return Net
