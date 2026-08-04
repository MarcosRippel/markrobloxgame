--!strict
--[[
	ConfiguracaoFazenda.lua  (ModuleScript em ReplicatedStorage)
	---------------------------------------------------------------
	Tunaveis globais. Mudar valores aqui afeta server e client.
]]

local C = {}

-- ====== Layout global ======
-- Baseline: TERRENO em Y=0. Todas as posicoes estao referenciadas nisso.
-- Layout compacto pra jogador ver tudo do spawn.

-- ====== Grid de capim ======
C.CAMPO_TAMANHO_X = 16                   -- nro de tufos em X
C.CAMPO_TAMANHO_Z = 16                   -- nro de tufos em Z (total: 256 tufos)
C.TUFO_ESPACAMENTO = 5                   -- studs entre tufos (80x80 studs de campo)
C.TUFO_REGROWTH_SEG = {minimo = 8, maximo = 18}
C.CAMPO_CENTRO_OFFSET = Vector3.new(-50, 0, 0)  -- campo A OESTE do spawn

-- ====== Trator ======
C.TRATOR_RAIO_CEIFEIRA = 6
C.TRATOR_VELOCIDADE_BASE = 24
C.TRATOR_POSICAO_INICIAL = Vector3.new(0, 1.5, -10) -- perto do spawn (norte)
C.TRATOR_ENGINE_SOUND_ID = "rbxassetid://131961136"

-- ====== Carrocao ======
C.CARROCAO_CAPACIDADE_BASE = 50

-- ====== Boi ======
C.BOI_QUANTIDADE_NO_CURRAL = 4
C.CURRAL_CENTRO = Vector3.new(35, 1, 0)  -- LESTE do spawn
C.CURRAL_RAIO = 10                       -- menor -> bois visiveis juntos
C.COCHO_POSICAO = Vector3.new(35, 1, -14) -- proximo ao curral, sul
C.COCHO_RAIO_DESCARGA = 14
C.BOI_INTERVALO_RESPAWN_SEG = 0.5

-- ====== Relho ======
C.RELHO_RAIO_ALCANCE = 14
C.RELHO_FORCA_TOQUE = 8

-- ====== Abatedor ======
C.ABATEDOR_ENTRADA = Vector3.new(62, 3, 0)   -- mais leste
C.ABATEDOR_SAIDA = Vector3.new(80, 3, 0)
C.ABATEDOR_TEMPO_PROCESSAMENTO_SEG = 1.5
C.BIFE_TEMPO_ATE_POFF_SEG = {minimo = 0.4, maximo = 1.4}
C.BIFE_QUANTIDADE_BASE = 3

-- ====== Economia ======
C.SALDO_INICIAL = 0

return C
