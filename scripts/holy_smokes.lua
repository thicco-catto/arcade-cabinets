local holy_smokes = {}
local game = Game()
local rng = RNG()
local SFXManager = SFXManager()
local MusicManager = MusicManager()
local ArcadeCabinetVariables

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
    PLAYER_HIT = Isaac.GetSoundIdByName("bsw player hit"),
    CHARGED = Isaac.GetSoundIdByName("hs charged"),
    HOLY_LASER = Isaac.GetSoundIdByName("hs holy laser"),

    STALAGMITE_DROP = Isaac.GetSoundIdByName("tug explosion"),
    SATAN_STALAGMITE_SCREAM = Isaac.GetSoundIdByName("jc special attack"),
    SHOCKWAVE = Isaac.GetSoundIdByName("tug rock break"),

    SPIT = Isaac.GetSoundIdByName("hs spit"),

    OPEN_CRACK = Isaac.GetSoundIdByName("hs open crack"),
    FIRE_LOOP = Isaac.GetSoundIdByName("hs fire loop"),

    GIGA_LASER = Isaac.GetSoundIdByName("hs giga laser"),

    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}

local MinigameMusic = Isaac.GetMusicIdByName("bsw black beat wielder")

-- Entities
local MinigameEntityTypes = {
    CUSTOM_ENTITY = Isaac.GetEntityTypeByName("satan head HS")
}

local MinigameEntityVariants = {
    PLATFORM = Isaac.GetEntityVariantByName("platform HS"),
    SATAN_HEAD = Isaac.GetEntityVariantByName("satan head HS"),
    STAGE_ELEMENT = Isaac.GetEntityVariantByName("stage element HS"),
    HOLY_LASER = Isaac.GetEntityVariantByName("holy laser HS"),
    END_EXPLOSION = Isaac.GetEntityVariantByName("end explosion HS"),

    STALAGMITE = Isaac.GetEntityVariantByName("stalagmite HS"),
    STALAGMITE_SHADOW = Isaac.GetEntityVariantByName("stalagmite shadow HS"),
    SHOCKWAVE = Isaac.GetEntityVariantByName("shockwave HS"),

    FLOOR_CRACK = Isaac.GetEntityVariantByName("floor crack HS"),
    FIRE_GEYSER = Isaac.GetEntityVariantByName("fire geyser HS"),

    DOUBLE_LASER = Isaac.GetEntityVariantByName("double laser HS")
}

-- Constants
local MinigameConstants = {
    SATAN_HEAD_SPAWNING_OFFSET = Vector(4.5, 52),
    PLATFORM_SPAWNING_OFFSET = Vector(0, 240),

    MAX_INTRO_FRAMES = 40,
    MAX_PLAYER_IFRAMES = 30,
    FIRST_NO_ATTACK_FRAMES = 30,
    MAX_NO_ATTACK_FRAMES = 120,
    MAX_BOSS_HEALTH_FLASH_FRAMES = 9,
    MAX_SPECIAL_ATTACK_FRAMES = 20,
    MAX_END_WAIT_FRAMES = 30,

    STALAGMITE_HEIGHT = 400,
    STALAGMITE_SPEED = 20,
    MAX_SHOCKWAVE_COUNT = 9,
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

    AMOUNT_OF_PROJECTILE_WAVES_LASER = 10,

    MAX_PLAYER_HEALTH = 5,
    MAX_PLAYER_POWER = 50,

    MAX_END_EXPLOSIONS = 5,
    FRAMES_BETWEEN_END_EXPLOSIONS = 3,
    END_EXPLOSION_SPAWNING_AREA = Vector(100, 100),
    END_EXPLOSION_SPAWNING_OFFSET = Vector(0, 75),
}

-- Timers
local MinigameTimers = {
    IntroTimer = 0,
    IFramesTimer = 0,
    NextAttackTimer = 0,
    BossHealthFlashTimer = 0,
    SpecialAttackTimer = 0,
    EndExplosionsTimer = 0,
    EndWaitTimer = 0,
}

-- States
local CurrentMinigameState = 0
local MinigameState = {
    INTRO = 0,
    NO_ATTACK = 1,
    BOSS_ATTACK = 2,
    SATAN_DYING = 3,
    WAIT_FOR_END = 4,

    LOSING = 5,
    WINNING = 6,
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
PlayerHealthUI:Load("gfx/hs_health_ui.anm2", true)
local PlayerPowerUI = Sprite()
PlayerPowerUI:Load("gfx/hs_power_ui.anm2", true)
local BossHealthUI = Sprite()
BossHealthUI:Load("gfx/hs_boss_health_ui.anm2", true)
local TransitionScreen = Sprite()
TransitionScreen:Load("gfx/minigame_transition.anm2", true)
TransitionScreen:ReplaceSpritesheet(0, "gfx/effects/holy smokes/hs_vs_screen.png")
TransitionScreen:LoadGraphics()

-- Other variables
local PlayerHP = 0
local PlayerPower = 0
local SatanHead = nil
local LastAttack = nil
local Backdrop = nil

local FallenStalagmitesNum = 0

local DiamondProjectileWavesNum = 0

local FloorCracksNum = 0

local DoubleLaserProjectilesNum = 0


-- UPDATE CALLBACKS
local function EndAttack()
    CurrentMinigameState = MinigameState.NO_ATTACK

    MinigameTimers.NextAttackTimer = math.max(30, MinigameConstants.MAX_NO_ATTACK_FRAMES - math.floor((SatanHead.MaxHitPoints - SatanHead.HitPoints) / 4))
end


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
    end
end


local function ManageShockWaves()
    local shockwaves = Isaac.FindByType(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.SHOCKWAVE, -1)

    for _, shockwave in ipairs(shockwaves) do
        if shockwave:GetSprite():IsFinished("Break") then
            if shockwave:GetData().ShockWaveCount == MinigameConstants.MAX_SHOCKWAVE_COUNT and
            FallenStalagmitesNum == MinigameConstants.MAX_STALAGMITES_NUM and
            #Isaac.FindByType(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.STALAGMITE, -1) == 0 then
                EndAttack()
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
            EndAttack()
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

    local hasAlreadySpawnedCracks = false

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

            if not SFXManager:IsPlaying(MinigameSounds.SATAN_STALAGMITE_SCREAM) then
                SFXManager:Play(MinigameSounds.SATAN_STALAGMITE_SCREAM)
                game:ShakeScreen(10)
            end
        end

        if crack:GetSprite():IsFinished("Close") then
            if crack:GetData().IsLast then
                EndAttack()
            end

            if not hasAlreadySpawnedCracks then
                SpawnFloorCracks()
                hasAlreadySpawnedCracks = true
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


local function ShootNoseLasers()
    local leftLaser = EntityLaser.ShootAngle(1, SatanHead.Position, 90 - 50, 500, Vector.Zero, SatanHead)
    leftLaser:SetActiveRotation(10, 30, 0.3, true)
    leftLaser.Visible = false

    local rightLaser = EntityLaser.ShootAngle(1, SatanHead.Position, 90 + 50, 500, Vector.Zero, SatanHead)
    rightLaser:SetActiveRotation(10, -30, -0.3, true)
    rightLaser.Visible = false

    local fakeLaser = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.DOUBLE_LASER, 0, SatanHead.Position, Vector.Zero, nil)
    fakeLaser.DepthOffset = 100
    fakeLaser:GetSprite():Play("CloseIn", true)
end


local function ShootDoubleLaserProjectiles()
    local spawningPos = SatanHead.Position + Vector(0, 25)
    local spawningSpeed = Vector(0, 10)
    local projectileType = 1 + DoubleLaserProjectilesNum % 2
    local params = ProjectileParams()
    params.BulletFlags = ProjectileFlags.NO_WALL_COLLIDE
    params.Spread = 1
    SatanHead:ToNPC():FireProjectiles(spawningPos, spawningSpeed, projectileType, params)

    DoubleLaserProjectilesNum = DoubleLaserProjectilesNum + 1

    SFXManager:Play(MinigameSounds.SPIT)
end


local function RemoveFireAndDoubleLasers()
    for _, fire in ipairs(Isaac.FindByType(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.FIRE_GEYSER, 0)) do
        fire:Remove()
    end

    Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.DOUBLE_LASER, 0)[1]:Remove()
end


local function ShootGigaLaser()
    local gigaLaser = EntityLaser.ShootAngle(11, SatanHead.Position, 90, 30, Vector.Zero, SatanHead)
    gigaLaser.Visible = false

    local fakeLaser = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.DOUBLE_LASER, 0, SatanHead.Position + Vector(0, 20), Vector.Zero, nil)
    fakeLaser:GetSprite():Load("gfx/hs_giga_laser.anm2", true)
    fakeLaser:GetSprite():Play("Idle", true)
    fakeLaser.DepthOffset = 200
    fakeLaser:GetData().IsGigaLaser = true

    SFXManager:Play(MinigameSounds.GIGA_LASER)
end


local function ManageSatanNoseLaserAttack()
    if SatanHead:GetSprite():IsPlaying("FireNoseLaser") and SatanHead:GetSprite():GetFrame() == 10 then
        ShootNoseLasers()
    elseif SatanHead:GetSprite():IsFinished("FireNoseLaser") or (SatanHead:GetSprite():IsFinished("ShootDoubleLaserProjectiles") and DoubleLaserProjectilesNum < MinigameConstants.AMOUNT_OF_PROJECTILE_WAVES_LASER) then
        SatanHead:GetSprite():Play("ShootDoubleLaserProjectiles", true)
    elseif SatanHead:GetSprite():IsPlaying("ShootDoubleLaserProjectiles") and SatanHead:GetSprite():GetFrame() == 12 then
        ShootDoubleLaserProjectiles()
    elseif SatanHead:GetSprite():IsFinished("ShootDoubleLaserProjectiles") then
        SatanHead:GetSprite():Play("ShootGigaLaser", true)
    elseif SatanHead:GetSprite():IsPlaying("ShootGigaLaser") and SatanHead:GetSprite():GetFrame() == 30 then
        RemoveFireAndDoubleLasers()
    elseif SatanHead:GetSprite():IsPlaying("ShootGigaLaser") and SatanHead:GetSprite():GetFrame() == 54 then
        ShootGigaLaser()
    elseif SatanHead:GetSprite():IsFinished("ShootGigaLaser") then
        EndAttack()
    end
end


local function SpawnFireAtGrid(pos)
    local fire = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.FIRE_GEYSER, 0, pos, Vector.Zero, nil)
    fire:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE | EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
    fire:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    fire:GetSprite():ReplaceSpritesheet(0, "gfx/effects/holy smokes/hs_flat_fire.png")
    fire:GetSprite():LoadGraphics()
    fire:GetSprite():Play("Idle", true)
end


local function SpawnLaserFires(frames)
    local room = game:GetRoom()
    local maxPos = room:GetGridPosition(223) + Vector(10, 5)
    local minPos = room:GetGridPosition(211) + Vector(-10, 5)

    if (frames + 8) % 9 == 0 then
        local offset = (frames + 8) / 9
        SpawnFireAtGrid(maxPos - Vector(15, 0) * offset)
        SpawnFireAtGrid(minPos + Vector(15, 0) * offset)
    end
end


local function ManageDoubleLaser()
    local doubleLaser = Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.DOUBLE_LASER, 0)[1]

    if not doubleLaser then
        SFXManager:Stop(MinigameSounds.FIRE_LOOP)
        return
    end

    if doubleLaser:GetData().IsGigaLaser then
        if doubleLaser.FrameCount == 30 then
            doubleLaser:Remove()
        end
    else
        if not SFXManager:IsPlaying(MinigameSounds.FIRE_LOOP) then
            SFXManager:Play(MinigameSounds.FIRE_LOOP)
        end

        if doubleLaser:GetSprite():IsPlaying("CloseIn") then
            SpawnLaserFires(doubleLaser:GetSprite():GetFrame())
        elseif doubleLaser:GetSprite():IsFinished("CloseIn") then
            doubleLaser:GetSprite():Play("Idle")
        end
    end
end


local function UpdateNoseLaserAttack()
    ManageSatanNoseLaserAttack()

    ManageDoubleLaser()
end


local function InitNoseLaserAttack()
    DoubleLaserProjectilesNum = 0
    SatanHead:GetSprite():Play("FireNoseLaser", true)
end


local function StartAttack()
    local chosenAttack

    if LastAttack then
        chosenAttack = rng:RandomInt(3)
        if chosenAttack >= LastAttack then chosenAttack = chosenAttack + 1 end
    else
        chosenAttack = rng:RandomInt(4)
    end

    LastAttack = chosenAttack

    CurrentSatanAttack = chosenAttack
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


local function CheckForSpecialAttack()
    if PlayerPower < MinigameConstants.MAX_PLAYER_POWER then return end

    if  laser then return end
    if Input.IsActionPressed(ButtonAction.ACTION_ITEM, 0) then
        local player = game:GetPlayer(0)
        local playerLaser = player:FireBrimstone(Vector(0, -1), player, 2.5)
        playerLaser:GetData().IsPlayerLaser = true
        playerLaser.Visible = false

        local fakeLaser = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.HOLY_LASER, 0, player.Position - Vector(0, 1), Vector.Zero, nil)
        fakeLaser:GetSprite():Play("Loop", true)

        PlayerPower = 0
        MinigameTimers.SpecialAttackTimer = MinigameConstants.MAX_SPECIAL_ATTACK_FRAMES

        SFXManager:Play(MinigameSounds.HOLY_LASER)
    end
end


local function ManageHolyLaser()
    local laser = Isaac.FindByType(EntityType.ENTITY_EFFECT, MinigameEntityVariants.HOLY_LASER, 0)[1]

    if not laser then return end

    laser.Position = game:GetPlayer(0).Position

    if MinigameTimers.SpecialAttackTimer == 1 and not laser:GetSprite():IsPlaying("End") then
        laser:GetSprite():Play("End", true)
    end

    if laser:GetSprite():IsFinished("End") then
        laser:Remove()
    end
end


local function RemoveEndExplosions()
    for _, explosion in ipairs(Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.END_EXPLOSION, 0)) do
        if explosion:GetSprite():IsFinished("Idle") then
            explosion:Remove()
        end
    end
end


local function SpawnEndExplosions()
    if game:GetFrameCount() % MinigameConstants.FRAMES_BETWEEN_END_EXPLOSIONS ~= 0 then return end

    if #Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.END_EXPLOSION, 0) < MinigameConstants.MAX_END_EXPLOSIONS then
        game:ShakeScreen(4)
        local spawningPos = SatanHead.Position - MinigameConstants.END_EXPLOSION_SPAWNING_AREA - MinigameConstants.END_EXPLOSION_SPAWNING_OFFSET
        spawningPos = spawningPos + Vector(0, MinigameTimers.EndExplosionsTimer * 3)

        spawningPos = Vector(spawningPos.X + rng:RandomInt(MinigameConstants.END_EXPLOSION_SPAWNING_AREA.X * 2),
        spawningPos.Y + rng:RandomInt(MinigameConstants.END_EXPLOSION_SPAWNING_AREA.Y * 2))

        local explosion = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.END_EXPLOSION, 0, spawningPos, Vector.Zero, nil)
        explosion:GetSprite():Play("Idle", true)
        explosion.DepthOffset = -1000
        SFXManager:Play(MinigameSounds.STALAGMITE_DROP)
    end
end


function holy_smokes:OnFrameUpdate()
    if MinigameTimers.IntroTimer > 0 then MinigameTimers.IntroTimer = MinigameTimers.IntroTimer - 1 end
    if MinigameTimers.IFramesTimer > 0 then MinigameTimers.IFramesTimer = MinigameTimers.IFramesTimer - 1 end
    if MinigameTimers.NextAttackTimer > 0 then MinigameTimers.NextAttackTimer = MinigameTimers.NextAttackTimer - 1 end
    if MinigameTimers.BossHealthFlashTimer > 0 then MinigameTimers.BossHealthFlashTimer = MinigameTimers.BossHealthFlashTimer - 1 end
    if MinigameTimers.SpecialAttackTimer > 0 then MinigameTimers.SpecialAttackTimer = MinigameTimers.SpecialAttackTimer - 1 end
    if MinigameTimers.EndWaitTimer > 0 then MinigameTimers.EndWaitTimer = MinigameTimers.EndWaitTimer - 1 end

    CheckForSpecialAttack()

    ManageHolyLaser()

    if CurrentMinigameState == MinigameState.INTRO then
        if MinigameTimers.IntroTimer == 0 then
            CurrentMinigameState = MinigameState.NO_ATTACK
            MinigameTimers.NextAttackTimer = MinigameConstants.FIRST_NO_ATTACK_FRAMES

            local playerNum = game:GetNumPlayers()
            for i = 0, playerNum - 1, 1 do
                local player = game:GetPlayer(i)
                player.ControlsEnabled = true
            end
        end
    elseif CurrentMinigameState == MinigameState.NO_ATTACK then
        if game:GetFrameCount() % 70 == 0 then
            SatanHead:GetSprite():Play("Breathe", true)
        end

        if SatanHead:GetSprite():IsFinished("Breathe") then
            SatanHead:GetSprite():Play("Idle", true)
        end

        if MinigameTimers.NextAttackTimer == 0 then
            StartAttack()
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
    elseif CurrentMinigameState == MinigameState.SATAN_DYING then
        MinigameTimers.EndExplosionsTimer = MinigameTimers.EndExplosionsTimer + 1
        SpawnEndExplosions()
        RemoveEndExplosions()

        if Backdrop:GetSprite():IsFinished("Die") then
            MinigameTimers.EndWaitTimer = MinigameConstants.MAX_END_WAIT_FRAMES
            CurrentMinigameState = MinigameState.WAIT_FOR_END
        end
    elseif CurrentMinigameState == MinigameState.WAIT_FOR_END then
        RemoveEndExplosions()

        if MinigameTimers.EndWaitTimer == 0 then
           CurrentMinigameState = MinigameState.WINNING
            SFXManager:Play(MinigameSounds.WIN)
            TransitionScreen:Play("Appear", true)

           local playerNum = game:GetNumPlayers()
           for i = 0, playerNum - 1, 1 do
               local player = game:GetPlayer(i)
                player:PlayExtraAnimation("Happy")
                player.ControlsEnabled = false
           end
        end
    end
end


function holy_smokes:OnPlayerUpdate(player)
    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_RANGE)
    player:EvaluateItems()

    if CurrentMinigameState == MinigameState.WINNING or CurrentMinigameState == MinigameState.LOSING  then
        if player:GetSprite():GetFrame() > 10 then
            player:GetSprite():SetFrame(10)
        end
    end
end


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
    if PlayerPowerUI:IsPlaying("Flash") and PlayerPower >= MinigameConstants.MAX_PLAYER_POWER then
        PlayerPowerUI:Update()
    else
        PlayerPowerUI:Play("Idle")
        PlayerPowerUI:SetFrame(math.floor(PlayerPower / MinigameConstants.MAX_PLAYER_POWER * 22))
    end

    PlayerPowerUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) + Vector(-189, 0), Vector.Zero, Vector.Zero)

     --Boss health
    if MinigameTimers.BossHealthFlashTimer > 0 then
        BossHealthUI:Play("Flash")
    else
        BossHealthUI:Play("Idle")
    end

    if SatanHead:Exists() then
        BossHealthUI:SetFrame(math.ceil(SatanHead.HitPoints / SatanHead.MaxHitPoints * 72))
    else
        BossHealthUI:SetFrame(0)
    end
   
    BossHealthUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) + Vector(190, 0), Vector.Zero, Vector.Zero)
end


local function RenderFadeOut()
    if CurrentMinigameState ~= MinigameState.LOSING and CurrentMinigameState ~= MinigameState.WINNING then return end

    if TransitionScreen:IsFinished("Appear") then
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)
            player:TryRemoveNullCostume(Isaac.GetCostumeIdByPath("gfx/costumes/hs_halo.anm2"))
        end

        if CurrentMinigameState == MinigameState.WINNING then
            ArcadeCabinetVariables.CurrentMinigameResult = ArcadeCabinetVariables.MinigameResult.WIN
        else
            ArcadeCabinetVariables.CurrentMinigameResult = ArcadeCabinetVariables.MinigameResult.LOSE
        end
    end

    if SFXManager:IsPlaying(MinigameSounds.WIN) then
        TransitionScreen:SetFrame(0)
    end

    TransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
    TransitionScreen:Update()
end


local function RenderVsScreen()
    if CurrentMinigameState ~= MinigameState.INTRO then return end

    TransitionScreen:SetFrame(0)
    TransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
end


function holy_smokes:OnRender()
    RenderUI()

    RenderFadeOut()

    RenderVsScreen()
end


--ENTITY CALLBACKS
local function EndAllAttacks()
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if not (entity:ToPlayer() or
        (entity.Type == EntityType.ENTITY_GENERIC_PROP and entity.Variant == ArcadeCabinetVariables.Backdrop1x2Variant) or
        (entity.Type == EntityType.ENTITY_GENERIC_PROP and entity.Variant == MinigameEntityVariants.PLATFORM) or
        entity:ToTear() or
        entity:ToEffect() or
        (entity.Type == MinigameEntityTypes.CUSTOM_ENTITY and entity.Variant == MinigameEntityVariants.SATAN_HEAD)) then
            entity:Remove()
        end
    end

    for _, sound in ipairs(MinigameSounds) do
        SFXManager:Stop(sound)
    end
end


function holy_smokes:OnPlayerDamage(player)
    player = player:ToPlayer()

    if MinigameTimers.IFramesTimer <= 0 and CurrentMinigameState ~= MinigameState.LOSING then
        MinigameTimers.IFramesTimer = MinigameConstants.MAX_PLAYER_IFRAMES
        PlayerPower = 0
        PlayerHP = PlayerHP - 1
        PlayerHealthUI:Play("Flash", true)

        if PlayerHP == 0 then
            CurrentMinigameState = MinigameState.LOSING

            EndAllAttacks()

            TransitionScreen:Play("Appear", true)
            SFXManager:Play(MinigameSounds.LOSE)

            local playerNum = game:GetNumPlayers()
            for i = 0, playerNum - 1, 1 do
                game:GetPlayer(i):PlayExtraAnimation("Sad")
                game:GetPlayer(i).ControlsEnabled = false
            end
        else
            SFXManager:Play(MinigameSounds.PLAYER_HIT)
            player:PlayExtraAnimation("Hit")
        end
    end

    return false
end


function holy_smokes:OnEntityDamage(tookDamage, damageAmount)
    if tookDamage.Variant ~= MinigameEntityVariants.SATAN_HEAD then return end

    MinigameTimers.BossHealthFlashTimer = MinigameConstants.MAX_BOSS_HEALTH_FLASH_FRAMES

    if MinigameTimers.SpecialAttackTimer <= 0 then
        PlayerPower = PlayerPower + damageAmount
    end

    if PlayerPower >= MinigameConstants.MAX_PLAYER_POWER and not PlayerPowerUI:IsPlaying("Flash")then
        PlayerPowerUI:Play("Flash", true)
        SFXManager:Play(MinigameSounds.CHARGED)
    end

    if tookDamage.HitPoints <= damageAmount then
        tookDamage:Remove()

        EndAllAttacks()

        CurrentMinigameState = MinigameState.SATAN_DYING
        Backdrop:GetSprite():Play("Die")
    end
end


function holy_smokes:OnTearPoofInit(poof)
    SFXManager:Stop(SoundEffect.SOUND_TEARIMPACTS)
    SFXManager:Stop(SoundEffect.SOUND_SPLATTER)
    if poof.Position.Y >= SatanHead.Position.Y - 40 then
        SFXManager:Play(MinigameSounds.TEAR_IMPACT)
    end

    poof:GetSprite():Load("gfx/hs_holy_tear_splash.anm2", true)
    poof:GetSprite():Play("Poof", true)
end


function holy_smokes:OnProjectilePoofInit(poof)
    poof.Visible = false
end


function holy_smokes:OnWaterSplashInit(splash)
    splash:Remove()
end


function holy_smokes:OnProjectilePoofUpdate(poof)
    --Remove sound on update because other it doesnt
    poof:Remove()
    SFXManager:Stop(SoundEffect.SOUND_TEARIMPACTS)
end


function holy_smokes:OnTinyFlyUpdate(effect)
    effect:Remove() --They should be removed but just in case
end


function holy_smokes:OnTearFire(tear)
    SFXManager:Stop(SoundEffect.SOUND_TEARS_FIRE)

    if tear.Velocity:Normalized().Y > 0 or tear.Velocity:Normalized().X > 0.5 or tear.Velocity:Normalized().X < -0.5 or MinigameTimers.SpecialAttackTimer > 0 then
        tear:Remove()
    else
        SFXManager:Play(MinigameSounds.TEAR_SHOOT)

        tear.Velocity = Vector(0, tear.Velocity.Y)
        tear:GetSprite():Load("gfx/hs_holy_tears.anm2", true)
        tear:GetSprite():Play("RegularTear6", true)
    end
end


function holy_smokes:OnTearCollision(_, collider)
    if collider.Type ~= MinigameEntityTypes.CUSTOM_ENTITY or collider.Variant ~= MinigameEntityVariants.SATAN_HEAD then
        return true
    end
end


function holy_smokes:OnProjectileInit(projectile)
    projectile:GetSprite():Load("gfx/hs_satan_projectile.anm2", true)
    projectile:GetSprite():Play("Idle", true)
end


function holy_smokes:OnProjectileUpdate(projectile)
    if projectile.Color.A < 1 then
        projectile:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 300, -1, false, false)
    end

    projectile.FallingSpeed = 0
    projectile.FallingAccel = -0.1
end


function holy_smokes:OnCache(player, cacheFlags)
    if CurrentMinigameState == MinigameState.WINNING or CurrentMinigameState == MinigameState.LOSING then return end

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


-- INIT MINIGAME
function holy_smokes:AddCallbacks(mod)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, holy_smokes.OnFrameUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, holy_smokes.OnPlayerUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, holy_smokes.OnRender)
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, holy_smokes.OnPlayerDamage, EntityType.ENTITY_PLAYER)
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, holy_smokes.OnEntityDamage, MinigameEntityTypes.CUSTOM_ENTITY)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, holy_smokes.OnTearPoofInit, EffectVariant.TEAR_POOF_A)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, holy_smokes.OnTearPoofInit, EffectVariant.TEAR_POOF_B)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, holy_smokes.OnProjectilePoofInit, EffectVariant.BULLET_POOF)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, holy_smokes.OnWaterSplashInit, EffectVariant.WATER_SPLASH)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, holy_smokes.OnProjectilePoofUpdate, EffectVariant.BULLET_POOF)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, holy_smokes.OnTinyFlyUpdate, EffectVariant.TINY_FLY)
    mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, holy_smokes.OnTearFire)
    mod:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, holy_smokes.OnTearCollision)
    mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, holy_smokes.OnProjectileInit)
    mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, holy_smokes.OnProjectileUpdate)
    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, holy_smokes.OnCache)
end


function holy_smokes:RemoveCallbacks(mod)
    mod:RemoveCallback(ModCallbacks.MC_POST_UPDATE, holy_smokes.OnFrameUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, holy_smokes.OnPlayerUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_RENDER, holy_smokes.OnRender)
    mod:RemoveCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, holy_smokes.OnPlayerDamage)
    mod:RemoveCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, holy_smokes.OnEntityDamage)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_INIT, holy_smokes.OnTearPoofInit)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_INIT, holy_smokes.OnTearPoofInit)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_INIT, holy_smokes.OnProjectilePoofInit)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_INIT, holy_smokes.OnWaterSplashInit)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, holy_smokes.OnProjectilePoofUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, holy_smokes.OnTinyFlyUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_FIRE_TEAR, holy_smokes.OnTearFire)
    mod:RemoveCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, holy_smokes.OnTearCollision)
    mod:RemoveCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, holy_smokes.OnProjectileInit)
    mod:RemoveCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, holy_smokes.OnProjectileUpdate)
    mod:RemoveCallback(ModCallbacks.MC_EVALUATE_CACHE, holy_smokes.OnCache)
end


function holy_smokes:Init(mod, variables)
    holy_smokes:AddCallbacks(mod)
    ArcadeCabinetVariables = variables

    -- Reset variables
    holy_smokes.result = nil
    PlayerHP = MinigameConstants.MAX_PLAYER_HEALTH
    PlayerPower = 0

    CurrentMinigameState = MinigameState.INTRO
    CurrentSatanAttack = SatanAttack.FALLING_STALAGMITES

    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    --Set vs screen stuff
    MinigameTimers.IntroTimer = MinigameConstants.MAX_INTRO_FRAMES
    TransitionScreen:Play("Idle", true)
    SFXManager:Play(MinigameSounds.SATAN_STALAGMITE_SCREAM)

    -- Backdrop
    Backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop1x2Variant, 0, game:GetRoom():GetCenterPos(), Vector.Zero, nil)
    Backdrop:GetSprite():Load("gfx/backdrop/backdrop_hs.anm2", true)
    Backdrop.DepthOffset = -9000

    local platform = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.PLATFORM, 0, game:GetRoom():GetCenterPos() + MinigameConstants.PLATFORM_SPAWNING_OFFSET, Vector.Zero, nil)
    platform.DepthOffset = -500

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


return holy_smokes