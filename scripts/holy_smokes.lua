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

    STALAGMITE_DROP = Isaac.GetSoundIdByName("tug explosion"),

    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}


local MinigameMusic = Isaac.GetMusicIdByName("bsw black beat wielder")

-- Entities
local MinigameEntityTypes = {
    CUSTOM_ENTITY = Isaac.GetEntityTypeByName("satan head HS")
}

local MinigameEntityVariants = {
    SATAN_HEAD = Isaac.GetEntityVariantByName("satan head HS"),

    STALAGMITE = Isaac.GetEntityVariantByName("stalagmite HS"),
    STALAGMITE_SHADOW = Isaac.GetEntityVariantByName("stalagmite shadow HS"),
    SHOCKWAVE = Isaac.GetEntityVariantByName("shockwave HS")
}

-- Constants
local MinigameConstants = {
    SATAN_HEAD_SPAWNING_OFFSET = Vector(0, 52),

    MAX_PLAYER_HEALTH = 5,
    MAX_PLAYER_POWER = 200,
}

-- Timers
local MinigameTimers = {}

-- States
local CurrentMinigameState = 0
local MinigameState = {
    INTRO = 0,
    NO_ATTACK = 1,
    BOSS_ATTACK = 2,
}

local CurrentSatanAttack = 0
local SatanAttack = {
    FALLING_STALAGMITES = 0
}

-- UI
local PlayerHealthUI = Sprite()
PlayerHealthUI:Load("gfx/hs_health_ui.anm2")
local PlayerPowerUI = Sprite()
PlayerPowerUI:Load("gfx/hs_power_ui.anm2")
local BossHealthUI = Sprite()
BossHealthUI:Load("gfx/hs_boss_health_ui.anm2")

-- Other variables
local PlayerHP = 0
local PlayerPower = 0
local SatanHead = nil

-- Stalagmite attack stuff
local IsLeft = false
local ShockWaveCount = 0


-- INIT MINIGAME
function holy_smokes:Init()
    -- Reset variables
    PlayerHP = MinigameConstants.MAX_PLAYER_HEALTH
    PlayerPower = 0

    CurrentMinigameState = MinigameState.NO_ATTACK
    CurrentSatanAttack = SatanAttack.FALLING_STALAGMITES

    -- Backdrop
    local backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop1x2Variant, 0, game:GetRoom():GetCenterPos(), Vector.Zero, nil)
    backdrop:GetSprite():ReplaceSpritesheet(0, "gfx/backdrop/hs_backdrop.png")
    backdrop:GetSprite():LoadGraphics()
    backdrop.DepthOffset = -1000

    -- Boss
    SatanHead = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.SATAN_HEAD, 0, game:GetRoom():GetCenterPos() + MinigameConstants.SATAN_HEAD_SPAWNING_OFFSET, Vector.Zero, nil)
    SatanHead:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE | EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)

    -- UI
    PlayerHealthUI:Play("Idle", true)
    PlayerPowerUI:Play("Idle", true)
    BossHealthUI:Play("Idle", true)

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
local function SpawnStalagmite()
    local room = game:GetRoom()

    local griPos = 211 and IsLeft or 223
    local stalagmiteFloorPos = room:GetGridPosition(griPos)

    local stalagmite = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.STALAGMITE, 0, stalagmiteFloorPos + Vector(0, -350), Vector.Zero, nil)
    local shadow = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.STALAGMITE_SHADOW, 0, stalagmiteFloorPos, Vector.Zero, stalagmite)
    shadow.DepthOffset = -50

    stalagmite:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE | EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
    stalagmite:GetSprite():Play("Fall")
    stalagmite.Child = shadow
    shadow:GetSprite():Play("Shadow")
end


local function SpawnNextShockWave()
    local room = game:GetRoom()

    local gridPos = 211 and IsLeft or 223
    gridPos = gridPos + ShockWaveCount * (1 and IsLeft or -1)
    local shockwavePos = room:GetGridPosition(gridPos)

    local shockwave = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.SHOCKWAVE, 0, shockwavePos, Vector.Zero, nil)
    shockwave:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE | EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
    shockwave:ClearEntityFlags(EntityFlag.FLAG_APPEAR)

    ShockWaveCount = ShockWaveCount + 1
end


local function ManageShockWaves()
    local shockwaves = Isaac.FindByType(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.SHOCKWAVE, -1)

    for _, shockwave in ipairs(shockwaves) do
        if shockwave:GetSprite():IsFinished("Break") then
            shockwave:Remove()
        elseif shockwave:GetSprite():GetFrame() == 10 then
            if ShockWaveCount == 4 then
                IsLeft = not IsLeft
                SpawnStalagmite()
            else
                SpawnNextShockWave()
            end
        end
    end
end


local function UpdateStalagmitesAttack()
    local stalagmites = Isaac.FindByType(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.STALAGMITE, -1)

    ManageShockWaves()

    if #stalagmites == 0 then
        SpawnStalagmite()
    else
        local stalagmite = stalagmites[1]

        if stalagmite:GetSprite():IsPlaying("Fall") then
            if stalagmite.Position.Y >= stalagmite.Child.Position.Y then
                stalagmite.Position = stalagmite.Child.Position
                stalagmite:GetSprite():Play("Break")
                stalagmite.Velocity = Vector(0, 0)

                stalagmite.Child:Remove()
                SFXManager:Play(MinigameSounds.STALAGMITE_DROP)

                SpawnNextShockWave()
            else
                stalagmite.Velocity = Vector(0, 20)
            end
        elseif stalagmite:GetSprite():IsFinished("Break") then
            stalagmite:Remove()
            CurrentMinigameState = MinigameState.NO_ATTACK
        end
    end
end


function holy_smokes:FrameUpdate()
    -- for i = 1, 800, 1 do
    --     if SFXManager:IsPlaying(i) then
    --         print(i)
    --     end
    -- end

    if CurrentMinigameState == MinigameState.NO_ATTACK then
        --Idle animation test
        if game:GetFrameCount() % 70 == 0 then
            SatanHead:GetSprite():Play("Breathe", true)
        end

        if SatanHead:GetSprite():IsFinished("Breathe") then
            SatanHead:GetSprite():Play("Idle", true)
        end
    elseif CurrentMinigameState == MinigameState.BOSS_ATTACK then

        if CurrentSatanAttack == SatanAttack.FALLING_STALAGMITES then
            UpdateStalagmitesAttack()
        end
    end
end
holy_smokes.callbacks[ModCallbacks.MC_POST_UPDATE] = holy_smokes.FrameUpdate


function holy_smokes:PlayerUpdate(player)
    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_RANGE)
    player:EvaluateItems()
end
holy_smokes.callbacks[ModCallbacks.MC_POST_PEFFECT_UPDATE] = holy_smokes.PlayerUpdate


local function RenderUI()
    --Health
    if PlayerHealthUI:IsPlaying("Flash") then
        PlayerHealthUI:Update()
    else
        PlayerHealthUI:Play("Idle")
        PlayerHealthUI:SetFrame(PlayerHP)
    end

    PlayerHealthUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) + Vector(-200, 0), Vector.Zero, Vector.Zero)

    --Power
    if PlayerPowerUI:IsPlaying("Flash") then
        PlayerPowerUI:Update()
    else
        PlayerPowerUI:Play("Idle")
        PlayerPowerUI:SetFrame(PlayerPower)
    end

    PlayerPowerUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) + Vector(-189, 0), Vector.Zero, Vector.Zero)

     --Boss health
     if BossHealthUI:IsPlaying("Flash") then
        BossHealthUI:Update()
    else
        BossHealthUI:Play("Idle")
        BossHealthUI:SetFrame(math.ceil(SatanHead.HitPoints / SatanHead.MaxHitPoints * 72))
    end

    BossHealthUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) + Vector(190, 0), Vector.Zero, Vector.Zero)
end


function holy_smokes:OnRender()
    RenderUI()
end
holy_smokes.callbacks[ModCallbacks.MC_POST_RENDER] = holy_smokes.OnRender


--ENTITY CALLBACKS
function holy_smokes:OnEntityDamage(tookDamage, _, _, _)
    if tookDamage:ToPlayer() then
        return false
    end
end
holy_smokes.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG] = holy_smokes.OnEntityDamage


function holy_smokes:OnEffectInit(effect)
    if effect.Variant == EffectVariant.TEAR_POOF_A or effect.Variant == EffectVariant.TEAR_POOF_B then
        SFXManager:Stop(SoundEffect.SOUND_TEARIMPACTS)
        SFXManager:Stop(SoundEffect.SOUND_SPLATTER)
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


function holy_smokes:OnCmd(command, arg)
	if command == "attack" then
		print("Attack set to " .. arg)
		CurrentSatanAttack = tonumber(arg)
        CurrentMinigameState = MinigameState.BOSS_ATTACK
	end
end
holy_smokes.callbacks[ModCallbacks.MC_EXECUTE_CMD] = holy_smokes.OnCmd

return holy_smokes