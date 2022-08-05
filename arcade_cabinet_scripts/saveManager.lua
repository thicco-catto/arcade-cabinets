local SaveManagement = {}
local ArcadeCabinetVariables
local ArcadeCabinetMod

local Helpers

local PlayerInventory

local game = Game()
local json = require("json")

local menuDataToSave = {}


function SaveManagement:SaveData(menuData)
    menuDataToSave = menuData

    local saveData = {}

    saveData.MachinesInRun = ArcadeCabinetVariables.MachinesInRun

    local inventoryData = PlayerInventory:GetSaveData()
    saveData.InventoryData = inventoryData

    saveData.MenuData = menuDataToSave

    local encodedSaveData = json.encode(saveData)
    ArcadeCabinetMod:SaveData(encodedSaveData)
end


local function StartNewGame()
    ArcadeCabinetVariables.MachinesInRun = {}

    PlayerInventory:OnNewGame()
end


local function ContinueGame()
    if ArcadeCabinetMod:HasData() then
        local encodedSaveData = ArcadeCabinetMod:LoadData()
        local saveData = json.decode(encodedSaveData)

        ArcadeCabinetVariables.MachinesInRun = saveData.MachinesInRun
        PlayerInventory:OnContinueGame(saveData.InventoryData)
    else
        --If the mod doesnt have save data (for some reason) just act like we started a new game
        StartNewGame()
    end

    --Check if the players were in a minigame when exiting
    local activeMinigame

    for minigame, item in pairs(ArcadeCabinetVariables.ArcadeCabinetItems) do
        if Helpers.DoesAnyPlayerHasItem(item) then
            activeMinigame = minigame
            break
        end
    end

    --If we cant find an active minigame then return
    if not activeMinigame then return end
end


function SaveManagement:GetMenuData()
    if ArcadeCabinetMod:HasData() then
        local encodedSaveData = ArcadeCabinetMod:LoadData()
        local saveData = json.decode(encodedSaveData)

        return saveData.MenuData
    else
        return {
            MenuPalette = nil,
            HudOffset = nil,
            GamepadToggle = nil,
            MenuKeybind = nil,
            MenusNotified = nil,
            MenusPoppedUp = nil
        }
    end
end


function SaveManagement:OnGameStart(isContinue)
    if ArcadeCabinetMod:HasData() then
        ArcadeCabinetVariables.IsShaderActive = SaveManagement:GetMenuData().shaderactive
    end

    if isContinue then
        ContinueGame()
    else
        StartNewGame()
    end
end


function SaveManagement:OnGameExit()
    --Set the game state to not playing
    ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.NOT_PLAYING
end



function SaveManagement:Init(mod, variables, inventory, helpers)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, SaveManagement.OnGameStart)
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, SaveManagement.OnGameExit)

    ArcadeCabinetVariables = variables
    ArcadeCabinetMod = mod
    PlayerInventory = inventory
    Helpers = helpers
end


return SaveManagement