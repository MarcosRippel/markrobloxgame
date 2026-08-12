--[[
	GolpeLocal — um sinal client-side entre o GestoCliente (que raycasta e sabe o
	ponto de impacto) e o FeedbackCliente (que faz o "juice").

	Existe pra que o VFX dispare IMEDIATO, no ponto que o cliente já tem, sem
	esperar o servidor (SPEC § risco #4 — mata o golpe borrachudo). Os dois
	LocalScripts vivem na mesma VM do cliente, então compartilham este módulo.
]]

export type Golpe = {
	ponto: Vector3,
	normal: Vector3,
	ferramenta: string,
}

local GolpeLocal = {}

local evento = Instance.new("BindableEvent")

--[[ Chamado pelo GestoCliente assim que um golpe válido é despachado. ]]
function GolpeLocal.emitir(golpe: Golpe)
	evento:Fire(golpe)
end

--[[ Chamado pelo FeedbackCliente pra reagir a cada golpe local. ]]
function GolpeLocal.conectar(callback: (Golpe) -> ()): RBXScriptConnection
	return evento.Event:Connect(callback)
end

return GolpeLocal
