--!strict
--[[
	Catalogo.Especies — as 7 espécies de árvore do rebrote (SPEC § 5).

	Pesos são PÚBLICOS (o jogador pode saber a chance de cada uma — transparência
	é parte do vício saudável). `valorMultiplicador` é o quanto a madeira dela vale
	em relação ao Pinho (base ×1). No M1 (SPEC § 4) ele JÁ VIRA $: o EconomiaServidor
	multiplica volume × valorMultiplicador × qualidade. Use `Especies.valorDe(nome)`
	pra ler o multiplicador sem repetir o loop (fonte da verdade fica aqui).

	Cores de tronco/copa dão a leitura visual instantânea da espécie. A Árvore de
	Ouro (0,4%) é o jackpot: dourada + destaque (o ArvoreServidor põe um Highlight).
]]

export type Especie = {
	nome: string,
	peso: number, -- peso relativo do sorteio (a soma NÃO precisa ser 100)
	valorMultiplicador: number, -- valor da madeira vs Pinho (×1)
	escala: number, -- tamanho da árvore (1 = base). Sequoia é GIGANTE de verdade.
	corTronco: Color3,
	corCopa: Color3,
	rara: boolean,
	ouro: boolean,
}

-- SPEC § 5: Pinho 45% ×1 · Eucalipto 25% ×1,6 · Carvalho 15% ×3 · Ipê 9% ×7 ·
-- Jacarandá 4% ×18 · Sequoia 1,6% ×60 · Árvore de Ouro 0,4% ×400.
local LISTA: { Especie } = {
	{
		nome = "Pinho",
		peso = 45,
		valorMultiplicador = 1,
		escala = 1.0,
		corTronco = Color3.fromRGB(104, 74, 48),
		corCopa = Color3.fromRGB(46, 96, 52),
		rara = false,
		ouro = false,
	},
	{
		nome = "Eucalipto",
		peso = 25,
		valorMultiplicador = 1.6,
		escala = 1.3,
		corTronco = Color3.fromRGB(158, 146, 126),
		corCopa = Color3.fromRGB(110, 156, 120),
		rara = false,
		ouro = false,
	},
	{
		nome = "Carvalho",
		peso = 15,
		valorMultiplicador = 3,
		escala = 1.6,
		corTronco = Color3.fromRGB(88, 60, 38),
		corCopa = Color3.fromRGB(58, 118, 50),
		rara = false,
		ouro = false,
	},
	{
		nome = "Ipê",
		peso = 9,
		valorMultiplicador = 7,
		escala = 2.2,
		corTronco = Color3.fromRGB(112, 92, 70),
		corCopa = Color3.fromRGB(226, 198, 72), -- ipê florido: amarelo
		rara = true,
		ouro = false,
	},
	{
		nome = "Jacarandá",
		peso = 4,
		valorMultiplicador = 18,
		escala = 2.8,
		corTronco = Color3.fromRGB(96, 74, 56),
		corCopa = Color3.fromRGB(150, 120, 214), -- flor roxa
		rara = true,
		ouro = false,
	},
	{
		nome = "Sequoia",
		peso = 1.6,
		valorMultiplicador = 60,
		escala = 4.5, -- GIGANTE de verdade: tronco grosso e alto (pedido do usuário)
		corTronco = Color3.fromRGB(150, 80, 54),
		corCopa = Color3.fromRGB(40, 104, 62),
		rara = true,
		ouro = false,
	},
	{
		nome = "Árvore de Ouro",
		peso = 0.4,
		valorMultiplicador = 400,
		escala = 3.0,
		corTronco = Color3.fromRGB(200, 158, 44),
		corCopa = Color3.fromRGB(255, 214, 84),
		rara = true,
		ouro = true,
	},
}

local Especies = {
	LISTA = LISTA,
}

local pesoTotal = 0
for _, e in ipairs(LISTA) do
	pesoTotal += e.peso
end
Especies.PESO_TOTAL = pesoTotal

--[[ Sorteio por peso (weighted random). Sem dependência externa. ]]
function Especies.sortear(): Especie
	local alvo = math.random() * pesoTotal
	local acumulado = 0
	for _, e in ipairs(LISTA) do
		acumulado += e.peso
		if alvo <= acumulado then
			return e
		end
	end
	return LISTA[1] -- fallback numérico (soma de floats)
end

function Especies.porNome(nome: string): Especie?
	for _, e in ipairs(LISTA) do
		if e.nome == nome then
			return e
		end
	end
	return nil
end

-- valor da madeira da espécie (×Pinho). Fallback ×1 pra nome desconhecido/ausente,
-- pra economia nunca quebrar num tronco solto sem espécie.
function Especies.valorDe(nome: string?): number
	local e = nome and Especies.porNome(nome)
	return e and e.valorMultiplicador or 1
end

return Especies
