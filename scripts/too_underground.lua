local too_underground = {}
local game = Game()
local rng = RNG()
local SFXManager = SFXManager()
local MusicManager = MusicManager()
local ArcadeCabinetVariables

--Sounds
local BannedSounds = {
    SoundEffect.SOUND_TEARS_FIRE,
    SoundEffect.SOUND_BLOODSHOOT,
    SoundEffect.SOUND_MEAT_IMPACTS,
    SoundEffect.SOUND_SUMMON_POOF,
    SoundEffect.SOUND_DOOR_HEAVY_CLOSE,
    SoundEffect.SOUND_DOOR_HEAVY_OPEN,
    SoundEffect.SOUND_DEATH_BURST_SMALL,
    SoundEffect.SOUND_MEATY_DEATHS,
    SoundEffect.SOUND_ANGRY_GURGLE,
    SoundEffect.SOUND_TEARIMPACTS,
    SoundEffect.SOUND_SPLATTER,
    SoundEffect.SOUND_POT_BREAK,
    SoundEffect.SOUND_POT_BREAK_2,
    SoundEffect.SOUND_ROCK_CRUMBLE,
    SoundEffect.SOUND_BATTERYCHARGE
}

local ReplacementSounds = {
    [SoundEffect.SOUND_BOSS1_EXPLOSIONS] = Isaac.GetSoundIdByName("tug explosion"),
}

local MinigameSounds = {
    INTRO = Isaac.GetSoundIdByName("tug intro"),
    ROCK_BREAK = Isaac.GetSoundIdByName("tug rock break"),
    TEAR_SPLASH = Isaac.GetSoundIdByName("tug tear splash"),
    CHEST_DROP = Isaac.GetSoundIdByName("tug chest drop"),
    CHEST_OPEN = Isaac.GetSoundIdByName("tug chest open"),
    BONE_GUY_RISE_DEAD = Isaac.GetSoundIdByName("tug skeleton rise dead"),
    DYNAMITE_PICKUP = Isaac.GetSoundIdByName("tug dynamite"),
    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}

local MinigameMusic = Isaac.GetMusicIdByName("tug under beats")

--Entities
local MinigameEntityVariants = {
    TEAR_POOF = Isaac.GetEntityVariantByName("tear poof TUG"),
    ROCK_ENTITY = Isaac.GetEntityVariantByName("rock TUG"),
    BONE_GUY = Isaac.GetEntityVariantByName("bone guy TUG"),
    CHEST = Isaac.GetEntityVariantByName("chest TUG"),
    DYNAMITE = Isaac.GetEntityVariantByName("dynamite TUG")
}

--Constants
local MinigameConstants = {
    CUSTOM_TNT_ACTIVE = Isaac.GetItemIdByName("TUG minecrafter"),

    ROCK_TYPES = {
        DEFAULT = 1,
        HARDENED = 2,
    },

    INTRO_SCREEN_MAX_FRAMES = 120,

    MAX_ROCK_COUNT = 170
}

--Timers
local MinigameTimers = {
    IntroScreenTimer = 0
}

--States
local MinigameState = {
    INTRO_SCREEN = 1,
    MINING = 2,
    WINNING = 3,
    LOSING = 4
}
local CurrentMinigameState = MinigameState.MINING

--UI
local StoneMeterUI = Sprite()
StoneMeterUI:Load("gfx/tug_rockmeter.anm2", true)
StoneMeterUI:Play("Idle", true)
local MinecraferUI = Sprite()
MinecraferUI:Load("gfx/tug_minecrafter_ui.anm2", true)
MinecraferUI:Play("Idle", true)
local WaveTransitionScreen = Sprite()
WaveTransitionScreen:Load("gfx/minigame_transition.anm2", false)
WaveTransitionScreen:ReplaceSpritesheet(0, "gfx/effects/too underground/tug_intro.png")
WaveTransitionScreen:LoadGraphics()

--Other Variables
local RocksInRoom = {}
local BrokenRocks = 0

local InmortalBoneGuy = nil
local RemoveBoneGuys = false
local LastRockPosition = nil

local BoneGuysPositions = {}
local BatteriesPositions = {}


local function AddRock(gridEntity, index)
    local rock = {}
    rock.rockEntity = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.ROCK_ENTITY, 0, gridEntity.Position - Vector(26, 26), Vector.Zero, nil)
    rock.gridEntity = gridEntity
    rock.gridEntity:GetSprite():ReplaceSpritesheet(0, "a")
    rock.gridEntity:GetSprite():LoadGraphics()

    if gridEntity:GetType() == GridEntityType.GRID_ROCK_ALT then
        rock.health = 8
        rock.type = MinigameConstants.ROCK_TYPES.HARDENED
        rock.rockEntity:GetSprite():ReplaceSpritesheet(0, "gfx/grid/tug_hardened_rock.png")
    else
        rock.health = 4
        rock.type = MinigameConstants.ROCK_TYPES.DEFAULT
    end

    rock.rockEntity:GetSprite():LoadGraphics()
    RocksInRoom[index] = rock
end


local function BreakRock(index, rock)
    local room = game:GetRoom()

    rock.rockEntity:Remove()
    room:RemoveGridEntity(index, 0, false)
    RocksInRoom[index] = nil
    SFXManager:Play(MinigameSounds.ROCK_BREAK)
    local rockBreak = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.TEAR_POOF, 0, rock.gridEntity.Position, Vector.Zero, nil)
    rockBreak:GetSprite():Load("gfx/tug_rock_break.anm2", true)
    rockBreak:GetSprite():Play("Poof", true)

    BrokenRocks = BrokenRocks + 1

    if BrokenRocks == MinigameConstants.MAX_ROCK_COUNT then
        LastRockPosition = rock.gridEntity.Position
    end

    --Spawn shockwave
    local chanceToSpawn = 7
    if rock.type == MinigameConstants.ROCK_TYPES.HARDENED then chanceToSpawn = 20 end

    if chanceToSpawn >= rng:RandomInt(100) then
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SHOCKWAVE_RANDOM, 0, rock.gridEntity.Position, Vector.Zero, nil)
    end
end


--UPDATE CALLBACKS
local function ManageSFX()
    --Completely stop banned sounds
    for _, sound in ipairs(BannedSounds) do
        if SFXManager:IsPlaying(sound) then SFXManager:Stop(sound) end
    end

    --Replace sounds to be changed
    for originalSound, replacement in pairs(ReplacementSounds) do
        if SFXManager:IsPlaying(originalSound) then
            SFXManager:Stop(originalSound)
            SFXManager:Play(replacement)
        end
    end

    --Play grunts
    if #Isaac.FindByType(EntityType.ENTITY_GAPER, -1, -1) > 0 and not SFXManager:IsPlaying(MinigameSounds.GAPER_GRUNT) then
        SFXManager:Play(MinigameSounds.GAPER_GRUNT)
    end
end


local function UpdateIntroScreen()
    if CurrentMinigameState ~= MinigameState.INTRO_SCREEN then return end

    MinigameTimers.IntroScreenTimer = MinigameTimers.IntroScreenTimer - 1

    --Spawn boneguys in waves
    if MinigameTimers.IntroScreenTimer % 6 == 0 and #BoneGuysPositions > 0 then
        local pos = BoneGuysPositions[#BoneGuysPositions]
        Isaac.Spawn(EntityType.ENTITY_CLICKETY_CLACK, MinigameEntityVariants.BONE_GUY, 0, pos, Vector.Zero, nil)
        BoneGuysPositions[#BoneGuysPositions] = nil
    end

    if MinigameTimers.IntroScreenTimer == 0 then
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)

            player.ControlsEnabled = true
        end

        --Spawn batteries because they keep getting deleted????
        for _, pos in ipairs(BatteriesPositions) do
            local battery = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.DYNAMITE, 0, pos, Vector.Zero, nil)
            battery:GetSprite():Play("Idle", true)
        end

        WaveTransitionScreen:Play("Appear", true)
        MusicManager:Resume()
        CurrentMinigameState = MinigameState.MINING
    end
end


local function CheckForWin()
    if CurrentMinigameState == MinigameState.INTRO_SCREEN then return end
    if BrokenRocks ~= MinigameConstants.MAX_ROCK_COUNT or #Isaac.FindByType(EntityType.ENTITY_PICKUP, MinigameEntityVariants.CHEST, -1) ~= 0 then return end

    RemoveBoneGuys = true
    local chest = Isaac.Spawn(EntityType.ENTITY_PICKUP, MinigameEntityVariants.CHEST, 0, LastRockPosition, Vector.Zero, nil)
    chest:AddEntityFlags(EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK | EntityFlag.FLAG_NO_KNOCKBACK)
end


local function RemovePickedBatteries()
    for _, battery in ipairs(Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.DYNAMITE, -1)) do
        if battery:GetSprite():IsFinished("Collect") then
            battery:Remove()
        end
    end
end


local function RemoveBoneGuysWin()
    if not RemoveBoneGuys or #Isaac.FindByType(EntityType.ENTITY_CLICKETY_CLACK, MinigameEntityVariants.BONE_GUY, -1) == 0 then return end
    if game:GetFrameCount() % 3 ~= 0 then return end

    local boneGuyToRemove = Isaac.FindByType(EntityType.ENTITY_CLICKETY_CLACK, MinigameEntityVariants.BONE_GUY, -1)[1]
    boneGuyToRemove:Remove()

    local rockBreak = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.TEAR_POOF, 0, boneGuyToRemove.Position, Vector.Zero, nil)
    rockBreak:GetSprite():Load("gfx/tug_rock_break.anm2", true)
    rockBreak:GetSprite():Play("Poof", true)
end


function too_underground:OnFrameUpdate()
    --Remove poofs
    for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.TEAR_POOF, 0)) do
        if entity:GetSprite():IsFinished("Poof") then entity:Remove() end
    end

    InmortalBoneGuy.Position = Vector(-99999999, -99999999)

    UpdateIntroScreen()

    RemovePickedBatteries()

    RemoveBoneGuysWin()

    CheckForWin()
end


local function FlipPlayer(player)
    --Flip the player if they shoot left and they aren't already moving left
    player.FlipX = Input.IsActionPressed(ButtonAction.ACTION_SHOOTLEFT, player.ControllerIndex) and not Input.IsActionPressed(ButtonAction.ACTION_LEFT, player.ControllerIndex) or
    Input.IsActionPressed(ButtonAction.ACTION_SHOOTRIGHT, player.ControllerIndex) and Input.IsActionPressed(ButtonAction.ACTION_LEFT, player.ControllerIndex)
end


local function CheckIfPickUpBattery(player)
    if player:GetActiveCharge() > 0 then return end

    local entitiesInRadius = Isaac.FindInRadius(player.Position, 10)
    local foundEntity = nil

    for _, entity in ipairs(entitiesInRadius) do
        if entity.Type == EntityType.ENTITY_GENERIC_PROP and entity.Variant == MinigameEntityVariants.DYNAMITE and not entity:GetSprite():IsPlaying("Collect") then
            foundEntity = entity
            break
        end
    end

    if foundEntity then
        foundEntity:GetSprite():Play("Collect", true)
        SFXManager:Play(MinigameSounds.DYNAMITE_PICKUP)

        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player2 = game:GetPlayer(i)

            player2:SetActiveCharge(1)
        end
    end
end


function too_underground:OnPlayerUpdate(player)
    FlipPlayer(player)

    CheckIfPickUpBattery(player)

    if CurrentMinigameState == MinigameState.WINNING then
        player:GetSprite():SetFrame(5)
    end
end


local function RenderIntro()
    if CurrentMinigameState ~= MinigameState.INTRO_SCREEN then return end

    WaveTransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
end


local function RenderUI()
    --Rockmeter
    local stonemeterFrame = math.floor((BrokenRocks / MinigameConstants.MAX_ROCK_COUNT) * 10)
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
    if CurrentMinigameState == MinigameState.INTRO_SCREEN or CurrentMinigameState == MinigameState.MINING then return end

    if WaveTransitionScreen:IsFinished("Appear") then
        for i = 0, game:GetNumPlayers() - 1, 1 do
            local player = game:GetPlayer(i)
            player:RemoveCollectible(MinigameConstants.CUSTOM_TNT_ACTIVE)
        end

        if CurrentMinigameState == MinigameState.WINNING then
            ArcadeCabinetVariables.CurrentMinigameResult = ArcadeCabinetVariables.MinigameResult.WIN
        else
            ArcadeCabinetVariables.CurrentMinigameResult = ArcadeCabinetVariables.MinigameResult.LOSE
        end
    end

    if SFXManager:IsPlaying(MinigameSounds.WIN) then
        WaveTransitionScreen:SetFrame(0)
    end

    WaveTransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
    WaveTransitionScreen:Update()
end


function too_underground:OnRender()
    ManageSFX()

    RenderUI()

    RenderIntro()

    RenderFadeOut()
end


--NPC CALLBACKS
function too_underground:OnTNTInit(tnt)
    tnt:GetSprite():ReplaceSpritesheet(0, "gfx/grid/tug_movable_tnt.png")
    tnt:GetSprite():LoadGraphics()
end


function too_underground:OnSpiderInit(spider)
    spider:Remove()
end


function too_underground:OnTNTUpdate(tnt)
    if tnt:GetData().hasExploded or tnt.State ~= NpcState.STATE_SPECIAL then return end

    tnt:GetData().hasExploded = true

    for index, rock in pairs(RocksInRoom) do
        if tnt.Position:Distance(rock.gridEntity.Position) < 110 then
            BreakRock(index, rock)
        end
    end
end


function too_underground:OnBoneGuyUpdate(boneGuy)
    local data = boneGuy:GetData()

    if data.LastState and data.LastState == 13 and data.LastState ~= boneGuy.State then
        SFXManager:Play(MinigameSounds.BONE_GUY_RISE_DEAD)
    end

    data.LastState = boneGuy.State
end


function too_underground:OnPlayerDamage()
    return false
end


function too_underground:OnBoneGuyDamage(tookDamage, _, damageFlags)
    if damageFlags == DamageFlag.DAMAGE_CRUSH then
        return false
    end

    if tookDamage:ToNPC().State == 4 then
        tookDamage.HitPoints = 0
        SFXManager:Play(MinigameSounds.BONE_GUY_RISE_DEAD)
    end
end


function too_underground:OnNPCCollision(entity, collider)
    if entity:ToNPC().State ~= 4 or not collider:ToPlayer() or CurrentMinigameState ~= MinigameState.MINING then return end

    CurrentMinigameState = MinigameState.LOSING
    MusicManager:VolumeSlide(0, 1)
    SFXManager:Play(MinigameSounds.LOSE)
    WaveTransitionScreen:Play("Appear")

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        player.ControlsEnabled = false
        player:PlayExtraAnimation("Sad")
    end
end


--TEAR CALLBACKS
function too_underground:TearInit(tear)
    tear:GetSprite():ReplaceSpritesheet(0, "gfx/effects/too underground/tug_tears.png")
    tear:GetSprite():LoadGraphics()
end


function too_underground:TearUpdate(tear)
    local room = game:GetRoom()
    local rock = RocksInRoom[room:GetClampedGridIndex(tear.Position)]

    if rock then
        --Do normal stuff
        tear:Remove()
        rock.health = rock.health - 1
        SFXManager:Play(MinigameSounds.TEAR_SPLASH)

        local newPoof = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.TEAR_POOF, 0, tear.Position + Vector(0, tear.Height), Vector.Zero, nil)
        newPoof:GetSprite():Play("Poof", true)

        --Remove if destroyed lmao
        if rock.health == 0 then
            BreakRock(room:GetClampedGridIndex(tear.Position), rock)
            return
        end

        --Set sprite
        if rock.type == MinigameConstants.ROCK_TYPES.HARDENED then
            rock.rockEntity:GetSprite():Play("Idle" .. math.ceil(rock.health/2))
        else
            rock.rockEntity:GetSprite():Play("Idle" .. rock.health)
        end
    end
end


function too_underground:TearCollision(_, collider)
    if collider.Type == EntityType.ENTITY_GENERIC_PROP then return true end
end


--EFFECT CALLBACKS
function too_underground:OnBombExplosionInit(explosion)
    explosion:GetSprite():ReplaceSpritesheet(0, "gfx/effects/too underground/tug_explosion.png")
    explosion:GetSprite():ReplaceSpritesheet(1, "")
    explosion:GetSprite():ReplaceSpritesheet(2, "")
    explosion:GetSprite():LoadGraphics()
end


function too_underground:OnTearPoofInit(poof)
    poof:Remove()
    SFXManager:Play(MinigameSounds.TEAR_SPLASH)

    local newPoof = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.TEAR_POOF, 0, poof.Position, Vector.Zero, nil)
    newPoof:GetSprite():Play("Poof", true)

    SFXManager:Stop(SoundEffect.SOUND_TEARIMPACTS)
    SFXManager:Stop(SoundEffect.SOUND_SPLATTER)
end


function too_underground:OnRockExplosionInit(explosion)
    explosion:GetSprite():Load("gfx/tug_shockwave.anm2", true)
    explosion:GetSprite():Play("Break", true)
end


function too_underground:OnRockExplosionUpdate(explosion)
    for index, rock in pairs(RocksInRoom) do
        if rock.gridEntity.Position:Distance(explosion.Position) < 45 then
            BreakRock(index, rock)
        end
    end
end


function too_underground:OnTinyFlyUpdate(fly)
    fly:Remove()
end


--PICKUP CALLBACKS
function too_underground:OnRemovablePickup(pickup)
    pickup:Remove()
end


function too_underground:PickupCollision(pickup, collider)
    if not collider:ToPlayer() then return end

    pickup:GetSprite():Play("Open", true)
    CurrentMinigameState = MinigameState.WINNING
    MusicManager:VolumeSlide(0, 1)
    SFXManager:Play(MinigameSounds.WIN)
    WaveTransitionScreen:Play("Appear")

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        player.ControlsEnabled = false
        player:PlayExtraAnimation("Happy")
    end
end


--OTHER CALLBACKS
function too_underground:OnEntitySpawn(entityType, entityVariant, _, _, _, _, seed)
    if entityType == EntityType.ENTITY_EFFECT and 
    (entityVariant == EffectVariant.TINY_FLY or entityVariant == EffectVariant.POOF01) then
        return {EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_SPLAT, 0, seed}
    end
end


function too_underground:OnActiveUse(_, _, player)
    local tnt = Isaac.Spawn(EntityType.ENTITY_MOVABLE_TNT, 0, 0, player.Position, Vector.Zero, nil)
    tnt:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    return false
end


--INIT MINIGAME
function too_underground:AddCallbacks(mod)
    --Generic updates
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, too_underground.OnFrameUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, too_underground.OnPlayerUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, too_underground.OnRender)

    --Npc callbacks
    mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, too_underground.OnTNTInit, EntityType.ENTITY_MOVABLE_TNT)
    mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, too_underground.OnSpiderInit, EntityType.ENTITY_SPIDER)

    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, too_underground.OnTNTUpdate, EntityType.ENTITY_MOVABLE_TNT)
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, too_underground.OnBoneGuyUpdate, EntityType.ENTITY_CLICKETY_CLACK)

    mod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, too_underground.OnNPCCollision, EntityType.ENTITY_CLICKETY_CLACK)

    --Damage callback
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, too_underground.OnPlayerDamage, EntityType.ENTITY_PLAYER)
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, too_underground.OnBoneGuyDamage, EntityType.ENTITY_CLICKETY_CLACK)

    --Tear callbacks
    mod:AddCallback(ModCallbacks.MC_POST_TEAR_INIT, too_underground.TearInit)
    mod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, too_underground.TearUpdate)
    mod:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, too_underground.TearCollision)

    --Effect callbacks
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, too_underground.OnBombExplosionInit, EffectVariant.BOMB_EXPLOSION)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, too_underground.OnTearPoofInit, EffectVariant.TEAR_POOF_A)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, too_underground.OnTearPoofInit, EffectVariant.TEAR_POOF_B)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, too_underground.OnRockExplosionInit, EffectVariant.ROCK_EXPLOSION)

    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, too_underground.OnRockExplosionUpdate, EffectVariant.ROCK_EXPLOSION)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, too_underground.OnTinyFlyUpdate, EffectVariant.TINY_FLY)

    --Pickup callbacks
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, too_underground.OnRemovablePickup, PickupVariant.PICKUP_COIN)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, too_underground.OnRemovablePickup, PickupVariant.PICKUP_COLLECTIBLE)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, too_underground.OnRemovablePickup, PickupVariant.PICKUP_TRINKET)

    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, too_underground.OnRemovablePickup, PickupVariant.PICKUP_COIN)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, too_underground.OnRemovablePickup, PickupVariant.PICKUP_COLLECTIBLE)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, too_underground.OnRemovablePickup, PickupVariant.PICKUP_TRINKET)

    mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, too_underground.PickupCollision, MinigameEntityVariants.CHEST)

    --Other callbacks
    mod:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, too_underground.OnEntitySpawn)
    mod:AddCallback(ModCallbacks.MC_USE_ITEM, too_underground.OnActiveUse)
end


function too_underground:RemoveCallbacks(mod)
    --Generic updates
    mod:RemoveCallback(ModCallbacks.MC_POST_UPDATE, too_underground.OnFrameUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, too_underground.OnPlayerUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_RENDER, too_underground.OnRender)

    --Npc callbacks
    mod:RemoveCallback(ModCallbacks.MC_POST_NPC_INIT, too_underground.OnTNTInit, EntityType.ENTITY_MOVABLE_TNT)
    mod:RemoveCallback(ModCallbacks.MC_POST_NPC_INIT, too_underground.OnSpiderInit, EntityType.ENTITY_SPIDER)

    mod:RemoveCallback(ModCallbacks.MC_NPC_UPDATE, too_underground.OnTNTUpdate, EntityType.ENTITY_MOVABLE_TNT)
    mod:RemoveCallback(ModCallbacks.MC_NPC_UPDATE, too_underground.OnBoneGuyUpdate, EntityType.ENTITY_CLICKETY_CLACK)

    mod:RemoveCallback(ModCallbacks.MC_PRE_NPC_COLLISION, too_underground.OnNPCCollision, EntityType.ENTITY_CLICKETY_CLACK)

    --Damage callback
    mod:RemoveCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, too_underground.OnPlayerDamage, EntityType.ENTITY_PLAYER)
    mod:RemoveCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, too_underground.OnBoneGuyDamage, EntityType.ENTITY_CLICKETY_CLACK)

    --Tear callbacks
    mod:RemoveCallback(ModCallbacks.MC_POST_TEAR_INIT, too_underground.TearInit)
    mod:RemoveCallback(ModCallbacks.MC_POST_TEAR_UPDATE, too_underground.TearUpdate)
    mod:RemoveCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, too_underground.TearCollision)

    --Effect callbacks
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_INIT, too_underground.OnBombExplosionInit, EffectVariant.BOMB_EXPLOSION)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_INIT, too_underground.OnTearPoofInit, EffectVariant.TEAR_POOF_A)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_INIT, too_underground.OnTearPoofInit, EffectVariant.TEAR_POOF_B)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_INIT, too_underground.OnRockExplosionInit, EffectVariant.ROCK_EXPLOSION)

    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, too_underground.OnRockExplosionUpdate, EffectVariant.ROCK_EXPLOSION)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, too_underground.OnTinyFlyUpdate, EffectVariant.TINY_FLY)

    --Pickup callbacks
    mod:RemoveCallback(ModCallbacks.MC_POST_PICKUP_INIT, too_underground.OnRemovablePickup, PickupVariant.PICKUP_COIN)
    mod:RemoveCallback(ModCallbacks.MC_POST_PICKUP_INIT, too_underground.OnRemovablePickup, PickupVariant.PICKUP_COLLECTIBLE)
    mod:RemoveCallback(ModCallbacks.MC_POST_PICKUP_INIT, too_underground.OnRemovablePickup, PickupVariant.PICKUP_TRINKET)

    mod:RemoveCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, too_underground.OnRemovablePickup, PickupVariant.PICKUP_COIN)
    mod:RemoveCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, too_underground.OnRemovablePickup, PickupVariant.PICKUP_COLLECTIBLE)
    mod:RemoveCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, too_underground.OnRemovablePickup, PickupVariant.PICKUP_TRINKET)

    mod:RemoveCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, too_underground.PickupCollision, MinigameEntityVariants.CHEST)

    --Other callbacks
    mod:RemoveCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, too_underground.OnEntitySpawn)
    mod:RemoveCallback(ModCallbacks.MC_USE_ITEM, too_underground.OnActiveUse)
end


function too_underground:Init(mod, variables)
    ArcadeCabinetVariables = variables
    too_underground:AddCallbacks(mod)

    local room = game:GetRoom()

    --Reset variables
    too_underground.result = nil
    RocksInRoom = {}
    BrokenRocks = 0
    RemoveBoneGuys = false
    BoneGuysPositions = {}
    BatteriesPositions = {}
    CurrentMinigameState = MinigameState.INTRO_SCREEN

    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    --Intro screen
    MinigameTimers.IntroScreenTimer = MinigameConstants.INTRO_SCREEN_MAX_FRAMES
    WaveTransitionScreen:Play("Idle", true)
    WaveTransitionScreen:SetFrame(0)
    SFXManager:Play(MinigameSounds.INTRO)

    --Music
    MusicManager:Play(MinigameMusic, 1)
    MusicManager:UpdateVolume()
    MusicManager:Pause()

    --Save bone guys positions
    for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_CLICKETY_CLACK, -1, -1)) do
        BoneGuysPositions[#BoneGuysPositions+1] = entity.Position
        entity:Remove()
    end

    --Save batteries positions
    for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LIL_BATTERY, -1)) do
        BatteriesPositions[#BatteriesPositions+1] = entity.Position
        entity:Remove()
    end

    --Spawn invinvible bone guy
    InmortalBoneGuy = Isaac.Spawn(EntityType.ENTITY_CLICKETY_CLACK, 0, 0, Vector(-99999999, -99999999), Vector.Zero, nil)
    InmortalBoneGuy:GetSprite():ReplaceSpritesheet(0, "a")
    InmortalBoneGuy:GetSprite():ReplaceSpritesheet(1, "a")
    InmortalBoneGuy:GetSprite():LoadGraphics()

    --Spawn backdrop
    local backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop1x2Variant, 0, game:GetRoom():GetCenterPos(), Vector.Zero, nil)
    backdrop:GetSprite():ReplaceSpritesheet(0, "gfx/backdrop/tug_backdrop.png")
    backdrop:GetSprite():LoadGraphics()
    backdrop.DepthOffset = -1000

    --Add rocks to the list
    for i = 16, 223, 1 do
        local gridEntity = room:GetGridEntity(i)
        if gridEntity and gridEntity:ToRock() then AddRock(gridEntity, i) end
    end

    --Set players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        --Items
        player:AddCollectible(MinigameConstants.CUSTOM_TNT_ACTIVE, 0, false)

        player.ControlsEnabled = false

        --Set spritesheet
        local playerSprite = player:GetSprite()
        playerSprite:Load("gfx/tug_isaac52.anm2", true)
        playerSprite:ReplaceSpritesheet(4, "a") --Empty head xd
        playerSprite:LoadGraphics()
    end
end



return too_underground