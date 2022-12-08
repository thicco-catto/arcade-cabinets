if not REPENTANCE then
	print("You must have Repentace to run Arcade Cabinets")
	return
end

local ArcadeCabinetMod = RegisterMod("ArcadeCabinetMod", 1)
local game = Game()

----------------------------------------------
--FANCY REQUIRE (Thanks manaphoenix <3)
----------------------------------------------
local function loadFile(loc, ...)
    local _, err = pcall(require, "")
    local modName = err:match("/mods/(.*)/%.lua")
    local path = "mods/" .. modName .. "/"
    return assert(loadfile(path .. loc .. ".lua"))(...)
end

local ArcadeCabinetVariables = require("arcade_cabinet_scripts/variables")

local Helpers = require("arcade_cabinet_scripts/helpers")
Helpers.Init(ArcadeCabinetVariables)

local PlayerInventory = require("arcade_cabinet_scripts/player inventory/playerInventory")
PlayerInventory:Init(ArcadeCabinetMod, Helpers)

local Cabinet = require("arcade_cabinet_scripts/cabinet")
Cabinet:Init(ArcadeCabinetVariables, Helpers)

local CabinetManagement = require("arcade_cabinet_scripts/cabinetManager")
CabinetManagement:Init(ArcadeCabinetMod, ArcadeCabinetVariables, PlayerInventory, Cabinet, Helpers)

local MinigameManagement = require("arcade_cabinet_scripts/minigameManager")
MinigameManagement:Init(ArcadeCabinetMod, ArcadeCabinetVariables, PlayerInventory, Cabinet, Helpers)

local PlayerManagement = require("arcade_cabinet_scripts/playerManager")
PlayerManagement:Init(ArcadeCabinetMod, ArcadeCabinetVariables, PlayerInventory, Cabinet, Helpers)

CabinetManagement:AddOtherManagers(MinigameManagement, PlayerManagement)
MinigameManagement:AddOtherManagers(CabinetManagement, PlayerManagement)
PlayerManagement:AddOtherManagers(CabinetManagement, MinigameManagement)

local SaveManagement = require("arcade_cabinet_scripts/saveManager")
SaveManagement:Init(ArcadeCabinetMod, ArcadeCabinetVariables, PlayerInventory, Helpers)

local DssCompat = require("arcade_cabinet_scripts/dssCompat")
DssCompat:Init(ArcadeCabinetVariables, SaveManagement)


local function SpawnMachine(variant, pos)
    local machine = Isaac.Spawn(6, variant, 0, pos, Vector.Zero, nil)
    local item = GetRoomItem(ItemPoolType.POOL_CRANE_GAME)
    local itemSprite = Isaac.GetItemConfig():GetCollectible(item).GfxFileName

    machine:GetSprite():ReplaceSpritesheet(2, itemSprite)
    machine:GetSprite():LoadGraphics()
end


function GetRoomItem(defaultPool, AllowActives, MinQuality)
    local pool = game:GetItemPool()
	defaultPool = defaultPool or ItemPoolType.POOL_GOLDEN_CHEST
	MinQuality = MinQuality or 0
	if AllowActives == nil then
    	AllowActives = true
  	end

  	local room = game:GetRoom()
  	local itemType = pool:GetPoolForRoom(room:GetType(), room:GetAwardSeed())
  	itemType = itemType > - 1 and itemType or defaultPool
  	local collectible = pool:GetCollectible(itemType, false)

  	if (not AllowActives or MinQuality > 0) then
    	local itemConfig = config:GetCollectible(collectible)
    	local active = (AllowActives == true) and true or itemConfig.Type == ItemType.ITEM_PASSIVE
    	local quality = true
    	if REPENTANCE then
      		quality = MinQuality == 0 and true or itemConfig.Quality >= MinQuality
    	end
    	while (not quality or not active) do
      		collectible = pool:GetCollectible(itemType, false)
      		itemConfig = config:GetCollectible(collectible)
      		active = (AllowActives == true) and true or itemConfig.Type == ItemType.ITEM_PASSIVE
      		quality = MinQuality == 0 and true or itemConfig.Quality >= MinQuality
    	end
  	end

  	return collectible
end


local floorsAnalyzed = 0
local totalFloorsAnalyzed = 0
local arcadeRooms = 0
local secretRooms = 0
local superSecretRooms = 0
local otherRooms = 0
local totalRooms = 0
local moddedRoomsPerFloors = {}


function ArcadeCabinetMod:OnFrameUpdate()
    if floorsAnalyzed > 0 then
        ArcadeCabinetMod:OnNewLevel()
        Isaac.ExecuteCommand("reseed")
    end
end
ArcadeCabinetMod:AddCallback(ModCallbacks.MC_POST_UPDATE, ArcadeCabinetMod.OnFrameUpdate)


function ArcadeCabinetMod:OnCMD(cmd, args)
    if cmd == "anal" then
        floorsAnalyzed = tonumber(args)
        totalFloorsAnalyzed = tonumber(args)

        arcadeRooms = 0
        secretRooms = 0
        superSecretRooms = 0
        otherRooms = 0
        totalRooms = 0
        moddedRoomsPerFloors = {}
	elseif cmd == "machines" then
		SpawnMachine(ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_BLACKSTONEWIELDER, Vector(100, 150))
        SpawnMachine(ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_GUSH, Vector(170, 150))
        SpawnMachine(ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_HOLYSMOKES, Vector(240, 150))

        SpawnMachine(ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_JUMPINGCOFFING, Vector(400, 150))
        SpawnMachine(ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NIGHTLIGHT, Vector(470, 150))
        SpawnMachine(ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NOSPLASH, Vector(540, 150))

        SpawnMachine(ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_THEGROUNDBELOW, Vector(100, 250))
        SpawnMachine(ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_TOOUNDERGROUND, Vector(540, 250))
	end
end
ArcadeCabinetMod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, ArcadeCabinetMod.OnCMD)


function ArcadeCabinetMod:OnNewLevel()
    local level = game:GetLevel()
    local rooms = level:GetRooms()

    local numModdedRooms = 0

    for i = 0, rooms.Size - 1, 1 do
        local room = rooms:Get(i)
        local roomData = room.Data
        local roomSpawns = roomData.Spawns

        for o = 0, roomSpawns.Size - 1, 1 do
            local spawn = roomSpawns:Get(o)
            local spawnEntry = spawn:PickEntry(0)

            if spawnEntry.Type == EntityType.ENTITY_SLOT and
            (spawnEntry.Variant == ArcadeCabinetVariables.RANDOM_CABINET_VARIANT or
            spawnEntry.Variant == ArcadeCabinetVariables.RANDOM_GLITCH_CABINET_VARIANT or
            Helpers.IsModdedCabinetVariant(spawnEntry.Variant)) then
                numModdedRooms = numModdedRooms + 1

                if roomData.Type == RoomType.ROOM_ARCADE then
                    arcadeRooms = arcadeRooms + 1
                elseif roomData.Type == RoomType.ROOM_SECRET then
                	secretRooms = secretRooms + 1
              	elseif roomData.Type == RoomType.ROOM_SUPERSECRET then
                    superSecretRooms = superSecretRooms + 1
                else
                    otherRooms = otherRooms + 1
                end

                break
            end
        end

        totalRooms = totalRooms + 1
    end

    if moddedRoomsPerFloors[numModdedRooms] then
        moddedRoomsPerFloors[numModdedRooms] = moddedRoomsPerFloors[numModdedRooms] + 1
    else
        moddedRoomsPerFloors[numModdedRooms] = 1
    end

    floorsAnalyzed = floorsAnalyzed - 1

    if floorsAnalyzed == 0 then
        Isaac.ExecuteCommand("clear")
        print(totalFloorsAnalyzed .. " floors were analyzed, out of which:")

        local biggestKey = 0
        for key, _ in pairs(moddedRoomsPerFloors) do
            if key > biggestKey then
                biggestKey = key
            end
        end

        for i = 0, biggestKey, 1 do
            local numFloors = moddedRoomsPerFloors[i]
            if not numFloors then numFloors = 0 end
            local percentage = numFloors / totalFloorsAnalyzed * 100
            print("-" .. numFloors .. " had " .. i .. " modded rooms (" .. percentage .. "%)")
        end

        print("\n")

        local totalModRooms = arcadeRooms + secretRooms + superSecretRooms + otherRooms
        if totalModRooms == 0 then
            print(totalRooms .. " rooms were generated, out of which " .. totalModRooms .. " were modded")
        else
            local modRoomsPercentage = totalModRooms / totalRooms * 100
            print(totalRooms .. " rooms were generated, out of which " .. totalModRooms .. " (".. modRoomsPercentage .."%) were modded, and out of which:")

            local arcadeRoomsPercentage = arcadeRooms / totalModRooms * 100
            print("-" .. arcadeRooms .. " were arcade rooms (" .. arcadeRoomsPercentage .. "%)")

            local secretRoomsPercentage = secretRooms / totalModRooms * 100
            print("-" .. secretRooms .. " were secret rooms (" .. secretRoomsPercentage .. "%)")

			local superSecretRoomsPercentage = superSecretRooms / totalModRooms * 100
            print("-" .. superSecretRooms .. " were super secret rooms (" .. superSecretRoomsPercentage .. "%)")

            local otherRoomsPercentage = otherRooms / totalModRooms * 100
            print("-" .. otherRooms .. " were other type of rooms (" .. otherRoomsPercentage .. "%)")
        end
    end
end


function ArcadeCabinetMod:OnRender()
    if floorsAnalyzed > 0 then
        local x = totalFloorsAnalyzed - floorsAnalyzed
        Isaac.RenderText(x .. "/" .. totalFloorsAnalyzed, 100, 100, 1, 1, 1, 1)
    end
end
ArcadeCabinetMod:AddCallback(ModCallbacks.MC_POST_RENDER, ArcadeCabinetMod.OnRender)


function ArcadeCabinetMod:OnGameStart()
	if MinimapAPI then
		local iconID = "arcade cabinet icon"

		local iconSprite = Sprite()
		iconSprite:Load("gfx/arcade_cabinets_minimap_icon.anm2", true)

		MinimapAPI:AddIcon(iconID, iconSprite, "Idle", 0)

		for _, variant in pairs(ArcadeCabinetVariables.ArcadeCabinetVariant) do
			local cabinetID = ArcadeCabinetVariables.ArcadeCabinetMinimapAPIIconID[variant]

			MinimapAPI:AddPickup(cabinetID, iconID, EntityType.ENTITY_SLOT, variant, nil, MinimapAPI.PickupSlotMachineNotBroken, "slots", 14000 + variant)
		end
	end
end
ArcadeCabinetMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, ArcadeCabinetMod.OnGameStart)


-------
--DUUMPPPPPPPPPPPPPPPPPPPPPPPPPPP
-------
local function shallowCopy(tab)
    return {table.unpack(tab)}
  end
  
  local function includes(tab, val)
    for _, v in pairs(tab) do
      if val == v then return true end
    end
    return false
  end
  
  function dump(o, depth, seen)
    depth = depth or 0
    seen = seen or {}
  
    if depth > 50 then return '' end -- prevent infloops
  
    if type(o) == 'userdata' then -- handle custom isaac types
      if includes(seen, tostring(o)) then return '(circular)' end
      if not getmetatable(o) then return tostring(o) end
      local t = getmetatable(o).__type
  
      if t == 'Entity' or t == 'EntityBomb' or t == 'EntityEffect' or t == 'EntityFamiliar' or t == 'EntityKnife' or t == 'EntityLaser' or t == 'EntityNPC' or t == 'EntityPickup' or t == 'EntityPlayer' or t == 'EntityProjectile' or t == 'EntityTear' then
        return t .. ': ' .. (o.Type or '0') .. '.' .. (o.Variant or '0') .. '.' .. (o.SubType or '0')
      elseif t == 'EntityRef' then
        return t .. ' -> ' .. dump(o.Ref, depth, seen)
      elseif t == 'EntityPtr' then
        return t .. ' -> ' .. dump(o.Entity, depth, seen)
      elseif t == 'GridEntity' or t == 'GridEntityDoor' or t == 'GridEntityPit' or t == 'GridEntityPoop' or t == 'GridEntityPressurePlate' or t == 'GridEntityRock' or t == 'GridEntitySpikes' or t == 'GridEntityTNT' then
        return t .. ': ' .. o:GetType() .. '.' .. o:GetVariant() .. '.' .. o.VarData .. ' at ' .. dump(o.Position, depth, seen)
      elseif t == 'GridEntityDesc' then
        return t .. ' -> ' .. o.Type .. '.' .. o.Variant .. '.' .. o.VarData
      elseif t == 'Vector' then
        return t .. '(' .. o.X .. ', ' .. o.Y .. ')'
      elseif t == 'Color' or t == "const Color" then
        return t .. '(' .. o.R .. ', ' .. o.G .. ', ' .. o.B .. ', ' .. o.RO .. ', ' .. o.GO .. ', ' .. o.BO .. ')'
      elseif t == 'Level' then
        return t .. ': ' .. o:GetName()
      elseif t == 'RNG' then
        return t .. ': ' .. o:GetSeed()
      elseif t == 'Sprite' then
        return t .. ': ' .. o:GetFilename() .. ' - ' .. (o:IsPlaying(o:GetAnimation()) and 'playing' or 'stopped at') .. ' ' .. o:GetAnimation() .. ' f' .. o:GetFrame()
      elseif t == 'TemporaryEffects' then
        local list = o:GetEffectsList()
        local tab = {}
        for i = 0, #list - 1 do
          table.insert(tab, list:Get(i))
        end
        return dump(tab, depth, seen)
      else
        local newt = {}
        for k,v in pairs(getmetatable(o)) do
          if type(k) ~= 'userdata' and k:sub(1, 2) ~= '__' then newt[k] = v end
        end
  
        return 'userdata ' .. dump(newt, depth, seen)
      end
    elseif type(o) == 'table' then -- handle tables
      --if includes(seen, tostring(o)) then return '(circular)' end
      table.insert(seen, tostring(o))
      local s = '{\n'
      local first = true
      for k,v in pairs(o) do
        if not first then
          s = s .. ',\n'
        end
        s = s .. string.rep('  ', depth + 1)
  
        if type(k) ~= 'number' then
          table.insert(seen, tostring(v))
          s = s .. dump(k, depth + 1, shallowCopy(seen)) .. ' = ' .. dump(v, depth + 1, shallowCopy(seen))
        else
          s = s .. dump(v, depth + 1, shallowCopy(seen))
        end
        first = false
      end
      if first then return '{}' end
      return s .. '\n' .. string.rep('  ', depth) .. '}'
    elseif type(o) == 'string' then -- anything else resolves pretty easily
      return '"' .. o .. '"'
    else
      return tostring(o)
    end
  end