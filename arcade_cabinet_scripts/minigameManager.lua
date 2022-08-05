local MinigameManagement = {}
local ArcadeCabinetVariables

local Cabinet
local Helpers

local CabinetManagement
local PlayerManagement
local PlayerInventory

local game = Game()


---Returns the cabinet entity that was used
local function FindUsedCabinet()
    for _, cabinet in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        if Helpers.IsModdedCabinetVariant(cabinet.Variant) then
            local room = game:GetRoom()
            local gridIndex = room:GetGridIndex(cabinet.Position)
            local cabinetObject = Cabinet:New(gridIndex, false, 1)

            if cabinetObject:Equals(ArcadeCabinetVariables.CurrentMinigameObject) then
                return cabinet
            end
        end
    end

    return nil
end


---@param slot Entity
function MinigameManagement:UseMachine(slot)
    --Set states and current minigame
    ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.FADE_IN
    ArcadeCabinetVariables.CurrentMinigameResult = nil
    ArcadeCabinetVariables.CurrentMinigame = slot.Variant
    ArcadeCabinetVariables.CurrentScript = ArcadeCabinetVariables.ArcadeCabinetScripts[ArcadeCabinetVariables.CurrentMinigame]
    ArcadeCabinetVariables.IsCurrentMinigameGlitched = slot:GetData().ArcadeCabinet.CabinetObject.glitched
    ArcadeCabinetVariables.CurrentMinigameObject = slot:GetData().ArcadeCabinet.CabinetObject

    --Set the transition screen graphics
    local path = "gfx/effects/"
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        path = path .. "glitched_"
    end
    path = path .. ArcadeCabinetVariables.ArcadeCabinetSprite[ArcadeCabinetVariables.CurrentMinigame]
    ArcadeCabinetVariables.TransitionScreen:ReplaceSpritesheet(0, path)
    ArcadeCabinetVariables.TransitionScreen:ReplaceSpritesheet(1, path)
    ArcadeCabinetVariables.TransitionScreen:LoadGraphics()
    ArcadeCabinetVariables.TransitionScreen:Play("Appear", true)

    --Disable player controls
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        game:GetPlayer(i).ControlsEnabled = false
    end

    --Visual stuff
    slot:GetSprite():Play("Wiggle", true)
    SFXManager():Play(SoundEffect.SOUND_COIN_SLOT, 1, 0, false, math.random(9,11)/10)
end


local function FinishTransitionFadeIn()
    --Set state and transition screen
    ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.TRANSITION
    ArcadeCabinetVariables.TransitionScreen:Play("Idle", true)
    ArcadeCabinetVariables.TransitionFrameCount = game:GetFrameCount()

    --Make hud invisible
    game:GetHUD():SetVisible(false)

    --Stop music
    MusicManager():Disable()

    --Store stage stuff to go back and set it to the null stage
    local level = game:GetLevel()
    ArcadeCabinetVariables.LevelStage = level:GetStage()
    ArcadeCabinetVariables.LevelStageType = level:GetStageType()
    level:SetStage(LevelStage.STAGE4_3, StageType.STAGETYPE_AFTERBIRTH)

    --Set options like chargebar and filter
    ArcadeCabinetVariables.OptionsChargeBar = Options.ChargeBars
    ArcadeCabinetVariables.OptionsFilter = Options.Filter
    ArcadeCabinetVariables.OptionsActiveCam = Options.CameraStyle

    Options.ChargeBars = false
    Options.Filter = false
    Options.CameraStyle = 2

    --Prepare all players for the minigame
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        PlayerManagement.InitPlayerForMinigame(game:GetPlayer(i))
    end

    PlayerInventory.PreparePlayersForSaveAndClear()
end


local function FinishTransitionFadeOut()
    ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.NOT_PLAYING

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        game:GetPlayer(i).ControlsEnabled = true
    end

    local cabinet = FindUsedCabinet()
    if ArcadeCabinetVariables.CurrentMinigameResult == ArcadeCabinetVariables.MinigameResult.WIN and cabinet then
        cabinet:GetSprite():Play("Prize", true)
    elseif cabinet then
        cabinet:GetSprite():Play("Failure", true)
    end
end


local function RenderTransitionScreen()
    --Only render the screen if it's on fade in or on transition
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.FADE_IN and
    ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.FADE_OUT then return end

    if ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.FADE_OUT and
    ArcadeCabinetVariables.FadeOutTimer > 0 then
        ArcadeCabinetVariables.FadeOutTimer = ArcadeCabinetVariables.FadeOutTimer - 1

        ArcadeCabinetVariables.TransitionScreen:SetFrame(0)
    end

    ArcadeCabinetVariables.TransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)

    --Do this after render so it changes animation after rendering (for when it changes states)
    if ArcadeCabinetVariables.TransitionScreen:IsFinished("Appear") then
        FinishTransitionFadeIn()
    elseif ArcadeCabinetVariables.TransitionScreen:IsFinished("Disappear") then
        FinishTransitionFadeOut()
    end
end


local function DebugRender()
    local itemsintheroom = Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1)
    for _, item in ipairs(itemsintheroom) do
        local pos = Isaac.WorldToScreen(item.Position)

        Isaac.RenderText(item.SubType, pos.X, pos.Y, 1, 1, 1, 255)
        --Isaac.RenderText(Isaac.GetItemConfig():GetCollectible(item.SubType).ID, pos.X, pos.Y + 10, 1, 1, 1, 255)       
    end

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        local data = player:GetData().ArcadeCabinet
        local pos = Isaac.WorldToScreen(player.Position)

        local a = "false"
        if player.ControlsEnabled then a = "true" end
        --Isaac.RenderText(a, pos.X, pos.Y, 1, 1, 1, 255)
        Isaac.RenderText(dump(data.collectedItems), pos.X, pos.Y, 1, 1, 1, 255)
        Isaac.RenderText(dump(data.collectedItemsOrdered), pos.X, pos.Y + 10, 1, 1, 1, 255)
    end
end


function MinigameManagement:GetShaderParams(shaderName)
    --Render transition (here so it renders on top of the hud)
    RenderTransitionScreen()

    --DebugRender()

    --Shader stuff
    local shouldBeEnabled = ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.TRANSITION or
    ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.PLAYING

	if shaderName == 'MinigameShader' then
        local isEnabled = 0
        if shouldBeEnabled and ArcadeCabinetVariables.IsShaderActive == 2 then
            isEnabled = 1
        end
        local params = {
                Time = Isaac.GetFrameCount(),
                Amount = "1",
                Enabled = isEnabled
            }
        return params;
    elseif shaderName == "MinigameShaderV2" then
        local isEnabled = 0
        if shouldBeEnabled and ArcadeCabinetVariables.IsShaderActive == 1 then
            isEnabled = 1
        end
        local params = { 
            Time = game:GetFrameCount(),
            Enabled = isEnabled
        }
        return params;
    end
end


function MinigameManagement:OnRender()
    --DebugRender()

    --Update the animation here because the anm2 and everything is planned to update on render
    --Incredibly shitty but works
    ArcadeCabinetVariables.TransitionScreen:Update()

    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.TRANSITION then return end

    --If its in the transition (Showing the minigame screen) render it here
    --If it was rendering on the shader callback, it'd literally render on top of the shader lmao
    ArcadeCabinetVariables.TransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
end


local function IsAnyPlayerPressingStart()
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        if Input.IsActionPressed(ButtonAction.ACTION_ITEM, player.ControllerIndex) then
            return true
        end
    end

    return false
end


local function CheckForTeleportToRoom()
    --We only need to run this function if we are on the minigame transition
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.TRANSITION then return end

    --Teleport only if the frame is 10, to leave some time to prepare the players
    if game:GetFrameCount() - ArcadeCabinetVariables.TransitionFrameCount ~= 10 then return end

    --Teleport players to the room
    local roomIndex = ArcadeCabinetVariables.ArcadeCabinetRooms[ArcadeCabinetVariables.CurrentMinigame]
    Isaac.ExecuteCommand("goto s.isaacs." .. roomIndex)

    --Give the player the minigame item
    local minigameItem = ArcadeCabinetVariables.ArcadeCabinetItems[ArcadeCabinetVariables.CurrentMinigame]
    Isaac.GetPlayer(0):AddCollectible(minigameItem)
end


local function CheckIfStartMinigame()
    --We only need to run this function if we are on the minigame transition
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.TRANSITION then return end

    --Give the players some time to admire the wonderful transition screen
    if game:GetFrameCount() - ArcadeCabinetVariables.TransitionFrameCount < 20 then return end

    if IsAnyPlayerPressingStart() then
        --Enable the music back
        MusicManager():Enable()

        ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.PLAYING
        ArcadeCabinetVariables.CurrentScript:Init(ArcadeCabinetMod, ArcadeCabinetVariables)
    end
end


local function CheckIfEndMinigame()
    --If we're not playing we can skip this
    if ArcadeCabinetVariables.CurrentGameState ~= ArcadeCabinetVariables.GameState.PLAYING then return end

    --If the result is nil the minigame hasnt ended yet
    if not ArcadeCabinetVariables.CurrentMinigameResult then return end

    --Set the state and transition screen
    ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.FADE_OUT
    ArcadeCabinetVariables.TransitionScreen:Play("Disappear")
    ArcadeCabinetVariables.FadeOutTimer = 60

    --Remove the callbacks for the mod
    ArcadeCabinetVariables.CurrentScript:RemoveCallbacks(ArcadeCabinetMod)

    --Set visible hud
    game:GetHUD():SetVisible(true)

    --Set all options to what they were
    Options.ChargeBars = ArcadeCabinetVariables.OptionsChargeBar
    Options.Filter = ArcadeCabinetVariables.OptionsFilter
    Options.CameraStyle = ArcadeCabinetVariables.OptionsActiveCam

    --Set stage back to original
    local level = game:GetLevel()
    level:SetStage(ArcadeCabinetVariables.LevelStage, ArcadeCabinetVariables.LevelStageType)

    --Teleport the players back through the door
    local room = game:GetRoom()
    local openDoor = nil
    for i = 0, 7, 1 do
        local door = room:GetDoor(i)
        if door then
            openDoor = door
            door:Open()
            break
        end
    end

    local extraVelocity = nil

    if openDoor.Direction == Direction.LEFT then
        extraVelocity = Vector(-100, 0)
    elseif openDoor.Direction == Direction.RIGHT then
        extraVelocity = Vector(100, 0)
    elseif openDoor.Direction == Direction.UP then
        extraVelocity = Vector(0, -100)
    else
        extraVelocity = Vector(0, 100)
    end

    game:GetPlayer(0).Position = openDoor.Position
    game:GetPlayer(0):AddVelocity(extraVelocity)

    --Set the restore positions flag for next on new room callback
    ArcadeCabinetVariables.RestorePlayers = true
end


function MinigameManagement:OnFrameUpdate()
    CheckForTeleportToRoom()

    CheckIfStartMinigame()

    CheckIfEndMinigame()

    if ArcadeCabinetVariables.CurrentGameState == ArcadeCabinetVariables.GameState.PLAYING then
        local room = game:GetRoom()
        for i = 0, 7, 1 do
            local door = room:GetDoor(i)
            if door then
                door:Close(true)
            end
        end
    end
end


--Set up
function MinigameManagement:Init(mod, variables, inventory, cabinet, helpers)
    mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, MinigameManagement.GetShaderParams)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, MinigameManagement.OnRender)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, MinigameManagement.OnFrameUpdate)

    ArcadeCabinetMod = mod
    ArcadeCabinetVariables = variables
    Cabinet = cabinet
    Helpers = helpers
    PlayerInventory = inventory
end


function MinigameManagement:AddOtherManagers(cabinetManager, playerManager)
    CabinetManagement = cabinetManager
    PlayerManagement = playerManager
end


return MinigameManagement