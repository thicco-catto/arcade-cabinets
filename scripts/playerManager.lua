local PlayerManagement = {}
local ArcadeCabinetMod = nil
local ArcadeCabinetVariables = nil
local Cabinet = nil

local CabinetManagement = nil
local MinigameManagement = nil

local game = Game()


--Set up
function PlayerManagement:Init(mod, variables, cabinet)
    ArcadeCabinetMod = mod
    ArcadeCabinetVariables = variables
    Cabinet = cabinet
end


function PlayerManagement:AddOtherManagers(cabinetManager, minigameManager)
    CabinetManagement = cabinetManager
    MinigameManagement = minigameManager
end

return PlayerManagement