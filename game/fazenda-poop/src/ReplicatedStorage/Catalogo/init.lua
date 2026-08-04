--!strict
--[[
	Catalogo (init)
	---------------------------------------------------------------
	Barrel export. require(ReplicatedStorage.Catalogo).Capim, .Boi, .Trator, .Relho, .Assets
]]

local Catalogo = {}

Catalogo.Capim = require(script.Capim)
Catalogo.Boi = require(script.Boi)
Catalogo.Trator = require(script.Trator)
Catalogo.Relho = require(script.Relho)
Catalogo.Assets = require(script.Assets) -- IDs do Toolbox (asset_catalog.py)

return Catalogo
