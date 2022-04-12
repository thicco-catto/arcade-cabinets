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
    SATAN_STALAGMITE_SCREAM = Isaac.GetSoundIdByName("jc special attack"),
    SHOCKWAVE = Isaac.GetSoundIdByName("tug rock break"),

    SPIT = Isaac.GetSoundIdByName("hs spit"),

    OPEN_CRACK = Isaac.GetSoundIdByName("hs open crack"),
    FIRE_LOOP = Isaac.GetSoundIdByName("hs fire loop"),

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
    SHOCKWAVE = Isaac.GetEntityVariantByName("shockwave HS"),

    FLOOR_CRACK = Isaac.GetEntityVariantByName("floor crack HS"),
    FIRE_GEYSER = Isaac.GetEntityVariantByName("fire geyser HS")
}

-- Constants
local MinigameConstants = {
    SATAN_HEAD_SPAWNING_OFFSET = Vector(4.5, 52),

    STALAGMITE_HEIGHT = 400,
    STALAGMITE_SPEED = 20,
    MAX_SHOCKWAVE_COUNT = 10,
    FRAMES_FOR_NEXT_SHOCKWAVE = 6,
    SHOCKWAVE_COUNT_TO_STALAGMITE = 8,
    MAX_STALAGMITES_NUM = 4,

    DIAMOND_PROJECTILE_SHOOTING_PATTERN = {
        0,
        1,
        2,
        1
    },
    AMOUNT_OF_PROJECTILE_WAVES_DIAMOND = 16,

    FLOOR_CRACK_PATTERN = {
        3,
        4,
        5,
        6
    },

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
    FALLING_STALAGMITES = 0,
    DIAMOND_PROJECTILES = 1,
    FLOOR_CRACKING = 2,
    NOSE_LASER = 3
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

local FallenStalagmitesNum = 0

local DiamondProjectileWavesNum = 0

local FloorCracksNum = 0

-- INIT MINIGAME
function holy_smokes:Init()
    -- Reset variables
    PlayerHP = MinigameConstants.MAX_PLAYER_HEALTH
    PlayerPower = 0

    CurrentMinigameState = MinigameState.NO_ATTACK
    CurrentSatanAttack = SatanAttack.FALLING_STALAGMITES

    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    -- Backdrop
    local backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop1x2Variant, 0, game:GetRoom():GetCenterPos(), Vector.Zero, nil)
    backdrop:GetSprite():ReplaceSpritesheet(0, "gfx/backdrop/hs_backdrop.png")
    backdrop:GetSprite():LoadGraphics()
    backdrop.DepthOffset = -1000

    -- Boss
    SatanHead = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.SATAN_HEAD, 0, game:GetRoom():GetCenterPos() + MinigameConstants.SATAN_HEAD_SPAWNING_OFFSET, Vector.Zero, nil)
    SatanHead:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE | EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
    SatanHead:ClearEntityFlags(EntityFlag.FLAG_APPEAR)

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
local function SpawnStalagmite(spawnLeft)
    local room = game:GetRoom()

    local gridPos = spawnLeft and 211 or 223
    local stalagmiteFloorPos = room:GetGridPosition(gridPos)

    local stalagmite = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.STALAGMITE, 0, stalagmiteFloorPos + Vector(0, -MinigameConstants.STALAGMITE_HEIGHT), Vector.Zero, nil)
    local shadow = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.STALAGMITE_SHADOW, 0, stalagmiteFloorPos, Vector.Zero, stalagmite)
    shadow.DepthOffset = -50

    stalagmite:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE | EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
    stalagmite:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    stalagmite:GetData().SpawnLeft = spawnLeft
    stalagmite.Child = shadow

    stalagmite:GetSprite():Play("Fall")
    shadow:GetSprite():Play("Shadow")

    SatanHead:GetSprite():Play("StalagmiteScream", true)

    FallenStalagmitesNum = FallenStalagmitesNum + 1
end


local function SpawnNextShockWave(spawnLeft, shockWaveCount)
    local room = game:GetRoom()

    local gridPos = spawnLeft and 211 or 223
    gridPos = gridPos + (shockWaveCount * (spawnLeft and 1 or -1))
    local shockwavePos = room:GetGridPosition(gridPos)

    local shockwave = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.SHOCKWAVE, 0, shockwavePos, Vector.Zero, nil)
    shockwave:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE | EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
    shockwave:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    shockwave:GetData().SpawnLeft = spawnLeft
    shockwave:GetData().ShockWaveCount = shockWaveCount

    shockwave:GetSprite():Play("Break", true)
    SFXManager:Play(MinigameSounds.SHOCKWAVE)
end


local function ManageStalagmite()
    local stalagmites = Isaac.FindByType(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.STALAGMITE, -1)

    if #stalagmites == 0 then return end

    local stalagmite = stalagmites[1]

    if stalagmite:GetSprite():IsPlaying("Fall") then
        if stalagmite.Position.Y >= stalagmite.Child.Position.Y then
            stalagmite.Position = stalagmite.Child.Position
            stalagmite:GetSprite():Play("Break")
            stalagmite.Velocity = Vector(0, 0)

            stalagmite.Child:Remove()
            SFXManager:Play(MinigameSounds.STALAGMITE_DROP)

            SpawnNextShockWave(stalagmite:GetData().SpawnLeft, 0)
        else
            stalagmite.Velocity = Vector(0, MinigameConstants.STALAGMITE_SPEED)
        end
    elseif stalagmite:GetSprite():IsFinished("Break") then
        stalagmite:Remove()
        --CurrentMinigameState = MinigameState.NO_ATTACK
    end
end


local function ManageShockWaves()
    local shockwaves = Isaac.FindByType(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.SHOCKWAVE, -1)

    for _, shockwave in ipairs(shockwaves) do
        if shockwave:GetSprite():IsFinished("Break") then
            if shockwave:GetData().ShockWaveCount == MinigameConstants.MAX_SHOCKWAVE_COUNT and
            FallenStalagmitesNum == MinigameConstants.MAX_STALAGMITES_NUM and
            #Isaac.FindByType(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.STALAGMITE, -1) == 0 then
                CurrentMinigameState = MinigameState.NO_ATTACK
            end

            shockwave:Remove()
        elseif shockwave:GetSprite():GetFrame() == MinigameConstants.FRAMES_FOR_NEXT_SHOCKWAVE then
            local data = shockwave:GetData()

            if data.ShockWaveCount ~= MinigameConstants.MAX_SHOCKWAVE_COUNT then
                SpawnNextShockWave(data.SpawnLeft, data.ShockWaveCount + 1)
            end

            if data.ShockWaveCount == MinigameConstants.SHOCKWAVE_COUNT_TO_STALAGMITE and FallenStalagmitesNum ~= MinigameConstants.MAX_STALAGMITES_NUM then
                SpawnStalagmite(not data.SpawnLeft)
            end
        end
    end
end


local function ManageSatanStalamiteAttack()
    if SatanHead:GetSprite():IsFinished("StalagmiteScream") then
        SatanHead:GetSprite():Play("Idle", true)
    elseif SatanHead:GetSprite():IsPlaying("StalagmiteScream") and SatanHead:GetSprite():GetFrame() == 6 then
        SFXManager:Play(MinigameSounds.SATAN_STALAGMITE_SCREAM)
        game:ShakeScreen(14)
    end
end


local function UpdateStalagmitesAttack()
    ManageStalagmite()

    ManageShockWaves()

    ManageSatanStalamiteAttack()
end


local function InitStalagmiteAttack()
    FallenStalagmitesNum = 0
    SpawnStalagmite(true)
end


local function ShootDiamondProjectiles()
    local spawningPos = SatanHead.Position + Vector(0, 25)
    local spawningSpeed = (game:GetPlayer(0).Position - spawningPos):Normalized() * 10
    local projectileType = MinigameConstants.DIAMOND_PROJECTILE_SHOOTING_PATTERN[(DiamondProjectileWavesNum % #MinigameConstants.DIAMOND_PROJECTILE_SHOOTING_PATTERN) + 1]
    local params = ProjectileParams()
    params.BulletFlags = ProjectileFlags.NO_WALL_COLLIDE
    params.Spread = 1
    SatanHead:ToNPC():FireProjectiles(spawningPos, spawningSpeed, projectileType, params)
end


local function ManageSatanDiamondProjectileAttack()
    if SatanHead:GetSprite():IsFinished("ShootDiamondProjectiles") then
        if DiamondProjectileWavesNum == MinigameConstants.AMOUNT_OF_PROJECTILE_WAVES_DIAMOND then
            SatanHead:GetSprite():Play("Idle", true)
            CurrentMinigameState = MinigameState.NO_ATTACK
        else
            SatanHead:GetSprite():Play("ShootDiamondProjectiles", true)
        end
    elseif SatanHead:GetSprite():GetFrame() == 12 then
        SFXManager:Play(MinigameSounds.SPIT)
        ShootDiamondProjectiles()
        DiamondProjectileWavesNum = DiamondProjectileWavesNum + 1
    end
end


local function UpdateDiamondProjectileAttack()
    ManageSatanDiamondProjectileAttack()
end


local function InitDiamondProjectileAttack()
    DiamondProjectileWavesNum = 0
    SatanHead:GetSprite():Play("ShootDiamondProjectiles", true)
end


local function RemoveTakenPositions(posiblePosition, chosenPosition)
    local sol = {}

    for _, pos in ipairs(posiblePosition) do
        if pos ~= chosenPosition - 1 and pos ~= chosenPosition and pos ~= chosenPosition + 1 then
            sol[#sol+1] = pos
        end
    end

    return sol
end


local function SpawnFloorCracks()
    local cracksNum = MinigameConstants.FLOOR_CRACK_PATTERN[FloorCracksNum]
    if not cracksNum then return end

    local room = game:GetRoom()
    local posbileSpawns = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
    local chosenSpawns = {}

    for _, crack in ipairs(Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.FLOOR_CRACK, 0)) do
        posbileSpawns = RemoveTakenPositions(posbileSpawns, room:GetClampedGridIndex(crack.Position))
    end

    chosenSpawns[1] = room:GetClampedGridIndex(game:GetPlayer(0).Position) - 211

    for _ = 2, cracksNum, 1 do
        posbileSpawns = RemoveTakenPositions(posbileSpawns, chosenSpawns[#chosenSpawns])

        if #posbileSpawns == 0 then
            break
        end

        chosenSpawns[#chosenSpawns+1] = posbileSpawns[rng:RandomInt(#posbileSpawns) + 1]
    end

    for _, pos in ipairs(chosenSpawns) do
        local crack = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.FLOOR_CRACK, 0, room:GetGridPosition(pos + 211), Vector.Zero, nil)
        crack:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
        crack:GetSprite():Play("Open", true)
        crack.DepthOffset = -50

        crack:GetData().IsLast = (FloorCracksNum == #MinigameConstants.FLOOR_CRACK_PATTERN)
    end

    SFXManager:Play(MinigameSounds.OPEN_CRACK)
    FloorCracksNum = FloorCracksNum + 1
end


local function ManageFloorCracks()
    local cracks = Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.FLOOR_CRACK, 0)
    if #cracks == 0 then return end

    for _, crack in ipairs(cracks) do
        if crack:GetSprite():IsPlaying("Open") and crack:GetSprite():GetFrame() == 10 and
         not SatanHead:GetSprite():IsPlaying("FloorCrackScream") then
            SatanHead:GetSprite():Play("FloorCrackScream", true)
        end

        if crack:GetSprite():IsFinished("Open") and not crack.Child then
            local fire = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.FIRE_GEYSER, 0, crack.Position, Vector.Zero, nil)
            fire:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE | EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
            fire:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
            fire:GetSprite():Play("Idle", true)

            crack.Child = fire
        end

        if crack:GetSprite():IsFinished("Close") then
            if crack:GetData().IsLast then
                CurrentMinigameState = MinigameState.NO_ATTACK
            end

            crack:Remove()
        end
    end
end


local function ManageFireGeysers()
    local fires = Isaac.FindByType(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.FIRE_GEYSER, 0)
    if #fires == 0 then 
        SFXManager:Stop(MinigameSounds.FIRE_LOOP)
        return
    end

    if not SFXManager:IsPlaying(MinigameSounds.FIRE_LOOP) then
        SFXManager:Play(MinigameSounds.FIRE_LOOP)
    end
end


local function ManageSatanFloorCrackingAttack()
    if SatanHead:GetSprite():IsFinished("FloorCrackScream") then
        SatanHead:GetSprite():Play("Idle", true)
    end

    if SatanHead:GetSprite():IsPlaying("FloorCrackScream") and SatanHead:GetSprite():GetFrame() == 66 then
        for _, crack in ipairs(Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.FLOOR_CRACK, 0)) do
            crack:GetSprite():Play("Close", true)
        end

        for _, fire in ipairs(Isaac.FindByType(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.FIRE_GEYSER, 0)) do
            fire:Remove()
        end

        SpawnFloorCracks()
    end
end


local function UpdateFloorCrackingAttack()
    ManageFloorCracks()

    ManageFireGeysers()

    ManageSatanFloorCrackingAttack()
end


local function InitFloorCrackingAttack()
    FloorCracksNum = 1

    SpawnFloorCracks()
end


local function UpdateNoseLaserAttack()
end


local function InitNoseLaserAttack()
    local leftLaser = EntityLaser.ShootAngle(1, SatanHead.Position, 90 - 60, 90, Vector.Zero, SatanHead)
    leftLaser:SetActiveRotation(50, 40, 1, false)
    leftLaser.DepthOffset = 100

    local rightLaser = EntityLaser.ShootAngle(1, SatanHead.Position, 90 + 60, 90, Vector.Zero, SatanHead)
    rightLaser:SetActiveRotation(50, -40, -1, false)
    rightLaser.DepthOffset = 100
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
        elseif CurrentSatanAttack == SatanAttack.DIAMOND_PROJECTILES then
            UpdateDiamondProjectileAttack()
        elseif CurrentSatanAttack == SatanAttack.FLOOR_CRACKING then
            UpdateFloorCrackingAttack()
        elseif CurrentSatanAttack == SatanAttack.NOSE_LASER then
            UpdateNoseLaserAttack()
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


function holy_smokes:OnEffectUpdate(effect)
    if effect.Variant == EffectVariant.BULLET_POOF then
        --Remove this there because otherwise it doesnt stop the sound lmao
        effect:Remove()
        SFXManager:Stop(SoundEffect.SOUND_TEARIMPACTS)
    end
end
holy_smokes.callbacks[ModCallbacks.MC_POST_EFFECT_UPDATE] = holy_smokes.OnEffectUpdate


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


function holy_smokes:OnProjectileInit(projectile)
    projectile:GetSprite():Load("gfx/hs_satan_projectile.anm2", true)
    projectile:GetSprite():Play("Idle", true)
end
holy_smokes.callbacks[ModCallbacks.MC_POST_PROJECTILE_INIT] = holy_smokes.OnProjectileInit


function holy_smokes:OnProjectileUpdate(projectile)
    if projectile.Color.A < 1 then
        projectile:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 300, -1, false, false)
    end

    projectile.FallingSpeed = 0
    projectile.FallingAccel = -0.1
end
holy_smokes.callbacks[ModCallbacks.MC_POST_PROJECTILE_UPDATE] = holy_smokes.OnProjectileUpdate


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

        if CurrentSatanAttack == SatanAttack.FALLING_STALAGMITES then
            InitStalagmiteAttack()
        elseif CurrentSatanAttack == SatanAttack.DIAMOND_PROJECTILES then
            InitDiamondProjectileAttack()
        elseif CurrentSatanAttack == SatanAttack.FLOOR_CRACKING then
            InitFloorCrackingAttack()
        elseif CurrentSatanAttack == SatanAttack.NOSE_LASER then
            InitNoseLaserAttack()
        end
	end
end
holy_smokes.callbacks[ModCallbacks.MC_EXECUTE_CMD] = holy_smokes.OnCmd

return holy_smokes