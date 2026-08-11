--[[
	DiagnosticoServidor — o PRODUTO do spike M0.

	Junta o resultado de cada corte e responde a única pergunta que importa
	agora (SPEC § 3.2 / § 11):

	  As APIs de sweep/subtract/fragment funcionam numa experience PUBLICADA,
	  para um jogador comum, ou o beta "Solid Modeling On Meshes" as mantém
	  presas ao Studio?

	Publique o place, entre com uma conta comum, dê alguns golpes e leia o
	veredito no canto da tela.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Net)
local FilaGeometria = require(script.Parent.FilaGeometria)
local DetritoServidor = require(script.Parent.DetritoServidor)

local DiagnosticoServidor = {}

local estado = {
	ambiente = if RunService:IsStudio() then "STUDIO" else "PUBLICADO",
	golpes = 0,
	sweepOk = 0,
	subtractOk = 0,
	fragmentOk = 0,
	descartados = 0,
	msSweep = 0,
	msSubtract = 0,
	msFragment = 0,
	ultimoErro = "—",
	veredito = "aguardando primeiro golpe",
}

local function media(total, n)
	return if n > 0 then total / n else 0
end

local function calcularVeredito()
	if estado.golpes == 0 then
		return "aguardando primeiro golpe"
	end
	if estado.sweepOk == 0 then
		return "PLANO B — sweep nunca funcionou aqui"
	end
	if estado.subtractOk == 0 then
		return "PLANO B — sweep vive, subtract não"
	end
	if estado.fragmentOk == 0 then
		return "PARCIAL — corta, mas nao estilhaça (fragment falhou)"
	end
	return "PLANO A VIVE — corte, subtração e estilhaço OK"
end

function DiagnosticoServidor.registrar(relatorio)
	estado.golpes += 1
	if relatorio.descartado then
		estado.descartados += 1
	end
	if relatorio.sweepOk then
		estado.sweepOk += 1
		estado.msSweep += relatorio.msSweep
	end
	if relatorio.subtractOk then
		estado.subtractOk += 1
		estado.msSubtract += relatorio.msSubtract
	end
	if relatorio.fragmentOk then
		estado.fragmentOk += 1
		estado.msFragment += relatorio.msFragment
	end
	if relatorio.erro then
		estado.ultimoErro = tostring(relatorio.erro)
	end

	estado.veredito = calcularVeredito()
	DiagnosticoServidor.transmitir()
end

function DiagnosticoServidor.instantaneo()
	local fila = FilaGeometria.estado()
	return {
		ambiente = estado.ambiente,
		veredito = estado.veredito,
		golpes = estado.golpes,
		sweepOk = estado.sweepOk,
		subtractOk = estado.subtractOk,
		fragmentOk = estado.fragmentOk,
		descartados = estado.descartados + fila.descartados,
		msSweep = media(estado.msSweep, estado.sweepOk),
		msSubtract = media(estado.msSubtract, estado.subtractOk),
		msFragment = media(estado.msFragment, estado.fragmentOk),
		cacosVivos = DetritoServidor.contagem(),
		ultimoErro = estado.ultimoErro,
	}
end

function DiagnosticoServidor.transmitir()
	if Net.DiagnosticoAtualizado then
		Net.DiagnosticoAtualizado:FireAllClients(DiagnosticoServidor.instantaneo())
	end
end

function DiagnosticoServidor.imprimir()
	local s = DiagnosticoServidor.instantaneo()
	print(
		string.format(
			"[M0 %s] %s | golpes=%d sweep=%d subtract=%d fragment=%d | ms: %.0f/%.0f/%.0f | cacos=%d | erro=%s",
			s.ambiente,
			s.veredito,
			s.golpes,
			s.sweepOk,
			s.subtractOk,
			s.fragmentOk,
			s.msSweep,
			s.msSubtract,
			s.msFragment,
			s.cacosVivos,
			s.ultimoErro
		)
	)
end

return DiagnosticoServidor
