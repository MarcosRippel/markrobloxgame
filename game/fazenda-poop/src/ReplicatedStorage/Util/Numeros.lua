--!strict
--[[
	Numeros.lua  (ModuleScript em ReplicatedStorage.Util)
	---------------------------------------------------------------
	Formatacao "humana" de numeros: 1.2k, 3.4M, 5.6B.
]]

local M = {}

function M.Formatar(n: number): string
	local abs = math.abs(n)
	if abs >= 1e12 then return string.format("%.1fT", n / 1e12) end
	if abs >= 1e9  then return string.format("%.1fB", n / 1e9)  end
	if abs >= 1e6  then return string.format("%.1fM", n / 1e6)  end
	if abs >= 1e3  then return string.format("%.1fk", n / 1e3)  end
	return tostring(math.floor(n))
end

return M
