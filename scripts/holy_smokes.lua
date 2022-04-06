local holy_smokes = {}
local game = Game()
local rng = RNG()
local SFXManager = SFXManager()
local MusicManager = MusicManager()
----------------------------------------------
-- FANCY REQUIRE (Thanks manaphoenix <3)
----------------------------------------------
local function loadFile(loc, ...)
    local _, err = pcall(require, "")
    local modName = err:match("/mods/(.*)/%.lua")
    local path = "mods/" .. modName .. "/"

    return assert(loadfile(path .. loc .. ".lua"))(...)
end
local ArcadeCabinetVariables = loadFile("scripts/variables")

holy_smokes.callbacks = {}
holy_smokes.result = nil
holy_smokes.startingItems = {}

-- Sounds
local BannedSounds = {
    SoundEffect.SOUND_TEARS_FIRE,
    SoundEffect.SOUND_BLOODSHOOT,
    SoundEffect.SOUND_MEAT_IMPACTS,
    SoundEffect.SOUND_SUMMON_POOF,
    SoundEffect.SOUND_DOOR_HEAVY_CLOSE,
    SoundEffect.SOUND_DEATH_BURST_SMALL,
    SoundEffect.SOUND_MEATY_DEATHS,
    SoundEffect.SOUND_ANGRY_GURGLE
}


local MinigameSounds = {
    TEAR_SHOOT = Isaac.GetSoundIdByName("hs tear shoot"),
    TEAR_IMPACT = Isaac.GetSoundIdByName("hs tear impact"),

    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}


local MinigameMusic = Isaac.GetMusicIdByName("bsw black beat wielder")

-- Entities
local MinigameEntityTypes = {
    CUSTOM_BOSS = Isaac.GetEntityTypeByName("satan head HS")
}

local MinigameEntityVariants = {
    SATAN_HEAD = Isaac.GetEntityVariantByName("satan head HS")
}

-- Constants
local MinigameConstants = {
    SATAN_HEAD_SPAWNING_OFFSET = Vector(0, 52)
}

-- Timers
local MinigameTimers = {}

-- States
local CurrentMinigameState = 0
local MinigameState = {}

-- UI

-- Other variables
local SatanHead = nil


-- INIT MINIGAME
function holy_smokes:Init()

    -- Backdrop
    local backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop1x2Variant, 0,
        game:GetRoom():GetCenterPos(), Vector.Zero, nil)
    backdrop:GetSprite():ReplaceSpritesheet(0, "gfx/backdrop/hs_backdrop.png")
    backdrop:GetSprite():LoadGraphics()
    backdrop.DepthOffset = -1000

    -- Boss
    SatanHead = Isaac.Spawn(MinigameEntityTypes.CUSTOM_BOSS, MinigameEntityVariants.SATAN_HEAD, 0,
        game:GetRoom():GetCenterPos() + MinigameConstants.SATAN_HEAD_SPAWNING_OFFSET, Vector.Zero, nil)
    SatanHead:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE | EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)

    -- Prepare players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        for _, item in ipairs(holy_smokes.startingItems) do
            player:AddCollectible(item, 0, false)
        end

        --Set the spritesheets
        local playerSprite = player:GetSprite()
        playerSprite:Load("gfx/hs_isaac52.anm2", true)
        playerSprite:ReplaceSpritesheet(1, "gfx/characters/isaac_hs.png")
        playerSprite:ReplaceSpritesheet(4, "gfx/characters/isaac_hs.png")
        playerSprite:ReplaceSpritesheet(12, "gfx/characters/isaac_hs.png")
        playerSprite:LoadGraphics()

        local costume = Isaac.GetCostumeIdByPath("gfx/costumes/hs_halo.anm2")
        player:AddNullCostume(costume)
    end
end


-- UPDATE CALLBACKS
function holy_smokes:FrameUpdate()
    for i = 1, 800, 1 do
        if SFXManager:IsPlaying(i) then
            print(i)
        end
    end

    if game:GetFrameCount() % 70 == 0 then
        SatanHead:GetSprite():Play("Breathe", true)
    end

    if SatanHead:GetSprite():IsFinished("Breathe") then
        SatanHead:GetSprite():Play("Idle", true)
    end
end
holy_smokes.callbacks[ModCallbacks.MC_POST_UPDATE] = holy_smokes.FrameUpdate


function holy_smokes:PlayerUpdate(player)
    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_RANGE)
    player:EvaluateItems()
end
holy_smokes.callbacks[ModCallbacks.MC_POST_PEFFECT_UPDATE] = holy_smokes.PlayerUpdate


function holy_smokes:OnEntityDamage(tookDamage, _, _, _)
    if tookDamage:ToPlayer() then
        return false
    end
end
holy_smokes.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG] = holy_smokes.OnEntityDamage


function holy_smokes:OnEffectInit(effect)
    if effect.Variant == EffectVariant.TEAR_POOF_A or effect.Variant == EffectVariant.TEAR_POOF_B then
        SFXManager:Stop(SoundEffect.SOUND_TEARIMPACTS)
        if effect.Position.Y >= SatanHead.Position.Y - 40 then
            SFXManager:Play(MinigameSounds.TEAR_IMPACT)
        end

        effect:GetSprite():Load("gfx/hs_holy_tear_splash.anm2", true)
        effect:GetSprite():Play("Poof", true)
    end
end
holy_smokes.callbacks[ModCallbacks.MC_POST_EFFECT_INIT] = holy_smokes.OnEffectInit


function holy_smokes:OnTearFire(tear)
    SFXManager:Stop(SoundEffect.SOUND_TEARS_FIRE)

    if tear.Velocity:Normalized().Y > 0 or tear.Velocity:Normalized().X > 0.5 or tear.Velocity:Normalized().X < -0.5 then
        tear:Remove()
    else
        SFXManager:Play(MinigameSounds.TEAR_SHOOT)

        tear.Velocity = Vector(0, tear.Velocity.Y)
        tear:GetSprite():Load("gfx/hs_holy_tears.anm2", true)
        tear:GetSprite():Play("RegularTear6", true)
    end
end
holy_smokes.callbacks[ModCallbacks.MC_POST_FIRE_TEAR] = holy_smokes.OnTearFire


function holy_smokes:OnCache(player, cacheFlags)
    if cacheFlags == CacheFlag.CACHE_DAMAGE then
        player.Damage = 2
    end

    if cacheFlags == CacheFlag.CACHE_FIREDELAY then
        player.MaxFireDelay = 5
    end

    if cacheFlags == CacheFlag.CACHE_SHOTSPEED then
        player.ShotSpeed = 1.33
    end

    if cacheFlags == CacheFlag.CACHE_RANGE then
        player.TearRange = 500
    end
end
holy_smokes.callbacks[ModCallbacks.MC_EVALUATE_CACHE] = holy_smokes.OnCache


return holy_smokes