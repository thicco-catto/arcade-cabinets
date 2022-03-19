local ArcadeCabinetMod = RegisterMod("ArcadeCabinetMod", 1)
local game = Game()
local rng = RNG()

----------------------------------------------
--FANCY REQUIRE (Thanks manaphoenix <3)
----------------------------------------------
local _, err = pcall(require, "")
local modName = err:match("/mods/(.*)/%.lua")
local path = "mods/" .. modName .. "/"

local function loadFile(loc, ...)
    return assert(loadfile(path .. loc .. ".lua"))(...)
end

local ArcadeCabinetVariables = loadFile("scripts/variables")

ArcadeCabinetVariables.TransitionScreen:Load("gfx/minigame_transition.anm2")

--Add this here so it doesn't loop infinitely
ArcadeCabinetVariables.ArcadeCabinetScripts = {
    loadFile("scripts/black_stone_wielder"),
    loadFile("scripts/gush"),
    loadFile("scripts/jumping_coffing"),
    loadFile("scripts/night_light"),
    loadFile("scripts/no_splash"),
    loadFile("scripts/the_blob"),
    loadFile("scripts/the_ground_below"),
    loadFile("scripts/too_underground")
}

local function InitPlayerForMinigame(player)
    local data = player:GetData().ArcadeCabinet

    --Store the previous character
    data.playerType = player:GetPlayerType()

    --Transform them to Isaac
    player:ChangePlayerType(PlayerType.PLAYER_ISAAC)

    --Store their pickups
    data.coins = player:GetNumCoins()
    data.bombs = player:GetNumBombs()
    data.keys = player:GetNumKeys()

    --Remove their pickups
    player:AddCoins(-player:GetNumCoins())
    player:AddBombs(-player:GetNumBombs())
    player:AddKeys(-player:GetNumKeys())

    --Store their trinkets
    data.trinkets = {}
    for i = 1, 0, -1 do
        if player:GetTrinket(i) ~= 0 then 
            Isaac.DebugString("Proceeding")
            data.trinkets[i] = player:GetTrinket(i) 
            player:TryRemoveTrinket(player:GetTrinket(i))
        end
    end

    --Store their active items
    data.activeItems = {}
    data.activeItemsCharges = {}
    for i = 3, 0, -1 do
        if player:GetActiveItem(i) ~= 0 then
            data.activeItems[i] = player:GetActiveItem(i)
            data.activeItemsCharges[i] = player:GetActiveCharge(i)
            player:RemoveCollectible(player:GetActiveItem(i), false, i)
        end
    end

    --Remove their items
    player:FlushQueueItem()
    for i = 1, #data.collectedItemsOrdered, 1 do
        player:RemoveCollectible(tonumber(data.collectedItemsOrdered[i]))
    end
end


local function RestorePlayerFromMinigame(player)
    local data = player:GetData().ArcadeCabinet
    
    for _, item in ipairs(ArcadeCabinetVariables.CurrentScript.startingItems) do
        player:RemoveCollectible(item)
    end

    --Transform them to their old player type
    player:ChangePlayerType(data.playerType)

    --Give their items back
    for i = #data.collectedItemsOrdered, 1, -1 do
        player:AddCollectible(tonumber(data.collectedItemsOrdered[i]))
    end
    
    --Give their active items back
    for slot, item in pairs(data.activeItems) do
        if item then
            player:AddCollectible(item, data.activeItemsCharges[slot], false, slot)
        end
    end

    --Give their trinkets back
    for i = 0, #data.trinkets, 1 do
        if data.trinkets[i] then
            player:AddTrinket(data.trinkets[i])
        end
    end

    --Remove pickups gained from items
    player:AddCoins(-player:GetNumCoins())
    player:AddBombs(-player:GetNumBombs())
    player:AddKeys(-player:GetNumKeys())

    --Remove their pickups
    player:AddCoins(data.coins)
    player:AddBombs(data.bombs)
    player:AddKeys(data.keys)
end


local function InitCabinetMinigame()
    --Set the current state and script
    ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.FADE_IN
    ArcadeCabinetVariables.CurrentScript = ArcadeCabinetVariables.ArcadeCabinetScripts[ArcadeCabinetVariables.CurrentMinigame]
    print(#ArcadeCabinetVariables.ArcadeCabinetScripts)

    --Disable the hud
    game:GetHUD():SetVisible(false)

    --Disable curses
    local level = game:GetLevel()
    ArcadeCabinetVariables.LevelCurses = level:GetCurses()
    level:RemoveCurses(level:GetCurses())

    --Disable controls for everyplayer
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        game:GetPlayer(i).ControlsEnabled = false       
    end

    --Set the transition screen graphics
    ArcadeCabinetVariables.TransitionScreen:ReplaceSpritesheet(0, "gfx/effects/" .. ArcadeCabinetVariables.ArcadeCabinetSprite[ArcadeCabinetVariables.CurrentMinigame])
    ArcadeCabinetVariables.TransitionScreen:ReplaceSpritesheet(1, "gfx/effects/" .. ArcadeCabinetVariables.ArcadeCabinetSprite[ArcadeCabinetVariables.CurrentMinigame])
    ArcadeCabinetVariables.TransitionScreen:LoadGraphics()
    ArcadeCabinetVariables.TransitionScreen:Play("Appear", true)

    --Set options like chargebar and filter
    ArcadeCabinetVariables.OptionsChargeBar = Options.ChargeBars
    ArcadeCabinetVariables.OptionsFilter = Options.Filter

    Options.ChargeBars = false
    Options.Filter = false
end


local function FinishCabinetMinigame()
    --Set the state and transition screen
    ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.FADE_OUT
    ArcadeCabinetVariables.TransitionScreen:Play("Disappear")
    ArcadeCabinetVariables.FadeOutTimer = 20

    --Remove the callbacks for the mod
    for callback, funct in pairs(ArcadeCabinetVariables.CurrentScript.callbacks) do
        ArcadeCabinetMod:RemoveCallback(callback, funct)
    end

    --Teleport the players back through the door
    ArcadeCabinetVariables.MinigameDoor:Open()

    local extraVelocity = nil

    if ArcadeCabinetVariables.MinigameDoor.Direction == Direction.LEFT then
        extraVelocity = Vector(-100, 0)
    elseif ArcadeCabinetVariables.MinigameDoor.Direction == Direction.RIGHT then
        extraVelocity = Vector(100, 0)
    elseif ArcadeCabinetVariables.MinigameDoor.Direction == Direction.UP then
        extraVelocity = Vector(0, -100)
    else
        extraVelocity = Vector(0, 100)
    end

    game:GetPlayer(0).Position = ArcadeCabinetVariables.MinigameDoor.Position
    game:GetPlayer(0):AddVelocity(extraVelocity)

    --Restore the options
    Options.ChargeBars = ArcadeCabinetVariables.OptionsChargeBar
    Options.Filter = ArcadeCabinetVariables.OptionsFilter

    --Restore the players' states
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        RestorePlayerFromMinigame(game:GetPlayer(i))
    end
end


local function DebugRender()
    local itemsintheroom = Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1)
    for _, item in ipairs(itemsintheroom) do
        local pos = Isaac.WorldToScreen(item.Position)

        Isaac.RenderText(item.SubType, pos.X, pos.Y, 1, 1, 1, 255)
        --Isaac.RenderText(Isaac.GetItemConfig():GetCollectible(item.SubType).ID, pos.X, pos.Y + 10, 1, 1, 1, 255)       
    end

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        local data = player:GetData().ArcadeCabinet
        local pos = Isaac.WorldToScreen(player.Position)

        Isaac.RenderText(dump(data.collectedItems), pos.X, pos.Y, 1, 1, 1, 255)
        Isaac.RenderText(dump(data.collectedItemsOrdered), pos.X, pos.Y + 10, 1, 1, 1, 255)
    end
end


local function CheckCollectedItems()
    local roomCollectibles = Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1)

    local aux = {}
    for _, item in ipairs(roomCollectibles) do
        if item.SubType ~= 0 and 
        (Isaac.GetItemConfig():GetCollectible(item.SubType).Type == ItemType.ITEM_PASSIVE or 
        Isaac.GetItemConfig():GetCollectible(item.SubType).Type == ItemType.ITEM_FAMILIAR) then 
            if aux[tostring(item.SubType)] then
                aux[tostring(item.SubType)] = aux[tostring(item.SubType)] + 1
            else
                aux[tostring(item.SubType)] = 1
            end
        end
    end
    roomCollectibles = aux

    local missingItems = {}
    local thereWasMissing = false

    for itemID, val in pairs(ArcadeCabinetVariables.LastRoomCollectibles) do
        if not roomCollectibles[itemID] then --That collectible is not longer in the room
            thereWasMissing = true
            missingItems[itemID] = 1
        elseif roomCollectibles[itemID] < val then --There are less of that collectible
            thereWasMissing = true
            missingItems[itemID] = val - roomCollectibles[itemID]
        end
    end

    if thereWasMissing then
        for itemId, _ in pairs(missingItems) do
            local playerNum = game:GetNumPlayers()

            for i = 0, playerNum - 1, 1 do
                local player = game:GetPlayer(i)
                local data = player:GetData().ArcadeCabinet
                local numCollectible = player:GetCollectibleNum(tonumber(itemId))

                if player.QueuedItem.Item then
                    if player.QueuedItem.Item.ID < 0 and ArcadeCabinetVariables.MAX_ID_TMTRAINER + player.QueuedItem.Item.ID + 1 == tonumber(itemId) or
                     player.QueuedItem.Item.ID == tonumber(itemId) then
                        numCollectible = numCollectible + 1
                    end
                end

                if (data.collectedItems[itemId] or 0) ~= numCollectible then
                    data.collectedItems[itemId] = numCollectible
                    data.collectedItemsOrdered[#data.collectedItemsOrdered+1] = itemId    
                end
            end            
        end
    end

    ArcadeCabinetVariables.LastRoomCollectibles = roomCollectibles
end


function ArcadeCabinetMod:OnArcadeRoom()
    local room = game:GetRoom()

    --It has to be an arcade and first visit
    if room:GetType() ~= RoomType.ROOM_ARCADE or not room:IsFirstVisit() then return end

    --Spawn a cabinet and set its state to idle
    local roomCenter = room:GetCenterPos()
    local freePos = Isaac.GetFreeNearPosition(roomCenter, 25)
    local chosenSubtype = rng:RandomInt(9) + 1
    local CabinetEnt = Isaac.Spawn(6, ArcadeCabinetVariables.ArcadeCabinetVar, chosenSubtype, freePos - Vector(100,100), Vector.Zero, nil)

    CabinetEnt:GetData().init = true
    CabinetEnt:GetData().State = "Idle"
end
ArcadeCabinetMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, ArcadeCabinetMod.OnArcadeRoom)


function ArcadeCabinetMod:OnCabinetUse(player, entity)

    local player = player:ToPlayer()

    if entity.Type ~= 6 or entity.Variant ~= ArcadeCabinetVariables.ArcadeCabinetVar 
    or player:GetNumCoins() < 5  or ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.NOT_PLAYING then return end

    --Remove coins from the player that used the machine
	player:AddCoins(-5)

    --Play the machine animation and play the sound
    entity:GetSprite():Play("Wiggle", true)
    SFXManager():Play(SoundEffect.SOUND_COIN_SLOT, 1, 0, false, math.random(9,11)/10)

    --Set the current minigame
    ArcadeCabinetVariables.CurrentMinigame = entity.SubType

    InitCabinetMinigame()
end
ArcadeCabinetMod:AddCallback(ModCallbacks.MC_PRE_PLAYER_COLLISION, ArcadeCabinetMod.OnCabinetUse)


function ArcadeCabinetMod:OnRender()

    --DebugRender()

    --Only render the screen if it's on fade in or on transition
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.FADE_IN and
    ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.TRANSITION and
    ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.FADE_OUT then return end

    if ArcadeCabinetVariables.TransitionScreen:IsFinished("Appear") then
        ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.TRANSITION
        ArcadeCabinetVariables.TransitionScreen:Play("Idle", true)
        ArcadeCabinetVariables.TransitionFrameCount = game:GetFrameCount()

        --Teleport players to the room
        local roomIndex = ArcadeCabinetVariables.ArcadeCabinetRooms[ArcadeCabinetVariables.CurrentMinigame][1]
        Isaac.ExecuteCommand("goto s.isaacs." .. roomIndex)

        --Change all players to isaac and manage their pickups
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            InitPlayerForMinigame(game:GetPlayer(i))
        end
    elseif ArcadeCabinetVariables.TransitionScreen:IsFinished("Disappear") then
        ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.NOT_PLAYING
        game:GetHUD():SetVisible(true)
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            game:GetPlayer(i).ControlsEnabled = true
        end
    end

    if ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.FADE_OUT and ArcadeCabinetVariables.FadeOutTimer > 0 then
        ArcadeCabinetVariables.FadeOutTimer = ArcadeCabinetVariables.FadeOutTimer - 1

        ArcadeCabinetVariables.TransitionScreen:SetFrame(0)
    end

    ArcadeCabinetVariables.TransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
    ArcadeCabinetVariables.TransitionScreen:Update()
end
ArcadeCabinetMod:AddCallback(ModCallbacks.MC_POST_RENDER, ArcadeCabinetMod.OnRender)


function ArcadeCabinetMod:GetShaderParams(shaderName)

	if shaderName == 'MinigameShader' then
        local isEnabled = 0
        if ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.TRANSITION or 
        ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.PLAYING then isEnabled = 1 end
        local params = { 
                Time = Isaac.GetFrameCount(),
                Amount = "1",
                Enabled = isEnabled
            }
        return params;
    end
end
ArcadeCabinetMod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, ArcadeCabinetMod.GetShaderParams)


function ArcadeCabinetMod:OnFrameUpdate()

    if game:GetFrameCount() == 1 then
		Isaac.Spawn(6, 1984, 1, Vector(100, 150), Vector.Zero, nil)
        Isaac.Spawn(6, 1984, 2, Vector(170, 150), Vector.Zero, nil)
        Isaac.Spawn(6, 1984, 3, Vector(240, 150), Vector.Zero, nil)

        Isaac.Spawn(6, 1984, 4, Vector(400, 150), Vector.Zero, nil)
        Isaac.Spawn(6, 1984, 5, Vector(470, 150), Vector.Zero, nil)
        Isaac.Spawn(6, 1984, 6, Vector(540, 150), Vector.Zero, nil)

        Isaac.Spawn(6, 1984, 7, Vector(100, 250), Vector.Zero, nil)
        Isaac.Spawn(6, 1984, 8, Vector(540, 250), Vector.Zero, nil)
    end

    CheckCollectedItems()

    if ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.PLAYING then
        if ArcadeCabinetVariables.CurrentScript.result ~= nil then
            FinishCabinetMinigame()

            if ArcadeCabinetVariables.CurrentScript.result == ArcadeCabinetVariables.MinigameResult.WIN then
                print("win")
            else
                print("lose")
            end
        else
            ArcadeCabinetVariables.MinigameDoor:Close()
        end
    elseif ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.TRANSITION then

        local room = game:GetRoom()

        if game:GetFrameCount() - ArcadeCabinetVariables.TransitionFrameCount == 2 then
            --If the 2 frames passed we must be in the new room so close doors
            for i = 0, 7, 1 do
                local door = room:GetDoor(i)
                if door then
                    ArcadeCabinetVariables.MinigameDoor = door
                end
            end
        elseif  game:GetFrameCount() - ArcadeCabinetVariables.TransitionFrameCount > 5 and Input.IsActionPressed(ButtonAction.ACTION_ITEM, 0) then
            --If the player presses space we begin playing
            ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.PLAYING

            ArcadeCabinetVariables.CurrentScript:Init()

            for callback, funct in pairs(ArcadeCabinetVariables.CurrentScript.callbacks) do
                ArcadeCabinetMod:AddCallback(callback, funct)
            end
        end
    end
end
ArcadeCabinetMod:AddCallback(ModCallbacks.MC_POST_UPDATE, ArcadeCabinetMod.OnFrameUpdate)


function ArcadeCabinetMod:OnPlayerInit(player)
    --Initialize the custom data table for each player
    player:GetData().ArcadeCabinet = {}
    player:GetData().ArcadeCabinet.collectedItems = {}
    player:GetData().ArcadeCabinet.collectedItemsOrdered = {}
    player:AddCoins(20)

    -- local costume = Isaac.GetCostumeIdByPath("gfx/costumes/bsw_robes.anm2")
    -- player:AddNullCostume(costume)
end
ArcadeCabinetMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, ArcadeCabinetMod.OnPlayerInit)

function ArcadeCabinetMod:OnPlayerUpdate(player)
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.PLAYING then return end
end
ArcadeCabinetMod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, ArcadeCabinetMod.OnPlayerUpdate)


-- function ArcadeCabinetMod:CheckForCabinet()
--     local cabinetExists = Isaac.CountEntities(cabinmod, EntityType.ENTITY_SLOT, Arcade_Cabinet_Var, -1)
--     if cabinetExists > 0 then
--         ArcadeCabinetMod:AddCallback(ModCallbacks.MC_POST_UPDATE, ArcadeCabinetMod.CabinetUpdate)
--         ArcadeCabinetMod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, ArcadeCabinetMod.BreakCabinet)
--     else
--         ArcadeCabinetMod:RemoveCallback(ModCallbacks.MC_POST_UPDATE, ArcadeCabinetMod.CabinetUpdate)
--         ArcadeCabinetMod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, ArcadeCabinetMod.BreakCabinet)
--     end
-- end
-- ArcadeCabinetMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, ArcadeCabinetMod.CheckForCabinet)

-- local animationTime = 0
-- function ArcadeCabinetMod:CabinetUpdate()
--     for i = 1, cabinetExists do
--         cabin_data = CabinetEnt:GetData()
--         --print(CabinetEnt)
--         --print(cabin_data)
--         if cabin_data.State == "Broken" and cabin_data.isBroken == nil then
--             print("broken")
--             cabin_data.isBroken = true
--             CabinetEnt:GetSprite():Play("Death",true)
--         elseif cabin_data.State == "Broken" and cabin_data.isBroken == true then
--             CabinetEnt:GetSprite():SetFrame("Broken", 1)
--         end
--     --print("cabinet detected")
--     end
--     if cabin_data.State ~= "Broken" then
--         for i = 1, game:GetNumPlayers() do
--         local player = Isaac.GetPlayer(i)
        
--             if player.Variant == 0 and player:GetNumCoins() >= 5 and (CabinetEnt.Position - player.Position):Length() < CabinetEnt.Size + player.Size and animationTime < 1 then
--                 animationTime = 31
--                 player:AddCoins(-5)
--                 CabinetEnt:GetSprite():Play("Initiate", true)
--                 sfx:Play(SoundEffect.SOUND_COIN_SLOT, 1, 0, false, 1)
--             end
--             if animationTime > 0 then
--                 CabinetEnt:GetSprite():Play("Idle", true)
--                 animationTime = animationTime - 1
--             end
--         end
--     end
-- end
--     --print(cabinetExists)

-- function ArcadeCabinetMod:BreakCabinet(eff)
-- 	if eff.Variant == EffectVariant.BOMB_EXPLOSION then -- checks if explosion hits
--         local explosionradius = 100*eff.Scale
--         if CabinetEnt and (CabinetEnt.Position - eff.Position):LengthSquared() <= (explosionradius + CabinetEnt.Size) ^ 2 then
--             cabin_data.PositionWhenBreaking = CabinetEnt.Position
--             if cabin_data.State ~= "Broken" then
--                 cabin_data.State = "Broken"
--             end
--         end
-- 	end
-- end






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
      elseif t == 'Color' then
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
      if includes(seen, tostring(o)) then return '(circular)' end
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