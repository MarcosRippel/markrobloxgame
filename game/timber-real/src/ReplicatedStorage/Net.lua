--[[
	Net — um lugar só para RemoteEvents (convenção da casa).
	Servidor cria; cliente espera.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NOMES = {
	-- C -> S : o cliente manda o GESTO; quem decide o corte é o servidor
	"GolpeAplicado",
	-- S -> C : resultado do corte (volume, qualidade)
	"CorteResolvido",
	-- S -> C : $ do jogador atualizou (golpe ou tora). { tipo, dinheiro, totalDinheiro, especie }
	-- Evento próprio (não engordo o CorteResolvido: ele é montado no BootServidor, fora
	-- do escopo da economia). O EconomiaServidor dispara; o HUDCliente exibe.
	"EconomiaAtualizada",
	-- S -> C : veredito do spike M0 (quais APIs funcionam aqui)
	"DiagnosticoAtualizado",
	-- S -> C : broadcast do INÍCIO da queda (arvore, posicao, direcao, qualidade, autor).
	-- O clímax pesado NÃO mora mais aqui: ver ImpactoSolo (SPEC § 2.6).
	"TroncoTombou",
	-- S -> C : broadcast do ASSENTAMENTO da tora no chão (SPEC § 2.6).
	-- { posicao: Vector3, autor: Player?, especie: string, qualidade: number }
	-- É aqui que o cliente toca o CRASH grave + poeira + shake: áudio segue a física.
	"ImpactoSolo",
	-- S -> C : lote atribuído ao jogador que entrou (SPEC § 2.5).
	-- { loteId: string, centro: Vector3, slots: number }
	"LoteAtribuido",
}

local Net = {}
local pasta

if RunService:IsServer() then
	pasta = ReplicatedStorage:FindFirstChild("Remotes")
	if not pasta then
		pasta = Instance.new("Folder")
		pasta.Name = "Remotes"
		pasta.Parent = ReplicatedStorage
	end
	for _, nome in ipairs(NOMES) do
		if not pasta:FindFirstChild(nome) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = nome
			ev.Parent = pasta
		end
	end
else
	pasta = ReplicatedStorage:WaitForChild("Remotes", 30)
end

for _, nome in ipairs(NOMES) do
	if RunService:IsServer() then
		Net[nome] = pasta:FindFirstChild(nome)
	else
		Net[nome] = pasta and pasta:WaitForChild(nome, 30)
	end
end

return Net
