local PlayerInventoryManager = {}

local Helpers

local game = Game()
local CurrentPlayerStates = {}
local SavedPlayerStates = {}
local PlayersToRestore = {}

local InventoryType = {
    COLLECTIBLE = 1,
    TRINKET = 2,
}
local HasTriggeredStart = false

local ForgottenControllerIndexesToChangeBody = {}


print("-=Commands=-")
print("save: saves the current players states")
print("clear: clears all items from players")
print("saveclear: saves AND clears all current player stats + some extras")
print("restore: restores the previously saved states")


---@param player EntityPlayer
function PlayerInventoryManager.SavePlayerState(player)
    local playerIndex = Helpers.GetPlayerIndex(player)
    local currentPlayerState = CurrentPlayerStates[playerIndex]
    local playerState = {}

    --Position
    playerState.Position = player.Position

    --Player type
    if player:GetPlayerType() == PlayerType.PLAYER_THESOUL then
        playerState.PlayerType = PlayerType.PLAYER_THEFORGOTTEN
        playerState.SoulPosition = player.Position

        for _, forgorBody in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.FORGOTTEN_BODY)) do
            forgorBody = forgorBody:ToFamiliar()
            local owner = forgorBody.Player
            local ownerIndex = Helpers.GetPlayerIndex(owner)

            if ownerIndex == playerIndex then
                playerState.Position = forgorBody.Position
            end
        end
    else
        playerState.PlayerType = player:GetPlayerType()
    end

    --Twins
    if player:GetOtherTwin() then
        playerState.TwinIndex = Helpers.GetPlayerIndex(player:GetOtherTwin())
    end

    --Character gimmicks
    playerState.PoopMana = player:GetPoopMana()
    playerState.SoulCharge = player:GetSoulCharge()
    playerState.BloodCharge = player:GetBloodCharge()

    --Health
    playerState.MaxHearts = player:GetMaxHearts()
    playerState.RedHearts = player:GetHearts()
    playerState.SoulHearts = player:GetSoulHearts()
    playerState.BlackHearts = player:GetBlackHearts()
    playerState.EternalHearts = player:GetEternalHearts()
    playerState.BoneHearts = player:GetBoneHearts()
    playerState.GoldenHearts = player:GetGoldenHearts()
    playerState.RottenHearts = player:GetRottenHearts()
    playerState.BrokenHearts = player:GetBrokenHearts()

    if player:GetSubPlayer() then
        local subPlayer = player:GetSubPlayer()

        playerState.SubMaxHearts = subPlayer:GetMaxHearts()
        playerState.SubRedHearts = subPlayer:GetHearts()
        playerState.SubSoulHearts = subPlayer:GetSoulHearts()
        playerState.SubBlackHearts = subPlayer:GetBlackHearts()
        playerState.SubEternalHearts = subPlayer:GetEternalHearts()
        playerState.SubBoneHearts = subPlayer:GetBoneHearts()
        playerState.SubGoldenHearts = subPlayer:GetGoldenHearts()
        playerState.SubRottenHearts = subPlayer:GetRottenHearts()
        playerState.SubBrokenHearts = subPlayer:GetBrokenHearts()
    end

    --Pickups
    playerState.Coins = player:GetNumCoins()

    playerState.Bombs = player:GetNumBombs()
    playerState.HasGoldenBomb = player:HasGoldenBomb()
    playerState.GigaBombs = player:GetNumGigaBombs()

    playerState.Keys = player:GetNumKeys()
    playerState.HasGoldenKey = player:HasGoldenKey()

    --Blue flies and spiders
    playerState.NumBlueFlies = player:GetNumBlueFlies()
    playerState.NumBlueSpiders = player:GetNumBlueSpiders()

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

    --Active items
    playerState.ActiveItems = {}
    for activeSlot = 3, 0, -1 do
        if player:GetActiveItem(activeSlot) ~= 0 then
            local id = player:GetActiveItem(activeSlot)
            local charge = player:GetActiveCharge(activeSlot)
            local subcharge = player:GetBatteryCharge(activeSlot)

            playerState.ActiveItems[activeSlot] = {id = id, charge = charge, subcharge = subcharge}
        end
    end

    --Held trinkets
    playerState.HoldTrinkets = {}
    for trinketSlot = 1, 0, -1 do
        if player:GetTrinket(trinketSlot) ~= 0 then
            local id = player:GetTrinket(trinketSlot)
            playerState.HoldTrinkets[trinketSlot] = {id = id}
        end
    end

    --Held cards
    playerState.HoldCards = {}
    for cardSlot = 3, 0, -1 do
        if player:GetCard(cardSlot) ~= 0 then
            local id = player:GetCard(cardSlot)
            playerState.HoldCards[cardSlot] = {id = id}
        end
    end

    --Held pills
    playerState.HoldPills = {}
    for pillSlot = 3, 0, -1 do
        if player:GetPill(pillSlot) ~= 0 then
            local id = player:GetPill(pillSlot)
            playerState.HoldPills[pillSlot] = {id = id}
        end
    end

    SavedPlayerStates[playerIndex] = playerState
end


---@param player EntityPlayer
function PlayerInventoryManager.ClearPlayerState(player)
    local playerIndex = Helpers.GetPlayerIndex(player)
    local currentPlayerState = CurrentPlayerStates[playerIndex]

    --Remove character gimmicks
    player:AddPoopMana(-player:GetPoopMana())
    player:AddSoulCharge(-player:GetSoulCharge())
    player:AddBloodCharge(-player:GetBloodCharge())

    --Remove eternal hearts and broken hearts because of jacob/esau
    player:AddEternalHearts(-player:GetEternalHearts())
    player:AddBrokenHearts(-player:GetBrokenHearts())

    --Remove trinkets
    for trinketSlot = 1, 0, -1 do
        if player:GetTrinket(trinketSlot) ~= 0 then
            local id = player:GetTrinket(trinketSlot)
            player:TryRemoveTrinket(id)
        end
    end

    --Remove actives
    for activeSlot = 3, 0, -1 do
        if player:GetActiveItem(activeSlot) ~= 0 then
            local id = player:GetActiveItem(activeSlot)
            player:RemoveCollectible(id, false, activeSlot)
        end
    end

    --Remove pocket items
    for pocketSlot = 1, 0, -1 do
        player:SetCard(pocketSlot, 0)
        player:SetPill(pocketSlot, 0)
    end

    --Remove items
    for _, inventoryItem in ipairs(currentPlayerState.InventoryOrdered) do
        if inventoryItem.type == InventoryType.COLLECTIBLE then
            player:RemoveCollectible(inventoryItem.id)
        else
            player:TryRemoveTrinket(inventoryItem.id)
        end
    end

    --Pick ups
    player:AddCoins(-player:GetNumCoins())

    player:AddBombs(-player:GetNumBombs())
    player:RemoveGoldenBomb()
    player:AddGigaBombs(-player:GetNumGigaBombs())

    player:AddKeys(-player:GetNumKeys())
    player:RemoveGoldenKey()
end


function PlayerInventoryManager.SaveAndClearAllPlayers()
    --First we save all players
    for i = 0, game:GetNumPlayers() - 1, 1 do
        local player = game:GetPlayer(i)
        PlayerInventoryManager.SavePlayerState(player)
    end

    --Then we remove everything they have
    for i = 0, game:GetNumPlayers() - 1, 1 do
        local player = game:GetPlayer(i)
        PlayerInventoryManager.ClearPlayerState(player)
    end

    --Remove all blue flies/spiders
    for _, blueFly in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_FLY)) do
        blueFly:Remove()
    end
    for _, blueSpider in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_SPIDER)) do
        blueSpider:Remove()
    end

    --Finally we change their player type to isaac
    for i = 0, game:GetNumPlayers() - 1, 1 do
        local player = game:GetPlayer(i)
        player:ChangePlayerType(PlayerType.PLAYER_ISAAC)
    end
end


---@param player EntityPlayer
function PlayerInventoryManager.RestorePlayerType(player)
    local playerIndex = Helpers.GetPlayerIndex(player)
    local playerState = SavedPlayerStates[playerIndex]

    --Player type
    player:ChangePlayerType(playerState.PlayerType)

    if playerState.SoulPosition then
        table.insert(ForgottenControllerIndexesToChangeBody, player.ControllerIndex)
    end

    if player:GetOtherTwin() then
        local twin = player:GetOtherTwin()
        local newTwinIndex = Helpers.GetPlayerIndex(twin)
        SavedPlayerStates[newTwinIndex] = SavedPlayerStates[playerState.TwinIndex]
    end
end


---@param player EntityPlayer
function PlayerInventoryManager.RestorePlayerState(player)
    local playerIndex = Helpers.GetPlayerIndex(player)
    local playerState = SavedPlayerStates[playerIndex]

    player.Position = playerState.Position

    --Player gimmicks
    player:AddPoopMana(playerState.PoopMana - player:GetPoopMana())
    player:AddSoulCharge(playerState.SoulCharge - player:GetSoulCharge())
    player:AddBloodCharge(playerState.BloodCharge - player:GetBloodCharge())

    --Inventory
    for _, inventoryItem in ipairs(playerState.Inventory) do
        if inventoryItem.type == InventoryType.COLLECTIBLE then
            player:AddCollectible(inventoryItem.id, 0, false)
        else
            player:AddTrinket(inventoryItem.id)
            player:UseActiveItem(CollectibleType.COLLECTIBLE_SMELTER, UseFlag.USE_NOANIM | UseFlag.USE_NOANNOUNCER)
        end
    end

    for activeSlot, activeItem in pairs(playerState.ActiveItems) do
        if activeSlot == ActiveSlot.SLOT_POCKET or activeSlot == ActiveSlot.SLOT_POCKET2 then
            player:SetPocketActiveItem(activeItem.id, activeSlot, true)
        else
            player:AddCollectible(activeItem.id, 0, false, activeSlot)
        end
        player:SetActiveCharge(activeItem.charge + activeItem.subcharge, activeSlot)
    end

    for trinketSlot = 0, 1, 1 do
        --Do it like this so the trinkets are given in the correct order
        local trinket = playerState.HoldTrinkets[trinketSlot]
        if trinket then
            player:AddTrinket(trinket.id, false)
        end
    end

    for pocketSlot = 3, 0, -1 do
        --Do it like this so they are given in the correct order
        --Yes, its the opposite of what the trinkets does, this game is stupid
        local card = playerState.HoldCards[pocketSlot]
        local pill = playerState.HoldPills[pocketSlot]

        if card then
            player:AddCard(card.id)
        elseif pill then
            player:AddPill(pill.id)
        end
    end

    --Pickups
    player:AddCoins(playerState.Coins - player:GetNumCoins())

    player:AddBombs(playerState.Bombs - player:GetNumBombs())
    if playerState.HasGoldenBomb then player:AddGoldenBomb() end
    player:AddGigaBombs(playerState.GigaBombs - player:GetNumGigaBombs())

    player:AddKeys(playerState.Keys - player:GetNumKeys())
    if playerState.HasGoldenKey then player:AddGoldenKey() end

    --Blue flies and spiders
    player:AddBlueFlies(playerState.NumBlueFlies, player.Position, nil)
    for _ = 1, playerState.NumBlueSpiders, 1 do
        player:AddBlueSpider(player.Position)
    end

    --Health
    player:AddMaxHearts(playerState.MaxHearts - player:GetMaxHearts(), false)
    player:AddHearts(playerState.RedHearts - player:GetHearts())
    player:AddSoulHearts(playerState.SoulHearts - player:GetSoulHearts())
    player:AddBlackHearts(playerState.BlackHearts)
    player:AddEternalHearts(playerState.EternalHearts - player:GetEternalHearts())
    player:AddBoneHearts(playerState.BoneHearts - player:GetBoneHearts())
    player:AddGoldenHearts(playerState.GoldenHearts - player:GetGoldenHearts())
    player:AddRottenHearts(playerState.RottenHearts - player:GetRottenHearts())
    player:AddBrokenHearts(playerState.BrokenHearts - player:GetBrokenHearts())

    if player:GetSubPlayer() then
        local subPlayer = player:GetSubPlayer()

        subPlayer:AddMaxHearts(playerState.SubMaxHearts - subPlayer:GetMaxHearts(), false)
        subPlayer:AddHearts(playerState.SubRedHearts - subPlayer:GetHearts())
        subPlayer:AddSoulHearts(playerState.SubSoulHearts - subPlayer:GetSoulHearts())
        subPlayer:AddBlackHearts(playerState.SubBlackHearts)
        subPlayer:AddEternalHearts(playerState.SubEternalHearts - subPlayer:GetEternalHearts())
        subPlayer:AddBoneHearts(playerState.SubBoneHearts - subPlayer:GetBoneHearts())
        subPlayer:AddGoldenHearts(playerState.SubGoldenHearts - subPlayer:GetGoldenHearts())
        subPlayer:AddRottenHearts(playerState.SubRottenHearts - subPlayer:GetRottenHearts())
        subPlayer:AddBrokenHearts(playerState.SubBrokenHearts - subPlayer:GetBrokenHearts())
    end

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


function PlayerInventoryManager.RestoreAllPlayerStates()
    local restoredPlayers = {}
    local playersLeftToRestore = true

    while playersLeftToRestore do
        playersLeftToRestore = false

        for i = 0, game:GetNumPlayers(), 1 do
            local player = game:GetPlayer(i)
            local playerIndex = Helpers.GetPlayerIndex(player)

            if not restoredPlayers[playerIndex] then
                playersLeftToRestore = true
                restoredPlayers[playerIndex] = true

                PlayerInventoryManager.RestorePlayerType(player)
                table.insert(PlayersToRestore, playerIndex)
            end
        end
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

    if not playerState then
        --If for some reason the current state is nil, initialize it again
        CurrentPlayerStates[playerIndex] = {
            InventoryOrdered = {},
            GulpedTrinkets = {},
            CollectedItems = {}
        }

        playerState = CurrentPlayerStates[playerIndex]
    end

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


function PlayerInventoryManager:OnInput(player, inputHook, buttonAction)
    if buttonAction ~= ButtonAction.ACTION_DROP then return end
    if #ForgottenControllerIndexesToChangeBody == 0 then return end
    if not player or not player:ToPlayer() then return end
    player = player:ToPlayer()

    for index, controller in ipairs(ForgottenControllerIndexesToChangeBody) do
        if player.ControllerIndex == controller then
            player:GetData().RestoreSoulPosition = true
            table.remove(ForgottenControllerIndexesToChangeBody, index)

            if inputHook == InputHook.GET_ACTION_VALUE then
                return 1.0
            else
                return true
            end
        end
    end
end


function PlayerInventoryManager:OnPlayerUpdate(player)
    local playerIndex = Helpers.GetPlayerIndex(player)

    if player:GetData().RestoreSoulPosition then
        local savedState = SavedPlayerStates[playerIndex]

        player.Position = savedState.SoulPosition

        player:GetData().RestoreSoulPosition = nil
    elseif #PlayersToRestore > 0 then
        for index, playerIndexToRestore in ipairs(PlayersToRestore) do
            if playerIndex == playerIndexToRestore then
                PlayerInventoryManager.RestorePlayerState(player)
                table.remove(PlayersToRestore, index)
            end
        end
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
    -- local playerNum = game:GetNumPlayers()
    -- for i = 0, playerNum - 1, 1 do
    --     local player = game:GetPlayer(i)
    --     local playerIndex = player:GetSoulHearts()
    --     local pos = Isaac.WorldToScreen(player.Position)

    --     Isaac.RenderText(playerIndex, pos.X, pos.Y, 1, 1, 1, 255)
    -- end
end


function PlayerInventoryManager:OnCMD(cmd, _)
    if cmd == "save" then
        print("Saving states")
        for i = 0, game:GetNumPlayers() - 1, 1 do
            local player = game:GetPlayer(i)
            PlayerInventoryManager.SavePlayerState(player)
        end
    elseif cmd == "blank" then
        print("Clearing states")
        for i = 0, game:GetNumPlayers() - 1, 1 do
            local player = game:GetPlayer(i)
            PlayerInventoryManager.ClearPlayerState(player)
        end

        for i = 0, game:GetNumPlayers() - 1, 1 do
            local player = game:GetPlayer(i)
            player:ChangePlayerType(PlayerType.PLAYER_ISAAC)
        end
    elseif cmd == "saveclear" then
        print("Saving and clearing states")
        PlayerInventoryManager.SaveAndClearAllPlayers()
    elseif cmd == "restore" then
        print("Restoring saved states")
        PlayerInventoryManager.RestoreAllPlayerStates()
    end
end


function PlayerInventoryManager:Init(mod, helpers)
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, PlayerInventoryManager.OnPeffectUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, PlayerInventoryManager.OnPlayerInit)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, PlayerInventoryManager.OnGameStart)
    mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, PlayerInventoryManager.OnInput)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, PlayerInventoryManager.OnPlayerUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, PlayerInventoryManager.OnRender)
    mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, PlayerInventoryManager.OnCMD)

    Helpers = helpers
end

return PlayerInventoryManager