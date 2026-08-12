--[[
	GestoCliente — grava o MOVIMENTO da lâmina e manda pro servidor.

	O cliente não corta nada: ele descreve o gesto. Quem resolve geometria e
	economia é o servidor (a doc é explícita que CSG no cliente não replica).

	O gesto é uma lista de CFrames — é exatamente o que SweepPartAsync consome
	pra transformar movimento em sólido.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.ConfiguracaoTimber)
local Net = require(ReplicatedStorage.Net)
local GolpeLocal = require(script.Parent.GolpeLocal)

local jogador = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = jogador:GetMouse()

local FERRAMENTA = Config.FerramentaPadraoM0
local ferramenta = Config.Ferramentas[FERRAMENTA]

local AMOSTRAS = 10
local DURACAO_GOLPE = 0.22

local cortando = false

local function mirar()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		jogador.Character,
		workspace:FindFirstChild("Floresta") and workspace.Floresta:FindFirstChild("Detritos"),
	}

	local origem = camera.CFrame.Position
	local direcao = (mouse.Hit.Position - origem)
	if direcao.Magnitude < 0.01 then
		return nil
	end
	return workspace:Raycast(origem, direcao.Unit * (ferramenta.alcance + 20), params)
end

--[[
	Monta o arco do golpe: a lâmina entra no tronco, atravessa uma fatia e sai.
	O arco é construído em torno da normal da superfície atingida — é isso que
	faz o corte acontecer ONDE o jogador mirou.
]]
local function montarArco(resultado)
	local ponto = resultado.Position
	local normal = resultado.Normal

	local eixoLateral = normal:Cross(Vector3.yAxis)
	if eixoLateral.Magnitude < 0.01 then
		eixoLateral = Vector3.xAxis
	end
	eixoLateral = eixoLateral.Unit

	local profundidade = ferramenta.laminaTamanho.X * 1.6
	local largura = ferramenta.laminaTamanho.Y * 0.9

	local cframes = {}
	for i = 1, AMOSTRAS do
		local t = (i - 1) / (AMOSTRAS - 1) -- 0 → 1
		-- entra, mergulha e sai: seno dá o mergulho
		local avanco = (t - 0.5) * 2 * largura
		local mergulho = math.sin(t * math.pi) * profundidade

		local posicao = ponto + eixoLateral * avanco - normal * (mergulho - profundidade * 0.15)

		table.insert(cframes, CFrame.lookAt(posicao, posicao + normal))
	end
	return cframes
end

local function golpear()
	if cortando then
		return
	end
	local resultado = mirar()
	if not resultado or not resultado.Instance then
		return
	end
	if not resultado.Instance:IsDescendantOf(workspace:FindFirstChild("Floresta") or workspace) then
		return
	end

	cortando = true

	-- juice IMEDIATO no ponto que já temos — não espera o servidor (SPEC risco #4).
	GolpeLocal.emitir({
		ponto = resultado.Position,
		normal = resultado.Normal,
		ferramenta = FERRAMENTA,
	})

	Net.GolpeAplicado:FireServer(resultado.Instance, montarArco(resultado), FERRAMENTA)

	task.delay(DURACAO_GOLPE, function()
		cortando = false
	end)
end

-- clique com a ferramenta equipada
local function ligarFerramenta(ferramentaInstancia)
	if ferramentaInstancia:IsA("Tool") then
		ferramentaInstancia.Activated:Connect(golpear)
	end
end

local function ligarPersonagem(personagem)
	personagem.ChildAdded:Connect(ligarFerramenta)
	for _, filho in ipairs(personagem:GetChildren()) do
		ligarFerramenta(filho)
	end
end

if jogador.Character then
	ligarPersonagem(jogador.Character)
end
jogador.CharacterAdded:Connect(ligarPersonagem)

-- atalho de teclado pro spike (não precisa equipar nada)
UserInputService.InputBegan:Connect(function(input, digitando)
	if digitando then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		golpear()
	end
end)
