local CabinetManagement = {}
local ArcadeCabinetVariables

local Cabinet
local Helpers

local MinigameManagement
local PlayerManagement
local PlayerInventory

local game = Game()


local function DestroyCabinet(cabinet)
    SFXManager():Play(SoundEffect.SOUND_BOSS1_EXPLOSIONS)
    Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BOMB_EXPLOSION, 0, cabinet.Position, Vector.Zero, nil)
    cabinet:GetSprite():Play("Death", true)
    cabinet:Die()
end


local function SetUpCabinet(cabinet, forceGlitch)
    cabinet:GetData().ArcadeCabinet = {}

    local room = game:GetRoom()
    local gridIndex = room:GetGridIndex(cabinet.Position)

    local gameSeed = game:GetSeeds():GetStartSeed()

    local level = game:GetLevel()
    local roomVariant = level:GetCurrentRoomDesc().Data.Variant

    local isGlitched = Helpers.DoesAnyPlayerHasItem(CollectibleType.COLLECTIBLE_TMTRAINER) or forceGlitch

    local cabinetObject = Cabinet:New(gridIndex, isGlitched, gameSeed + roomVariant)

    if cabinetObject:Exists() then
        cabinetObject = cabinetObject:Exists()
    else
        --If it didnt exist, play the appear animation and add it to the list
        if isGlitched then
            SFXManager():Play(SoundEffect.SOUND_EDEN_GLITCH, 1, 2, false, 0.9 + math.random()*0.2)
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

    --Show collectible
    if cabinetObject.glitched then
        cabinet:GetSprite():ReplaceSpritesheet(1, "gfx/slots/glitched_" .. ArcadeCabinetVariables.ArcadeCabinetSprite[cabinet.Variant])
        cabinet:GetSprite():ReplaceSpritesheet(2, "gfx/slots/glitch_item_icon.png")
    else
        local chosenCollectible = cabinetObject:GetCollectible()
        local itemSprite = Isaac.GetItemConfig():GetCollectible(chosenCollectible).GfxFileName
        cabinet:GetSprite():ReplaceSpritesheet(2, itemSprite)
    end

    cabinet:GetSprite():LoadGraphics()

    cabinet:GetData().ArcadeCabinet.CabinetObject = cabinetObject
end


function CabinetManagement:OnNewRoom()
    local room = game:GetRoom()

    for _, slot in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        local slotRNG = slot:GetDropRNG()

        if slot.Variant == 16 and slotRNG:RandomInt(100) <= ArcadeCabinetVariables.CHANCE_FOR_CRANE_TO_CABINET
        and room:IsFirstVisit() then
            --If its a crane slot have a chance to replace it with a random cabinet
            local cabinet = Helpers.SpawnRandomCabinet(slot.Position, slotRNG)
            SetUpCabinet(cabinet)
            slot:Remove()
        elseif slot.Variant == ArcadeCabinetVariables.RANDOM_CABINET_VARIANT then
            --If its a random cabinet, spawn it
            local cabinet = Helpers.SpawnRandomCabinet(slot.Position, slotRNG)
            SetUpCabinet(cabinet)
            slot:Remove()
        elseif slot.Variant == ArcadeCabinetVariables.RANDOM_GLITCH_CABINET_VARIANT then
            --If its a random cabinet glitched, force it to be glitch
            local cabinet = Helpers.SpawnRandomCabinet(slot.Position, slotRNG)
            SetUpCabinet(cabinet, true)
            slot:Remove()
        elseif Helpers.IsModdedCabinetVariant(slot.Variant) then
            --If its already a normal cabinet, set it up normally
            SetUpCabinet(slot)
        end
    end
end


local function SpawnCabinetReward(cabinet)
    local cabinetObject = cabinet:GetData().ArcadeCabinet.CabinetObject
    --Choose the item
    local chosenCollectible = cabinetObject:GetCollectible()

    --If no player has tmtrainer, give it to the the first player
    local removeTMTrainer = false
    if cabinetObject.glitched and not Helpers.DoesAnyPlayerHasItem(CollectibleType.COLLECTIBLE_TMTRAINER) then
        removeTMTrainer = true
        Isaac.GetPlayer(0):AddCollectible(CollectibleType.COLLECTIBLE_TMTRAINER)
    end

    --Spawn the item pedestal
    local pedestal = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, chosenCollectible, cabinet.Position + Vector(0, -10), Vector.Zero, nilw)

    if removeTMTrainer then
        Isaac.GetPlayer(0):RemoveCollectible(CollectibleType.COLLECTIBLE_TMTRAINER)
    end

    --Load the appropiate graphics
    local pedestalGfx = "gfx/items/altar_" .. ArcadeCabinetVariables.ArcadeCabinetSprite[cabinet.Variant]
    pedestal:GetSprite():ReplaceSpritesheet(5, pedestalGfx)

    pedestal:GetSprite():LoadGraphics()

    --Set data so we know to set its frame
    pedestal:GetData().ArcadeCabinet = {}
    pedestal:GetData().ArcadeCabinet.IsCabinetReward = true
    pedestal:GetSprite():SetOverlayFrame("Alternates", 1)

    --Remove the cabinet
    cabinet:Remove()
end


local function DestroyCabinetsIfTaintedJacob()
    if not Helpers.IsAnyPlayerOfType(PlayerType.PLAYER_JACOB2_B) then return end

    local closestCabinet = nil
    local closestDistance = math.maxinteger

    for _, slot in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
        if Helpers.IsModdedCabinetVariant(slot.Variant) and slot:GetSprite():IsPlaying("Idle") then
            if (Isaac.GetPlayer(0).Position - slot.Position):Length() < closestDistance then
                closestCabinet = slot
                closestDistance = (Isaac.GetPlayer(0).Position - slot.Position):Length()
            end
        end
    end

    if closestCabinet then
        DestroyCabinet(closestCabinet)
    end
end


local function OnCabinetUpdate(cabinet)
    if not cabinet:GetData().ArcadeCabinet then SetUpCabinet(cabinet) return end
    if not cabinet:GetData().ArcadeCabinet.CabinetObject then SetUpCabinet(cabinet) return end

    local cabinetSpr = cabinet:GetSprite()
    local cabinetObject = cabinet:GetData().ArcadeCabinet.CabinetObject

    --Check if it should pay out
    if cabinetSpr:IsEventTriggered("Prize") then
        SpawnCabinetReward(cabinet)
        return
    end

    if cabinetSpr:IsFinished("Failure") then
        if cabinetObject:ShouldGetDestroyed() then
            DestroyCabinet(cabinet)
        else
            local cabinetObjectInList = cabinetObject:Exists()
            cabinetObject.numberOfAttempts = cabinetObject.numberOfAttempts + 1
            cabinetObjectInList.numberOfAttempts = cabinetObject.numberOfAttempts
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
    DestroyCabinetsIfTaintedJacob()

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

    collectible:GetSprite():SetOverlayFrame("Alternates", 1)
end


--Set up
function CabinetManagement:Init(mod, variables, inventory, cabinet, helpers)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, CabinetManagement.OnNewRoom)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, CabinetManagement.OnFrameUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, CabinetManagement.OnCollectibleUpdate, PickupVariant.PICKUP_COLLECTIBLE)

    ArcadeCabinetVariables = variables
    Cabinet = cabinet
    Helpers = helpers
    PlayerInventory = inventory
end


function CabinetManagement:AddOtherManagers(minigameManager, playerManager)
    MinigameManagement = minigameManager
    PlayerManagement = playerManager
end


return CabinetManagement