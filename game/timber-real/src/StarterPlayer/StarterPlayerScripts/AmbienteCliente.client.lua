--[[
	AmbienteCliente — a cama de som de FUNDO da floresta, client-side.

	Um ÚNICO Sound global (2D, parented no SoundService) tocando em loop suave:
	vento/folhas + pássaros (SFX_AMBIENTE_FLORESTA, "Leaves Rustle Wind Blowing
	Through Trees 1", ~76s). Volume BAIXO — é atmosfera, não pode competir com o
	juice do golpe/queda. Começa no spawn e nunca empilha (guard reentrante).

	Robustez (regra do catálogo): o asset é candidato NÃO VERIFICADO. Se falhar em
	carregar, pcall engole e o jogo segue MUDO — nunca trava. Sem som por frame:
	é um Sound persistente, criado uma vez.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Assets = require(ReplicatedStorage:WaitForChild("Catalogo"):WaitForChild("Assets"))

-- volume BAIXO de atmosfera (brief: ~0.15–0.25). Fica embaixo do golpe/queda.
local VOLUME_AMBIENTE = 0.2
-- nome fixo pra garantir "um só": se o script correr de novo (não deveria), a
-- guarda por FindFirstChild impede empilhar duas camadas de vento.
local NOME_SOM = "AmbienteFloresta"

local function iniciarAmbiente()
	-- já existe? não empilha.
	if SoundService:FindFirstChild(NOME_SOM) then
		return
	end

	local rbx = Assets.Rbx("SFX_AMBIENTE_FLORESTA")
	if not rbx then
		return -- catálogo sem a chave: silêncio, sem crash
	end

	-- Sound global (2D): parented no SoundService, sem posição no mundo → toca
	-- igual em qualquer lugar, é a cama de fundo. Looped pra rodar sem emenda.
	local som = Instance.new("Sound")
	som.Name = NOME_SOM
	som.SoundId = rbx
	som.Looped = true
	som.Volume = VOLUME_AMBIENTE
	som.Parent = SoundService

	-- preload pra não entrar com gap/estouro no 1º ciclo; se o asset falhar, o
	-- pcall come a exceção e seguimos (o Play abaixo simplesmente não soa).
	pcall(function()
		ContentProvider:PreloadAsync({ som })
	end)

	pcall(function()
		som:Play()
	end)
end

iniciarAmbiente()
