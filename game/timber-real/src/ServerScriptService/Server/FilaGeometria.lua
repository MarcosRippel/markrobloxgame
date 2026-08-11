--[[
	FilaGeometria — teto de operações GeometryService concorrentes.

	A doc da Roblox é explícita: "you should not perform a large series of calls
	such as UnionAsync() in quick succession". Sem essa fila, uma motosserra
	segurada vira 60 subtracts por segundo e derruba o servidor.

	Ver SPEC § 10.
]]

local Config = require(game:GetService("ReplicatedStorage").ConfiguracaoTimber)

local FilaGeometria = {}

local MAX = Config.Geometria.OPERACOES_CONCORRENTES_MAX
local FILA_MAX = 8 -- acima disso o golpe é descartado em vez de enfileirado

local emUso = 0
local esperando = {}

FilaGeometria.descartados = 0
FilaGeometria.executados = 0

-- Executa `fn` respeitando o teto. Retorna (aceito, ok, resultado).
-- aceito=false significa que a fila estava cheia e o golpe foi descartado.
function FilaGeometria.executar(fn)
	if emUso >= MAX then
		if #esperando >= FILA_MAX then
			FilaGeometria.descartados += 1
			return false, false, "fila cheia"
		end
		table.insert(esperando, coroutine.running())
		coroutine.yield()
	end

	emUso += 1
	local ok, resultado = pcall(fn)
	emUso -= 1
	FilaGeometria.executados += 1

	local proxima = table.remove(esperando, 1)
	if proxima then
		task.spawn(proxima)
	end

	return true, ok, resultado
end

function FilaGeometria.estado()
	return {
		emUso = emUso,
		esperando = #esperando,
		executados = FilaGeometria.executados,
		descartados = FilaGeometria.descartados,
	}
end

return FilaGeometria
