--!strict
--[[
	RngPesado.lua  (ModuleScript em ReplicatedStorage.Util)
	---------------------------------------------------------------
	Sorteio com pesos. Aceita lista {[key]={peso=N, ...}} OU array {{peso=N, valor=X}}.
]]

local M = {}

-- Sorteia uma chave de tabela {[key]={peso=N, ...}}
function M.SortearChave(dict: {[any]: {peso: number}}, rng: Random?): any
	local r = rng or Random.new()
	local total = 0
	for _, item in dict do
		total += (item.peso or 0)
	end
	if total <= 0 then return nil end
	local alvo = r:NextNumber(0, total)
	local acumulado = 0
	for k, item in dict do
		acumulado += (item.peso or 0)
		if alvo <= acumulado then
			return k
		end
	end
	-- fallback (shouldn't reach if pesos > 0)
	for k in dict do return k end
	return nil
end

-- Sorteia um valor de array [{peso, valor}]
function M.SortearArray(arr: {{peso: number, valor: any}}, rng: Random?): any
	local r = rng or Random.new()
	local total = 0
	for _, item in arr do
		total += (item.peso or 0)
	end
	if total <= 0 then return nil end
	local alvo = r:NextNumber(0, total)
	local acumulado = 0
	for _, item in arr do
		acumulado += (item.peso or 0)
		if alvo <= acumulado then
			return item.valor
		end
	end
	return arr[#arr] and arr[#arr].valor or nil
end

return M
