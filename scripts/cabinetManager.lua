local CabinetManagement = {}
local ArcadeCabinetVariables

local Cabinet
local Helpers

local MinigameManagement
local PlayerManagement

local game = Game()


local function SetUpCabinet(cabinet)
    cabinet:GetData().ArcadeCabinet = {}

    local room = game:GetRoom()
    local gridIndex = room:GetGridIndex(cabinet.Position)

    local gameSeed = game:GetSeeds():GetStartSeed()

    local level = game:GetLevel()
    local roomVariant = level:GetCurrentRoomDesc().Data.Variant

    local isGlitched = Helpers.DoesAnyPlayerHasItem(CollectibleType.COLLECTIBLE_TMTRAINER)

    local cabinetObject = Cabinet:New(gridIndex, isGlitched, gameSeed + roomVariant)

    if cabinetObject:Exists() then
        cabinetObject = cabinetObject:Exists()
    else
        --If it didnt exist, play the appear animation and add it to the list
        if isGlitched then
            cabinet:GetSprite():Play("Glitch", true)
        else
            cabinet:GetSprite():Play("Initiate", true)
        end
        table.insert(ArcadeCabinetVariables.MachinesInRun, cabinetObject)
    end

    --If the machine wasn't glitched, but is glitched now, do the glitch anim and update the object
    if not cabinetObject.glitched and isGlitched then
        cabinet:GetSprite():Play("Glitch", true)
        cabinetObject.glitched = isGlitched
    end

    --If its glitched, replace the screen
    if cabinetObject.glitched then
        cabinet:GetSprite():ReplaceSpritesheet(1, "gfx/slots/glitched_" .. ArcadeCabinetVariables.ArcadeCabinetSprite[cabinet.Variant])
    end

    --Show collectible
    local chosenCollectible = cabinetObject:GetCollectible()
    local itemSprite = Isaac.GetItemConfig():GetCollectible(chosenCollectible).GfxFileName
    cabinet:GetSprite():ReplaceSpritesheet(2, itemSprite)

    cabinet:GetSprite():LoadGraphics()

    cabinet:GetData().ArcadeCabinet.CabinetObject = cabinetObject
end


function CabinetManagement:OnNewRoom()
    local room = game:GetRoom()

    for _, slot in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        if slot.Variant == 16 and slot:GetDropRNG():RandomInt(100) <= ArcadeCabinetVariables.CHANCE_FOR_CRANE_TO_CABINET
        and room:IsFirstVisit() then
            local cabinet = Helpers.SpawnRandomCabinet(slot.Position, slot:GetDropRNG())
            SetUpCabinet(cabinet)
            slot:Remove()
        elseif Helpers.IsModdedCabinetVariant(slot.Variant) then
            SetUpCabinet(slot)
        end
    end
end


local function SpawnCabinetReward(cabinet)
    local cabinetObject = cabinet:GetData().ArcadeCabinet.CabinetObject
    --Choose the item
    local chosenCollectible = cabinetObject:GetCollectible()

    --Spawn the item pedestal
    local pedestal = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, chosenCollectible, cabinet.Position, Vector.Zero, nilw)

    --Load the appropiate graphics
    local collectibleGfx = Isaac.GetItemConfig():GetCollectible(chosenCollectible).GfxFileName
    pedestal:GetSprite():Load("gfx/cabinet_collectible_pedestal.anm2", true)
    pedestal:GetSprite():ReplaceSpritesheet(1, collectibleGfx)

    local pedestalGfx = "gfx/slots/" .. ArcadeCabinetVariables.ArcadeCabinetSprite[cabinet.Variant]
    pedestal:GetSprite():ReplaceSpritesheet(5, pedestalGfx)

    pedestal:GetSprite():LoadGraphics()

    --Play the animations
    pedestal:GetSprite():Play("Idle", true)
    pedestal:GetSprite():PlayOverlay("Alternates", true)

    --Set data so we know to set its frame to 0
    pedestal:GetData().ArcadeCabinet = {}
    pedestal:GetData().ArcadeCabinet.IsCabinetReward = true

    --Remove the cabinet
    cabinet:Remove()
end


local function OnCabinetUpdate(cabinet)
    local cabinetSpr = cabinet:GetSprite()
    local cabinetObject = cabinet:GetData().ArcadeCabinet.CabinetObject

    --Check if it should pay out
    if cabinetSpr:IsEventTriggered("Prize") then
        SpawnCabinetReward(cabinet)
        return
    end

    if cabinetSpr:IsFinished("Failure") then
        if cabinetObject:ShouldGetDestroyed() then
            SFXManager():Play(SoundEffect.SOUND_BOSS1_EXPLOSIONS)
            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BOMB_EXPLOSION, 0, cabinet.Position, Vector.Zero, nil)
            cabinetSpr:Play("Death", true)
            cabinet:Die()
        else
            cabinetObject.numberOfAttempts = cabinetObject.numberOfAttempts + 1
            cabinetSpr:Play("Idle", true)
        end
    end

    if cabinetSpr:IsFinished("Initiate") or cabinetSpr:IsFinished("Glitch") then
        cabinetSpr:Play("Idle")
    end

    --If the GridCollisionClass is 5 it means it has been broken
    if cabinet.GridCollisionClass == 5 and not cabinetSpr:IsPlaying("Broken") or
    cabinetSpr:IsFinished("Death") then
        cabinetSpr:Play("Broken")
    end
end


function CabinetManagement:OnFrameUpdate()
    for _, slot in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        if Helpers.IsModdedCabinetVariant(slot.Variant) then
            OnCabinetUpdate(slot)
        end
    end
end


---@param collectible EntityPickup
function CabinetManagement:OnCollectibleUpdate(collectible)
    if not collectible:GetData().ArcadeCabinet then return end
    if not collectible:GetData().ArcadeCabinet.IsCabinetReward then return end

    collectible:GetSprite():SetOverlayFrame("Alternates", 0)
end


--Set up
function CabinetManagement:Init(mod, variables, cabinet, helpers)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, CabinetManagement.OnNewRoom)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, CabinetManagement.OnFrameUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, CabinetManagement.OnCollectibleUpdate, PickupVariant.PICKUP_COLLECTIBLE)

    ArcadeCabinetVariables = variables
    Cabinet = cabinet
    Helpers = helpers
end


function CabinetManagement:AddOtherManagers(minigameManager, playerManager)
    MinigameManagement = minigameManager
    PlayerManagement = playerManager
end


return CabinetManagement