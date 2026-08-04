--!strict
--[[
	TratorServidor.lua v3
	---------------------------------------------------------------
	Fixes:
	- ceifar corta na direcao +LookVector (era -LookVector = BUG que impedia corte)
	- ProximityPrompt raio 20 (era 12)
	- Sound de motor (rbxassetid://131961136) com pitch on throttle
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.ConfiguracaoFazenda)

local M = {}
local capimServidor
local economia
local trator: Model? = nil
local chassis: BasePart? = nil
local seat: VehicleSeat? = nil
local engineSound: Sound? = nil

function M.SetCapimServidor(c) capimServidor = c end
function M.SetEconomia(e) economia = e end

local function soldarAoChassis(p: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = chassis :: BasePart
	w.Part1 = p
	w.Parent = p
end

local function novaPart(nome: string, size: Vector3, cor: Color3, mat: Enum.Material?, cfRel: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Size = size
	p.Color = cor
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CFrame = (chassis :: BasePart).CFrame * cfRel
	p.Parent = parent
	soldarAoChassis(p)
	return p
end

function M.MontarTrator(fazenda: Instance)
	local pasta = fazenda:FindFirstChild("Trator")
	if not pasta then
		pasta = Instance.new("Model")
		pasta.Name = "Trator"
		pasta.Parent = fazenda
	end

	local corPrimaria = Color3.fromRGB(220, 60, 45)
	local corSecundaria = Color3.fromRGB(70, 55, 45)
	local corMetal = Color3.fromRGB(90, 90, 100)
	local corBorracha = Color3.fromRGB(30, 30, 30)
	local corAmarelo = Color3.fromRGB(240, 200, 60)

	local c = Instance.new("Part")
	c.Name = "Chassis"
	c.Size = Vector3.new(4, 1, 8)
	c.Color = corSecundaria
	c.Material = Enum.Material.Metal
	c.Position = Config.TRATOR_POSICAO_INICIAL
	c.Anchored = false
	c.CanCollide = true
	c.Parent = pasta
	pasta.PrimaryPart = c
	chassis = c

	novaPart("Hood", Vector3.new(3, 2, 3.5), corPrimaria, Enum.Material.SmoothPlastic,
		CFrame.new(0, 1.5, -2), pasta)
	novaPart("Grade", Vector3.new(2.6, 1.2, 0.2), Color3.fromRGB(30, 30, 30), Enum.Material.Metal,
		CFrame.new(0, 1.3, -3.9), pasta)

	local escape = Instance.new("Part")
	escape.Name = "Escape"
	escape.Shape = Enum.PartType.Cylinder
	escape.Size = Vector3.new(2, 0.5, 0.5)
	escape.Color = corMetal
	escape.Material = Enum.Material.Metal
	escape.Anchored = false
	escape.CanCollide = false
	escape.CFrame = c.CFrame * CFrame.new(-1, 3.5, -2.5) * CFrame.Angles(0, 0, math.rad(90))
	escape.Parent = pasta
	soldarAoChassis(escape)

	local pilarSize = Vector3.new(0.3, 3.5, 0.3)
	novaPart("PilarFE", pilarSize, corMetal, Enum.Material.Metal, CFrame.new(-1.4, 2.75, 0), pasta)
	novaPart("PilarFD", pilarSize, corMetal, Enum.Material.Metal, CFrame.new( 1.4, 2.75, 0), pasta)
	novaPart("PilarTE", pilarSize, corMetal, Enum.Material.Metal, CFrame.new(-1.4, 2.75, 2.5), pasta)
	novaPart("PilarTD", pilarSize, corMetal, Enum.Material.Metal, CFrame.new( 1.4, 2.75, 2.5), pasta)
	novaPart("TetoCabine", Vector3.new(3.5, 0.25, 3), corAmarelo, Enum.Material.Plastic,
		CFrame.new(0, 4.3, 1.2), pasta)
	novaPart("Volante", Vector3.new(1.2, 0.15, 0.15), Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic,
		CFrame.new(0, 2, 0.5), pasta)

	novaPart("Ceifeira", Vector3.new(8, 0.8, 1.8), corMetal, Enum.Material.Metal,
		CFrame.new(0, -0.1, -5), pasta)
	for i = -3, 3 do
		novaPart("DenteCeifeira", Vector3.new(0.5, 0.5, 0.8), corMetal, Enum.Material.Metal,
			CFrame.new(i * 1.1, -0.1, -5.9), pasta)
	end

	novaPart("Engate", Vector3.new(0.4, 0.3, 1.5), corMetal, Enum.Material.Metal,
		CFrame.new(0, 0.2, 4.8), pasta)
	novaPart("CarrocaoPiso", Vector3.new(4.5, 0.4, 5), corSecundaria, Enum.Material.Wood,
		CFrame.new(0, 0.5, 8), pasta)
	novaPart("CarrocaoParedeE", Vector3.new(0.3, 2, 5), corSecundaria, Enum.Material.Wood,
		CFrame.new(-2.3, 1.5, 8), pasta)
	novaPart("CarrocaoParedeD", Vector3.new(0.3, 2, 5), corSecundaria, Enum.Material.Wood,
		CFrame.new(2.3, 1.5, 8), pasta)
	novaPart("CarrocaoParedeT", Vector3.new(4.5, 2, 0.3), corSecundaria, Enum.Material.Wood,
		CFrame.new(0, 1.5, 10.4), pasta)

	local function fazerRoda(nome: string, cfRel: CFrame, diam: number)
		local w = Instance.new("Part")
		w.Name = nome
		w.Shape = Enum.PartType.Cylinder
		w.Size = Vector3.new(0.6, diam, diam)
		w.Color = corBorracha
		w.Material = Enum.Material.SmoothPlastic
		w.Anchored = false
		w.CanCollide = false
		w.CFrame = c.CFrame * cfRel * CFrame.Angles(0, 0, math.rad(90))
		w.Parent = pasta
		soldarAoChassis(w)
	end
	fazerRoda("RodaFE", CFrame.new(-2.3, -0.5, -2.5), 2.4)
	fazerRoda("RodaFD", CFrame.new( 2.3, -0.5, -2.5), 2.4)
	fazerRoda("RodaTE", CFrame.new(-2.4, -0.2, 2),    3.6)
	fazerRoda("RodaTD", CFrame.new( 2.4, -0.2, 2),    3.6)

	local s = Instance.new("VehicleSeat")
	s.Name = "Seat"
	s.Size = Vector3.new(2, 1, 2)
	s.HeadsUpDisplay = false
	s.Anchored = false
	s.CanCollide = true
	s.Color = Color3.fromRGB(40, 40, 40)
	s.Material = Enum.Material.SmoothPlastic
	s.CFrame = c.CFrame * CFrame.new(0, 2, 1.2)
	s.Parent = pasta
	soldarAoChassis(s)
	seat = s

	-- ProximityPrompt (F pra Dirigir), raio maior
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PromptDirigir"
	prompt.ActionText = "Dirigir"
	prompt.ObjectText = "Trator"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 20
	prompt.RequiresLineOfSight = false
	prompt.Parent = s

	prompt.Triggered:Connect(function(player)
		local char = player.Character
		if not char then return end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid and not s.Occupant then
			s:Sit(humanoid)
		end
	end)

	-- Placa "SEU TRATOR" flutuando
	local bill = Instance.new("BillboardGui")
	bill.Adornee = c
	bill.Size = UDim2.new(0, 200, 0, 50)
	bill.StudsOffset = Vector3.new(0, 6, 0)
	bill.AlwaysOnTop = true
	bill.Parent = c
	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency = 1
	txt.Size = UDim2.new(1, 0, 1, 0)
	txt.Text = "SEU TRATOR"
	txt.Font = Enum.Font.GothamBlack
	txt.TextColor3 = Color3.fromRGB(255, 220, 100)
	txt.TextStrokeTransparency = 0
	txt.TextScaled = true
	txt.Parent = bill

	-- Sound de motor
	local snd = Instance.new("Sound")
	snd.Name = "EngineSound"
	snd.SoundId = Config.TRATOR_ENGINE_SOUND_ID
	snd.Volume = 0.7
	snd.Looped = true
	snd.RollOffMode = Enum.RollOffMode.Linear
	snd.RollOffMinDistance = 5
	snd.RollOffMaxDistance = 80
	snd.Parent = c
	engineSound = snd

	trator = pasta
	print(string.format("[TratorServidor v3] trator montado em %s", tostring(c.Position)))
end

local function updateMovimento(_dt: number)
	if not chassis or not seat then return end
	if not seat.Occupant then
		local v = chassis.AssemblyLinearVelocity
		chassis.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
		chassis.AssemblyAngularVelocity = Vector3.zero
		if engineSound and engineSound.Playing then
			engineSound:Stop()
		end
		return
	end
	if engineSound and not engineSound.Playing then
		engineSound:Play()
	end
	local throttle = seat.Throttle
	local steer = seat.Steer
	local lookDir = chassis.CFrame.LookVector
	local speed = Config.TRATOR_VELOCIDADE_BASE
	chassis.AssemblyLinearVelocity = Vector3.new(
		lookDir.X * speed * throttle,
		chassis.AssemblyLinearVelocity.Y,
		lookDir.Z * speed * throttle
	)
	chassis.AssemblyAngularVelocity = Vector3.new(0, -steer * 2.2, 0)
	-- pitch conforme velocidade
	if engineSound then
		local mag = math.abs(throttle)
		engineSound.PlaybackSpeed = 0.7 + mag * 0.6
	end
end

local function ceifar()
	if not capimServidor or not economia or not chassis or not seat then return end
	if not seat.Occupant then return end
	if chassis.AssemblyLinearVelocity.Magnitude < 0.5 then return end
	-- CORRIGIDO: LookVector aponta pra FRENTE; ceifeira eh a frente do trator
	local frente = chassis.CFrame.Position + chassis.CFrame.LookVector * 5
	local tufos = capimServidor.TufosCrescidosNoRaio(frente, Config.TRATOR_RAIO_CEIFEIRA)
	for _, tufo in tufos do
		local tipoId, ok = capimServidor.Cortar(tufo)
		if ok and tipoId then
			economia.AdicionarAoCarrocao(tipoId, 1)
		end
	end
end

function M.Iniciar()
	local ultimoCorte = 0
	RunService.Heartbeat:Connect(function(dt)
		updateMovimento(dt)
		local agora = os.clock()
		if agora - ultimoCorte >= 0.2 then
			ultimoCorte = agora
			ceifar()
		end
	end)
end

return M
