--!strict
--[[
	Catalogo.Assets  (parcialmente GERADO por asset_catalog.py)
	---------------------------------------------------------------
	Só IDs públicos do Toolbox. Inserir mesh/model no Studio ainda é
	manual (docs: create.roblox.com/docs/pt-br/projects/assets).
	Som/decal podem usar rbxassetid direto em Sound/Decal.
]]

export type AssetEntry = {
	id: number,
	rbx: string,
	nome: string,
	tipo: string,
	hasScripts: boolean,
}

local Assets: {[string]: AssetEntry} = {
	AUDIO_UI_3_CLICKS_02_HOVER_139719503904449 = { id = 139719503904449, rbx = "rbxassetid://139719503904449", nome = "UI_3_Clicks_02_Hover", tipo = "Audio", hasScripts = false },
	AUDIO_UI_SIMPLE_BUTTON_CLICK_88442833509532 = { id = 88442833509532, rbx = "rbxassetid://88442833509532", nome = "ui-simple-button-click", tipo = "Audio", hasScripts = false },
	AUDIO_COIN_COLLECT_2_SFX_1169806635 = { id = 1169806635, rbx = "rbxassetid://1169806635", nome = "Coin Collect 2 - SFX", tipo = "Audio", hasScripts = false },
	AUDIO_COIN_COLLECT_8646410774 = { id = 8646410774, rbx = "rbxassetid://8646410774", nome = "Coin collect", tipo = "Audio", hasScripts = false },
	AUDIO_BLING_DIAMOND_PICKUP_2_4612374393 = { id = 4612374393, rbx = "rbxassetid://4612374393", nome = "bling_diamond_pickup_2", tipo = "Audio", hasScripts = false },
	AUDIO_YAY_3422389728 = { id = 3422389728, rbx = "rbxassetid://3422389728", nome = "yay", tipo = "Audio", hasScripts = false },
	AUDIO_SWORD_SWING_WHOOSH_SOUND_EFFECT_1__135315310485417 = { id = 135315310485417, rbx = "rbxassetid://135315310485417", nome = "sword-swing-whoosh-sound-effect-1-full-pack", tipo = "Audio", hasScripts = false },
	AUDIO_WHOOSH_SWINGING_SOUND_123796710194563 = { id = 123796710194563, rbx = "rbxassetid://123796710194563", nome = "Whoosh Swinging Sound", tipo = "Audio", hasScripts = false },
	DECAL_SPARKLE_431559365 = { id = 431559365, rbx = "rbxassetid://431559365", nome = "Sparkle", tipo = "Decal", hasScripts = false },
	DECAL_STAR_SPARKLE_PARTICLE_6490035158 = { id = 6490035158, rbx = "rbxassetid://6490035158", nome = "star sparkle particle", tipo = "Decal", hasScripts = false },
	DECAL_STAR_PARTICLE_98450296135718 = { id = 98450296135718, rbx = "rbxassetid://98450296135718", nome = "star particle", tipo = "Decal", hasScripts = false },
	DECAL_GENSHIN_IMPACT_STAR_PARTICLE_5946093990 = { id = 5946093990, rbx = "rbxassetid://5946093990", nome = "Genshin Impact Star Particle", tipo = "Decal", hasScripts = false },
	MESH_PINE_TREE_183435411 = { id = 183435411, rbx = "rbxassetid://183435411", nome = "Pine Tree", tipo = "Model", hasScripts = false },
	MESH_GRASS_BASEPLATE_10100805 = { id = 10100805, rbx = "rbxassetid://10100805", nome = "Grass Baseplate", tipo = "Model", hasScripts = false },
	MESH_GRASS_BASEPLATE_2286648632 = { id = 2286648632, rbx = "rbxassetid://2286648632", nome = "Grass Baseplate", tipo = "Model", hasScripts = false },
	MESH_PINE_TREE_365275430 = { id = 365275430, rbx = "rbxassetid://365275430", nome = "Pine Tree", tipo = "Model", hasScripts = false },
	MESH_HAY_BALE_289410173 = { id = 289410173, rbx = "rbxassetid://289410173", nome = "Hay Bale", tipo = "Model", hasScripts = false },
	MESH_LOW_POLY_TREE_4893246329 = { id = 4893246329, rbx = "rbxassetid://4893246329", nome = "Low Poly Tree", tipo = "Model", hasScripts = false },
	MESH_OLD_OAK_TREE_15799943463 = { id = 15799943463, rbx = "rbxassetid://15799943463", nome = "old oak tree", tipo = "Model", hasScripts = false },
	MESH_LOW_POLY_TREE_3287226226 = { id = 3287226226, rbx = "rbxassetid://3287226226", nome = "Low-Poly Tree.", tipo = "Model", hasScripts = false },
	MESH_OAK_TREE_11672970103 = { id = 11672970103, rbx = "rbxassetid://11672970103", nome = "Oak Tree", tipo = "Model", hasScripts = false },
	MESH_WOOD_FENCE_560487546 = { id = 560487546, rbx = "rbxassetid://560487546", nome = "Wood Fence", tipo = "Model", hasScripts = false },
	MESH_WOOD_FENCE_1414907427 = { id = 1414907427, rbx = "rbxassetid://1414907427", nome = "Wood Fence", tipo = "Model", hasScripts = false },
	MESH_FARM_TRACTOR_3266977232 = { id = 3266977232, rbx = "rbxassetid://3266977232", nome = "Farm Tractor", tipo = "Model", hasScripts = false },
	MESH_COW_3430082667 = { id = 3430082667, rbx = "rbxassetid://3430082667", nome = "cow", tipo = "Model", hasScripts = false },
	MESH_MOOSE_BULL_5035574661 = { id = 5035574661, rbx = "rbxassetid://5035574661", nome = "Moose (Bull)", tipo = "Model", hasScripts = false },
	MESH_COW_7941898086 = { id = 7941898086, rbx = "rbxassetid://7941898086", nome = "cow", tipo = "Model", hasScripts = false },
	MESH_HAY_BALES_5464985431 = { id = 5464985431, rbx = "rbxassetid://5464985431", nome = "Hay-Bales", tipo = "Model", hasScripts = false },
	MESH_BULLS_EYE_TARGET_424110567 = { id = 424110567, rbx = "rbxassetid://424110567", nome = "Bulls-Eye Target", tipo = "Model", hasScripts = false },
	MESH_FARM_TRACTOR_1425786359 = { id = 1425786359, rbx = "rbxassetid://1425786359", nome = "Farm tractor", tipo = "Model", hasScripts = false },
	AUDIO_BENEATH_THE_DREAD_MOON_98165789328752 = { id = 98165789328752, rbx = "rbxassetid://98165789328752", nome = "Beneath the Dread Moon", tipo = "Audio", hasScripts = false },
	AUDIO_HORROR_CINEMATIC_DARK_SCARY_AMBIEN_138890398994853 = { id = 138890398994853, rbx = "rbxassetid://138890398994853", nome = "Horror Cinematic Dark Scary Ambience Spooky", tipo = "Audio", hasScripts = false },
	AUDIO_ALARM_BEEP_PORTAL_2_418308086 = { id = 418308086, rbx = "rbxassetid://418308086", nome = "Alarm Beep [PORTAL 2]", tipo = "Audio", hasScripts = false },
	AUDIO_CAR_ALARM_BEEP_2_96665651845930 = { id = 96665651845930, rbx = "rbxassetid://96665651845930", nome = "Car Alarm Beep 2", tipo = "Audio", hasScripts = false },
	AUDIO_DOOR_CREAK_OPEN_125209584906878 = { id = 125209584906878, rbx = "rbxassetid://125209584906878", nome = "Door Creak Open", tipo = "Audio", hasScripts = false },
	AUDIO_OPEN_DOOR_CREAK_96136915248428 = { id = 96136915248428, rbx = "rbxassetid://96136915248428", nome = "Open Door Creak", tipo = "Audio", hasScripts = false },
	MESH_HOSPITAL_BED_5236086234 = { id = 5236086234, rbx = "rbxassetid://5236086234", nome = "Hospital Bed", tipo = "Model", hasScripts = false },
	MESH_HOSPITAL_BED_13571090371 = { id = 13571090371, rbx = "rbxassetid://13571090371", nome = "Hospital Bed", tipo = "Model", hasScripts = false },
	MESH_CLIPBOARD_FOR_MY_WORKSHOP_DESK_140639097 = { id = 140639097, rbx = "rbxassetid://140639097", nome = "ClipBoard for my Workshop Desk", tipo = "Model", hasScripts = false },
	MESH_PBR_CLIPBOARD_11329271645 = { id = 11329271645, rbx = "rbxassetid://11329271645", nome = "PBR Clipboard", tipo = "Model", hasScripts = false },
	MESH_FINAL_PLZ_10192129020 = { id = 10192129020, rbx = "rbxassetid://10192129020", nome = "final plz", tipo = "MeshPart", hasScripts = false },
	MESH_OFFICE_DESK_6204079308 = { id = 6204079308, rbx = "rbxassetid://6204079308", nome = "Office Desk", tipo = "MeshPart", hasScripts = false },
	MESH_MESHES_MESHPART_7237837062 = { id = 7237837062, rbx = "rbxassetid://7237837062", nome = "Meshes/meshPart", tipo = "MeshPart", hasScripts = false },
	MESH_OPERATING_TABLE_HOSPITAL_MEDICAL_WH_115459625452653 = { id = 115459625452653, rbx = "rbxassetid://115459625452653", nome = "Operating Table Hospital Medical White Interior", tipo = "Model", hasScripts = false },
	MESH_PEMENTA_2454225622 = { id = 2454225622, rbx = "rbxassetid://2454225622", nome = "Pementa", tipo = "MeshPart", hasScripts = false },
	MESH_FRIDAY_NIGHT_FUNKIN_GARCELLO_7034790982 = { id = 7034790982, rbx = "rbxassetid://7034790982", nome = "Friday Night Funkin' Garcello", tipo = "MeshPart", hasScripts = false },
	AUDIO_CLICK_SOUND_138567614125924 = { id = 138567614125924, rbx = "rbxassetid://138567614125924", nome = "Click sound", tipo = "Audio", hasScripts = false },
	AUDIO_UI_LEVEL_UP_112485797063762 = { id = 112485797063762, rbx = "rbxassetid://112485797063762", nome = "UI - Level Up", tipo = "Audio", hasScripts = false },
	AUDIO_LEVEL_UP_3120909354 = { id = 3120909354, rbx = "rbxassetid://3120909354", nome = "Level_up", tipo = "Audio", hasScripts = false },
	DECAL_GLOW_CIRCLE_CROSSHAIR_10891594364 = { id = 10891594364, rbx = "rbxassetid://10891594364", nome = "glow circle crosshair", tipo = "Decal", hasScripts = false },
	DECAL_GLOW_5538771889 = { id = 5538771889, rbx = "rbxassetid://5538771889", nome = "Glow", tipo = "Decal", hasScripts = false },
	MESH_WOODEN_CRATE_182451181 = { id = 182451181, rbx = "rbxassetid://182451181", nome = "Wooden Crate", tipo = "Model", hasScripts = false },
	MESH_BARREL_470360075 = { id = 470360075, rbx = "rbxassetid://470360075", nome = "Barrel", tipo = "Model", hasScripts = false },
	MESH_WOOD_CRATES_3272950683 = { id = 3272950683, rbx = "rbxassetid://3272950683", nome = "Wood Crates", tipo = "Model", hasScripts = false },
	MESH_BARRELS_AND_CRATES_13018691172 = { id = 13018691172, rbx = "rbxassetid://13018691172", nome = "Barrels and Crates", tipo = "Model", hasScripts = false },
}

function Assets.Rbx(idLab: string): string?
	local e = Assets[idLab]
	return if e then e.rbx else nil
end

return Assets
