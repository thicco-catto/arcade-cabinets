local MinigameManagement = {}
local ArcadeCabinetMod = nil
local ArcadeCabinetVariables = nil
local Cabinet = nil

local CabinetManagement = nil
local PlayerManagement = nil

local game = Game()


---@param machineVariant number
---@return boolean
local function IsModdedVariant(machineVariant)
    for _, variant in pairs(ArcadeCabinetVariables.ArcadeCabinetVariant) do
        if machineVariant == variant then
            return true
        end
    end

    return false
end


---Returns a rng object for a determined cabinet. It is the same everytime for each machine.
---@param cabinet Entity
---@return RNG
local function GetCabinetRNG(cabinet)
    local rng = RNG()
    local level = game:GetLevel()
    local room = game:GetRoom()
    local gridIndex = room:GetGridIndex(cabinet.Position)

    rng:SetSeed(game:GetSeeds():GetStartSeed() + level:GetAbsoluteStage() + level:GetCurrentRoomIndex() + gridIndex, 35)

    return rng
end


---Returns the cabinet entity that was used
---@return Entity
local function FindUsedCabinet()
    for _, cabinet in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        if IsModdedVariant(cabinet.Variant) and
        ArcadeCabinetVariables.CurrentMinigameSeed == GetCabinetRNG(cabinet):GetSeed() then
            return cabinet
        end
    end

    return nil
end


---@param slot Entity
local function UseMachine(slot)
    --Set states and current minigame
    ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.FADE_IN
    ArcadeCabinetVariables.CurrentMinigameResult = nil
    ArcadeCabinetVariables.CurrentMinigame = slot.Variant
    ArcadeCabinetVariables.CurrentScript = ArcadeCabinetVariables.ArcadeCabinetScripts[ArcadeCabinetVariables.CurrentMinigame]
    ArcadeCabinetVariables.IsCurrentMinigameGlitched = slot:GetData().IsGlitched
    ArcadeCabinetVariables.CurrentMinigameSeed = GetCabinetRNG(slot):GetSeed()

    --Set the transition screen graphics
    local path = "gfx/effects/"
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        path = path .. "glitched_"
    end
    path = path .. ArcadeCabinetVariables.ArcadeCabinetSprite[ArcadeCabinetVariables.CurrentMinigame]
    ArcadeCabinetVariables.TransitionScreen:ReplaceSpritesheet(0, path)
    ArcadeCabinetVariables.TransitionScreen:ReplaceSpritesheet(1, path)
    ArcadeCabinetVariables.TransitionScreen:LoadGraphics()
    ArcadeCabinetVariables.TransitionScreen:Play("Appear", true)

    --Disable player controls
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        game:GetPlayer(i).ControlsEnabled = false
    end

    --Visual stuff
    slot:GetSprite():Play("Wiggle", true)
    SFXManager():Play(SoundEffect.SOUND_COIN_SLOT, 1, 0, false, math.random(9,11)/10)
end


---@param player EntityPlayer
function MinigameManagement:OnPlayerUpdate(player)
    --If we started playing we dont need to compute collision
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.NOT_PLAYING then return end
    --If the player has less than 5 coins we dont need to compute collision
    if player:GetNumCoins() < 5 then return end

    for _, slot in pairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        --If has to be one of our machines and it has to be playing the idle animation
        if IsModdedVariant(slot.Variant) and slot:GetSprite():IsPlaying("Idle") then
            --Distance must be less that the hardcoded radius (like this so we dont have to use player collision callback)
            if (player.Position - slot.Position):Length() <= ArcadeCabinetVariables.CABINET_RADIUS then
                player:AddCoins(-5)
                UseMachine(slot)
            end
        end
    end
end


---@param player EntityPlayer
local function InitPlayerForMinigame(player)
    local data = player:GetData().ArcadeCabinet

    --Store the previous character
    data.playerType = player:GetPlayerType()

    --Transform them to Isaac
    player:ChangePlayerType(PlayerType.PLAYER_ISAAC)

    --Store player position
    data.position = player.Position

    --Store their pickups
    data.coins = player:GetNumCoins()
    data.bombs = player:GetNumBombs()
    data.keys = player:GetNumKeys()

    --Remove their pickups
    player:AddCoins(-player:GetNumCoins())
    player:AddBombs(-player:GetNumBombs())
    player:AddKeys(-player:GetNumKeys())

    --TODO: Smelted trinkets
    --TODO: Golden trinkets
    --Store their trinkets
    data.trinkets = {}
    for i = 1, 0, -1 do
        if player:GetTrinket(i) ~= 0 then
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


---@param player EntityPlayer
local function RestorePlayerFromMinigame(player)
    local data = player:GetData().ArcadeCabinet

    --Disable controls while the fade out is happening
    player.ControlsEnabled = false

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

    --Give their pickups back
    player:AddCoins(data.coins)
    player:AddBombs(data.bombs)
    player:AddKeys(data.keys)
end


local function FinishTransitionFadeIn()
    --Set state and transition screen
    ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.TRANSITION
    ArcadeCabinetVariables.TransitionScreen:Play("Idle", true)
    ArcadeCabinetVariables.TransitionFrameCount = game:GetFrameCount()

    --Make hud invisible
    game:GetHUD():SetVisible(false)

    --Teleport players to the room
    local roomIndex = ArcadeCabinetVariables.ArcadeCabinetRooms[ArcadeCabinetVariables.CurrentMinigame]
    Isaac.ExecuteCommand("goto s.isaacs." .. roomIndex)

    --Set options like chargebar and filter
    ArcadeCabinetVariables.OptionsChargeBar = Options.ChargeBars
    ArcadeCabinetVariables.OptionsFilter = Options.Filter
    ArcadeCabinetVariables.OptionsActiveCam = Options.CameraStyle

    Options.ChargeBars = false
    Options.Filter = false
    Options.CameraStyle = 2

    --Prepare all players for the minigame
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        InitPlayerForMinigame(game:GetPlayer(i))
    end
end


local function FinishTransitionFadeOut()
    ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.NOT_PLAYING

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        game:GetPlayer(i).ControlsEnabled = true
    end

    local cabinet = FindUsedCabinet()
    if ArcadeCabinetVariables.CurrentMinigameResult == ArcadeCabinetVariables.MinigameResult.WIN then
        cabinet:GetSprite():Play("Prize", true)
    else
        cabinet:GetSprite():Play("Failure", true)
    end
end


local function RenderTransitionScreen()
    --Only render the screen if it's on fade in or on transition
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.FADE_IN and
    ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.FADE_OUT then return end

    if ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.FADE_OUT and
    ArcadeCabinetVariables.FadeOutTimer > 0 then
        ArcadeCabinetVariables.FadeOutTimer = ArcadeCabinetVariables.FadeOutTimer - 1

        ArcadeCabinetVariables.TransitionScreen:SetFrame(0)
    end

    ArcadeCabinetVariables.TransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)

    --Do this after render so it changes animation after rendering (for when it changes states)
    if ArcadeCabinetVariables.TransitionScreen:IsFinished("Appear") then
        FinishTransitionFadeIn()
    elseif ArcadeCabinetVariables.TransitionScreen:IsFinished("Disappear") then
        FinishTransitionFadeOut()
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

        local a = "false"
        if player.ControlsEnabled then a = "true" end
        Isaac.RenderText(a, pos.X, pos.Y, 1, 1, 1, 255)
        --Isaac.RenderText(dump(data.collectedItems), pos.X, pos.Y, 1, 1, 1, 255)
        --Isaac.RenderText(dump(data.collectedItemsOrdered), pos.X, pos.Y + 10, 1, 1, 1, 255)
    end

    for _, slot in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        local pos = Isaac.WorldToScreen(slot.Position)
        local str = slot:GetDropRNG():GetSeed()
        local str2 = GetCabinetRNG(slot):GetSeed()

        Isaac.RenderText(str, pos.X, pos.Y, 1, 1, 1, 255)
        Isaac.RenderText(str2, pos.X, pos.Y + 10, 1, 1, 1, 255)
    end
end


---@param shaderName string
function MinigameManagement:GetShaderParams(shaderName)
    --Render transition (here so it renders on top of the hud)
    RenderTransitionScreen()

    --DebugRender()

    --Shader stuff
	if shaderName == 'MinigameShader' then
        local params = {
                Time = Isaac.GetFrameCount(),
                Amount = "1",
                Enabled = 0
            }
        return params;
    elseif shaderName == "MinigameShaderV2" then
        local isEnabled = 0
        if ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.TRANSITION or
        ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.PLAYING then isEnabled = 1 end
        local params = { 
            Time = game:GetFrameCount(),
            Enabled = isEnabled
        }
        return params;
    end
end


function MinigameManagement:OnRender()
    DebugRender()

    --Update the animation here because the anm2 and everything is planned to update on render
    --Incredibly shitty but works
    ArcadeCabinetVariables.TransitionScreen:Update()

    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.TRANSITION then return end

    --If its in the transition (Showing the minigame screen) render it here
    --If it was rendering on the shader callback, it'd literally render on top of the shader lmao
    ArcadeCabinetVariables.TransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
end


local function SpawnCabinetReward(cabinet)
    --Choose the item
    print(cabinet)
    local cabinetRng = GetCabinetRNG(cabinet)
    local seed = cabinetRng:RandomInt(999) * 10000 + 10000
    local chosenItem = game:GetItemPool():GetCollectible(ItemPoolType.POOL_CRANE_GAME, false, seed)

    --Spawn the item pedestal
    local pedestal = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, chosenItem, cabinet.Position, Vector.Zero, nilw)

    --Load the appropiate graphics
    local collectibleGfx = Isaac.GetItemConfig():GetCollectible(chosenItem).GfxFileName
    pedestal:GetSprite():Load("gfx/cabinet_collectible_pedestal.anm2", true)
    pedestal:GetSprite():ReplaceSpritesheet(1, collectibleGfx)

    local pedestalGfx = "gfx/slots/" .. ArcadeCabinetVariables.ArcadeCabinetSprite[cabinet.Variant]
    pedestal:GetSprite():ReplaceSpritesheet(5, pedestalGfx)

    pedestal:GetSprite():LoadGraphics()

    --Play the animations
    pedestal:GetSprite():Play("Idle", true)
    pedestal:GetSprite():PlayOverlay("Alternates", true)

    --Set data so we know to set its frame to 0
    pedestal:GetData().ArcadeCabinet = {}
    pedestal:GetData().ArcadeCabinet.IsCabinetReward = true

    --Remove the cabinet
    cabinet:Remove()
end


---@param cabinet Entity
local function OnCabinetUpdate(cabinet)
    local cabinetSpr = cabinet:GetSprite()

    --Check if it should pay out
    if cabinetSpr:IsEventTriggered("Prize") then
        SpawnCabinetReward(cabinet)
        return
    end

    if cabinetSpr:IsFinished("Failure") then
        local anyPlayerHasLuckyFoot = false
        for i = 0, game:GetNumPlayers() - 1, 1 do
            local player = game:GetPlayer(i)
            if player:HasCollectible(CollectibleType.COLLECTIBLE_LUCKY_FOOT) then
                anyPlayerHasLuckyFoot = true
                break
            end
        end

        local cabinetRNG = GetCabinetRNG(cabinet)
        local breakingChance = cabinetRNG:RandomInt(100)
        if breakingChance <= ArcadeCabinetVariables.CHANCE_FOR_CABINET_EXPLODING or
        anyPlayerHasLuckyFoot and breakingChance <= ArcadeCabinetVariables.CHANCE_FOR_CABINET_EXPLODING_LUCKY_FOOT then
            SFXManager():Play(SoundEffect.SOUND_BOSS1_EXPLOSIONS)
            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BOMB_EXPLOSION, 0, cabinet.Position, Vector.Zero, nil)
            cabinetSpr:Play("Death", true)
            cabinet:Die()
        else
            cabinetSpr:Play("Idle", true)
        end
    end

    --If the GridCollisionClass is 5 it means it has been broken
    if cabinet.GridCollisionClass == 5 and not cabinetSpr:IsPlaying("Broken") or
    cabinetSpr:IsFinished("Death") then
        cabinetSpr:Play("Broken")
    end
end


local function IsAnyPlayerPressingStart()
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        if Input.IsActionPressed(ButtonAction.ACTION_ITEM, player.ControllerIndex) then
            return true
        end
    end

    return false
end


local function CheckIfStartMinigame()
    --We only need to run this function if we are on the minigame transition
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.TRANSITION then return end

    --Give the players some time to admire the wonderful transition screen
    if game:GetFrameCount() - ArcadeCabinetVariables.TransitionFrameCount < 20 then return end

    if IsAnyPlayerPressingStart() then
        ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.PLAYING
        ArcadeCabinetVariables.CurrentScript:Init(ArcadeCabinetMod, ArcadeCabinetVariables)
    end
end


local function CheckIfEndMinigame()
    --If we're not playing we can skip this
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.PLAYING then return end

    --If the result is nil the minigame hasnt ended yet
    if not ArcadeCabinetVariables.CurrentMinigameResult then return end

    --Set the state and transition screen
    ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.FADE_OUT
    ArcadeCabinetVariables.TransitionScreen:Play("Disappear")
    ArcadeCabinetVariables.FadeOutTimer = 60

    --Remove the callbacks for the mod
    ArcadeCabinetVariables.CurrentScript:RemoveCallbacks(ArcadeCabinetMod)

    --Set visible hud
    game:GetHUD():SetVisible(true)

    --Teleport the players back through the door
    local room = game:GetRoom()
    local openDoor = nil
    for i = 0, 7, 1 do
        local door = room:GetDoor(i)
        if door then
            openDoor = door
            door:Open()
            break
        end
    end

    local extraVelocity = nil

    if openDoor.Direction == Direction.LEFT then
        extraVelocity = Vector(-100, 0)
    elseif openDoor.Direction == Direction.RIGHT then
        extraVelocity = Vector(100, 0)
    elseif openDoor.Direction == Direction.UP then
        extraVelocity = Vector(0, -100)
    else
        extraVelocity = Vector(0, 100)
    end

    game:GetPlayer(0).Position = openDoor.Position
    game:GetPlayer(0):AddVelocity(extraVelocity)

    --Restore the options
    Options.ChargeBars = ArcadeCabinetVariables.OptionsChargeBar
    Options.Filter = ArcadeCabinetVariables.OptionsFilter
    Options.CameraStyle = ArcadeCabinetVariables.OptionsActiveCam

    --Restore the players' states
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        RestorePlayerFromMinigame(game:GetPlayer(i))
    end

    --Set the restore positions flag for next on new room callback
    ArcadeCabinetVariables.RepositionPlayers = true
end


function MinigameManagement:OnFrameUpdate()
    for _, cabinet in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        if IsModdedVariant(cabinet.Variant) then
            OnCabinetUpdate(cabinet)
        end
    end

    CheckIfStartMinigame()

    CheckIfEndMinigame()

    if ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.PLAYING then
        local room = game:GetRoom()
        for i = 0, 7, 1 do
            local door = room:GetDoor(i)
            if door then
                door:Close(true)
            end
        end
    end
end


---@param player EntityPlayer
function CheckCollectedItems(player)
    local data = player:GetData().ArcadeCabinet
    local itemConfig = Isaac.GetItemConfig()
    ---@type ItemConfigList
    local itemList = itemConfig:GetCollectibles()

    for id = 1, itemList.Size - 1, 1 do
        local item = itemConfig:GetCollectible(id)
        if item and item.Type ~= ItemType.ITEM_ACTIVE then
            local itemId = item.ID
            local collectedItems = data.collectedItems[itemId] or 0
            local collectibleNum = player:GetCollectibleNum(itemId, true)

            if collectibleNum > collectedItems then
                --Player has picked up an item
                data.collectedItems[itemId] = collectibleNum
                table.insert(data.collectedItemsOrdered, itemId)
            elseif collectibleNum < collectedItems then
                --Player has lost an item
                data.collectedItems[itemId] = collectibleNum
                for i = 1, #data.collectedItemsOrdered, 1 do
                    if data.collectedItemsOrdered[i] == itemId then
                        table.remove(data.collectedItemsOrdered, i)
                        break
                    end
                end
            end
        end
    end
end


---@param player EntityPlayer
function MinigameManagement:OnPeffectUpdate(player)
    CheckCollectedItems(player)

    --If we're in transition and the player has controls enabled (because of moving to another room), disable them
    if ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.TRANSITION and player.ControlsEnabled then
        player.ControlsEnabled = false
    end
end


---@param cabinet Entity
local function SetUpCabinet(cabinet)
    local cabinetRng = GetCabinetRNG(cabinet)
    --Do the 10000 thing because the collectible doesnt change for small values
    local seed = cabinetRng:RandomInt(999) * 10000 + 10000
    local chosenCollectible = game:GetItemPool():GetCollectible(ItemPoolType.POOL_CRANE_GAME, false, seed)
    local itemSprite = Isaac.GetItemConfig():GetCollectible(chosenCollectible).GfxFileName
    cabinet:GetSprite():ReplaceSpritesheet(2, itemSprite)

    if cabinetRng:RandomInt(1) < 5 then
        cabinet:GetSprite():ReplaceSpritesheet(1, "gfx/slots/glitched_" .. ArcadeCabinetVariables.ArcadeCabinetSprite[cabinet.Variant])
        cabinet:GetData().IsGlitched = true
    end

    cabinet:GetSprite():LoadGraphics()
end


function MinigameManagement:OnNewRoom()
    --Find all modded cabinets and set them up
    for _, slot in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        if IsModdedVariant(slot.Variant) then
            SetUpCabinet(slot)
        end
    end

    --If the restore positions flag is set, well, do that
    if ArcadeCabinetVariables.RepositionPlayers then
        ArcadeCabinetVariables.RepositionPlayers = false

        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)
            player.Position = player:GetData().ArcadeCabinet.position
        end
    end
end


---@param collectible EntityPickup
function MinigameManagement:OnCollectibleUpdate(collectible)
    if not collectible:GetData().ArcadeCabinet then return end
    if not collectible:GetData().ArcadeCabinet.IsCabinetReward then return end

    collectible:GetSprite():SetOverlayFrame("Alternates", 0)
end


function MinigameManagement:Init(mod, variables, cabinet)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, MinigameManagement.OnPlayerUpdate)
    mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, MinigameManagement.GetShaderParams)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, MinigameManagement.OnRender)
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, MinigameManagement.OnPeffectUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, MinigameManagement.OnNewRoom)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, MinigameManagement.OnFrameUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, MinigameManagement.OnCollectibleUpdate, PickupVariant.PICKUP_COLLECTIBLE)
    ArcadeCabinetMod = mod
    ArcadeCabinetVariables = variables
    Cabinet = cabinet
end


function MinigameManagement:AddOtherManagers(cabinetManager, playerManager)
    CabinetManagement = cabinetManager
    PlayerManagement = playerManager
end


return MinigameManagement