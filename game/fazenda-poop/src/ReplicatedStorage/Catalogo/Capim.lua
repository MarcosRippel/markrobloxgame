--!strict
--[[
	Catalogo.Capim
	---------------------------------------------------------------
	Tipos de capim com pesos pra RNG no regrowth.
	xpMultiplier = multiplicador do XP que o capim da pro boi quando alimentado.
	cor          = cor do tufo no campo (visual rapido pra debug; troca por mesh depois).
]]

export type TipoCapim = {
	id: number,
	nome: string,
	peso: number,         -- chance relativa no sorteio do regrowth
	xpMultiplier: number,
	cor: Color3,
	valor: number,        -- valor de venda direta (caso o jogador venda capim em vez de alimentar)
}

local Capim: {[number]: TipoCapim} = {
	[1] = {
		id = 1, nome = "Comum",
		peso = 85, xpMultiplier = 1.0, valor = 1,
		cor = Color3.fromRGB(80, 180, 60),
	},
	[2] = {
		id = 2, nome = "Premium",
		peso = 12, xpMultiplier = 1.5, valor = 3,
		cor = Color3.fromRGB(120, 220, 80),
	},
	[3] = {
		id = 3, nome = "Raro",
		peso = 3,  xpMultiplier = 3.0, valor = 10,
		cor = Color3.fromRGB(180, 230, 120),
	},
}

return Capim
