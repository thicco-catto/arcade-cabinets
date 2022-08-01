local Cabinet = {
    stage = -1,
    room = -1,
    gridPosition = -1,
    glitched = false,
    initialSeed = 0,
    numberOfAttempts = 0,
    numberOfRerolls = 0
}
local ArcadeCabinetVariables = nil

local Helpers

local game = Game()


function Cabinet:New(gridPosition, glitched, initialSeed)
    local level = game:GetLevel()

    local cabinet = {
        stage = level:GetAbsoluteStage(),
        room = level:GetCurrentRoomIndex(),
        gridPosition = gridPosition,
        glitched = glitched,
        initialSeed = initialSeed,
        numberOfAttempts = 0,
        numberOfRerolls = 0
    }
    setmetatable(cabinet, self)
    self.__index = self

    return cabinet
end


function Cabinet:Equals(other)
    return self.stage == other.stage and
    self.room == other.room and
    self.gridPosition == other.gridPosition
end


---Checks if a cabinet exists in the current list we have for the run.
---If it does, returns the cabinet that already exists
---If it doesnt, returns nil
function Cabinet:Exists()
    for _, cabinet in ipairs(ArcadeCabinetVariables.MachinesInRun) do
        if self:Equals(cabinet) then
            return cabinet
        end
    end

    return nil
end


function Cabinet:GetRNG()
    local rng = RNG()
    rng:SetSeed(self.initialSeed + self.stage + self.room, 35 + self.gridPosition)
    return rng
end


---Returns a random CollectibleType from the Crane item pool.
---Increase the numberOfRerolls attribute to change this.
function Cabinet:GetCollectible()
    local cabinetRNG = self:GetRNG()

    --Iterate once for each reroll so as to change this
    for _ = 1, self.numberOfRerolls, 1 do
        cabinetRNG:Next()
    end

    --Do the 10000 thing because the collectible doesnt change for small values
    local seed = cabinetRNG:RandomInt(999) * 10000 + 10000
    local itemPool = game:GetItemPool()
    local chosenCollectible = itemPool:GetCollectible(ItemPoolType.POOL_CRANE_GAME, false, seed)

    return chosenCollectible
end


---Returns whether a machine should get destroyed or not.
---Will account for lucky foot and changes for each attempt.
function Cabinet:ShouldGetDestroyed()
    local cabinetRNG = self:GetRNG()

    --Iterate once for each attemt so as to change this
    for _ = 1, self.numberOfAttempts, 1 do
        cabinetRNG:Next()
    end

    --Check if any player has lucky foot
    local anyPlayerHasLuckyFoot = Helpers.DoesAnyPlayerHasItem(CollectibleType.COLLECTIBLE_LUCKY_FOOT)

    --If any player has lucky foot, the chance if bigger
    local breakingChance = cabinetRNG:RandomInt(100)
    return breakingChance <= ArcadeCabinetVariables.CHANCE_FOR_CABINET_EXPLODING or
    anyPlayerHasLuckyFoot and breakingChance <= ArcadeCabinetVariables.CHANCE_FOR_CABINET_EXPLODING_LUCKY_FOOT
end


function Cabinet:Init(variables, helpers)
    ArcadeCabinetVariables = variables
    Helpers = helpers
end

return Cabinet