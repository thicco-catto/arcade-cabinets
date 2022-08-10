local PlayerInventoryManager = {}

local Helpers

local game = Game()
local CurrentPlayerStates = {}
local SavedPlayerStates = {}
local PlayersToRestore = {}
local StrawmansToRestore = {}

local InventoryType = {
    COLLECTIBLE = 1,
    TRINKET = 2,
}
local ShouldSaveAndClearPlayers = false

local ForgottenControllerIndexesToChangeBody = {}
local FlippedLazarusIndexes = {}
local DeadTaintedLazPositions = {}
local TaintedLazBirthRightPlayerIndexes = {}
local TaintedLazToFlip = {}

local TransformItems = {
    SPUN = Isaac.GetItemIdByName("Spun transform"),
    MOM = Isaac.GetItemIdByName("Mom transform"),
    GUPPY = Isaac.GetItemIdByName("Guppy transform"),
    FLY = Isaac.GetItemIdByName("Fly transform"),
    BOB = Isaac.GetItemIdByName("Bob transform"),
    MUSHROOM = Isaac.GetItemIdByName("Mushroom transform"),
    BABY = Isaac.GetItemIdByName("Baby transform"),
    ANGEL = Isaac.GetItemIdByName("Angel transform"),
    DEVIL = Isaac.GetItemIdByName("Devil transform"),
    POOP = Isaac.GetItemIdByName("Poop transform"),
    BOOK = Isaac.GetItemIdByName("Book transform"),
    SPIDER = Isaac.GetItemIdByName("Spider transform"),
}

local CheckCurrentPlayerStates = true

local DontUseFlipOnNextTaintedLaz = false
local DeadTaintedLazWasActive = false


---@param player EntityPlayer
function PlayerInventoryManager.SavePlayerState(player)
    local playerIndex = Helpers.GetPlayerIndex(player)
    local currentPlayerState = CurrentPlayerStates[playerIndex]
    local playerState = {}

    playerState.PlayerData = {}
    playerState.PlayerData = Helpers.CopyTable(playerState.PlayerData, player:GetData())

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

    if player.Parent and player:GetPlayerType() == PlayerType.PLAYER_KEEPER then
        --It should be strawman
        local parentPlayer = player.Parent:ToPlayer()
        local parentIndex = Helpers.GetPlayerIndex(parentPlayer)
        local parentState = SavedPlayerStates[parentIndex]

        if parentState.StrawmansIndexes then
            table.insert(parentState.StrawmansIndexes, playerIndex)
        else
            parentState.StrawmansIndexes = { playerIndex }
        end
    end

    if #DeadTaintedLazPositions > 0 then
        for index, deadTaintedLazPosition in ipairs(DeadTaintedLazPositions) do
            local playerDistanceToLaz = (player.Position - deadTaintedLazPosition):Length()
            local hasToTransformIntoDeadLaz = true

            for i = 0, game:GetNumPlayers() - 1, 1 do
                local playerToCheckDistance = game:GetPlayer(i)
                local playerToCheckDistanceIndex = Helpers.GetPlayerIndex(playerToCheckDistance)

                if playerToCheckDistanceIndex ~= playerIndex then
                    if (playerToCheckDistance.Position - deadTaintedLazPosition):Length() < playerDistanceToLaz then
                        hasToTransformIntoDeadLaz = false
                        break
                    end
                end
            end

            if hasToTransformIntoDeadLaz then
                playerState.WasDeadTaintedLaz = true
                table.remove(DeadTaintedLazPositions, index)
            end
        end
    end

    for n, index in ipairs(TaintedLazBirthRightPlayerIndexes) do
        if index == Helpers.GetPlayerIndex(player) then
            playerState.WasDeadTaintedLaz = true
            table.remove(TaintedLazBirthRightPlayerIndexes, n)
            break
        end
    end

    --Character gimmicks
    playerState.PoopMana = player:GetPoopMana()
    playerState.SoulCharge = player:GetSoulCharge()
    playerState.BloodCharge = player:GetBloodCharge()
    playerState.BerserkCharge = player.SamsonBerserkCharge

    --Health
    playerState.MaxHearts = player:GetMaxHearts()
    playerState.RedHearts = player:GetHearts()
    playerState.SoulHearts = player:GetSoulHearts()
    playerState.BlackHearts = Helpers.CountBits(player:GetBlackHearts())
    if playerState.SoulHearts % 2 == 1 and player:IsBlackHeart(math.ceil(playerState.SoulHearts / 2)) then
        playerState.BlackHearts = playerState.BlackHearts - 1
    end
    playerState.SoulHearts = playerState.SoulHearts - playerState.BlackHearts
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
        playerState.SubBlackHearts = Helpers.CountBits(subPlayer:GetBlackHearts())
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

    --Transformations
    playerState.IsGuppy = player:HasPlayerForm(PlayerForm.PLAYERFORM_GUPPY)
    playerState.IsLordOfFlies = player:HasPlayerForm(PlayerForm.PLAYERFORM_LORD_OF_THE_FLIES)
    playerState.IsFunGuy = player:HasPlayerForm(PlayerForm.PLAYERFORM_MUSHROOM)
    playerState.IsAngel = player:HasPlayerForm(PlayerForm.PLAYERFORM_ANGEL)
    playerState.IsBobby = player:HasPlayerForm(PlayerForm.PLAYERFORM_BOB)
    playerState.IsJunkie = player:HasPlayerForm(PlayerForm.PLAYERFORM_DRUGS)
    playerState.IsMom = player:HasPlayerForm(PlayerForm.PLAYERFORM_MOM)
    playerState.IsBaby = player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY)
    playerState.IsLeviathan = player:HasPlayerForm(PlayerForm.PLAYERFORM_EVIL_ANGEL)
    playerState.IsShit = player:HasPlayerForm(PlayerForm.PLAYERFORM_POOP)
    playerState.IsBookWorm = player:HasPlayerForm(PlayerForm.PLAYERFORM_BOOK_WORM)
    playerState.IsSpiderBaby = player:HasPlayerForm(PlayerForm.PLAYERFORM_SPIDERBABY)

    --Temporary effects
    local playerEffects = player:GetEffects()
    local itemConfig = Isaac.GetItemConfig()

    --Temporary collectible effects
    playerState.CollectibleEffects = {}
    local itemList = itemConfig:GetCollectibles()

    for id = 1, itemList.Size - 1, 1 do
        local item = itemConfig:GetCollectible(id)
        if item then
            local effectNum = playerEffects:GetCollectibleEffectNum(item.ID)
            if effectNum > 0 then
                table.insert(playerState.CollectibleEffects, { id = item.ID, num = effectNum })
            end
        end
    end

    --Temporary null item effects
    playerState.NullItemEffects = {}
    local nullitemList = itemConfig:GetNullItems()

    for id = 1, nullitemList.Size - 1, 1 do
        local nullItem = itemConfig:GetNullItem(id)
        if nullItem and nullItem.Type ~= ItemType.ITEM_ACTIVE then
            local effectNum = playerEffects:GetNullEffectNum(nullItem.ID)
            if effectNum > 0 then
                table.insert(playerState.NullItemEffects, { id = nullItem.ID, num = effectNum })
            end
        end
    end

    --Temporary trinkets effects
    playerState.TrinketEffects = {}
    local trinketList = itemConfig:GetTrinkets()

    for id = 1, trinketList.Size - 1, 1 do
        local trinket = itemConfig:GetTrinket(id)
        if trinket then
            local effectNum = playerEffects:GetTrinketEffectNum(trinket.ID)
            if effectNum > 0 then
                table.insert(playerState.TrinketEffects, { id = trinket.ID, num = effectNum })
            end
        end
    end

    --Dark esaus
    playerState.ExtraDarkEsauNum = 0
    for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_DARK_ESAU, 0)) do
        if entity.SpawnerEntity and Helpers.GetPlayerIndex(entity.SpawnerEntity:ToPlayer()) == playerIndex then
            playerState.ExtraDarkEsauNum = playerState.ExtraDarkEsauNum + 1
        end
    end

    if player:GetPlayerType() == PlayerType.PLAYER_JACOB_B or player:GetPlayerType() == PlayerType.PLAYER_JACOB2_B then
        if player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) then
            playerState.ExtraDarkEsauNum = playerState.ExtraDarkEsauNum - 2
        else
            playerState.ExtraDarkEsauNum = playerState.ExtraDarkEsauNum - 1
        end
    end

    --Track all familiars
    playerState.Familiars = {}
    for _, familiar in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR)) do
        ---@type EntityFamiliar
        familiar = familiar:ToFamiliar()

        if Helpers.GetPlayerIndex(familiar.Player) == playerIndex then
            local variant = familiar.Variant
            local subtype = familiar.SubType
            local position = familiar.Position
            local state = familiar.State
            local coins = familiar.Coins
            local keys = familiar.Keys
            local hearts = familiar.Hearts
            local roomCount = familiar.RoomClearCount
            local data = {}
            Helpers.CopyTable(data, familiar:GetData())

            table.insert(playerState.Familiars, {
                variant = variant,
                subtype = subtype,
                position = position,
                state = state,
                coins = coins,
                keys = keys,
                hearts = hearts,
                roomCount = roomCount,
                data = data
            })
        end
    end

    --Lost soul
    playerState.LostSouls = 0
    for _, familiar in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.LOST_SOUL)) do
        ---@type EntityFamiliar
        familiar = familiar:ToFamiliar()

        if Helpers.GetPlayerIndex(familiar.Player) == playerIndex then
            playerState.LostSouls = playerState.LostSouls + 1
        end
    end

    --Wisps
    playerState.Wisps = {}
    for _, wisp in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.WISP)) do
        local parentIndex = Helpers.GetPlayerIndex(wisp:ToFamiliar().Player)

        if parentIndex == playerIndex then
            local id = wisp.SubType
            local data = {}
            Helpers.CopyTable(data, wisp:GetData())
            table.insert(playerState.Wisps, { subtype = id, data = data })
        end
    end

    playerState.ItemWisps = {}
    for _, itemWisp in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.ITEM_WISP)) do
        local parentIndex = Helpers.GetPlayerIndex(itemWisp:ToFamiliar().Player)

        if parentIndex == playerIndex then
            local id = itemWisp.SubType
            local data = {}
            Helpers.CopyTable(data, itemWisp:GetData())
            table.insert(playerState.ItemWisps, { subtype = id, data = data })
        end
    end

    --Clots
    playerState.Clots = {}
    for _, clot in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLOOD_BABY)) do
        local parentIndex = Helpers.GetPlayerIndex(clot:ToFamiliar().Player)

        if parentIndex == playerIndex then
            local id = clot.SubType
            local hp = clot.HitPoints
            local data = {}
            Helpers.CopyTable(data, clot:GetData())
            table.insert(playerState.Clots, { subtype = id, hp = hp, data = data })
        end
    end

    --Minisaacs
    playerState.Minisaacs = {}
    for _, minisaac in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.MINISAAC)) do
        local parentIndex = Helpers.GetPlayerIndex(minisaac:ToFamiliar().Player)

        if parentIndex == playerIndex then
            local id = minisaac.SubType
            local hp = minisaac.HitPoints
            local data = {}
            Helpers.CopyTable(data, minisaac:GetData())
            table.insert(playerState.Minisaacs, { subtype = id, hp = hp, data = data })
        end
    end

    --Dips
    playerState.Dips = {}
    for _, dip in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.DIP)) do
        local parentIndex = Helpers.GetPlayerIndex(dip:ToFamiliar().Player)

        if parentIndex == playerIndex then
            local id = dip.SubType
            local hp = dip.HitPoints
            local data = {}
            Helpers.CopyTable(data, dip:GetData())
            table.insert(playerState.Dips, { subtype = id, hp = hp, data = data })
        end
    end

    --Locusts
    playerState.Locusts = {}
    for _, locust in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.ABYSS_LOCUST)) do
        local parentIndex = Helpers.GetPlayerIndex(locust:ToFamiliar().Player)

        if parentIndex == playerIndex then
            local id = locust.SubType
            local data = {}
            Helpers.CopyTable(data, locust:GetData())
            table.insert(playerState.Locusts, { subtype = id, data = data })
        end
    end

    --Special blue flies
    playerState.SpecialBlueFlies = {}
    for _, blueFly in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_FLY)) do
        local parentIndex = Helpers.GetPlayerIndex(blueFly:ToFamiliar().Player)

        if parentIndex == playerIndex and blueFly.SubType ~= 0 then
            if playerState.SpecialBlueFlies[blueFly.SubType] then
                playerState.SpecialBlueFlies[blueFly.SubType] = playerState.SpecialBlueFlies[blueFly.SubType] + 1
            else
                playerState.SpecialBlueFlies[blueFly.SubType] = 1
            end
        end
    end

    --Special blue flies
    playerState.SpecialBlueSpiders = {}
    for _, blueSpider in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_SPIDER)) do
        local parentIndex = Helpers.GetPlayerIndex(blueSpider:ToFamiliar().Player)

        if parentIndex == playerIndex and blueSpider.SubType ~= 0 then
            if playerState.SpecialBlueSpiders[blueSpider.SubType] then
                playerState.SpecialBlueSpiders[blueSpider.SubType] = playerState.SpecialBlueSpiders[blueSpider.SubType] +
                    1
            else
                playerState.SpecialBlueSpiders[blueSpider.SubType] = 1
            end
        end
    end

    --Charmed enemies
    playerState.CharmedEnemies = {}
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if entity:ToNPC() and entity:HasEntityFlags(EntityFlag.FLAG_CHARM) and entity.SpawnerEntity:ToPlayer() and
            Helpers.GetPlayerIndex(entity.SpawnerEntity:ToPlayer()) == playerIndex then
            local type = entity.Type
            local variant = entity.Variant
            local subtype = entity.SubType
            local flags = entity:GetEntityFlags()
            local data = {}
            Helpers.CopyTable(data, entity:GetData())

            table.insert(playerState.CharmedEnemies,
                { type = type, variant = variant, subtype = subtype, flags = flags, data = data })
        end
    end

    --Active items
    playerState.ActiveItems = {}
    for activeSlot = 3, 0, -1 do
        if player:GetActiveItem(activeSlot) ~= 0 and
        player:GetActiveItem(activeSlot) ~= CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES then
            local id = player:GetActiveItem(activeSlot)
            local charge = player:GetActiveCharge(activeSlot)
            local subcharge = player:GetBatteryCharge(activeSlot)

            playerState.ActiveItems[activeSlot] = { id = id, charge = charge, subcharge = subcharge }
        end
    end

    --Held trinkets
    playerState.HoldTrinkets = {}
    for trinketSlot = 1, 0, -1 do
        if player:GetTrinket(trinketSlot) ~= 0 then
            local id = player:GetTrinket(trinketSlot)
            playerState.HoldTrinkets[trinketSlot] = { id = id }
        end
    end

    --Held cards
    playerState.HoldCards = {}
    for cardSlot = 3, 0, -1 do
        if player:GetCard(cardSlot) ~= 0 then
            local id = player:GetCard(cardSlot)
            playerState.HoldCards[cardSlot] = { id = id }
        end
    end

    --Held pills
    playerState.HoldPills = {}
    for pillSlot = 3, 0, -1 do
        if player:GetPill(pillSlot) ~= 0 then
            local id = player:GetPill(pillSlot)
            playerState.HoldPills[pillSlot] = { id = id }
        end
    end

    SavedPlayerStates[playerIndex] = playerState
end

---@param player EntityPlayer
function PlayerInventoryManager.ClearPlayerState(player)
    local playerIndex = Helpers.GetPlayerIndex(player)
    local currentPlayerState = CurrentPlayerStates[playerIndex]
    local playerState = SavedPlayerStates[playerIndex]

    --Remove data
    for key, _ in pairs(player:GetData()) do
        player:GetData()[key] = nil
    end

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
            if inventoryItem.id ~= CollectibleType.COLLECTIBLE_STRAW_MAN then
                player:RemoveCollectible(inventoryItem.id)
            end
        else
            player:TryRemoveTrinket(inventoryItem.id)
        end
    end

    --Clear effects
    player:GetEffects():ClearEffects()

    for _, temporaryItem in ipairs(playerState.CollectibleEffects) do
        --Strawmans have this collectible effect so they now when to get removed, so dont remove it
        if temporaryItem.id ~= CollectibleType.COLLECTIBLE_STRAW_MAN then
            player:GetEffects():RemoveCollectibleEffect(temporaryItem.id, temporaryItem.num)
        end
    end

    for _, temporaryItem in ipairs(playerState.NullItemEffects) do
        player:GetEffects():RemoveNullEffect(temporaryItem.id, temporaryItem.num)
    end

    for _, temporaryItem in ipairs(playerState.TrinketEffects) do
        player:GetEffects():RemoveTrinketEffect(temporaryItem.id, temporaryItem.num)
    end

    --Charmed entities
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if entity:ToNPC() and entity:HasEntityFlags(EntityFlag.FLAG_CHARM) then
            entity:Remove()
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

---@param player EntityPlayer
function PlayerInventoryManager.ClearPlayerStateAfterPlayerType(player)
    local playerIndex = Helpers.GetPlayerIndex(player)
    local currentPlayerState = CurrentPlayerStates[playerIndex]
    local playerState = SavedPlayerStates[playerIndex]

    --Familiars that dont get removed with items
    for _, familiar in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR)) do
        ---@type EntityFamiliar
        familiar = familiar:ToFamiliar()

        if Helpers.GetPlayerIndex(familiar.Player) == playerIndex then
            if familiar.Variant == FamiliarVariant.ITEM_WISP then
                --If you dont kill them the item effect stays there
                familiar:Kill()
            else
                familiar:Remove()
            end
        end
    end
end


function PlayerInventoryManager.PreparePlayersForSaveAndClear()
    --Prepare all variables neccesary for saveclear
    StrawmansToRestore = {}
    PlayersToRestore = {}
    ForgottenControllerIndexesToChangeBody = {}
    DeadTaintedLazPositions = {}
    TaintedLazBirthRightPlayerIndexes = {}
    FlippedLazarusIndexes = {}
    TaintedLazToFlip = {}
    CheckCurrentPlayerStates = false

    --Special check for t laz
    for i = 0, game:GetNumPlayers() - 1, 1 do
        local player = game:GetPlayer(i)
        if player:GetPlayerType() == PlayerType.PLAYER_LAZARUS2_B then
            --Check if the player has already been flipped
            for _, index in ipairs(FlippedLazarusIndexes) do
                if Helpers.GetPlayerIndex(player) == index then
                    DontUseFlipOnNextTaintedLaz = true
                    break
                end
            end

            if DontUseFlipOnNextTaintedLaz then
                DontUseFlipOnNextTaintedLaz = false
            else
                table.insert(FlippedLazarusIndexes, Helpers.GetPlayerIndex(player))
                player:UseActiveItem(CollectibleType.COLLECTIBLE_FLIP, UseFlag.USE_NOANIM | UseFlag.USE_NOCOSTUME)

                if player:GetOtherTwin() then
                    table.insert(TaintedLazBirthRightPlayerIndexes, Helpers.GetPlayerIndex(player:GetOtherTwin()))
                else
                    table.insert(DeadTaintedLazPositions, player.Position)
                end
            end
        end

        --Check for t.laz birthright
        if player:GetPlayerType() == PlayerType.PLAYER_LAZARUS_B or player:GetPlayerType() == PlayerType.PLAYER_LAZARUS2_B and
        player:GetOtherTwin() then
            if player:GetPlayerType() == PlayerType.PLAYER_LAZARUS_B then
                if DeadTaintedLazWasActive then
                    DeadTaintedLazWasActive = false
                else
                    DontUseFlipOnNextTaintedLaz = true
                end
            else
                DeadTaintedLazWasActive = true
            end

            for _ = 1, player:GetCollectibleNum(CollectibleType.COLLECTIBLE_BIRTHRIGHT), 1 do
                player:RemoveCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT)
            end

            local twin = player:GetOtherTwin()
            --Double check here
            if twin then
                for _ = 1, twin:GetCollectibleNum(CollectibleType.COLLECTIBLE_BIRTHRIGHT), 1 do
                    twin:RemoveCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT)
                end
            end
        end
    end

    ShouldSaveAndClearPlayers = true
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

    --We remove strawman items here so they dont get removed
    for i = 0, game:GetNumPlayers() - 1, 1 do
        local player = game:GetPlayer(i)
        local strawmanNum = player:GetCollectibleNum(CollectibleType.COLLECTIBLE_STRAW_MAN)

        for _ = 1, strawmanNum, 1 do
            player:RemoveCollectible(CollectibleType.COLLECTIBLE_STRAW_MAN)
        end
    end

    --Finally we change their player type to isaac
    for i = 0, game:GetNumPlayers() - 1, 1 do
        local player = game:GetPlayer(i)

        player:ChangePlayerType(PlayerType.PLAYER_ISAAC)
    end

    --Do the clearing stuff that has to be done after changing players
    for i = 0, game:GetNumPlayers() - 1, 1 do
        local player = game:GetPlayer(i)
        PlayerInventoryManager.ClearPlayerStateAfterPlayerType(player)
    end

    --Reset special flags
    CheckCurrentPlayerStates = true
    DontUseFlipOnNextTaintedLaz = false
    DeadTaintedLazWasActive = false
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
local function AddTransformationItem(player, item)
    for i = 1, 3, 1 do
        player:AddCollectible(item)
        player:RemoveCollectible(item, false, ActiveSlot.SLOT_PRIMARY, false)
    end
end


---@param player EntityPlayer
function PlayerInventoryManager.RestorePlayerState(player)
    local playerIndex = Helpers.GetPlayerIndex(player)
    local playerState = SavedPlayerStates[playerIndex]

    if playerState.SoulPosition then
        for _, forgorBody in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.FORGOTTEN_BODY)) do
            forgorBody = forgorBody:ToFamiliar()
            local owner = forgorBody.Player
            local ownerIndex = Helpers.GetPlayerIndex(owner)

            if ownerIndex == playerIndex then
                forgorBody.Position = playerState.Position
            end
        end

        player.Position = playerState.SoulPosition
    else
        player.Position = playerState.Position
    end

    --Player gimmicks
    player:AddPoopMana(playerState.PoopMana - player:GetPoopMana())
    player:AddSoulCharge(playerState.SoulCharge - player:GetSoulCharge())
    player:AddBloodCharge(playerState.BloodCharge - player:GetBloodCharge())
    player.SamsonBerserkCharge = playerState.BerserkCharge

    --Wisps
    for _, wispData in ipairs(playerState.Wisps) do
        local subtype = wispData.subtype
        local wisp = Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.WISP, subtype, player.Position, Vector.Zero
            , player)
        wisp:ToFamiliar().Player = player

        local data = wispData.data
        for key, value in pairs(data) do
            wisp:GetData()[key] = value
        end
    end

    for _, wispData in ipairs(playerState.ItemWisps) do
        local subtype = wispData.subtype
        local wisp = player:AddItemWisp(subtype, player.Position, true)

        local data = wispData.data
        for key, value in pairs(data) do
            wisp:GetData()[key] = value
        end
    end

    --Clots
    for _, clot in ipairs(playerState.Clots) do
        local clotEntity = Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLOOD_BABY, clot.subtype,
            player.Position, Vector.Zero, player)
        clotEntity:ToFamiliar().Player = player
        clotEntity.HitPoints = clot.hp

        local data = clot.data
        for key, value in pairs(data) do
            clotEntity:GetData()[key] = value
        end
    end

    --Minisaacs
    for _, minisaac in ipairs(playerState.Minisaacs) do
        local minisaacEntity = Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.MINISAAC, minisaac.subtype,
            player.Position, Vector.Zero, player)
        minisaacEntity:ToFamiliar().Player = player
        minisaacEntity.HitPoints = minisaac.hp

        local data = minisaac.data
        for key, value in pairs(data) do
            minisaacEntity:GetData()[key] = value
        end
    end

    --Dips
    for _, dip in ipairs(playerState.Dips) do
        local dipEntity = Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.DIP, dip.subtype, player.Position,
            Vector.Zero, player)
        dipEntity:ToFamiliar().Player = player
        dipEntity.HitPoints = dip.hp

        local data = minisaac.data
        for key, value in pairs(data) do
            minisaacEntity:GetData()[key] = value
        end
    end

    --Locusts
    for _, locustData in ipairs(playerState.Locusts) do
        local subtype = locustData.subtype
        local locust = Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.ABYSS_LOCUST, subtype, player.Position,
            Vector.Zero, player)
        locust:ToFamiliar().Player = player

        local data = locustData.data
        for key, value in pairs(data) do
            minisaacEntity:GetData()[key] = value
        end
    end

    --Special blue flies
    for blueFlySubType, count in pairs(playerState.SpecialBlueFlies) do
        for _ = 1, count, 1 do
            local fly = Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_FLY, blueFlySubType, player.Position
                , Vector.Zero, player)
            fly:ToFamiliar().Player = player
        end
    end

    --Special blue spiders
    for blueSpiderSubType, count in pairs(playerState.SpecialBlueSpiders) do
        for _ = 1, count, 1 do
            local spider = Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_SPIDER, blueSpiderSubType,
                player.Position, Vector.Zero, player)
            spider:ToFamiliar().Player = player
        end
    end

    --Charmed enemies
    for _, charmedEntity in ipairs(playerState.CharmedEnemies) do
        local entity = Isaac.Spawn(charmedEntity.type, charmedEntity.variant, charmedEntity.subtype, player.Position,
            Vector.Zero, player)
        entity:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
        entity:AddEntityFlags(charmedEntity.flags)

        for key, value in pairs(charmedEntity.data) do
            entity:GetData()[key] = value
        end
    end

    --Check for transformations
    if playerState.IsGuppy and not player:HasPlayerForm(PlayerForm.PLAYERFORM_GUPPY) then
        AddTransformationItem(player, TransformItems.GUPPY)
    end

    if playerState.IsLordOfFlies and not player:HasPlayerForm(PlayerForm.PLAYERFORM_LORD_OF_THE_FLIES) then
        AddTransformationItem(player, TransformItems.FLY)
    end

    if playerState.IsFunGuy and not player:HasPlayerForm(PlayerForm.PLAYERFORM_MUSHROOM) then
        AddTransformationItem(player, TransformItems.MUSHROOM)
    end

    if playerState.IsAngel and not player:HasPlayerForm(PlayerForm.PLAYERFORM_ANGEL) then
        AddTransformationItem(player, TransformItems.ANGEL)
    end

    if playerState.IsBobby and not player:HasPlayerForm(PlayerForm.PLAYERFORM_BOB) then
        AddTransformationItem(player, TransformItems.BOB)
    end

    if playerState.IsJunkie and not player:HasPlayerForm(PlayerForm.PLAYERFORM_DRUGS) then
        AddTransformationItem(player, TransformItems.SPUN)
    end

    if playerState.IsMom and not player:HasPlayerForm(PlayerForm.PLAYERFORM_MOM) then
        AddTransformationItem(player, TransformItems.MOM)
    end

    if playerState.IsBaby and not player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY) then
        AddTransformationItem(player, TransformItems.BABY)
    end

    if playerState.IsLeviathan and not player:HasPlayerForm(PlayerForm.PLAYERFORM_EVIL_ANGEL) then
        AddTransformationItem(player, TransformItems.DEVIL)
    end

    if playerState.IsShit and not player:HasPlayerForm(PlayerForm.PLAYERFORM_POOP) then
        AddTransformationItem(player, TransformItems.POOP)
    end

    if playerState.IsBookWorm and not player:HasPlayerForm(PlayerForm.PLAYERFORM_BOOK_WORM) then
        AddTransformationItem(player, TransformItems.BOOK)
    end

    if playerState.IsSpiderBaby and not player:HasPlayerForm(PlayerForm.PLAYERFORM_SPIDERBABY) then
        AddTransformationItem(player, TransformItems.SPIDER)
    end

    --Inventory
    for _, inventoryItem in ipairs(playerState.Inventory) do
        if inventoryItem.type == InventoryType.COLLECTIBLE then
            player:AddCollectible(inventoryItem.id, 0, false)

            if inventoryItem.id == CollectibleType.COLLECTIBLE_STRAW_MAN then
                if StrawmansToRestore[playerIndex] then
                    StrawmansToRestore[playerIndex] = StrawmansToRestore[playerIndex] + 1
                else
                    StrawmansToRestore[playerIndex] = 1
                end
            end
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

    --Temporary effects
    local playerEffects = player:GetEffects()

    for _, temporaryItem in ipairs(playerState.CollectibleEffects) do
        local difference = temporaryItem.num - playerEffects:GetCollectibleEffectNum(temporaryItem.id)

        if difference > 0 then
            playerEffects:AddCollectibleEffect(temporaryItem.id, true, difference)
        elseif difference < 0 then
            playerEffects:RemoveCollectibleEffect(temporaryItem.id, math.abs(difference))
        end
    end

    for _, temporaryItem in ipairs(playerState.NullItemEffects) do
        local difference = temporaryItem.num - playerEffects:GetNullEffectNum(temporaryItem.id)

        if difference > 0 then
            playerEffects:AddNullEffect(temporaryItem.id, true, difference)
        elseif difference < 0 then
            --Dont remove the jacobs curse, or else dark esau wont spawn
            if temporaryItem.id ~= NullItemID.ID_JACOBS_CURSE then
                playerEffects:RemoveNullEffect(temporaryItem.id, math.abs(difference))
            end
        end
    end

    for _, temporaryItem in ipairs(playerState.TrinketEffects) do
        local difference = temporaryItem.num - playerEffects:GetTrinketEffectNum(temporaryItem.id)

        if difference > 0 then
            playerEffects:AddTrinketEffect(temporaryItem.id, false, difference)
        elseif difference < 0 then
            playerEffects:RemoveTrinketEffect(temporaryItem.id, math.abs(difference))
        end
    end

    --Dark esaus
    for _ = 1, playerState.ExtraDarkEsauNum, 1 do
        Isaac.Spawn(EntityType.ENTITY_DARK_ESAU, 0, 0, game:GetRoom():GetCenterPos(), Vector.Zero, player)
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
    local actualSoulHeartsNum = player:GetSoulHearts()
    local actualBlackHeartsNum = Helpers.CountBits(player:GetBlackHearts())
    if actualSoulHeartsNum % 2 == 1 and player:IsBlackHeart(math.ceil(actualSoulHeartsNum / 2)) then
        actualBlackHeartsNum = actualBlackHeartsNum - 1
    end
    actualSoulHeartsNum = actualSoulHeartsNum - actualBlackHeartsNum

    player:AddMaxHearts(playerState.MaxHearts - player:GetMaxHearts(), false)
    player:AddHearts(playerState.RedHearts - player:GetHearts())
    player:AddSoulHearts(playerState.SoulHearts - actualSoulHeartsNum)
    player:AddBlackHearts(playerState.BlackHearts - actualBlackHeartsNum)
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
        subPlayer:AddBlackHearts(playerState.SubBlackHearts - Helpers.CountBits(subPlayer:GetBlackHearts()))
        subPlayer:AddEternalHearts(playerState.SubEternalHearts - subPlayer:GetEternalHearts())
        subPlayer:AddBoneHearts(playerState.SubBoneHearts - subPlayer:GetBoneHearts())
        subPlayer:AddGoldenHearts(playerState.SubGoldenHearts - subPlayer:GetGoldenHearts())
        subPlayer:AddRottenHearts(playerState.SubRottenHearts - subPlayer:GetRottenHearts())
        subPlayer:AddBrokenHearts(playerState.SubBrokenHearts - subPlayer:GetBrokenHearts())
    end

    if playerState.WasDeadTaintedLaz then
        table.insert(TaintedLazToFlip, playerIndex)
    end

    player:RespawnFamiliars()

    --Check correctly spawned familiars
    for _, familiar in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR)) do
        ---@type EntityFamiliar
        familiar = familiar:ToFamiliar()

        if Helpers.GetPlayerIndex(familiar.Player) == playerIndex then
            for index, familiarData in ipairs(playerState.Familiars) do
                if familiar.Variant == familiarData.variant and familiar.SubType == familiarData.subtype then
                    familiar.Coins = familiarData.coins
                    familiar.Keys = familiarData.keys
                    familiar.Hearts = familiarData.hearts
                    familiar.RoomClearCount = familiarData.roomCount
                    familiar.State = familiarData.state
                    local data = familiarData.data

                    for key, value in pairs(data) do
                        familiar:GetData()[key] = value
                    end

                    familiar:GetData().HasAlreadyBeenRestored = true

                    table.remove(playerState.Familiars, index)
                    break
                end
            end
        end
    end

    --Assume that familiars with the same variant but different subtype are the same
    for _, familiar in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR)) do
        ---@type EntityFamiliar
        familiar = familiar:ToFamiliar()

        if Helpers.GetPlayerIndex(familiar.Player) == playerIndex and not familiar:GetData().HasAlreadyBeenRestored then
            for index, familiarData in ipairs(playerState.Familiars) do
                if familiar.Variant == familiarData.variant then
                    familiar.Coins = familiarData.coins
                    familiar.Keys = familiarData.keys
                    familiar.Hearts = familiarData.hearts
                    familiar.RoomClearCount = familiarData.roomCount
                    familiar.State = familiarData.state
                    local data = familiarData.data

                    for key, value in pairs(data) do
                        familiar:GetData()[key] = value
                    end

                    familiar:GetData().HasAlreadyBeenRestored = true

                    table.remove(playerState.Familiars, index)
                    break
                end
            end
        end
    end

    --Spawn remaining familiars
    for _, familiarData in ipairs(playerState.Familiars) do
        local variant = familiarData.variant
        local subtype = familiarData.subtype

        local familiar = Isaac.Spawn(EntityType.ENTITY_FAMILIAR, variant, subtype, player.Position, Vector.Zero, player)
        ---@type EntityFamiliar
        familiar = familiar:ToFamiliar()

        familiar.Player = player

        familiar.Coins = familiarData.coins
        familiar.Keys = familiarData.keys
        familiar.Hearts = familiarData.hearts
        familiar.RoomClearCount = familiarData.roomCount
        familiar.State = familiarData.state
        local data = familiarData.data

        for key, value in pairs(data) do
            familiar:GetData()[key] = value
        end

        familiar:GetData().HasAlreadyBeenRestored = true
    end

    --Remove remaining familiars that arent on the list
    for _, familiar in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR)) do
        ---@type EntityFamiliar
        familiar = familiar:ToFamiliar()

        if Helpers.GetPlayerIndex(familiar.Player) == playerIndex and not familiar:GetData().HasAlreadyBeenRestored then
            familiar:Remove()
        end
    end

    --Do this again just in case
    player:RespawnFamiliars()

    --Kill lost souls
    for _, familiar in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.LOST_SOUL)) do
        ---@type EntityFamiliar
        familiar = familiar:ToFamiliar()

        if Helpers.GetPlayerIndex(familiar.Player) == playerIndex then
            if playerState.LostSouls == 0 then
                --Do it twice for holy mantle
                familiar:TakeDamage(1, 0, EntityRef(player), 0)
                familiar:TakeDamage(1, 0, EntityRef(player), 0)
            end
        end
    end

    --Restore data
    for key, value in pairs(playerState.PlayerData) do
        player:GetData()[key] = value
    end

    --Players with changed player indexes wont have a current player state registered
    if not CurrentPlayerStates[playerIndex] then
        CurrentPlayerStates[playerIndex] = {
            InventoryOrdered = {},
            CollectedItems = {},
            GulpedTrinkets = {}
        }
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
                    table.insert(playerState.InventoryOrdered, { type = InventoryType.COLLECTIBLE, id = itemId })
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
                    table.insert(playerState.InventoryOrdered, { type = InventoryType.TRINKET, id = trinketId })
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

    --Special flag for the frame between preparing the players and actually clearing their states
    if not CheckCurrentPlayerStates then return end

    CheckCollectedItems(player, playerState)

    CheckGulpedTrinkets(player, playerState)
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

    if player.Parent and player:GetPlayerType() == PlayerType.PLAYER_KEEPER and
        not player:GetData().AlreadyRestoredStrawman then
        player:GetData().AlreadyRestoredStrawman = true
        local parentPlayer = player.Parent:ToPlayer()
        local parentIndex = Helpers.GetPlayerIndex(parentPlayer)
        local parentState = SavedPlayerStates[parentIndex]

        if parentState and parentState.StrawmansIndexes and #parentState.StrawmansIndexes > 0 then
            table.insert(PlayersToRestore, playerIndex)
            SavedPlayerStates[playerIndex] = SavedPlayerStates[
                parentState.StrawmansIndexes[#parentState.StrawmansIndexes]]
            parentState.StrawmansIndexes[#parentState.StrawmansIndexes] = nil
        end
    end

    for n, index in ipairs(TaintedLazToFlip) do
        if index == playerIndex then
            player:UseActiveItem(CollectibleType.COLLECTIBLE_FLIP, UseFlag.USE_NOANIM | UseFlag.USE_NOCOSTUME)
            table.remove(TaintedLazToFlip, n)
            break
        end
    end

    if player:GetData().RestoreSoulPosition then
        local savedState = SavedPlayerStates[playerIndex]

        player.Position = savedState.Position

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


function PlayerInventoryManager:OnFrameUpdate()
    if ShouldSaveAndClearPlayers then
        ShouldSaveAndClearPlayers = false
        PlayerInventoryManager.SaveAndClearAllPlayers()
    end
end


function PlayerInventoryManager:OnNewGame()
    CurrentPlayerStates = {}
    SavedPlayerStates = {}
end


function PlayerInventoryManager:OnContinueGame(inventoryData)
    CurrentPlayerStates = {}
    SavedPlayerStates = {}

    for _, currentPlayerStateFromSaveData in ipairs(inventoryData.CurrentPlayerStates) do
        local playerIndex = tonumber(currentPlayerStateFromSaveData.playerIndex)
        local savedState = currentPlayerStateFromSaveData.playerState

        if playerIndex then
            local playerState = {}

            playerState.InventoryOrdered = savedState.InventoryOrdered

            playerState.CollectedItems = {}
            for _, itemFromSave in ipairs(savedState.CollectedItemsForSaving) do
                playerState.CollectedItems[itemFromSave.item] = itemFromSave.num
            end

            playerState.GulpedTrinkets = {}
            for _, trinketFromSave in ipairs(savedState.GulpedTrinketsForSaving) do
                playerState.GulpedTrinkets[trinketFromSave.trinket] = trinketFromSave.num
            end

            CurrentPlayerStates[playerIndex] = playerState
        end
    end

    for _, savedPlayerStateFromSaveData in ipairs(inventoryData.SavedPlayerStates) do
        local playerIndex = tonumber(savedPlayerStateFromSaveData.playerIndex)
        local savedState = savedPlayerStateFromSaveData.playerState

        if playerIndex then
            savedState.CollectedItems = {}
            for _, itemFromSave in ipairs(savedState.CollectedItemsForSaving) do
                savedState.CollectedItems[itemFromSave.item] = itemFromSave.num
            end

            savedState.GulpedTrinkets = {}
            for _, trinketFromSave in ipairs(savedState.GulpedTrinketsForSaving) do
                savedState.CollectedItems[trinketFromSave.trinket] = trinketFromSave.num
            end

            savedState.Position = Vector(savedState.PositionForSaving.x, savedState.PositionForSaving.y)

            SavedPlayerStates[playerIndex] = savedState
        end
    end

end


function PlayerInventoryManager:GetSaveData()
    local inventoryData = {}

    local currentPlayerStatesForSaving = {}

    for playerIndex, playerState in pairs(CurrentPlayerStates) do
        local saveState = {}

        saveState.CollectedItemsForSaving = {}
        for item, num in pairs(playerState.CollectedItems) do
            table.insert(saveState.CollectedItemsForSaving, {item = item, num = num})
        end

        saveState.GulpedTrinketsForSaving = {}
        for trinket, num in pairs(playerState.GulpedTrinkets) do
            table.insert(saveState.GulpedTrinketsForSaving, {trinket = trinket, num = num})
        end

        saveState.InventoryOrdered = playerState.InventoryOrdered

        table.insert(currentPlayerStatesForSaving, {playerIndex = playerIndex, playerState = saveState})
    end

    local savedPlayerStatesForSaving = {}

    for playerIndex, playerState in pairs(SavedPlayerStates) do
        local saveState = playerState

        local CollectedItemsForSaving = {}
        for item, num in pairs(playerState.CollectedItems) do
            table.insert(CollectedItemsForSaving, {item = item, num = num})
        end
        saveState.CollectedItemsForSaving = CollectedItemsForSaving

        local GulpedTrinketsForSaving = {}
        for trinket, num in pairs(playerState.GulpedTrinkets) do
            table.insert(GulpedTrinketsForSaving, {trinket = trinket, num = num})
        end
        saveState.GulpedTrinketsForSaving = GulpedTrinketsForSaving

        saveState.PositionForSaving = {x = playerState.Position.X, y = playerState.Position.Y}

        table.insert(savedPlayerStatesForSaving, {playerIndex = playerIndex, playerState = saveState})
    end

    inventoryData.CurrentPlayerStates = currentPlayerStatesForSaving
    inventoryData.SavedPlayerStates = savedPlayerStatesForSaving

    return inventoryData
end


function PlayerInventoryManager:OnRender()
    -- local playerNum = game:GetNumPlayers()
    -- for i = 0, playerNum - 1, 1 do
    --     local player = game:GetPlayer(i)
    --     local playerIndex = Helpers.GetPlayerIndex(player)
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
        PlayerInventoryManager.PreparePlayersForSaveAndClear()
    elseif cmd == "restore" then
        print("Restoring saved states")
        PlayerInventoryManager.RestoreAllPlayerStates()
    elseif cmd == "1" then
        print(dump(SavedPlayerStates))
    elseif cmd == "2" then
        print(dump(CurrentPlayerStates))
    end
end


function PlayerInventoryManager:Init(mod, helpers)
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, PlayerInventoryManager.OnPeffectUpdate)
    mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, PlayerInventoryManager.OnInput)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, PlayerInventoryManager.OnPlayerUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, PlayerInventoryManager.OnFrameUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, PlayerInventoryManager.OnRender)
    mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, PlayerInventoryManager.OnCMD)

    Helpers = helpers
end


return PlayerInventoryManager
