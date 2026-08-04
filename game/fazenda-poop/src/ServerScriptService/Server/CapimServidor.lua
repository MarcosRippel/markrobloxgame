--!strict
--[[
	CapimServidor.lua
	---------------------------------------------------------------
	V3: Terrain Grass (pintado pelo BootServidor) + grid de hitboxes invisiveis
	rastreando estado por celula.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Net)
local Config = require(ReplicatedStorage.ConfiguracaoFazenda)
local Catalogo = require(ReplicatedStorage.Catalogo)
local RngPesado = require(ReplicatedStorage.Util.RngPesado)
local DropBreathing = require(ReplicatedStorage.Math.DropBreathing)

local M = {}

local rng = Random.new()
local tufos: {[number]: BasePart} = {}
local proxId = 0
-- índice da série caótica (mapa logístico exportado) — avança a cada sorteio
local breathIndex = 0

local function novoId(): number
	proxId += 1
	return proxId
end

local function sortearTipoCapim(): number
	-- Pesos "respiram" com a série pré-computada (caos offline → Luau).
	-- Fallback: catálogo estático se o módulo Math faltar.
	breathIndex += 1
	local dict = DropBreathing.PesosComoDict(breathIndex)
	return RngPesado.SortearChave(dict, rng) or RngPesado.SortearChave(Catalogo.Capim, rng) or 1
end

local function pintarCelula(pos: Vector3, material: Enum.Material)
	local esp = Config.TUFO_ESPACAMENTO
	local regiao = Region3.new(
		pos + Vector3.new(-esp/2, -3, -esp/2),
		pos + Vector3.new( esp/2,  0,  esp/2)
	):ExpandToGrid(4)
	Workspace.Terrain:FillRegion(regiao, 4, material)
end

function M.MontarCampo(fazenda: Instance)
	local campo = fazenda:FindFirstChild("CampoCapim")
	if not campo then
		campo = Instance.new("Folder")
		campo.Name = "CampoCapim"
		campo.Parent = fazenda
	end

	local nX, nZ = Config.CAMPO_TAMANHO_X, Config.CAMPO_TAMANHO_Z
	local esp = Config.TUFO_ESPACAMENTO
	local origem = Config.CAMPO_CENTRO_OFFSET
		- Vector3.new(((nX - 1) * esp) / 2, 0, ((nZ - 1) * esp) / 2)

	for ix = 0, nX - 1 do
		for iz = 0, nZ - 1 do
			local id = novoId()
			local tipoId = sortearTipoCapim()
			local pos = origem + Vector3.new(ix * esp, 0.5, iz * esp)

			local hb = Instance.new("Part")
			hb.Name = "Tufo"
			hb.Anchored = true
			hb.CanCollide = false
			hb.Transparency = 1
			hb.Size = Vector3.new(esp, 1, esp)
			hb.Position = pos
			hb:SetAttribute("TufoId", id)
			hb:SetAttribute("TipoId", tipoId)
			hb:SetAttribute("Crescido", true)
			hb:SetAttribute("RegrowthAt", 0)
			hb.Parent = campo
			tufos[id] = hb
		end
	end
	print(string.format("[CapimServidor] campo v3 montado: %d hitboxes em %dx%d", nX * nZ, nX, nZ))
end

function M.Cortar(hb: BasePart): (number?, boolean)
	if not hb:GetAttribute("Crescido") then return nil, false end
	local tipoId = hb:GetAttribute("TipoId") :: number
	hb:SetAttribute("Crescido", false)
	local jitter = rng:NextNumber(Config.TUFO_REGROWTH_SEG.minimo, Config.TUFO_REGROWTH_SEG.maximo)
	hb:SetAttribute("RegrowthAt", os.clock() + jitter)
	pintarCelula(hb.Position, Enum.Material.Ground)
	Net.CapimCortado:FireAllClients({
		tufoId = hb:GetAttribute("TufoId"),
		tipoId = tipoId,
		posicao = hb.Position,
	})
	return tipoId, true
end

function M.TufosCrescidosNoRaio(centro: Vector3, raio: number): {BasePart}
	local res = {}
	for _, hb in tufos do
		if hb:GetAttribute("Crescido") and (hb.Position - centro).Magnitude <= raio then
			table.insert(res, hb)
		end
	end
	return res
end

local function processarRegrowth(agora: number)
	for _, hb in tufos do
		if not hb:GetAttribute("Crescido") then
			local at = hb:GetAttribute("RegrowthAt") :: number
			if at and at > 0 and agora >= at then
				local novoTipo = sortearTipoCapim()
				hb:SetAttribute("TipoId", novoTipo)
				hb:SetAttribute("Crescido", true)
				hb:SetAttribute("RegrowthAt", 0)
				pintarCelula(hb.Position, Enum.Material.Grass)
				Net.CapimRegerou:FireAllClients({
					tufoId = hb:GetAttribute("TufoId"),
					tipoId = novoTipo,
				})
			end
		end
	end
end

function M.Iniciar()
	local ultimo = 0
	RunService.Heartbeat:Connect(function()
		local agora = os.clock()
		if agora - ultimo < 0.5 then return end
		ultimo = agora
		processarRegrowth(agora)
	end)
end

return M
