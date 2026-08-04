--!strict
--[[
	Catalogo.Trator
	---------------------------------------------------------------
	Tiers do trator. Cada upgrade aumenta velocidade e capacidade do carrocao.
]]

export type TierTrator = {
	tier: number,
	nome: string,
	velocidade: number,
	capacidadeCarrocao: number,
	custo: number,
}

local Trator: {[number]: TierTrator} = {
	[1] = {tier = 1, nome = "Trator de Ferro Velho",  velocidade = 24, capacidadeCarrocao = 50,    custo = 0},
	[2] = {tier = 2, nome = "Trator Compacto",         velocidade = 32, capacidadeCarrocao = 120,   custo = 250},
	[3] = {tier = 3, nome = "Trator Robusto",          velocidade = 40, capacidadeCarrocao = 280,   custo = 1500},
	[4] = {tier = 4, nome = "Trator Industrial",       velocidade = 50, capacidadeCarrocao = 700,   custo = 8000},
	[5] = {tier = 5, nome = "Trator Foguete",          velocidade = 65, capacidadeCarrocao = 1800,  custo = 40000},
}

return Trator
