--[[
	LoteServidor — o LOTE por jogador (SPEC § 2.5), a mudança central do v2.

	Substitui o gerenciador global de proximidade que morava no ArvoreServidor
	(§ 2.5.6: semearMundo / iniciarGerenciador / promover / rebaixar / construirProxy).
	Em vez de 168 sites que viravam proxy ↔ árvore real conforme o jogador andava,
	cada jogador ganha um LOTE FÍSICO próprio, com um conjunto FIXO de árvores reais,
	watertight e cortáveis desde o spawn. Sem promoção, sem rebaixamento — a árvore
	que está no slot é a árvore que o jogador vai cortar, do spawn até tombar. É isso
	que mata os bugs 1-4 do § 0.5 (troca de espécie, gigante sumindo, árvore mal
	formada, adulta reciclada antes de virar tora).

	Estrutura no workspace:

		Floresta/
		  Lotes/
		    Lote<userId>/        ← criado no PlayerAdded, DESTRUÍDO no PlayerRemoving
		      Slot1/  Arvore1    ← um Folder por slot; a árvore vive dentro dele
		      Slot2/  Arvore2
		      ...

	O REBROTE por slot é AUTÔNOMO: quando a árvore tomba, o próprio
	`ArvoreServidor.iniciarCicloToco` põe o toco → brotos → nova árvore adulta no
	MESMO Slot folder. Este módulo não orquestra rebrote nenhum; só semeia a primeira
	árvore de cada slot e limpa tudo quando o jogador sai.

	Isolamento visual: os centros de lote ficam a `Config.Lote.ESPACAMENTO` studs uns
	dos outros, acima do StreamingTargetRadius do place (default.project.json) — o
	vizinho nem chega a ser enviado pro cliente. "Cada um vê as suas árvores" sai de
	graça do streaming, sem nenhuma lógica de visibilidade por jogador (§ 2.5.3).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.ConfiguracaoTimber)
local Net = require(ReplicatedStorage.Net)
local Especies = require(ReplicatedStorage.Catalogo.Especies)
local ArvoreServidor = require(script.Parent.ArvoreServidor)

local LoteServidor = {}

type SlotLote = {
	indice: number,
	centro: Vector3,
	dono: Player?,
}

type LoteAtivo = {
	slot: SlotLote,
	folder: Folder,
	conexaoPersonagem: RBXScriptConnection?,
}

local raizLotes: Folder? = nil
local slots: { SlotLote } = {}
local ativos: { [Player]: LoteAtivo } = {}

-- ─────────────────────────────────────────────────────────────
-- Grade de lotes: LINHAS × COLUNAS centrada em Config.Lote.ORIGEM. Posições FIXAS e
-- determinísticas (nada de sorteio) — o lote 3 é sempre o mesmo lugar, o que deixa a
-- persistência do M2 trivial e o teste de 2 jogadores reproduzível.
-- ─────────────────────────────────────────────────────────────
local function centrosDaGrade(): { Vector3 }
	local lote = Config.Lote
	local origem = lote.ORIGEM
	local largura = (lote.COLUNAS - 1) * lote.ESPACAMENTO
	local profundidade = (lote.LINHAS - 1) * lote.ESPACAMENTO

	local centros = {}
	for linha = 0, lote.LINHAS - 1 do
		for coluna = 0, lote.COLUNAS - 1 do
			table.insert(
				centros,
				Vector3.new(
					origem.X - largura / 2 + coluna * lote.ESPACAMENTO,
					0, -- chão em y=0 (Terrain do BootServidor); a árvore planta a base sozinha
					origem.Z - profundidade / 2 + linha * lote.ESPACAMENTO
				)
			)
		end
	end
	return centros
end

-- ─────────────────────────────────────────────────────────────
-- Posições das árvores DENTRO do lote: anéis concêntricos em volta do centro,
-- começando FORA do RAIO_CLAREIRA (o jogador nasce e respawna limpo) e terminando no
-- RAIO_CAMPO_LOTE. Cada anel cabe `2πr / ESPACAMENTO_ARVORES` árvores; anéis
-- consecutivos entram girados pra não formar corredor radial (cara de grade).
-- ─────────────────────────────────────────────────────────────
local function posicoesDasArvores(centro: Vector3, quantidade: number): { Vector3 }
	local lote = Config.Lote
	local passo = math.max(4, lote.ESPACAMENTO_ARVORES)
	local posicoes = {}

	local raio = lote.RAIO_CLAREIRA + passo
	local anel = 0
	while #posicoes < quantidade and raio <= lote.RAIO_CAMPO_LOTE do
		anel += 1
		local cabem = math.max(1, math.floor((2 * math.pi * raio) / passo))
		local neste = math.min(cabem, quantidade - #posicoes)
		local giro = anel * 0.7 -- desencontra os anéis
		for i = 0, neste - 1 do
			local ang = giro + (i / neste) * math.pi * 2
			table.insert(
				posicoes,
				Vector3.new(centro.X + math.cos(ang) * raio, 0, centro.Z + math.sin(ang) * raio)
			)
		end
		raio += passo
	end

	if #posicoes < quantidade then
		warn(
			string.format(
				"[timber] lote: só couberam %d de %d árvores (RAIO_CAMPO_LOTE %d, ESPACAMENTO_ARVORES %d)",
				#posicoes,
				quantidade,
				lote.RAIO_CAMPO_LOTE,
				passo
			)
		)
	end
	return posicoes
end

-- ─────────────────────────────────────────────────────────────
-- iniciar(floresta) — cria Floresta.Lotes e monta a grade de slots de lote livres.
-- Idempotente: chamar de novo não duplica a pasta.
-- ─────────────────────────────────────────────────────────────
function LoteServidor.iniciar(floresta: Instance?): number
	local raiz: Instance? = floresta
	if typeof(raiz) ~= "Instance" then
		raiz = workspace:FindFirstChild("Floresta")
		if not raiz then
			local nova = Instance.new("Folder")
			nova.Name = "Floresta"
			nova.Parent = workspace
			raiz = nova
		end
	end

	local pasta = (raiz :: Instance):FindFirstChild("Lotes")
	if not pasta then
		local nova = Instance.new("Folder")
		nova.Name = "Lotes"
		nova.Parent = raiz
		pasta = nova
	end
	raizLotes = pasta :: Folder

	slots = {}
	for indice, centro in ipairs(centrosDaGrade()) do
		table.insert(slots, { indice = indice, centro = centro, dono = nil })
	end

	return #slots
end

-- primeiro slot de lote livre (nil se acabaram — não deveria, com maxPlayers 8)
local function slotLivre(): SlotLote?
	for _, slot in ipairs(slots) do
		if not slot.dono then
			return slot
		end
	end
	return nil
end

-- leva o personagem pro centro do lote. Roda em thread própria porque o Character
-- pode ainda estar carregando (WaitForChild). Vale pro 1º spawn e pra cada respawn.
local function levarAoLote(personagem: Model?, centro: Vector3)
	if typeof(personagem) ~= "Instance" then
		return
	end
	task.spawn(function()
		local raizPersonagem = personagem:FindFirstChild("HumanoidRootPart")
			or personagem:WaitForChild("HumanoidRootPart", 10)
		if not raizPersonagem or not personagem.Parent then
			return
		end
		pcall(function()
			personagem:PivotTo(CFrame.new(centro + Vector3.new(0, Config.Lote.ALTURA_SPAWN, 0)))
		end)
	end)
end

-- ─────────────────────────────────────────────────────────────
-- atribuir(player) — pega o 1º lote livre, semeia as árvores FIXAS, leva o jogador
-- pro centro e avisa o cliente (Net.LoteAtribuido). Cada árvore nasce em pcall: um
-- slot falhar (copa throttlando, p.ex.) não pode matar o lote nem o PlayerAdded.
-- ─────────────────────────────────────────────────────────────
function LoteServidor.atribuir(player: Player): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if ativos[player] then
		return true -- já tem lote (PlayerAdded + varredura de GetPlayers no boot)
	end
	if not raizLotes then
		warn("[timber] LoteServidor.atribuir antes de iniciar() — ignorado")
		return false
	end

	local slot = slotLivre()
	if not slot then
		warn(
			string.format(
				"[timber] sem lote livre pra %s — a grade tem %d lotes (maxPlayers do place deveria bater com isso)",
				player.Name,
				#slots
			)
		)
		return false
	end
	slot.dono = player

	local folder = Instance.new("Folder")
	folder.Name = "Lote" .. tostring(player.UserId)
	folder:SetAttribute("Dono", player.UserId)
	folder:SetAttribute("SlotLote", slot.indice)
	folder:SetAttribute("Centro", slot.centro)
	folder.Parent = raizLotes

	-- árvores FIXAS do lote: espécie sorteada UMA vez por slot (§ 2.5.7 bug 1) e já
	-- ADULTAS no spawn — cortáveis na hora, sem promoção.
	local posicoes = posicoesDasArvores(slot.centro, Config.Lote.ARVORES_POR_LOTE)
	local nasceram = 0
	for i, pos in ipairs(posicoes) do
		local ok, err = pcall(function()
			local slotFolder = Instance.new("Folder")
			slotFolder.Name = "Slot" .. i
			slotFolder:SetAttribute("EmCiclo", false)
			slotFolder.Parent = folder

			ArvoreServidor.nascer(i, slotFolder, {
				posicao = pos,
				especie = Especies.sortear(),
			})
		end)
		if ok then
			nasceram += 1
		else
			warn(
				string.format("[timber] lote %s slot %d falhou: %s", folder.Name, i, tostring(err))
			)
		end
	end

	-- spawn e TODO respawn caem no centro do lote (senão o jogador volta pro 0,0,0 do
	-- mapa a cada morte, a ~900 studs do lote dele).
	levarAoLote(player.Character, slot.centro)
	local conexao = player.CharacterAdded:Connect(function(personagem)
		levarAoLote(personagem, slot.centro)
	end)

	ativos[player] = { slot = slot, folder = folder, conexaoPersonagem = conexao }

	Net.LoteAtribuido:FireClient(player, {
		loteId = folder.Name,
		centro = slot.centro,
		slots = nasceram,
	})

	print(
		string.format(
			"[timber] lote %d de %s: %d/%d árvores em (%d, %d)",
			slot.indice,
			player.Name,
			nasceram,
			#posicoes,
			slot.centro.X,
			slot.centro.Z
		)
	)
	return true
end

-- ─────────────────────────────────────────────────────────────
-- liberar(player) — destrói o lote inteiro (árvores, tocos, brotos e toras em voo
-- morrem junto com o Folder) e devolve o slot pra lista de livres.
-- ─────────────────────────────────────────────────────────────
function LoteServidor.liberar(player: Player)
	local ativo = ativos[player]
	if not ativo then
		return
	end
	ativos[player] = nil

	if ativo.conexaoPersonagem then
		ativo.conexaoPersonagem:Disconnect()
	end
	if ativo.folder and ativo.folder.Parent then
		ativo.folder:Destroy()
	end
	ativo.slot.dono = nil
end

-- centro do lote do jogador (nil se não tem lote) — gancho pro M2 (persistência,
-- máquinas por lote) e pra qualquer validação de raio server-side.
function LoteServidor.centroDe(player: Player): Vector3?
	local ativo = ativos[player]
	return ativo and ativo.slot.centro or nil
end

return LoteServidor
