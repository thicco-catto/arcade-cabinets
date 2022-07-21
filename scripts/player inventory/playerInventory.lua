local PlayerInventoryManager = {}

local Helpers

local game = Game()
local CurrentPlayerStates = {}
local SavedPlayerStates = {}

local InventoryType = {
    COLLECTIBLE = 1,
    TRINKET = 2,
}
local HasTriggeredStart = false


---@param player EntityPlayer
function PlayerInventoryManager.SavePlayerState(player)
    local playerIndex = Helpers.GetPlayerIndex(player)
    local currentPlayerState = CurrentPlayerStates[playerIndex]
    local playerState = {}

    --Player type
    playerState.PlayerType = player:GetPlayerType()

    --Health
    playerState.MaxHearts = player:GetMaxHearts()
    playerState.RedHearts = player:GetHearts()
    playerState.SoulHearts = player:GetSoulHearts()
    playerState.BlackHearts = player:GetBlackHearts()
    playerState.BoneHearts = player:GetBoneHearts()
    playerState.GoldenHearts = player:GetGoldenHearts()
    playerState.RottenHearts = player:GetRottenHearts()
    playerState.BrokenHearts = player:GetBrokenHearts()

    --Pickups
    playerState.Coins = player:GetNumCoins()

    playerState.Bombs = player:GetNumBombs()
    playerState.HasGoldenBomb = player:HasGoldenBomb()
    playerState.GigaBombs = player:GetNumGigaBombs()

    playerState.Keys = player:GetNumKeys()
    playerState.HasGoldenKey = player:HasGoldenKey()

    --Inventory
    playerState.Inventory = {}
    for _, inventoryItem in ipairs(currentPlayerState.InventoryOrdered) do
        table.insert(playerState.Inventory, inventoryItem)
    end
    playerState.CollectedItems = {}
    for itemId, count in pairs(currentPlayerState.CollectedItems) do
        playerState.CollectedItems[itemId] = count
    end
    playerState.GulpedTrinkets = {}
    for trinketId, count in pairs(currentPlayerState.GulpedTrinkets) do
        playerState.GulpedTrinkets[trinketId] = count
    end

    playerState.ActiveItems = {}
    for activeSlot = 3, 0, -1 do
        if player:GetActiveItem(activeSlot) ~= 0 then
            local id = player:GetActiveItem(activeSlot)
            local charge = player:GetActiveCharge(activeSlot)
            local subcharge = player:GetBatteryCharge(activeSlot)

            playerState.ActiveItems[activeSlot] = {id = id, charge = charge, subcharge = subcharge}
        end
    end

    playerState.HoldTrinkets = {}
    for trinketSlot = 1, 0, -1 do
        if player:GetTrinket(trinketSlot) ~= 0 then
            local id = player:GetTrinket(trinketSlot)
            playerState.HoldTrinkets[trinketSlot] = {id = id}
        end
    end

    playerState.HoldCards = {}
    for cardSlot = 1, 0, -1 do
        if player:GetCard(cardSlot) ~= 0 then
            local id = player:GetTrinket(cardSlot)
            playerState.HoldCards[cardSlot] = {id = id}
        end
    end

    playerState.HoldPills = {}
    for pillSlot = 1, 0, -1 do
        if player:GetCard(pillSlot) ~= 0 then
            local id = player:GetPill(pillSlot)
            playerState.HoldPills[pillSlot] = {id = id}
        end
    end

    SavedPlayerStates[playerIndex] = playerState
end


---@param player EntityPlayer
function PlayerInventoryManager.RestorePlayerState(player)
    local playerIndex = Helpers.GetPlayerIndex(player)
    local playerState = SavedPlayerStates[playerIndex]

    --Player type
    player:ChangePlayerType(playerState.PlayerType)

    --Inventory
    for _, inventoryItem in ipairs(playerState.Inventory) do
        if inventoryItem.type == InventoryType.COLLECTIBLE then
            player:AddCollectible(inventoryItem.id, 0, false)
        else
            player:AddTrinket(inventoryItem.id)
            player:UseActiveItem(CollectibleType.COLLECTIBLE_SMELTER, UseFlag.USE_NOANIM | UseFlag.USE_NOANNOUNCER)
        end
    end

    --Health
    player:AddMaxHearts(playerState.MaxHearts - player:GetMaxHearts(), false)
    player:AddHearts(playerState.RedHearts - player:GetHearts())
    player:AddSoulHearts(playerState.SoulHearts - player:GetSoulHearts())
    player:AddBlackHearts(playerState.BlackHearts)
    player:AddBoneHearts(playerState.BoneHearts - player:GetBoneHearts())
    player:AddGoldenHearts(playerState.GoldenHearts - player:GetGoldenHearts())
    player:AddRottenHearts(playerState.RottenHearts - player:GetRottenHearts())
    player:AddBrokenHearts(playerState.BrokenHearts - player:GetBrokenHearts())

    local currentPlayerState = CurrentPlayerStates[playerIndex]
    for _, inventoryItem in ipairs(playerState.Inventory) do
        table.insert(currentPlayerState.InventoryOrdered, inventoryItem)
    end
    for itemId, count in pairs(playerState.CollectedItems) do
        currentPlayerState.CollectedItems[itemId] = count
    end
    for trinketId, count in pairs(playerState.GulpedTrinkets) do
        currentPlayerState.GulpedTrinkets[trinketId] = count
    end
end


local function CheckCollectedItems(player, playerState)
    local itemConfig = Isaac.GetItemConfig()
    local itemList = itemConfig:GetCollectibles()

    --itemList.Size actually returns the last item id, not the actual size
    for id = 1, itemList.Size - 1, 1 do
        local item = itemConfig:GetCollectible(id)
        --Only check for non active items
        if item and item.Type ~= ItemType.ITEM_ACTIVE then
            local itemId = item.ID

            local pastCollectibleNum = playerState.CollectedItems[itemId] or 0
            local actualCollectibleNum = player:GetCollectibleNum(itemId, true)

            if actualCollectibleNum > pastCollectibleNum then
                --If the actual num is bigger than what we had, player has picked up an item
                playerState.CollectedItems[itemId] = actualCollectibleNum
                for _ = 1, actualCollectibleNum - pastCollectibleNum, 1 do
                    table.insert(playerState.InventoryOrdered, {type = InventoryType.COLLECTIBLE, id = itemId})
                end
            elseif actualCollectibleNum < pastCollectibleNum then
                --If the actual num is smaller than what we had, player has lost an item
                playerState.CollectedItems[itemId] = actualCollectibleNum

                for i = 1, #playerState.InventoryOrdered, 1 do
                    local inventoryItem = playerState.InventoryOrdered[i]
                    if inventoryItem.type == InventoryType.COLLECTIBLE and inventoryItem.id == itemId then
                        for _ = 1, pastCollectibleNum - actualCollectibleNum, 1 do
                            table.remove(playerState.InventoryOrdered, i)
                        end
                        break
                    end
                end
            end
        end
    end
end


local function CheckGulpedTrinkets(player, playerState)
    local itemConfig = Isaac.GetItemConfig()
    local trinketList = itemConfig:GetTrinkets()

    --itemList.Size actually returns the last item id, not the actual size
    for id = 1, trinketList.Size - 1, 1 do
        local trinket = itemConfig:GetTrinket(id)
        --Only check for non active items
        if trinket then
            local trinketId = trinket.ID

            local pastGulpedNum = playerState.GulpedTrinkets[trinketId] or 0
            local actualGulpedNum = Helpers.GetSmeltedTrinketMultiplier(player, trinketId)

            if actualGulpedNum > pastGulpedNum then
                --If the actual num is bigger than what we had, player has gulped a trinket
                playerState.GulpedTrinkets[trinketId] = actualGulpedNum

                for _ = 1, actualGulpedNum - pastGulpedNum, 1 do   
                    table.insert(playerState.InventoryOrdered, {type = InventoryType.TRINKET, id = trinketId})
                end
            elseif actualGulpedNum < pastGulpedNum then
                --If the actual num is smaller than what we had, player has lost an item
                playerState.GulpedTrinkets[trinketId] = actualGulpedNum

                for i = 1, #playerState.InventoryOrdered, 1 do
                    local inventoryItem = playerState.InventoryOrdered[i]
                    if inventoryItem.type == InventoryType.TRINKET and inventoryItem.id == trinketId then

                        for _ = 1, pastGulpedNum - actualGulpedNum, 1 do
                            table.remove(playerState.InventoryOrdered, i)
                        end

                        break
                    end
                end
            end
        end
    end
end


function PlayerInventoryManager:OnPeffectUpdate(player)
    if not HasTriggeredStart then return end

    local playerIndex = Helpers.GetPlayerIndex(player)
    local playerState = CurrentPlayerStates[playerIndex]

    CheckCollectedItems(player, playerState)

    CheckGulpedTrinkets(player, playerState)
end


function PlayerInventoryManager:OnPlayerInit(player)
    if not HasTriggeredStart then return end

    local playerIndex = Helpers.GetPlayerIndex(player)

    if not CurrentPlayerStates[playerIndex] then
        CurrentPlayerStates[playerIndex] = {
            InventoryOrdered = {},
            GulpedTrinkets = {},
            CollectedItems = {}
        }
    end
end


function PlayerInventoryManager:OnGameStart(IsContinue)
    HasTriggeredStart = true

    if IsContinue then
        --Load data from save
    else
        --Initialize data
        CurrentPlayerStates = {}
        SavedPlayerStates = {}
    end

    for i = 0, game:GetNumPlayers(), 1 do
        local player = game:GetPlayer(i)
        PlayerInventoryManager:OnPlayerInit(player)
    end
end


function PlayerInventoryManager:OnRender()
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        local playerIndex = Helpers.GetPlayerIndex(player)
        local data = CurrentPlayerStates[playerIndex]
        local pos = Isaac.WorldToScreen(player.Position)

        Isaac.RenderText(dump(data.InventoryOrdered), pos.X, pos.Y, 1, 1, 1, 255)
        Isaac.RenderText(dump(data.CollectedItems), pos.X, pos.Y + 10, 1, 1, 1, 255)
    end
end


function PlayerInventoryManager:OnCMD(cmd, _)
    if cmd == "save" then
        print("Saving states")
        for i = 0, game:GetNumPlayers() - 1, 1 do
            local player = game:GetPlayer(i)
            PlayerInventoryManager.SavePlayerState(player)
        end
    elseif cmd == "restore" then
        print("Restoring saved states")
        for i = 0, game:GetNumPlayers() - 1, 1 do
            local player = game:GetPlayer(i)
            PlayerInventoryManager.RestorePlayerState(player)
        end
    end
end


function PlayerInventoryManager:Init(mod, helpers)
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, PlayerInventoryManager.OnPeffectUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, PlayerInventoryManager.OnPlayerInit)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, PlayerInventoryManager.OnGameStart)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, PlayerInventoryManager.OnRender)
    mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, PlayerInventoryManager.OnCMD)

    Helpers = helpers
end

return PlayerInventoryManager