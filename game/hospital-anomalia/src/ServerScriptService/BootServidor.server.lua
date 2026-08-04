--!strict
--[[
	BootServidor.server.lua
	---------------------------------------------------------------
	Entrypoint do servidor. Roda 1x quando o servidor sobe.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Net)
Net.InicializarServidor()

-- Garante pasta Anomalias (templates entram aqui depois)
if not ReplicatedStorage:FindFirstChild("Anomalias") then
	local p = Instance.new("Folder")
	p.Name = "Anomalias"
	p.Parent = ReplicatedStorage
end

-- Garante o piso minimo do Hospital pra nao cair ao spawnar enquanto o mapa nao existe
local function garantirPlaceholderHospital()
	local hospital = Workspace:FindFirstChild("Hospital")
	if not hospital then
		hospital = Instance.new("Folder")
		hospital.Name = "Hospital"
		hospital.Parent = Workspace
	end
	if not hospital:FindFirstChild("FloorPlaceholder") then
		local floor = Instance.new("Part")
		floor.Name = "FloorPlaceholder"
		floor.Size = Vector3.new(200, 1, 200)
		floor.Position = Vector3.new(0, 0, 0)
		floor.Anchored = true
		floor.Material = Enum.Material.SmoothPlastic
		floor.Color = Color3.fromRGB(220, 220, 220)
		floor.Parent = hospital
	end
end

local function garantirSpawnLobby()
	local lobby = Workspace:FindFirstChild("Lobby")
	if not lobby then
		lobby = Instance.new("Folder")
		lobby.Name = "Lobby"
		lobby.Parent = Workspace
	end
	if not lobby:FindFirstChildOfClass("SpawnLocation") then
		local sp = Instance.new("SpawnLocation")
		sp.Name = "SpawnPadrao"
		sp.Size = Vector3.new(6, 1, 6)
		sp.Position = Vector3.new(0, 5, 30)
		sp.Anchored = true
		sp.Neutral = true
		sp.Material = Enum.Material.Neon
		sp.Color = Color3.fromRGB(80, 200, 120)
		sp.Parent = lobby
	end
end

garantirSpawnLobby()
garantirPlaceholderHospital()

local AnomaliaServidor = require(ServerScriptService.Server.AnomaliaServidor)
AnomaliaServidor.Iniciar()

print("[BootServidor] online — HospitalAnomalia v0.1")
