local Helpers = {}
local ArcadeCabinetVariables
local game = Game()


function Helpers:IsModdedCabinetVariant(machineVariant)
    for _, variant in pairs(ArcadeCabinetVariables.ArcadeCabinetVariant) do
        if machineVariant == variant then
            return true
        end
    end

    return false
end


function Helpers:DoesAnyPlayerHasItem(itemType)
    for i = 0, game:GetNumPlayers() - 1, 1 do
        local player = game:GetPlayer(i)
        if player:HasCollectible(itemType) then
            return true
        end
    end

    return false
end


function Helpers:SpawnRandomCabinet(pos, rng)
    local i = 1
    local left = ArcadeCabinetVariables.MINIGAME_NUM
    local chosenVariant

    for _, variant in pairs(ArcadeCabinetVariables.ArcadeCabinetVariant) do
        if rng:RandomFloat() <= 1/left then
            chosenVariant = variant
            break
        end

        left = left - 1
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


function Helpers:Init(variables)
    ArcadeCabinetVariables = variables
end

return Helpers