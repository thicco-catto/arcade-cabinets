local PlayerManagement = {}
local ArcadeCabinetVariables

local Cabinet
local Helpers

local CabinetManagement
local MinigameManagement
local PlayerInventory

local game = Game()


---@param player EntityPlayer
function PlayerManagement.InitPlayerForMinigame(player)
    --Remove their items
    player:FlushQueueItem()
end


function PlayerManagement:OnPlayerUpdate(player)
    --If we started playing we dont need to compute collision
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.NOT_PLAYING then return end
    --If the player has less than 5 coins we dont need to compute collision
    if player:GetNumCoins() < 5 then return end

    for _, slot in pairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        --If has to be one of our machines and it has to be playing the idle animation
        if Helpers.IsModdedCabinetVariant(slot.Variant) and slot:GetSprite():IsPlaying("Idle") then
            --Distance must be less that the hardcoded radius (like this so we dont have to use player collision callback)
            if (player.Position - slot.Position):Length() <= ArcadeCabinetVariables.CABINET_RADIUS then
                player:AddCoins(-5)
                MinigameManagement:UseMachine(slot)
            end
        end
    end
end


---@param player EntityPlayer
function PlayerManagement:OnPeffectUpdate(player)
    --CheckCollectedItems(player)

    --If we're in transition and the player has controls enabled (because of moving to another room), disable them
    if ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.TRANSITION and player.ControlsEnabled then
        player.ControlsEnabled = false
    end
end


function PlayerManagement:OnNewRoom()
    if ArcadeCabinetVariables.RestorePlayers then
        ArcadeCabinetVariables.RestorePlayers = false

        PlayerInventory.RestoreAllPlayerStates()
    end
end


--Set up
function PlayerManagement:Init(mod, variables, inventory, cabinet, helpers)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, PlayerManagement.OnPlayerUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, PlayerManagement.OnPeffectUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, PlayerManagement.OnNewRoom)

    ArcadeCabinetVariables = variables
    Cabinet = cabinet
    Helpers = helpers
    PlayerInventory = inventory
end


function PlayerManagement:AddOtherManagers(cabinetManager, minigameManager)
    CabinetManagement = cabinetManager
    MinigameManagement = minigameManager
end


return PlayerManagement