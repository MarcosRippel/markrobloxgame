--!strict
--[[
	Net.lua  (ModuleScript em ReplicatedStorage)
	---------------------------------------------------------------
	Camada central de RemoteEvents do HospitalAnomalia.

	Servidor cria os Remotes (idempotente). Cliente apenas espera.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	"IniciarTurno",     -- Cliente -> Servidor: jogador comecou o expediente
	"EstadoTurno",      -- Servidor -> Cliente(s): {estado, numTurno, restanteSeg}
	"AnomaliaAtiva",    -- Servidor -> Cliente(s): {tipoId, descricao} (debug-only por ora)
	"ReportarAnomalia", -- Cliente -> Servidor: tipoId (palpite do jogador)
	"FeedbackReport",   -- Servidor -> Cliente: {acerto: boolean, pontos: number, msg: string}
}

local Net = {}

local function pastaRemotes(): Folder
	local pasta = ReplicatedStorage:FindFirstChild("Remotes")
	if not pasta then
		assert(RunService:IsServer(), "Pasta 'Remotes' ainda nao existe; o servidor precisa inicializar primeiro.")
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
			local remote = obterRemote(chave)
			rawset(Net, chave, remote)
			return remote
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
