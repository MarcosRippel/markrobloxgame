--!strict
--[[
	Manipulador.client.lua  (LocalScript dentro do Tool Relho)
	---------------------------------------------------------------
	Tool.Activated -> acha boi mais proximo dentro do raio -> FireServer.
	Cooldown local pra evitar spam (servidor tambem valida).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Net)
local Config = require(ReplicatedStorage.ConfiguracaoFazenda)

local tool = script.Parent :: Tool
local player = Players.LocalPlayer

local ultimoToque = 0
local cooldown = 0.50 -- tier 1 default (espelha Catalogo.Relho[1].cooldownSeg)

local function boiMaisProximo(pos: Vector3): (number?, number)
	local fazenda = Workspace:FindFirstChild("Fazenda")
	local curral = fazenda and fazenda:FindFirstChild("Curral")
	if not curral then return nil, math.huge end
	local melhorId, melhorDist = nil, math.huge
	for _, m in curral:GetChildren() do
		if m:IsA("Model") and m.PrimaryPart then
			-- so toca boi PRONTO
			if m:GetAttribute("Estado") == "PRONTO" then
				local d = (m.PrimaryPart.Position - pos).Magnitude
				if d < melhorDist then
					melhorDist = d
					melhorId = m:GetAttribute("BoiId")
				end
			end
		end
	end
	return melhorId, melhorDist
end

tool.Activated:Connect(function()
	local agora = os.clock()
	if agora - ultimoToque < cooldown then return end
	local char = player.Character
	if not char or not char.PrimaryPart then return end
	local boiId, dist = boiMaisProximo(char.PrimaryPart.Position)
	if boiId and dist <= Config.RELHO_RAIO_ALCANCE then
		ultimoToque = agora
		Net.RelhoTocar:FireServer({boiId = boiId})
	end
end)
