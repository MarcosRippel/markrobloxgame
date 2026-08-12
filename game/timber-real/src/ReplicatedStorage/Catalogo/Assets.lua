--!strict
--[[
	Catalogo.Assets — os IDs de mídia do jogo num lugar só (convenção da casa,
	espelha FazendaPoop/Catalogo/Assets.lua). O FeedbackCliente lê daqui, nunca
	hardcoded.

	⚠️ Os SFX abaixo são CANDIDATOS NÃO VERIFICADOS do Creator Store. Podem exigir
	estar na conta do dev pra tocar. Se um Sound falhar em carregar, o jogo NÃO
	pode quebrar — só fica mudo (o FeedbackCliente engole a falha com pcall).

	// polish: rodar lab-factory-assets pra confirmar/licenciar os IDs.
]]

export type AssetEntry = {
	id: number,
	rbx: string,
	nome: string,
	tipo: string,
	hasScripts: boolean,
}

local Assets: { [string]: AssetEntry } = {
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
}

--[[ Devolve o rbxassetid:// de uma chave do catálogo, ou nil se não existir. ]]
function Assets.Rbx(idLab: string): string?
	local e = Assets[idLab]
	return if e then e.rbx else nil
end

return Assets
