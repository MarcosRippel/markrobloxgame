--!strict
--[[
	Catalogo.Relho
	---------------------------------------------------------------
	Tiers do Relho (cattle prod). Forca = quantos studs o boi anda por toque.
	Cooldown = segundos entre toques permitidos.
]]

export type TierRelho = {
	tier: number,
	nome: string,
	forcaPorToque: number,    -- studs que o boi anda
	cooldownSeg: number,      -- entre toques
	custo: number,
}

local Relho: {[number]: TierRelho} = {
	[1] = {tier = 1, nome = "Relho de Couro",        forcaPorToque = 8,  cooldownSeg = 0.50, custo = 0},
	[2] = {tier = 2, nome = "Relho Reforcado",       forcaPorToque = 12, cooldownSeg = 0.40, custo = 200},
	[3] = {tier = 3, nome = "Relho de Comando",      forcaPorToque = 18, cooldownSeg = 0.30, custo = 1200},
	[4] = {tier = 4, nome = "Bastao Eletrico",       forcaPorToque = 28, cooldownSeg = 0.22, custo = 7000},
	[5] = {tier = 5, nome = "Relho do Cocoricó",     forcaPorToque = 45, cooldownSeg = 0.15, custo = 35000},
}

return Relho
