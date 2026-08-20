--!strict
--[[
	Catalogo.Assets — os IDs de mídia do jogo num lugar só (convenção da casa,
	espelha FazendaPoop/Catalogo/Assets.lua). O FeedbackCliente lê daqui, nunca
	hardcoded.

	⚠️ Os SFX abaixo são CANDIDATOS NÃO VERIFICADOS do Creator Store. Podem exigir
	estar na conta do dev pra tocar. Se um Sound falhar em carregar, o jogo NÃO
	pode quebrar — só fica mudo (o FeedbackCliente engole a falha com pcall).

	--------------------------------------------------------------------------
	CURADORIA DE MESHES/MODELOS (2026-08-13)
	--------------------------------------------------------------------------
	Fonte: pipeline interno de curadoria de assets + índice real do Creator
	Store. Todo ID em MESHES/MODELOS é um asset PÚBLICO indexado
	no Creator Store (verificável em https://create.roblox.com/store/asset/<id>),
	salvo os marcados `NÃO VERIFICADO`.

	Como consumir:
	  • MESHES  → MeshPart.MeshId = entry.rbx  (category=meshes no store)
	  • MODELOS → InsertService:LoadAsset(entry.id) ou Toolbox no Studio (Model)
	Nada aqui é auto-inserido: são os IDs curados pro cenário/ferramenta usarem.

	WATERTIGHT: só o TRONCO CORTÁVEL precisa ser watertight/manifold (passa por
	Blender 5.1 antes de virar alvo de GeometryService). Copa, folhagem, grama e
	árvores de cenário são decorativas — NÃO precisam ser watertight.

	// polish: licenciar/aprovar os IDs marcados
	// "curadoria pendente" e resolver o machado (NÃO VERIFICADO).
]]

export type AssetEntry = {
	id: number,
	rbx: string,
	nome: string,
	tipo: string,
	hasScripts: boolean,
}

-- As entradas ficam num sub-campo tipado; assim o módulo pode carregar também a
-- função Assets.Rbx sem que o Script Analysis acuse "função não é AssetEntry"
-- (o mapa é estritamente { [string]: AssetEntry }).
local SFX: { [string]: AssetEntry } = {
	-- impacto do machado no tronco (dois pra alternar e não repetir zoado)
	SFX_HIT_MADEIRA_1 = {
		id = 131261474470044,
		rbx = "rbxassetid://131261474470044",
		nome = "hit-tree",
		tipo = "Audio",
		hasScripts = false,
	},
	SFX_HIT_MADEIRA_2 = {
		id = 98223650777126,
		rbx = "rbxassetid://98223650777126",
		nome = "tree-hit03",
		tipo = "Audio",
		hasScripts = false,
	},
	-- lasca/estilhaço (segundo burst quando o servidor confirma cacos)
	SFX_LASCA_MADEIRA = {
		id = 7214256592,
		rbx = "rbxassetid://7214256592",
		nome = "tree-log-breaking",
		tipo = "Audio",
		hasScripts = false,
	},
	-- QUEDA DA ÁRVORE (clímax do tombamento) — antes o jogo reusava o estalo grave.
	-- Fonte: índice do Creator Store (categoria Audio).
	-- Asset "Tree Fall" (pilot_pie1Lot): "tree falling and crashing... Timber!
	-- lumberjack". Free, sem scripts. ⚠️ NÃO VERIFICADO auditivamente (áudio legado
	-- pode exigir permissão/conta pra tocar pós-privacidade de áudio 2022) — testar
	-- no Studio; se mudo, o pcall do FeedbackCliente engole. Alternativas indexadas
	-- (mesmo need, também Free/sem scripts): 5451436860 "tree falling" (0x_wisp),
	-- 1911995155 "Falling Tree Sound Effect" (dirtpee).
	SFX_QUEDA_ARVORE = {
		id = 6365855087,
		rbx = "rbxassetid://6365855087",
		nome = "Tree Fall", -- SPEC §13 `tree-fall-6365855087`
		tipo = "Audio",
		hasScripts = false,
	},
	-- AMBIENTE DE FLORESTA (loop de fundo) — vento/folhas + pássaros.
	-- Fonte: índice Creator Store. Asset "Leaves Rustle Wind Blowing Through Trees 1"
	-- (ProSoundEffects): "Leaves Rustle, Wind Blowing through Trees, Soft Crackling,
	-- Gusts Swelling, Some Birds", 75.8s, rating 100 — ótimo pra Sound.Looped=true de
	-- fundo. Free, sem scripts. ⚠️ NÃO VERIFICADO auditivamente — testar no Studio.
	SFX_AMBIENTE_FLORESTA = {
		id = 9116258071,
		rbx = "rbxassetid://9116258071",
		nome = "Leaves Rustle Wind Blowing Through Trees 1 (SFX)", -- SPEC §13 `...-9116258071`
		tipo = "Audio",
		hasScripts = false,
	},
}

-- MESHES: assets category=meshes no Creator Store. Usar como MeshPart.MeshId.
local MESHES: { [string]: AssetEntry } = {
	-- Tronco cortável (candidato SPEC §13 `tree-trunk-537409716`). É MeshId puro.
	-- ⚠️ WATERTIGHT OBRIGATÓRIO: valida/repara no Blender 5.1 (3D Print Toolbox)
	-- ANTES de virar alvo de GeometryService:FragmentAsync. Sem isso a API falha.
	MESH_TRONCO_TREE_TRUNK = {
		id = 537409716,
		rbx = "rbxassetid://537409716",
		nome = "Tree Trunk (mesh)",
		tipo = "MeshPart", -- MeshId
		hasScripts = false,
	},
}

-- MODELOS: assets category=models. Carregar via InsertService:LoadAsset(id) ou
-- inserir pelo Toolbox no Studio. Guardo `id` e o `rbx` (rbxassetid) por padrão
-- da casa; pra Model o que importa é o `id`.
local MODELOS: { [string]: AssetEntry } = {
	-------------------------------------------------------------------- MACHADO
	-- ⚠️ NÃO VERIFICADO: o fetch (keyword "axe"), o índice do Creator Store e o
	-- curadoria NÃO trouxeram nenhuma mesh/model de machado pública. Nada de ID
	-- inventado. Caminho de resolução:
	--   1) Studio Toolbox: buscar "axe"/"woodcutting axe" e curar um Model, OU
	--   2) Quaternius survival/tools pack (externo) → Blender → import como Mesh.
	-- Enquanto isso, ConstruirFerramentas.server.lua monta um Handle blockout
	-- (cabo cilíndrico + cabeça soldada) — o jogo NÃO depende deste ID.
	-- MODELO_MACHADO = { id = 0, ... } -- preencher quando houver ID real.

	------------------------------------------------------------- COPA / FOLHAS
	-- Sem mesh "canopy" isolada no índice. Proxy decorativo (não-watertight):
	-- usar a geometria folhada de um tree pack pra coroar o tronco. Curadoria
	-- pendente (extrair só a copa do Model no Studio).
	MODELO_COPA_TREE_PACK = {
		id = 3556701939,
		rbx = "rbxassetid://3556701939",
		nome = "Tree Pack (fonte de copa/folhas)", -- SPEC §13 `tree-pack-3556701939`
		tipo = "Model",
		hasScripts = false,
	},

	------------------------------------------------ FOLHAGEM / ARBUSTO / GRAMA
	-- Espalhar no chão pra densidade visual além da grama de Terrain. Decorativo.
	MODELO_NATURE_PACK = {
		id = 82060619904561,
		rbx = "rbxassetid://82060619904561",
		nome = "Nature Pack Studs Trees Bush Grass Flower", -- bush+grama+flor
		tipo = "Model",
		hasScripts = false,
	},
	MODELO_GRASS_GROUNDCOVER = {
		id = 116715066942677,
		rbx = "rbxassetid://116715066942677",
		nome = "Grass & Groundcover [Greenleaf]", -- tufos de grama (rating 100)
		tipo = "Model",
		hasScripts = false,
	},
	MODELO_LOWPOLY_GRASS = {
		id = 6447246239,
		rbx = "rbxassetid://6447246239",
		nome = "Low-Poly Grass", -- tufos low-poly (rating 97)
		tipo = "Model",
		hasScripts = false,
	},

	--------------------------------------------- ÁRVORES DE CENÁRIO (não-corte)
	-- Fundo/floresta. Não precisam ser watertight.
	MODELO_ARVORE_REALISTA = {
		id = 6020696518,
		rbx = "rbxassetid://6020696518",
		nome = "Realistic Tree", -- rating 97
		tipo = "Model",
		hasScripts = false,
	},
	MODELO_ARVORE_REALISTAS_PACK = {
		id = 3256343670,
		rbx = "rbxassetid://3256343670",
		nome = "Realistic Trees (pack)", -- rating 92
		tipo = "Model",
		hasScripts = false,
	},
	MODELO_LOWPOLY_TREE = {
		id = 4893246329,
		rbx = "rbxassetid://4893246329",
		nome = "Low Poly Tree", -- SPEC §13 `low-poly-tree-4893246329`
		tipo = "Model",
		hasScripts = false,
	},
	MODELO_PINE_TREE = {
		id = 183435411,
		rbx = "rbxassetid://183435411",
		nome = "Pine Tree", -- ✅ endorsed, aprovado na curadoria
		tipo = "Model",
		hasScripts = false,
	},

	------------------------------------------------- TRONCO/LOG DEITADO (ref.)
	-- Log já tombado — bom pra "árvore derrubada" decorativa OU candidato de
	-- tronco cortável (SPEC §13). Se virar alvo de corte, passa por Blender.
	MODELO_TREE_LOG = {
		id = 9731248486,
		rbx = "rbxassetid://9731248486",
		nome = "Tree log", -- SPEC §13 `tree-log-9731248486`
		tipo = "Model",
		hasScripts = false,
	},
}

local Assets = {
	SFX = SFX,
	MESHES = MESHES,
	MODELOS = MODELOS,
}

--[[ Devolve o rbxassetid:// de uma chave do catálogo, ou nil se não existir.
	Procura em SFX, depois MESHES, depois MODELOS (chaves não colidem). ]]
function Assets.Rbx(idLab: string): string?
	local e = SFX[idLab] or MESHES[idLab] or MODELOS[idLab]
	return if e then e.rbx else nil
end

return Assets
