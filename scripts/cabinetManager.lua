local CabinetManagement = {}
local ArcadeCabinetMod = nil
local ArcadeCabinetVariables = nil
local Cabinet = nil

local MinigameManagement = {}
local PlayerManagement = {}

local game = Game()

function CabinetManagement:Init(mod, variables, cabinet)
    ArcadeCabinetMod = mod
    ArcadeCabinetVariables = variables
    Cabinet = cabinet
end


function CabinetManagement:AddOtherManagers(minigameManager, playerManager)
    MinigameManagement = minigameManager
    PlayerManagement = playerManager
end


return CabinetManagement