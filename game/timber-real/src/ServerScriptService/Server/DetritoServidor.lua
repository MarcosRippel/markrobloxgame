--[[
	DetritoServidor — os cacos que caem e se amontoam no chão.

	A doc avisa: "the number of small pieces created can be massive ... you need
	a system in place for cleaning up the pieces". Este módulo é esse sistema.

	Ver SPEC § 10.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.ConfiguracaoTimber)

local DetritoServidor = {}

local pasta
local vivos = 0

function DetritoServidor.iniciar(raiz)
	pasta = Instance.new("Folder")
	pasta.Name = "Detritos"
	pasta.Parent = raiz
end

function DetritoServidor.contagem()
	return vivos
end

--[[
	Solta um caco no mundo.
	`dono` recebe network ownership para a física ficar suave do lado de quem cortou.
]]
function DetritoServidor.soltar(caco, dono, impulso)
	if not pasta then
		caco:Destroy()
		return false
	end

	if vivos >= Config.Detrito.CACOS_SIMULTANEOS_MAX then
		-- orçamento estourado: o caco mais novo simplesmente não existe.
		-- Melhor perder um caco do que perder o servidor.
		caco:Destroy()
		return false
	end

	caco.Anchored = false
	caco.CanCollide = true
	caco.Parent = pasta
	vivos += 1

	if dono and dono.Parent then
		pcall(function()
			caco:SetNetworkOwner(dono)
		end)
	end

	if impulso then
		caco:ApplyImpulse(impulso * caco.AssemblyMass)
	end

	Debris:AddItem(caco, Config.Detrito.VIDA_CACO_S)
	caco.Destroying:Connect(function()
		vivos -= 1
	end)

	return true
end

return DetritoServidor
