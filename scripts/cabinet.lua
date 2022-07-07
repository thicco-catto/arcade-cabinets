local CabinetManagement = {}
local game = Game()
local rng = RNG()

----------------------------------------------
--FANCY REQUIRE (Thanks manaphoenix <3)
----------------------------------------------
local function loadFile(loc, ...)
    local _, err = pcall(require, "")
    local modName = err:match("/mods/(.*)/%.lua")
    local path = "mods/" .. modName .. "/"
    return assert(loadfile(path .. loc .. ".lua"))(...)
end

local ArcadeCabinetVariables = nil

---@param slot Entity
local function UseMachine(slot)
    --Set states and current minigame
    ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.FADE_IN
    ArcadeCabinetVariables.CurrentMinigame = slot.Variant
    ArcadeCabinetVariables.CurrentScript = ArcadeCabinetVariables.ArcadeCabinetScripts[ArcadeCabinetVariables.CurrentMinigame]

    --Set the transition screen graphics
    ArcadeCabinetVariables.TransitionScreen:ReplaceSpritesheet(0, "gfx/effects/" .. ArcadeCabinetVariables.ArcadeCabinetSprite[ArcadeCabinetVariables.CurrentMinigame])
    ArcadeCabinetVariables.TransitionScreen:ReplaceSpritesheet(1, "gfx/effects/" .. ArcadeCabinetVariables.ArcadeCabinetSprite[ArcadeCabinetVariables.CurrentMinigame])
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
function CabinetManagement:OnPlayerUpdate(player)
    --If we started playing we dont need to compute collision
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.NOT_PLAYING then return end
    --If the player has less than 5 coins we dont need to compute collision
    if player:GetNumCoins() < 5 then return end

    for _, slot in pairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        for _, variant in pairs(ArcadeCabinetVariables.ArcadeCabinetVariant) do
            if slot.Variant == variant then
                isModdedMachine = true
                break
            end
        end

        --If it isnt one of our machines we can just skip the rest
        if not isModdedMachine then break end

        if (player.Position - slot.Position):Length() <= ArcadeCabinetVariables.CabinetRadius then
            player:AddCoins(-5)
            UseMachine(slot)
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

    --Change all players to isaac and manage their pickups
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        InitPlayerForMinigame(game:GetPlayer(i))
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
        ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.NOT_PLAYING
        game:GetHUD():SetVisible(true)
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            game:GetPlayer(i).ControlsEnabled = true
        end
    end
end


---@param shaderName string
function CabinetManagement:GetShaderParams(shaderName)
    --Render transition (here so it renders on top of the hud)
    RenderTransitionScreen()
    Isaac.RenderText(ArcadeCabinetVariables.CurrentGameState, 50, 50, 1, 1, 1, 1)

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

    for _, entity in ipairs(Isaac.FindByType(889, 2, 0)) do
        local pos = Isaac.WorldToScreen(entity.Position)
        local color = entity:GetColor()

        Isaac.RenderText(dump(color), pos.X, pos.Y, 1, 1, 1, 255)
    end
end


function CabinetManagement:OnRender()
    DebugRender()

    --Update the animation here because the anm2 and everything is planned to update on render
    --Incredibly shitty but works
    ArcadeCabinetVariables.TransitionScreen:Update()

    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.TRANSITION then return end

    --If its in the transition (Showing the minigame screen) render it here
    --If it was rendering on the shader callback, it'd literally render on top of the shader lmao
    ArcadeCabinetVariables.TransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
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
function CabinetManagement:OnPeffectUpdate(player)
    CheckCollectedItems(player)
end


function CabinetManagement:Init(mod, variables)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, CabinetManagement.OnPlayerUpdate)
    mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, CabinetManagement.GetShaderParams)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, CabinetManagement.OnRender)
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, CabinetManagement.OnPeffectUpdate)
    ArcadeCabinetVariables = variables
end

return CabinetManagement