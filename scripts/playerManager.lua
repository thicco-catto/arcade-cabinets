local PlayerManagement = {}
local ArcadeCabinetVariables

local Cabinet
local Helpers

local CabinetManagement
local MinigameManagement

local game = Game()


---@param player EntityPlayer
function PlayerManagement.InitPlayerForMinigame(player)
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
function PlayerManagement.RestorePlayerFromMinigame(player)
    local data = player:GetData().ArcadeCabinet

    --Disable controls while the fade out is happening
    player.ControlsEnabled = false

    --Transform them to their old player type
    player:ChangePlayerType(data.playerType)

    --Give their items back
    for i = #data.collectedItemsOrdered, 1, -1 do
        print(data.collectedItemsOrdered[i])
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


function PlayerManagement:OnPlayerUpdate(player)
    --If we started playing we dont need to compute collision
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.NOT_PLAYING then return end
    --If the player has less than 5 coins we dont need to compute collision
    if player:GetNumCoins() < 5 then return end

    for _, slot in pairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        --If has to be one of our machines and it has to be playing the idle animation
        if Helpers:IsModdedCabinetVariant(slot.Variant) and slot:GetSprite():IsPlaying("Idle") then
            --Distance must be less that the hardcoded radius (like this so we dont have to use player collision callback)
            if (player.Position - slot.Position):Length() <= ArcadeCabinetVariables.CABINET_RADIUS then
                player:AddCoins(-5)
                MinigameManagement:UseMachine(slot)
            end
        end
    end
end


-- ---@param player EntityPlayer
-- function CheckCollectedItems(player)
--     local data = player:GetData().ArcadeCabinet
--     local itemConfig = Isaac.GetItemConfig()
--     ---@type ItemConfigList
--     local itemList = itemConfig:GetCollectibles()

--     for id = 1, itemList.Size - 1, 1 do
--         local item = itemConfig:GetCollectible(id)
--         if item and item.Type ~= ItemType.ITEM_ACTIVE then
--             local itemId = item.ID
--             local collectedItems = data.collectedItems[itemId] or 0
--             local collectibleNum = player:GetCollectibleNum(itemId, true)

--             if collectibleNum > collectedItems then
--                 --Player has picked up an item
--                 data.collectedItems[itemId] = collectibleNum
--                 table.insert(data.collectedItemsOrdered, itemId)
--                 print(itemId)
--             elseif collectibleNum < collectedItems then
--                 --Player has lost an item
--                 data.collectedItems[itemId] = collectibleNum
--                 for i = 1, #data.collectedItemsOrdered, 1 do
--                     if data.collectedItemsOrdered[i] == itemId then
--                         table.remove(data.collectedItemsOrdered, i)
--                         break
--                     end
--                 end
--             end
--         end
--     end
-- end


---@param player EntityPlayer
function PlayerManagement:OnPeffectUpdate(player)
    --CheckCollectedItems(player)

    --If we're in transition and the player has controls enabled (because of moving to another room), disable them
    if ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.TRANSITION and player.ControlsEnabled then
        player.ControlsEnabled = false
    end
end


--Set up
function PlayerManagement:Init(mod, variables, cabinet, helpers)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, PlayerManagement.OnPlayerUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, PlayerManagement.OnPeffectUpdate)

    ArcadeCabinetVariables = variables
    Cabinet = cabinet
    Helpers = helpers
end


function PlayerManagement:AddOtherManagers(cabinetManager, minigameManager)
    CabinetManagement = cabinetManager
    MinigameManagement = minigameManager
end


return PlayerManagement