--[[
	BootServidor — orquestração do servidor.

	Monta o mundo sozinho (nada precisa ser construído à mão no Studio), liga a rede
	e responde aos golpes.

	v2 (SPEC § 2.5): o campo global de árvores + gerenciador de proximidade SAIU.
	Quem semeia árvore agora é o LoteServidor — um LOTE físico por jogador, com
	árvores reais e cortáveis desde o spawn, criado no PlayerAdded e destruído no
	PlayerRemoving. Aqui ficou só o cenário (Terrain), a fiação de rede e o
	Diagnóstico.

	Ver README (M1).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.ConfiguracaoTimber)
local Net = require(ReplicatedStorage.Net)

local CortadorServidor = require(script.Parent.Server.CortadorServidor)
local DetritoServidor = require(script.Parent.Server.DetritoServidor)
local DiagnosticoServidor = require(script.Parent.Server.DiagnosticoServidor)
local LoteServidor = require(script.Parent.Server.LoteServidor)

-- ─────────────────────────────────────────────────────────────
-- Cenário
-- ─────────────────────────────────────────────────────────────
local raiz = Instance.new("Folder")
raiz.Name = "Floresta"
raiz.Parent = workspace

DetritoServidor.iniciar(raiz)

-- LOTES (SPEC § 2.5): a grade de lotes é montada agora; as árvores só nascem quando
-- um jogador entra e recebe o seu lote (atribuir). Nada de campo global de árvores.
local totalLotes = LoteServidor.iniciar(raiz)
print(
	string.format(
		"[timber] boot ok: grade de %d lotes pronta (%d árvores por lote)",
		totalLotes,
		Config.Lote.ARVORES_POR_LOTE
	)
)

-- ─────────────────────────────────────────────────────────────
-- Chão de GRAMA REAL (Terrain, não Part)
-- ─────────────────────────────────────────────────────────────
-- O usuário reclamou "não tem grama": um Part plano verde NUNCA vira lâmina 3D, e
-- um Baseplate/Chao por cima esconde o Terrain. Então: (1) remove qualquer piso
-- plano que cubra a grama, (2) preenche a clareira com Terrain Grass de verdade,
-- (3) liga Decoration (lâminas 3D animadas — default é FALSE, por isso não aparecia).
do
	-- (1) tira o piso plano que tapava a grama (Baseplate default do Studio + o Chao
	-- Part antigo). Se existirem, sem eles a grama de Terrain fica visível.
	for _, nome in ipairs({ "Baseplate", "Chao" }) do
		local piso = workspace:FindFirstChild(nome)
		if piso and piso:IsA("BasePart") then
			piso:Destroy()
		end
	end

	-- (2) Terrain Grass cobrindo a clareira inteira. Topo em y=0 (troncos plantados
	-- em ORIGEM.Y=0 assentam no topo, sem flutuar nem afundar). Bloco chapado de
	-- propósito: nada de relevo/buraco onde a árvore tomba.
	local terreno = workspace.Terrain
	local tamanho = Config.M0.CHAO_TAMANHO
	local espessura = Config.M0.CHAO_ESPESSURA
	terreno:FillBlock(
		CFrame.new(0, -espessura / 2, 0),
		Vector3.new(tamanho, espessura, tamanho),
		Enum.Material.Grass
	)

	-- (3) grama 3D + cor mais viva. `Terrain.Decoration`/`GrassLength` exigem a
	-- capability "Environment" (ver a doc de Terrain da Roblox): sob runtime
	-- restrito (ex.: ponte MCP/plugin, sandbox) o write EXPLODE e derruba o boot.
	-- Envolve tudo num pcall único + warn: grama 3D animada liga quando dá, e
	-- quando não dá vira aviso VISÍVEL no Output em vez de erro que mata o resto.
	local okGrama, errGrama = pcall(function()
		terreno.Decoration = true
		terreno.GrassLength = Config.M0.GRAMA_ALTURA -- lâmina 3D (0.1..1)
		terreno:SetMaterialColor(Enum.Material.Grass, Config.M0.COR_GRAMA)
	end)
	if not okGrama then
		warn(
			"[timber] grama 3D (Decoration/GrassLength) indisponível neste runtime: "
				.. tostring(errGrama)
		)
	end
end

-- ─────────────────────────────────────────────────────────────
-- Rede
-- ─────────────────────────────────────────────────────────────
Net.GolpeAplicado.OnServerEvent:Connect(function(jogador, alvo, cframes, ferramentaId)
	if typeof(ferramentaId) ~= "string" then
		ferramentaId = Config.FerramentaPadraoM0
	end

	local relatorio = CortadorServidor.cortar(jogador, alvo, cframes, ferramentaId)
	DiagnosticoServidor.registrar(relatorio)

	Net.CorteResolvido:FireClient(jogador, {
		ok = relatorio.subtractOk,
		volume = relatorio.volumeRemovido,
		cacos = relatorio.cacos,
		erro = relatorio.erro,
	})
end)

Players.PlayerRemoving:Connect(function(jogador)
	CortadorServidor.esquecerJogador(jogador)
	LoteServidor.liberar(jogador) -- destrói o Lote<userId> e devolve o slot pra grade
end)

-- LOTE por jogador. `atribuir` é idempotente, então o padrão PlayerAdded seguro
-- (conectar + varrer quem JÁ entrou antes deste script rodar) não duplica lote.
Players.PlayerAdded:Connect(function(jogador)
	LoteServidor.atribuir(jogador)
end)
for _, jogador in ipairs(Players:GetPlayers()) do
	task.spawn(LoteServidor.atribuir, jogador)
end

Players.PlayerAdded:Connect(function()
	task.wait(2)
	DiagnosticoServidor.transmitir()
end)

-- ─────────────────────────────────────────────────────────────
-- Relatório periódico no output do servidor
-- ─────────────────────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(15)
		DiagnosticoServidor.imprimir()
	end
end)

DiagnosticoServidor.imprimir()
print(
	string.format(
		"[timber-real] mundo no ar — %d lotes de %d árvores (espaçamento %d) no mapa %dx%d. "
			.. "Cada jogador nasce no PRÓPRIO lote, com as árvores já cortáveis. Equipe o Machado.",
		totalLotes,
		Config.Lote.ARVORES_POR_LOTE,
		Config.Lote.ESPACAMENTO,
		Config.M0.CHAO_TAMANHO,
		Config.M0.CHAO_TAMANHO
	)
)
