local Helpers = {}
local ArcadeCabinetVariables
local game = Game()


function Helpers.IsModdedCabinetVariant(machineVariant)
    for _, variant in pairs(ArcadeCabinetVariables.ArcadeCabinetVariant) do
        if machineVariant == variant then
            return true
        end
    end

    return false
end


function Helpers.DoesAnyPlayerHasItem(itemType)
    for i = 0, game:GetNumPlayers() - 1, 1 do
        local player = game:GetPlayer(i)
        if player:HasCollectible(itemType, true) then
            return true
        end
    end

    return false
end


local function GetCabinetVariantsInRoom()
    local variantsInRoom = {}
    local variantsInRoomToCheck = {}

    for _, slot in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        if Helpers.IsModdedCabinetVariant(slot.Variant) and not variantsInRoomToCheck[slot.Variant] then
            variantsInRoomToCheck[slot.Variant] = true
            table.insert(variantsInRoom, slot.Variant)
        end
    end

    return variantsInRoom
end


function Helpers.SpawnRandomCabinet(pos, rng)
    local cabinetVariantsInRoom = GetCabinetVariantsInRoom()
    local left = ArcadeCabinetVariables.MINIGAME_NUM - #cabinetVariantsInRoom

    --If we have spawned all variants then just repeat
    if left <= 0 then
        cabinetVariantsInRoom = {}
        left = ArcadeCabinetVariables.MINIGAME_NUM
    end

    local chosenVariant

    for _, variant in pairs(ArcadeCabinetVariables.ArcadeCabinetVariant) do
        --First check if this variant is already in the room
        local isRepeatedVariant = false
        for i = 1, #cabinetVariantsInRoom, 1 do
            if variant == cabinetVariantsInRoom[i] then
                isRepeatedVariant = true
            end
        end

        --If it is repeated, dont try to check
        if not isRepeatedVariant then
            if rng:RandomFloat() <= 1/left then
                chosenVariant = variant
                break
            end

            left = left - 1
        end
    end

    return Isaac.Spawn(EntityType.ENTITY_SLOT, chosenVariant, 0, pos, Vector.Zero, nil)
end


function Helpers.GetPlayerIndex(player, ignoreTaintedLaz)
    if not ignoreTaintedLaz and player:GetPlayerType() == PlayerType.PLAYER_LAZARUS2_B then
        return player:GetCollectibleRNG(2):GetSeed()
    else
        return player:GetCollectibleRNG(1):GetSeed()
    end
end


--By Xalum
function Helpers.GetSmeltedTrinketMultiplier(player, trinket)
    local totalMultiplier = player:GetTrinketMultiplier(trinket)
    local playerHasMomsBox = player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_BOX)

    for i = 0, 1 do
        local slotTrinket = player:GetTrinket(i)
        if slotTrinket & ~ TrinketType.TRINKET_GOLDEN_FLAG == trinket then
            local reduction = playerHasMomsBox and 2 or 1
            if slotTrinket & TrinketType.TRINKET_GOLDEN_FLAG > 0 then
                reduction = reduction + 1
            end

            totalMultiplier = totalMultiplier - reduction
        end
    end

    return totalMultiplier
end


function Helpers.CopyTable(target, toCopy)
    --Make sure target is empty
    target = {}

    for key, value in pairs(toCopy) do
        target[key] = value
    end

    return target
end


function Helpers.IsAnyPlayerOfType(playerType)
    local isPlayerOfType = false

    for i = 0, game:GetNumPlayers() - 1, 1 do
        local player = game:GetPlayer(i)

        if player:GetPlayerType() == playerType then
            isPlayerOfType = true
        end
    end

    return isPlayerOfType
end


function Helpers.DoesAnyPlayerHasCollectibleEffect(CollectibleEffectId)
    local doesAnyPlayerHasEffect = false

    for i = 0, game:GetNumPlayers() - 1, 1 do
        local player = game:GetPlayer(i)

        if player:GetEffects():HasCollectibleEffect(CollectibleEffectId) then
            doesAnyPlayerHasEffect = true
        end
    end

    return doesAnyPlayerHasEffect
end


--By Xalum
function Helpers.CountBits(mask)
    local count = 0
    while mask ~= 0 do
        count = count + 1
        mask = mask & mask - 1
    end

    return count
end


function Helpers.Init(variables)
    ArcadeCabinetVariables = variables
end

return Helpers