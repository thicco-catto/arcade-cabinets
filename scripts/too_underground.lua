local too_underground = {}
local game = Game()
local SFXManager = SFXManager()
too_underground.callbacks = {}
too_underground.result = nil
too_underground.startingItems = {
    CollectibleType.COLLECTIBLE_ISAACS_HEART,
    --CollectibleType.COLLECTIBLE_MINE_CRAFTER
    Isaac.GetItemIdByName("TUG minecrafter")
}

----------------------------------------------
--FANCY REQUIRE (Thanks manaphoenix <3)
----------------------------------------------
local _, err = pcall(require, "")
local modName = err:match("/mods/(.*)/%.lua")
local path = "mods/" .. modName .. "/"

local function loadFile(loc, ...)
    return assert(loadfile(path .. loc .. ".lua"))(...)
end

local ArcadeCabinetVariables = loadFile("scripts/variables")


local bannedSounds = {
    SoundEffect.SOUND_TEARS_FIRE,
    SoundEffect.SOUND_BLOODSHOOT,
    SoundEffect.SOUND_MEAT_IMPACTS,
    SoundEffect.SOUND_SUMMON_POOF,
    SoundEffect.SOUND_DOOR_HEAVY_CLOSE,
    SoundEffect.SOUND_DEATH_BURST_SMALL,
    SoundEffect.SOUND_MEATY_DEATHS,
    SoundEffect.SOUND_ANGRY_GURGLE,
    SoundEffect.SOUND_TEARIMPACTS,
    SoundEffect.SOUND_SPLATTER,
    SoundEffect.SOUND_POT_BREAK,
    SoundEffect.SOUND_POT_BREAK_2,
    SoundEffect.SOUND_ROCK_CRUMBLE
}

local replacementSounds = {
    [SoundEffect.SOUND_BOSS1_EXPLOSIONS] = Isaac.GetSoundIdByName("tug explosion"),
    [SoundEffect.SOUND_BATTERYCHARGE] = Isaac.GetSoundIdByName("tug dynamite")
}

local minigameSounds = {
    ROCK_BREAK = Isaac.GetSoundIdByName("tug rock break"),
    TEAR_SPLASH = Isaac.GetSoundIdByName("tug tear splash"),
    CHEST_DROP = Isaac.GetSoundIdByName("tug chest drop"),
    CHEST_OPEN = Isaac.GetSoundIdByName("tug chest open"),
    BONE_GUY_RISE_DEAD = Isaac.GetSoundIdByName("tug skeleton rise dead"),
    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}

local minigameEntityVariants = {
    TEAR_POOF = Isaac.GetEntityVariantByName("tear poof TUG"),
    ROCK_ENTITY = Isaac.GetEntityVariantByName("rock TUG"),
    BONE_GUY = Isaac.GetEntityVariantByName("bone guy TUG"),
    CHEST = Isaac.GetEntityVariantByName("chest TUG")
}

local rockTypes = {
    DEFAULT = 1,
    HARDENED = 2,
    BARREL = 3
}
local RocksInRoom = {}

local Backdrop = nil

local InmortalBoneGuy = nil

local RemoveBoneGuys = false

--Stone meter
local MaxRocks = 171
local BrokenRocks = 0
local StoneMeterUI = Sprite()
StoneMeterUI:Load("gfx/tug_rockmeter.anm2", true)
StoneMeterUI:Play("Idle", true)

--Minecrafter
local MinecraferUI = Sprite()
MinecraferUI:Load("gfx/tug_minecrafter_ui.anm2", true)
MinecraferUI:Play("Idle", true)

--Fade out screen
local WaveTransitionScreen = Sprite()
WaveTransitionScreen:Load("gfx/minigame_transition.anm2")

local MinigameState = {
    MINING = 1,
    WINNING = 2,
    LOSING = 3
}
local CurrentMinigameState = MinigameState.MINING


local function AddRock(gridEntity, index)
    local rock = {}
    rock.rockEntity = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, minigameEntityVariants.ROCK_ENTITY, 0, gridEntity.Position - Vector(26, 26), Vector.Zero, nil)
    rock.gridEntity = gridEntity
    rock.gridEntity:GetSprite():ReplaceSpritesheet(0, "a")
    rock.gridEntity:GetSprite():LoadGraphics()

    if gridEntity:GetType() == GridEntityType.GRID_ROCK_ALT then
        rock.health = 8
        rock.type = rockTypes.HARDENED
        rock.rockEntity:GetSprite():ReplaceSpritesheet(0, "gfx/grid/tug_hardened_rock.png")
    else
        rock.health = 4
        rock.type = rockTypes.DEFAULT
    end

    rock.rockEntity:GetSprite():LoadGraphics()
    RocksInRoom[index] = rock
end


local function BreakRock(index, rock)
    local room = game:GetRoom()

    rock.rockEntity:Remove()
    room:RemoveGridEntity(index, 0, false)
    RocksInRoom[index] = nil
    SFXManager:Play(minigameSounds.ROCK_BREAK)
    local rockBreak = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, minigameEntityVariants.TEAR_POOF, 0, rock.gridEntity.Position, Vector.Zero, nil)
    rockBreak:GetSprite():Load("gfx/tug_rock_break.anm2", true)
    rockBreak:GetSprite():Play("Poof", true)

    BrokenRocks = BrokenRocks + 1

    --Spawn shockwave
    local chanceToSpawn = 7
    if rock.type == rockTypes.HARDENED then chanceToSpawn = 20 end

    if chanceToSpawn >= math.random(100) then
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SHOCKWAVE_RANDOM, 0, rock.gridEntity.Position, Vector.Zero, nil)
    end
end


function too_underground:Init()
    local room = game:GetRoom()

    --Reset variables
    too_underground.result = nil
    RocksInRoom = {}
    BrokenRocks = 0
    MaxRocks = 170
    RemoveBoneGuys = false
    CurrentMinigameState = MinigameState.MINING
    WaveTransitionScreen:Play("Appear", true)
    WaveTransitionScreen:SetFrame(0)

    --Replace bone guys to my gibless bone guys
    for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_CLICKETY_CLACK, -1, -1)) do
        Isaac.Spawn(EntityType.ENTITY_CLICKETY_CLACK, minigameEntityVariants.BONE_GUY, 0, entity.Position, Vector.Zero, nil)
        entity:Remove()
    end

    --Spawn invinvible bone guy
    InmortalBoneGuy = Isaac.Spawn(EntityType.ENTITY_CLICKETY_CLACK, 0, 0, Vector(-99999999, -99999999), Vector.Zero, nil)
    InmortalBoneGuy:GetSprite():ReplaceSpritesheet(0, "a")
    InmortalBoneGuy:GetSprite():ReplaceSpritesheet(1, "a")
    InmortalBoneGuy:GetSprite():LoadGraphics()

    --Change sprite for batteries
    for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LIL_BATTERY, -1)) do
        entity:GetSprite():ReplaceSpritesheet(0, "gfx/pick ups/tug_tnt.png")
        entity:GetSprite():LoadGraphics()
    end

    --Spawn backdrop
    Backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.BackdropVariant, 0, Vector.Zero, Vector.Zero, nil)
    Backdrop:GetSprite():Load("gfx/backdrop/tug_backdrop.anm2", true)

    --Add rocks to the list
    for i = 16, 223, 1 do
        local gridEntity = room:GetGridEntity(i)
        if gridEntity and gridEntity:ToRock() then AddRock(gridEntity, i) end
    end

    --Set players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        for _, item in ipairs(too_underground.startingItems) do
            player:AddCollectible(item, 0, false)
        end

        --Set spritesheet
        local playerSprite = player:GetSprite()
        playerSprite:Load("gfx/tug_isaac52.anm2", true)
        --playerSprite:ReplaceSpritesheet(1, "gfx/characters/isaac_tug.png")
        playerSprite:ReplaceSpritesheet(4, "a") --Empty head xd
        --playerSprite:ReplaceSpritesheet(12, "gfx/characters/isaac_tug.png")
        playerSprite:LoadGraphics()
    end

    for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.ISAACS_HEART, -1)) do
        entity.Position = Vector(-99999999, -99999999)
    end
end


--UPDATE CALLBACKS
local function ManageSFX()
    --Completely stop banned sounds
    for _, sound in ipairs(bannedSounds) do
        if SFXManager:IsPlaying(sound) then SFXManager:Stop(sound) end
    end

    --Replace sounds to be changed
    for originalSound, replacement in pairs(replacementSounds) do
        if SFXManager:IsPlaying(originalSound) then
            SFXManager:Stop(originalSound)
            SFXManager:Play(replacement)
        end
    end

    --Play grunts
    if #Isaac.FindByType(EntityType.ENTITY_GAPER, -1, -1) > 0 and not SFXManager:IsPlaying(minigameSounds.GAPER_GRUNT) then
        SFXManager:Play(minigameSounds.GAPER_GRUNT)
    end
end


local function CheckForWin()
    if BrokenRocks ~= MaxRocks or #Isaac.FindByType(EntityType.ENTITY_PICKUP, minigameEntityVariants.CHEST, -1) ~= 0 then return end

    RemoveBoneGuys = true
    local room = game:GetRoom()
    local chest = Isaac.Spawn(EntityType.ENTITY_PICKUP, minigameEntityVariants.CHEST, 0, room:GetCenterPos(), Vector.Zero, nil)
    chest:AddEntityFlags(EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK | EntityFlag.FLAG_NO_KNOCKBACK)
end


local function RemoveBoneGuysWin()
    if not RemoveBoneGuys or #Isaac.FindByType(EntityType.ENTITY_CLICKETY_CLACK, minigameEntityVariants.BONE_GUY, -1) == 0 then return end
    if game:GetFrameCount() % 2 ~= 0 then return end

    local boneGuyToRemove = Isaac.FindByType(EntityType.ENTITY_CLICKETY_CLACK, minigameEntityVariants.BONE_GUY, -1)[1]
    boneGuyToRemove:Remove()

    local rockBreak = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, minigameEntityVariants.TEAR_POOF, 0, boneGuyToRemove.Position, Vector.Zero, nil)
    rockBreak:GetSprite():Load("gfx/tug_rock_break.anm2", true)
    rockBreak:GetSprite():Play("Poof", true)
end


function too_underground:FrameUpdate()
    -- for i = 1, 800, 1 do
    --     if SFXManager:IsPlaying(i) then print(i) end
    -- end

    --Remove tear poofs
    for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, minigameEntityVariants.TEAR_POOF, 0)) do
        if entity:GetSprite():IsFinished("Poof") then entity:Remove() end
    end

    InmortalBoneGuy.Position = Vector(-99999999, -99999999)

    RemoveBoneGuysWin()

    CheckForWin()
end
too_underground.callbacks[ModCallbacks.MC_POST_UPDATE] = too_underground.FrameUpdate


function too_underground:PlayerUpdate(player)
    --Flip the player if they shoot left and they aren't already moving left
    player.FlipX = Input.IsActionPressed(ButtonAction.ACTION_SHOOTLEFT, player.ControllerIndex) and not Input.IsActionPressed(ButtonAction.ACTION_LEFT, player.ControllerIndex) or
    Input.IsActionPressed(ButtonAction.ACTION_SHOOTRIGHT, player.ControllerIndex) and Input.IsActionPressed(ButtonAction.ACTION_LEFT, player.ControllerIndex)

    if CurrentMinigameState == MinigameState.WINNING then
        player:GetSprite():SetFrame(5)
    end
end
too_underground.callbacks[ModCallbacks.MC_POST_PEFFECT_UPDATE] = too_underground.PlayerUpdate


local function RenderUI()
    --Rockmeter
    local stonemeterFrame = math.floor((BrokenRocks / MaxRocks) * 10)
    StoneMeterUI:SetFrame(stonemeterFrame)
    StoneMeterUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) - Vector(100, -120), Vector.Zero, Vector.Zero)

    --Minecrafter ui
    local minecrafterFrame = 0
    if game:GetPlayer(0):GetActiveCharge() > 0 then
        minecrafterFrame = 1
    end
    MinecraferUI:SetFrame(minecrafterFrame)
    MinecraferUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) - Vector(-150, -120), Vector.Zero, Vector.Zero)
end


local function RenderFadeOut()
    if CurrentMinigameState == MinigameState.MINING then return end

    if WaveTransitionScreen:IsFinished("Appear") then
        if CurrentMinigameState == MinigameState.WINNING then
            too_underground.result = ArcadeCabinetVariables.MinigameResult.WIN
        else
            too_underground.result = ArcadeCabinetVariables.MinigameResult.LOSE
        end
    end

    if SFXManager:IsPlaying(minigameSounds.WIN) then
        WaveTransitionScreen:SetFrame(0)
    end

    WaveTransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
    WaveTransitionScreen:Update()
end


function too_underground:OnRender()
    ManageSFX()

    RenderUI()

    RenderFadeOut()
end
too_underground.callbacks[ModCallbacks.MC_POST_RENDER] = too_underground.OnRender


--NPC CALLBACKS
function too_underground:NPCInit(entity)
    if entity.Type == EntityType.ENTITY_MOVABLE_TNT then
        entity:GetSprite():ReplaceSpritesheet(0, "gfx/grid/tug_movable_tnt.png")
        entity:GetSprite():LoadGraphics()
    elseif entity.Type == EntityType.ENTITY_SPIDER then
        entity:Remove()
    end
end
too_underground.callbacks[ModCallbacks.MC_POST_NPC_INIT] = too_underground.NPCInit


function too_underground:NPCUpdate(entity)
    if entity.Type == EntityType.ENTITY_MOVABLE_TNT and not entity:GetData().hasExploded and entity.State == 16 then
        entity:GetData().hasExploded = true

        for index, rock in pairs(RocksInRoom) do
            if entity.Position:Distance(rock.gridEntity.Position) < 110 then
                BreakRock(index, rock)
            end
        end
    elseif entity.Type == EntityType.ENTITY_CLICKETY_CLACK then
        local data = entity:GetData()

        if data.LastState and data.LastState == 13 and data.LastState ~= entity.State then
            SFXManager:Play(minigameSounds.BONE_GUY_RISE_DEAD)
        end
        entity:GetData().LastState = entity.State
    end
end
too_underground.callbacks[ModCallbacks.MC_NPC_UPDATE] = too_underground.NPCUpdate


function too_underground:OnEntityDamage(tookDamage, _, damageflags, _)
    if tookDamage:ToPlayer() then return end

    if damageflags == DamageFlag.DAMAGE_COUNTDOWN then
        --Negate contact damage (DamageFlag.DAMAGE_COUNTDOWN is damage flag for contact damage)
        return false
    end

    if damageflags == DamageFlag.DAMAGE_CRUSH then
        return false
    end

    if tookDamage.Type == EntityType.ENTITY_CLICKETY_CLACK and tookDamage:ToNPC().State == 4 then
        tookDamage.HitPoints = 0
        SFXManager:Play(minigameSounds.BONE_GUY_RISE_DEAD)
    end
end
too_underground.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG] = too_underground.OnEntityDamage


function too_underground:OnNPCCollision(entity, collider)
    if entity.Type == EntityType.ENTITY_CLICKETY_CLACK and entity:ToNPC().State == 4 and collider:ToPlayer() and CurrentMinigameState == MinigameState.MINING then
        CurrentMinigameState = MinigameState.LOSING
        SFXManager:Play(minigameSounds.LOSE)
        WaveTransitionScreen:Play("Appear")

        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)
            player.ControlsEnabled = false
            player:PlayExtraAnimation("Sad")
        end
    end
end
too_underground.callbacks[ModCallbacks.MC_PRE_NPC_COLLISION] = too_underground.OnNPCCollision


--TEAR CALLBACKS
function too_underground:TearInit(tear)
    tear:GetSprite():ReplaceSpritesheet(0, "gfx/effects/too underground/tug_tears.png")
    tear:GetSprite():LoadGraphics()
end
too_underground.callbacks[ModCallbacks.MC_POST_TEAR_INIT] = too_underground.TearInit


function too_underground:TearUpdate(tear)
    local room = game:GetRoom()
    local rock = RocksInRoom[room:GetClampedGridIndex(tear.Position)]

    if rock then
        --Do normal stuff
        tear:Remove()
        rock.health = rock.health - 1
        SFXManager:Play(minigameSounds.TEAR_SPLASH)

        local newPoof = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, minigameEntityVariants.TEAR_POOF, 0, tear.Position + Vector(0, tear.Height), Vector.Zero, nil)
        newPoof:GetSprite():Play("Poof", true)

        --Remove if destroyed lmao
        if rock.health == 0 then
            BreakRock(room:GetClampedGridIndex(tear.Position), rock)
            return
        end

        --Set sprite
        if rock.type == rockTypes.HARDENED then
            rock.rockEntity:GetSprite():Play("Idle" .. math.ceil(rock.health/2))
        else
            rock.rockEntity:GetSprite():Play("Idle" .. rock.health)
        end
    end
end
too_underground.callbacks[ModCallbacks.MC_POST_TEAR_UPDATE] = too_underground.TearUpdate


function too_underground:TearCollision(_, collider)
    if collider.Type == EntityType.ENTITY_GENERIC_PROP then return true end
end
too_underground.callbacks[ModCallbacks.MC_PRE_TEAR_COLLISION] = too_underground.TearCollision


--EFFECT CALLBACKS
function too_underground:EffectInit(effect)
    if effect.Variant == EffectVariant.BOMB_EXPLOSION then
        effect:GetSprite():ReplaceSpritesheet(0, "gfx/effects/too underground/tug_explosion.png")
        effect:GetSprite():ReplaceSpritesheet(1, "a")
        effect:GetSprite():ReplaceSpritesheet(2, "a")
        effect:GetSprite():LoadGraphics()
    elseif effect.Variant == EffectVariant.TEAR_POOF_A or effect.Variant == EffectVariant.TEAR_POOF_B then
        effect:Remove()
        SFXManager:Play(minigameSounds.TEAR_SPLASH)

        local newPoof = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, minigameEntityVariants.TEAR_POOF, 0, effect.Position, Vector.Zero, nil)
        newPoof:GetSprite():Play("Poof", true)

        SFXManager:Stop(SoundEffect.SOUND_TEARIMPACTS)
        SFXManager:Stop(SoundEffect.SOUND_SPLATTER)
    elseif effect.Variant == EffectVariant.ROCK_EXPLOSION then
        effect:GetSprite():Load("gfx/tug_shockwave.anm2", true)
        effect:GetSprite():Play("Break", true)
    end
end
too_underground.callbacks[ModCallbacks.MC_POST_EFFECT_INIT] = too_underground.EffectInit


function too_underground:EffectUpdate(effect)
    if effect.Variant == EffectVariant.ROCK_EXPLOSION then
        for index, rock in pairs(RocksInRoom) do
            if rock.gridEntity.Position:Distance(effect.Position) < 45 then
                BreakRock(index, rock)
            end
        end
    elseif effect.Variant == EffectVariant.TINY_FLY then
        effect:Remove() --They should be removed but just in case
    end
end
too_underground.callbacks[ModCallbacks.MC_POST_EFFECT_UPDATE] = too_underground.EffectUpdate


--PICKUP CALLBACKS
function too_underground:PickupInit(pickup)
    if pickup.Variant == PickupVariant.PICKUP_COIN or pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE or
    pickup.Variant == PickupVariant.PICKUP_TRINKET then
        pickup:Remove()
    end
end
too_underground.callbacks[ModCallbacks.MC_POST_PICKUP_INIT] = too_underground.PickupInit


function too_underground:PickupCollision(pickup, collider)
    if pickup.Variant == minigameEntityVariants.CHEST and collider:ToPlayer() then
        pickup:GetSprite():Play("Open", true)
        CurrentMinigameState = MinigameState.WINNING
        SFXManager:Play(minigameSounds.WIN)
        WaveTransitionScreen:Play("Appear")

        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)
            player.ControlsEnabled = false
            player:PlayExtraAnimation("Happy")
        end
    end
end
too_underground.callbacks[ModCallbacks.MC_PRE_PICKUP_COLLISION] = too_underground.PickupCollision


--OTHER CALLBACKS
function too_underground:OnEntitySpawn(entityType, entityVariant, _, _, _, _, seed)
    if entityType == EntityType.ENTITY_EFFECT and 
    (entityVariant == EffectVariant.TINY_FLY or entityVariant == EffectVariant.POOF01) then
        return {EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_SPLAT, 0, seed}
    end
end
too_underground.callbacks[ModCallbacks.MC_PRE_ENTITY_SPAWN] = too_underground.OnEntitySpawn


function too_underground:OnFamiliarUpdate(FamiliarEnt)
    if FamiliarEnt.Variant ~= FamiliarVariant.ISAACS_HEART then return end

    --Move isaac's heart very very far away
    FamiliarEnt.Position = Vector(-99999999, -99999999)
end
too_underground.callbacks[ModCallbacks.MC_FAMILIAR_UPDATE] = too_underground.OnFamiliarUpdate


function too_underground:OnActiveUse(_, _, player)
    Isaac.Spawn(EntityType.ENTITY_MOVABLE_TNT, 0, 0, player.Position, Vector.Zero, nil)
    return false
end
too_underground.callbacks[ModCallbacks.MC_USE_ITEM] = too_underground.OnActiveUse


return too_underground