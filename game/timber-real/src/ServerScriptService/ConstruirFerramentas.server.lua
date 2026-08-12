--[[
	ConstruirFerramentas — dá corpo ao Machado.

	Decisão de pipeline de arte: blockout em CÓDIGO agora (o repo é puro Luau, sem
	rbxmx), mesh Blender/Toolbox depois. O jogador precisa VER um machado na mão
	ao equipar — hoje o Tool não tinha visual (RequiresHandle=false).

	Estratégia mais robusta: montar o Handle+cabeça DENTRO do template que já mora
	no StarterPack. O Roblox distribui o StarterPack pro Backpack de cada player no
	spawn, então basta o template ter o Handle uma vez, no boot, antes de qualquer
	player nascer — todo mundo recebe a cópia com machado. Sem risco de Tool
	duplicado (que aconteceria se a gente também desse um no PlayerAdded).

	// polish: trocar o blockout por mesh via lab-factory-assets.
]]

local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")

local COR_CABO = Color3.fromRGB(120, 82, 52) -- madeira
local COR_CABECA = Color3.fromRGB(150, 154, 158) -- metal

local COMPRIMENTO_CABO = 2.6
local RAIO_CABO = 0.12

--[[
	Monta o Handle (cabo cilíndrico) e solda a cabeça no topo. Devolve o Handle
	já com a cabeça grudada — pronto pra virar filho de um Tool.
]]
local function construirCorpoMachado(): BasePart
	-- cabo = o Handle. Cylinder no Roblox tem o eixo em X: o comprimento vai no X.
	local cabo = Instance.new("Part")
	cabo.Name = "Handle"
	cabo.Shape = Enum.PartType.Cylinder
	cabo.Size = Vector3.new(COMPRIMENTO_CABO, RAIO_CABO * 2, RAIO_CABO * 2)
	cabo.Material = Enum.Material.Wood
	cabo.Color = COR_CABO
	cabo.CanCollide = false
	cabo.CFrame = CFrame.new()

	-- cabeça: cunha metálica soldada numa ponta do cabo (a "ponta de cima").
	local cabeca = Instance.new("Part")
	cabeca.Name = "Cabeca"
	cabeca.Size = Vector3.new(0.9, 1.0, 0.35)
	cabeca.Material = Enum.Material.Metal
	cabeca.Color = COR_CABECA
	cabeca.CanCollide = false
	cabeca.Massless = true
	-- topo do cabo = +X/2. Sobe a cabeça um tico pra ela "coroar" o cabo.
	cabeca.CFrame = cabo.CFrame * CFrame.new(COMPRIMENTO_CABO / 2, 0.15, 0)

	local solda = Instance.new("WeldConstraint")
	solda.Part0 = cabo
	solda.Part1 = cabeca
	solda.Parent = cabo

	cabeca.Parent = cabo
	return cabo
end

--[[
	Garante que um Tool tenha Handle+cabeça e responda a Activated com Handle.
	Idempotente: se já tiver Handle, não faz nada.
]]
local function darCorpo(tool: Tool)
	tool.RequiresHandle = true
	if tool:FindFirstChild("Handle") then
		return
	end
	local corpo = construirCorpoMachado()
	corpo.Parent = tool
	-- grip: aponta o machado pra frente e um pouco pra cima na mão (blockout).
	tool.Grip = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
end

-- 1) o template do StarterPack (fonte que o Roblox clona pro Backpack no spawn)
local machadoTemplate = StarterPack:FindFirstChild("Machado")
if machadoTemplate and machadoTemplate:IsA("Tool") then
	darCorpo(machadoTemplate)
end

-- 2) fallback: se algum lugar clonar o Machado de outra fonte no futuro, deixa
--    um template pronto no ServerStorage pra reaproveitar (não é usado no M0,
--    mas evita reescrever o construtor). Sem custo se ninguém pegar.
do
	local guardado = Instance.new("Tool")
	guardado.Name = "Machado"
	guardado.RequiresHandle = true
	guardado.CanBeDropped = false
	guardado.ToolTip = "Clique num tronco para golpear"
	darCorpo(guardado)
	guardado.Parent = ServerStorage
end
