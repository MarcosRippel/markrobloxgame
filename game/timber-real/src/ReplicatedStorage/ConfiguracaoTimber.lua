--[[
	ConfiguracaoTimber — TODO número tunável do jogo mora aqui.
	Nada de constante mágica espalhada pelo código (convenção da casa).

	Escopo atual: M1 — corte real, economia e lote por jogador (ver README).
]]

local Config = {}

-- ─────────────────────────────────────────────────────────────
-- Tags de CollectionService — um lugar só (servidor e cliente leem daqui,
-- sem string mágica espalhada). O corte por GeometryService depende de TRONCO.
-- ─────────────────────────────────────────────────────────────
Config.Tags = {
	TRONCO = "TroncoCortavel",
}

-- ─────────────────────────────────────────────────────────────
-- Orçamento de performance (SPEC § 10 — não negociável)
-- ─────────────────────────────────────────────────────────────
Config.Geometria = {
	-- doc Roblox proíbe séries rápidas de operações async
	OPERACOES_CONCORRENTES_MAX = 2,

	-- golpe que chega a menos disso do anterior (mesmo jogador) é descartado
	CADENCIA_MINIMA_S = 0.10,

	-- teto de 20k triângulos por parte resultante: consolidar antes disso
	CORTES_RETIDOS_POR_TRONCO = 12,

	-- amostras de CFrame que o cliente manda por golpe
	AMOSTRAS_GESTO_MIN = 2,
	AMOSTRAS_GESTO_MAX = 24,
}

Config.Detrito = {
	CACOS_POR_GOLPE_MAX = 8,
	CACOS_SIMULTANEOS_MAX = 120,
	VIDA_CACO_S = 25,
	-- acima disso num raio, funde a pilha num monte estático
	FUNDIR_PILHA_ACIMA_DE = 20,
	RAIO_PILHA = 6,
}

-- ─────────────────────────────────────────────────────────────
-- Ferramentas — cada uma muda a FORMA do corte, não só o dano
-- (SPEC § 2). No M0 só o machado está ligado.
-- ─────────────────────────────────────────────────────────────
Config.Ferramentas = {
	Facao = {
		nome = "Facão",
		laminaTamanho = Vector3.new(0.18, 1.6, 0.18),
		raioEstilhaco = 0.7,
		cacosPorGolpe = 4,
		alcance = 12,
		continua = false,
	},
	Machado = {
		nome = "Machado",
		laminaTamanho = Vector3.new(0.45, 2.4, 0.45),
		raioEstilhaco = 1.4,
		cacosPorGolpe = 8,
		alcance = 12,
		continua = false,
	},
	SerraManual = {
		nome = "Serra manual",
		laminaTamanho = Vector3.new(0.10, 2.8, 0.10),
		raioEstilhaco = 0.0, -- serragem é partícula, não geometria
		cacosPorGolpe = 0,
		alcance = 10,
		continua = true,
	},
	Motosserra = {
		nome = "Motosserra",
		laminaTamanho = Vector3.new(0.6, 3.2, 0.6),
		raioEstilhaco = 1.1,
		cacosPorGolpe = 6,
		alcance = 12,
		continua = true,
	},
}

Config.FerramentaPadraoM0 = "Machado"

-- ─────────────────────────────────────────────────────────────
-- Economia (SPEC § 4) — o corte vira $. FÓRMULA:
--   $ = volume removido × valorMultiplicador da espécie (Catalogo.Especies)
--       × multiplicador de QUALIDADE do resíduo × VALOR_BASE
-- Server-authoritative: quem calcula é o EconomiaServidor; o cliente só exibe.
-- Nada de constante mágica no código — todo número tunável de $ mora aqui.
-- ─────────────────────────────────────────────────────────────
Config.Economia = {
	-- multiplicador de QUALIDADE do resíduo (SPEC § 4): quanto mais "inteiro" o
	-- pedaço, mais vale. Golpe normal solta LASCA (×0,4). Derrubar a árvore inteira
	-- sem picá-la = TORA LIMPA, o grande prêmio (×2,0). serragem/naco ficam prontos
	-- pro dia em que serra (serragem) e machadadas grossas (naco) forem diferenciadas.
	QUALIDADE = {
		serragem = 0.1, -- pó de serra (serra manual/motosserra — resíduo mais fino)
		lasca = 0.4, -- estilhaço do golpe normal (o caso padrão do machado)
		naco = 0.7, -- toco/naco grosso arrancado
		toraLimpa = 2.0, -- tronco tombado inteiro (não picado) — o bônus de tora
	},
	-- fator de escala global do $ (identidade = 1,0: mantém a fórmula do SPEC exata).
	-- Knob de tuning pra deixar os números do HUD gostosos sem mexer no código.
	VALOR_BASE = 1.0,
}

-- ─────────────────────────────────────────────────────────────
-- Feedback R1 (juice) — client-side, imediato no ponto do golpe.
-- Diretriz de VFX (ver README): empilhar número + partícula + som + shake LEVE.
-- Anti-padrões proibidos: shake constante, som a cada frame, Rate sem cap.
-- ─────────────────────────────────────────────────────────────
Config.Feedback = {
	-- serragem (ParticleEmitter, só burst via :Emit — Rate fica 0)
	SERRAGEM_PARTICULAS = 16,
	SERRAGEM_VIDA_MIN = 0.4,
	SERRAGEM_VIDA_MAX = 0.7,
	SERRAGEM_VELOCIDADE = 9,

	-- número pop ("+madeira" → volume real quando o servidor responde)
	POP_SUBIDA_STUDS = 3,
	POP_DURACAO_S = 0.6,
	POP_MAX_SIMULTANEOS = 24, -- clicker gera spam: teto pra não vazar GUI

	-- camera shake LEVE (graus) — cooldown pra não empilhar e enjoar
	SHAKE_DURACAO_S = 0.12,
	SHAKE_AMPLITUDE_GRAUS = 0.35,
	SHAKE_COOLDOWN_S = 0.15,

	-- som de impacto — cooldown mínimo (serra/motosserra é contínua)
	SOM_COOLDOWN_S = 0.08,
	SOM_VOLUME = 0.5,
	-- variação de pitch do impacto (0.9–1.1) pra não enjoar de repetir
	SOM_PITCH_MIN = 0.9,
	SOM_PITCH_MAX = 1.1,
	-- estalo/quebra (cacos) — um pouco mais baixo que o impacto
	SOM_VOLUME_LASCA = 0.42,
	-- QUEDA (clímax do tombamento): mais alto e grave que tudo. Toca no IMPACTO
	-- com o chão (Net.ImpactoSolo), não no início da queda (SPEC § 2.6).
	SOM_VOLUME_QUEDA = 1.0,
	SOM_PITCH_QUEDA = 0.82,
	-- RANGIDO de INÍCIO da queda (Net.TroncoTombou): o estalo leve de quando a árvore
	-- perde a estrutura e começa a tombar. Baixo e grave — nunca o "CRASH".
	SOM_VOLUME_RANGIDO = 0.34,
	SOM_PITCH_RANGIDO = 0.72,

	-- pop DOURADO de "TORA!" no tombamento (clímax visual). Bônus simbólico do
	-- multiplicador de tora limpa (SPEC § 4) — número de tuning, ajustar depois.
	POP_TORA_COR = Color3.fromRGB(255, 214, 90),
	POP_TORA_ESCALA = 1.9, -- multiplica o tamanho do BillboardGui do pop
	POP_TORA_DURACAO_S = 1.1,
	POP_TORA_SUBIDA_STUDS = 5,
	TORA_BONUS = 250, -- madeira-bônus ao derrubar a árvore inteira

	-- HUD de madeira acumulada — tickzinho de animação quando o total sobe
	HUD_TICK_ESCALA = 1.16,
	HUD_TICK_DURACAO_S = 0.12,

	-- shake da ÁRVORE por golpe (R1 SPEC § 14): wobble rotacional LEVE e amortecido
	-- na copa, pivotando na base (balança a copa, não a base). NÃO é o camera shake
	-- acima — é o Model sacudindo no ponto do golpe. Cooldown pra não empilhar.
	ARVORE_SHAKE_GRAUS = 2.4, -- amplitude do 1º pico da oscilação amortecida
	ARVORE_SHAKE_DURACAO_S = 0.30, -- tempo até assentar de volta ao repouso
	ARVORE_SHAKE_COOLDOWN_S = 0.10, -- por árvore
	ARVORE_SHAKE_OSCILACOES = 2.2, -- nº de ida-e-volta dentro da duração
	ARVORE_SHAKE_RAIO_BUSCA = 16, -- ponto do golpe → tronco mais próximo (studs)
}

-- ─────────────────────────────────────────────────────────────
-- Tombamento (SPEC § 2) — o tronco só tomba quando a geometria remanescente
-- na linha de corte cai abaixo do limiar; cai pro lado do entalhe e a FÍSICA
-- resolve a direção (nada de tween roteirizado). Guardamos MassaInicial no Model.
-- ─────────────────────────────────────────────────────────────
Config.Tombamento = {
	-- começa a cair quando resta ≤55% da madeira (≈45% de massa removida) —
	-- decisão do usuário (Onda B): força o jogador a de fato "comer" o tronco antes
	-- de cair (tensão + "quase lá"), em vez dos ~7% de antes que caía cedo demais.
	LIMIAR_MASSA = 0.55,
	-- impulso horizontal aplicado no TOPO do tronco (multiplicado pela massa,
	-- pra ficar independente do tamanho). Empurrão leve; gravidade faz o resto.
	IMPULSO = 16,
	-- torque angular de ajuda pra garantir que tombe no eixo certo (× massa)
	TORQUE = 9,
	-- fração da altura onde o impulso é aplicado (topo = alavanca que derruba)
	ALTURA_EMPURRAO = 0.45,
	-- assentamento: abaixo desta velocidade vira "tora" deitada
	VEL_ASSENTAR = 2.5,
	-- teto de segurança caso nunca assente (nunca marca tora antes disso)
	TEMPO_MAX_ASSENTAR_S = 8,
}

-- ─────────────────────────────────────────────────────────────
-- Copa (folhas) — decorativa, não cortável, CanCollide=false. Primeiro tenta o
-- MODELO real curado no catálogo (folhas de verdade via InsertService:LoadAsset);
-- se falhar, cai no fallback procedural (aglomerado de esferas verdes em camadas).
-- ─────────────────────────────────────────────────────────────
Config.Copa = {
	-- modelo real VENDORIZADO: agora vem de ReplicatedStorage.Modelos.<INSTANCIA>
	-- (Rojo sincroniza o .rbxm curado). Nada de InsertService:LoadAsset em runtime —
	-- LoadAsset de asset de terceiro falha em jogo não publicado e a copa caía 100%
	-- no procedural ("bolinhas"). MODELO_CHAVE segue como referência ao catálogo.
	USAR_MODELO_REAL = true,
	MODELO_CHAVE = "MODELO_COPA_TREE_PACK",
	MODELO_INSTANCIA = "CopaTreePack", -- nome do .rbxm em src/ReplicatedStorage/Modelos
	DIAMETRO_ALVO = 10, -- copa é escalada pra ~este diâmetro horizontal (studs)
	SOBREPOR = 1.4, -- quanto a base da copa afunda no topo do tronco (sem gap)

	-- fallback procedural (esferas)
	BOLAS = 8, -- esferas por camada do aglomerado
	RAIO = 3.6, -- raio médio de cada esfera
	DISPERSAO = 2.6, -- quão espalhadas ficam em torno do centro
	ALTURA_OFFSET = 1.0, -- centro da copa acima do topo do tronco
	COR = Color3.fromRGB(58, 128, 46),
	MATERIAL = Enum.Material.LeafyGrass,
}

-- ─────────────────────────────────────────────────────────────
-- Rebrote (SPEC § 5/§ 8) — fecha o core loop: a árvore RENASCE após cair, com
-- espécie sorteada (Catalogo.Especies) e crescimento visível. Intervalo VARIÁVEL
-- (jitter) pra o rebrote não virar metrônomo robótico (anti-farm). Offline fica
-- pro M2; aqui é só o rebrote em tempo real.
-- ─────────────────────────────────────────────────────────────
Config.Rebrote = {
	INTERVALO_BASE_S = 6, -- (legado) tempo médio entre a tora assentar e a nova nascer
	JITTER = 0.35, -- ±35% em torno do base (mapa logístico ainda não existe no projeto)
	DURACAO_CRESCIMENTO_S = 2.5, -- muda de escala pequena → cheia
	PASSO_CRESCIMENTO_S = 0.1, -- passo fixo do crescimento (~25 passos, não por frame)
	ESCALA_INICIAL = 0.08, -- tamanho da muda ao nascer (cresce até 1)
	TORA_VIDA_S = 5, -- a tora deitada some no máx. isso depois (o ciclo do toco a substitui)
}

-- ─────────────────────────────────────────────────────────────
-- Ciclo TOCO → BROTOS (rebrote realista, substitui a muda nascendo inteira no slot).
-- Ao tombar: a base vira um TOCO ancorado (não cortável); depois de um intervalo com
-- jitter brotam 1-3 mudinhas; uma delas cresce (Rebrote acima) até adulta e VOLTA a
-- ser cortável. O toco some quando a nova árvore fica adulta (ou fica de detalhe).
-- ─────────────────────────────────────────────────────────────
Config.Toco = {
	ALTURA = 1.3, -- altura do cepo (cilindro baixo plantado no lugar)
	RAIO_FATOR = 1.12, -- toco levemente mais gordo que o tronco (raio × isto)
	ANEIS = true, -- disco fino de anéis no topo do toco (barato: 1 part)
	COR_ANEIS_LERP = 0.4, -- clareia a cor do tronco pro topo dos anéis

	INTERVALO_BROTO_S = 4, -- toco parado antes de brotar
	JITTER = 0.35, -- ±35% no intervalo do broto (anti-metrônomo)
	BROTOS_MIN = 1, -- nº mínimo de mudinhas que brotam
	BROTOS_MAX = 3, -- nº máximo
	BROTO_ALTURA = 1.7, -- altura da mudinha decorativa (haste + copa mini)
	BROTO_ESPALHA = 0.55, -- quão longe do centro do toco as mudinhas nascem (× raio toco)
	ESPERA_CRESCER_S = 1.4, -- mudinhas aparecem, DEPOIS a principal cresce de verdade
	SUMIR_TOCO = true, -- toco some quando a nova árvore vira adulta
}

-- ─────────────────────────────────────────────────────────────
-- LOTE POR JOGADOR (SPEC § 2.5) — a mudança central do v2. Cada jogador ganha um
-- LOTE físico próprio numa grade de lotes bem espaçados; dentro dele nasce um
-- conjunto FIXO de árvores reais e cortáveis (sem proxy, sem promoção). A distância
-- entre centros é maior que o raio de streaming (Workspace.StreamingTargetRadius no
-- default.project.json), então o vizinho não é sequer enviado pro cliente — é o que
-- entrega "cada um vê as suas árvores" sem lógica de visibilidade por jogador.
--
-- Geometria da grade (calibrar M1): LINHAS × COLUNAS lotes centrados em ORIGEM.
-- Com 2×4 e ESPACAMENTO 900 a grade ocupa 2700×900 studs (cabe em CHAO_TAMANHO
-- 3000) e o lote mais interno fica a ~636 studs do centro do mapa — FORA do anel
-- de backdrop do CenarioVisual (raio ≤ 480), pra nenhuma árvore de cenário
-- (não cortável) aparecer dentro do lote de alguém.
-- ─────────────────────────────────────────────────────────────
Config.Lote = {
	LINHAS = 2, -- (calibrar M1) 2×4 = 8 lotes = maxPlayers do place
	COLUNAS = 4,
	-- distância entre centros de lote. REGRA: > StreamingTargetRadius (512 no
	-- default.project.json) + RAIO_CAMPO_LOTE, senão o vizinho renderiza. (calibrar M1)
	ESPACAMENTO = 900,
	ORIGEM = Vector3.new(0, 0, 0), -- centro da grade de lotes (y ignorado: chão em y=0)

	-- clareira central: o jogador nasce/respawna limpo, sem árvore em cima dele
	RAIO_CLAREIRA = 16,
	-- as árvores do lote ficam entre RAIO_CLAREIRA e este raio (anéis concêntricos)
	RAIO_CAMPO_LOTE = 60,
	-- conservador de propósito (risco #8 do SPEC: 12 × 8 lotes = 96 árvores reais).
	-- Subir só depois de medir. (calibrar M1)
	ARVORES_POR_LOTE = 12,
	-- distância mínima entre árvores do lote (define quantas cabem por anel)
	ESPACAMENTO_ARVORES = 22,
	-- altura do teleporte pro centro do lote (o personagem cai os últimos studs)
	ALTURA_SPAWN = 5,
}

-- ─────────────────────────────────────────────────────────────
-- RETIRADO v2 (ver Server/LoteServidor.lua) — `Config.Mundo` era o campo global de
-- 168 sites com promoção/rebaixamento por proximidade (SITES_MAX / ATIVAS_MAX /
-- RAIO_ATIVO / RAIO_DESATIVA / THROTTLE_S ...). O churn proxy ↔ real era a causa
-- comum dos bugs 1-4 do SPEC § 0.5 (troca de espécie, gigante sumindo, árvore mal
-- formada, adulta reciclada antes de virar tora). Substituído pelo LOTE fixo acima.
-- Nada mais no projeto pode ler `Config.Mundo`.
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- Cenário do spike
-- ─────────────────────────────────────────────────────────────
Config.M0 = {
	-- 6 árvores JOGÁVEIS (cortáveis) numa grade 3×2 na clareira, à frente do spawn
	-- (todas em z ≤ ORIGEM.z, longe da floresta de cenário que começa a ~50 studs do
	-- centro). Espaçamento generoso pra caber as GIGANTES (Sequoia até 4,5×) sem colar.
	TRONCOS = 6,
	TRONCO_ALTURA = 12,
	TRONCO_RAIO = 1.6,
	ESPACAMENTO = 24, -- distância entre colunas (X)
	ESPACAMENTO_LINHA = 20, -- distância entre linhas (Z, sempre pra -Z)
	COLUNAS = 3, -- árvores por linha da grade
	ORIGEM = Vector3.new(0, 0, -20),
	COR_TRONCO = Color3.fromRGB(104, 74, 48),
	-- chão: grama REALISTA via Terrain (lâminas 3D de verdade, não um Part liso).
	-- Topo do terreno em y=0; troncos e player nascem em cima. Mapa GRANDE o bastante
	-- pra a GRADE DE LOTES inteira caber (v2): 2×4 lotes a 900 de espaçamento ocupam
	-- 2700×900 studs, + RAIO_CAMPO_LOTE nas bordas → 3000×3000 com folga. Preenchido
	-- 1× no boot (StreamingEnabled cobre o custo de render).
	CHAO_TAMANHO = 3000,
	CHAO_ESPESSURA = 20,
	COR_GRAMA = Color3.fromRGB(86, 140, 58),
	GRAMA_ALTURA = 0.6, -- Terrain.GrassLength (lâmina 3D): válido só entre 0.1 e 1
}

return Config
