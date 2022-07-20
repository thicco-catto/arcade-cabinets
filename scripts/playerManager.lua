local PlayerManagement = {}
local ArcadeCabinetVariables

local Cabinet
local Helpers

local CabinetManagement
local MinigameManagement

local game = Game()


--Set up
function PlayerManagement:Init(mod, variables, cabinet, helpers)
    ArcadeCabinetVariables = variables
    Cabinet = cabinet
    Helpers = helpers
end


function PlayerManagement:AddOtherManagers(cabinetManager, minigameManager)
    CabinetManagement = cabinetManager
    MinigameManagement = minigameManager
end

return PlayerManagement