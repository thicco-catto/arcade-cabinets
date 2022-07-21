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


function Helpers:Init(variables)
    ArcadeCabinetVariables = variables
end

return Helpers