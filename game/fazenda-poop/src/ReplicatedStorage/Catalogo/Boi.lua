--!strict
--[[
	Catalogo.Boi
	---------------------------------------------------------------
	Raças de boi com pesos pra RNG no spawn.

	xpMax              = quanto XP precisa pra ficar PRONTO pra abate
	multiplicadorBife  = multiplicador de qtd e valor dos bifes no abatedor
	cor                = cor base do boi (placeholder ate ter mesh)
	escalaBezerro      = escala visual no nivel 1 (fica pequeno)
	escalaAdulto       = escala visual no nivel maximo
]]

export type RacaBoi = {
	id: number,
	nome: string,
	peso: number,
	xpMax: number,
	multiplicadorBife: number,
	cor: Color3,
	escalaBezerro: number,
	escalaAdulto: number,
	valorBifeBase: number,
}

local Boi: {[number]: RacaBoi} = {
	[1] = {
		id = 1, nome = "Nelore",
		peso = 70,
		xpMax = 100,
		multiplicadorBife = 1.0,
		valorBifeBase = 5,
		cor = Color3.fromRGB(230, 220, 200),
		escalaBezerro = 0.5, escalaAdulto = 1.0,
	},
	[2] = {
		id = 2, nome = "Brahman",
		peso = 22,
		xpMax = 150,
		multiplicadorBife = 1.4,
		valorBifeBase = 8,
		cor = Color3.fromRGB(200, 190, 160),
		escalaBezerro = 0.55, escalaAdulto = 1.15,
	},
	[3] = {
		id = 3, nome = "Angus",
		peso = 7,
		xpMax = 220,
		multiplicadorBife = 2.0,
		valorBifeBase = 14,
		cor = Color3.fromRGB(45, 35, 30),
		escalaBezerro = 0.55, escalaAdulto = 1.25,
	},
	[4] = {
		id = 4, nome = "Wagyu",
		peso = 1,
		xpMax = 400,
		multiplicadorBife = 4.0,
		valorBifeBase = 35,
		cor = Color3.fromRGB(80, 60, 50),
		escalaBezerro = 0.6, escalaAdulto = 1.4,
	},
}

return Boi
