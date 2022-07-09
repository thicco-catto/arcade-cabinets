local no_splash = {}
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

no_splash.callbacks = {}
no_splash.result = nil
no_splash.startingItems = {}

-- Sounds
local MinigameSounds = {
    PLAYER_HIT = Isaac.GetSoundIdByName("bsw player hit"),

    HISS = Isaac.GetSoundIdByName("ns hiss"),
    RAWR = Isaac.GetSoundIdByName("ns rawr"),
    WAVE_FINISH = Isaac.GetSoundIdByName("ns wave finish"),
    ZAP = Isaac.GetSoundIdByName("ns zap"),
    CHUCK_CHICANERY = Isaac.GetSoundIdByName("jc third wave"),
    CHUCK_DASH_START = Isaac.GetSoundIdByName("jc special attack"),
    CHUCK_DASH = Isaac.GetSoundIdByName("ns charge"),

    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}

local MinigameMusic = Isaac.GetMusicIdByName("bsw black beat wielder")

-- Entities
local MinigameEntityTypes = {
    CUSTOM_ENTITY = Isaac.GetEntityTypeByName("spiked mine NS")
}

local MinigameEntityVariants = {
    FAKE_PLAYER = Isaac.GetEntityVariantByName("fake player NL"),
    BUBBLE = Isaac.GetEntityVariantByName("bubble NS"),
    ARROW = Isaac.GetEntityVariantByName("arrow NS"),
    BACKGROUND = Isaac.GetEntityVariantByName("background TGB"),

    FISH = Isaac.GetEntityVariantByName("fish NS"),
    CUNT = Isaac.GetEntityVariantByName("cunt NS"),
    EEL = Isaac.GetEntityVariantByName("eel NS"),
    CLAM = Isaac.GetEntityVariantByName("clam NS"),
    SPIKED_MINE = Isaac.GetEntityVariantByName("spiked mine NS"),
    ANGLER_FISH = Isaac.GetEntityVariantByName("angler fish NS")
}

-- Constants
local MinigameConstants = {
    MAX_PLAYER_IFRAMES = 30,

    --UI
    ARROW_SPAWNING_POS = Vector(400, 200),
    PLAYER_HEALTH_RENDER_POS = Vector(120, 20),
    MAX_BOSS_HEALTH_FLASH_FRAMES = 9,

    --Wave stuff
    MAX_WAVES = 1,
    DISTANCE_NEEDED_FOR_WAVE_START = 450,
    X_POSITION_TO_SPAWN = 500,
    X_POSITION_PER_MINIWAVE = 200,

    --Bubble stuff
    MIN_BUBBLE_SPAWN_TIMER_FRAMES = 7,
    RANDOM_FRAMES_BUBBLE_SPAWN_TIMER = 10,
    BUBBLE_Y_SPAWN_POSITION = 500,
    BUBBLE_MAX_X_SPAWN_POSITION = 600,
    BUBBLE_Y_VELOCITY = 2.5,
    BUBBLE_Y_VELOCITY_RANDOM_OFFSET = 1,
    BUBBLE_X_ACCELERATION = 0.1,
    BUBBLE_MAX_X_VELOCITY = 3,

    --Fish stuff
    FISH_AMOUNT = 2,
    FISH_VELOCITY = 3.5,
    BONE_FISH_VELOCITY = 5,

    --Cunt stuff
    CUNT_AMOUNT = 8,
    CUNT_VELOCITY = 5,

    --Eel stuff
    EEL_VELOCITY = 3,
    EEL_SHOOT_COOLDOWN = 60,

    --Clam stuff
    CLAM_VELOCITY = 3,
    CLAM_TARGET_Y = 400,
    CLAM_SPAWNING_Y = 700,
    CLAM_SPAWNING_X = 120,
    CLAM_SPAWNING_X_OFFSET = 300,
    CLAM_SHOOT_COOLDOWN = 30,

    --Angler fish stuff
    BONE_CUNTS_NUMBER = 8,
    ANGLER_FISH_BONE_CUNT_OFFSET = Vector(70, 5),
    ANGLER_FISH_PROJECTILE_OFFSET = Vector(110, -60),
    ANGLER_FISH_PROJECTILE_NUMBER = 3,
    ANGLER_FISH_VELOCITY = 2.5,
    ANGLER_FISH_CHARGE_START_VELOCITY = 0.5,
    ANGLER_FISH_CHARGE_VELOCITY = 15,
    ANGLER_FISH_CHARGE_STOP_RIGHT = 720,
    ANGLER_FISH_CHARGE_STOP_LEFT = -80,
    ANGLER_FISH_SPAWN = Vector(450, 550),
    ANGLER_FISH_Y_SOUND = 500,
    ANGLER_FISH_INITIAL_COOLDOWN = 30,
    ANGLER_FISH_ATTACK_COOLDOWN = 45,
    ANGLER_FISH_MAX_ATTACKS_IN_A_ROW = 5,
    ANGLER_FISH_NORMAL_ATTACK_RIGHT = 450,
    ANGLER_FISH_NORMAL_ATTACK_LEFT = 180
}

-- Timers
local MinigameTimers = {
    BubbleSpawnTimer = 0,
    AnglerFishAttackTimer = 0,
    IFramesTimer = 0,
    BossHealthFlashTimer = 0,
}

-- States
local CurrentMinigameState = 0
local MinigameState = {
    INTRO = 1,
    SWIMMING = 2,
    FIGHTING = 3,

    LOSING = 5,
    WINNING = 6,
}

-- UI
local TransitionScreen = Sprite()
TransitionScreen:Load("gfx/minigame_transition.anm2", true)
local PlayerHealthUI = Sprite()
PlayerHealthUI:Load("gfx/ns_player_health_ui.anm2", true)
local CoolTextUI = Sprite()
CoolTextUI:Load("gfx/ns_cool_text_ui.anm2", true)
local BossHealthUI = Sprite()
BossHealthUI:Load("gfx/ns_boss_health_ui.anm2", true)

--Other Variables
local PlayerHP = 3
local CurrentBubbleXVelocity = 0
local DistanceTraveled = 0
local CurrentWave = 0
local Arrow = nil
local AnglerFishProjectiles = 0
local AnglerFishAttacksInARow = 0


function no_splash:Init()
    --Reset variables
    PlayerHP = 3
    CurrentWave = 0
    DistanceTraveled = 0
    AnglerFishProjectiles = 0
    AnglerFishAttacksInARow = 0
    no_splash.result = nil

    MinigameTimers.IFramesTimer = 0

    CurrentMinigameState = MinigameState.SWIMMING

    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    local overlay = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND, 0, game:GetRoom():GetCenterPos(), Vector.Zero, nil)
    overlay:GetSprite():Load("gfx/ns_overlay.anm2", true)
    overlay:GetSprite():Play("Idle", true)
    overlay.DepthOffset = 1000

    local bg = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND, 0, game:GetRoom():GetCenterPos(), Vector.Zero, nil)
    bg:GetSprite():Load("gfx/ns_bg.anm2", true)
    bg:GetSprite():Play("Idle", true)
    bg.DepthOffset = -1000

    Arrow = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.ARROW, 0, MinigameConstants.ARROW_SPAWNING_POS, Vector.Zero, nil)

    -- Prepare players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        for _, item in ipairs(no_splash.startingItems) do
            player:AddCollectible(item, 0, false)
        end

        player.Position = game:GetRoom():GetCenterPos()
        player.Visible = false

        local fakePlayer = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.FAKE_PLAYER, 0, player.Position + Vector(0, 0.1), Vector.Zero, nil)
        fakePlayer:GetSprite():Load("gfx/ns_player.anm2", true)
        player:GetData().FakePlayer = fakePlayer
    end
end


local function SpawnBubbles()
    if MinigameTimers.BubbleSpawnTimer > 0 then
        MinigameTimers.BubbleSpawnTimer = MinigameTimers.BubbleSpawnTimer - 1
        return
    end

    MinigameTimers.BubbleSpawnTimer = MinigameConstants.MIN_BUBBLE_SPAWN_TIMER_FRAMES + rng:RandomInt(MinigameConstants.RANDOM_FRAMES_BUBBLE_SPAWN_TIMER)

    local xPosition = rng:RandomInt(MinigameConstants.BUBBLE_MAX_X_SPAWN_POSITION)
    local bubble = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BUBBLE, 0, Vector(xPosition, MinigameConstants.BUBBLE_Y_SPAWN_POSITION), Vector(0, -MinigameConstants.BUBBLE_Y_VELOCITY - rng:RandomFloat() * MinigameConstants.BUBBLE_Y_VELOCITY_RANDOM_OFFSET), nil)
    local bubbleSize = rng:RandomInt(3) + 1
    bubble:GetSprite():Play("Idle" .. bubbleSize, true)
    bubble.DepthOffset = -500
end


local function CalculateBubbleVelocity()
    if (Input.IsActionPressed(ButtonAction.ACTION_LEFT, 0) or Input.IsActionPressed(ButtonAction.ACTION_RIGHT, 0)) and not
    (Input.IsActionPressed(ButtonAction.ACTION_LEFT, 0) and Input.IsActionPressed(ButtonAction.ACTION_RIGHT, 0)) and
    CurrentMinigameState == MinigameState.SWIMMING then
        if Input.IsActionPressed(ButtonAction.ACTION_LEFT, 0) then
            CurrentBubbleXVelocity = CurrentBubbleXVelocity + MinigameConstants.BUBBLE_X_ACCELERATION

            if CurrentBubbleXVelocity > MinigameConstants.BUBBLE_MAX_X_VELOCITY then
                CurrentBubbleXVelocity = MinigameConstants.BUBBLE_MAX_X_VELOCITY
            end
        end

        if Input.IsActionPressed(ButtonAction.ACTION_RIGHT, 0) then
            CurrentBubbleXVelocity = CurrentBubbleXVelocity - MinigameConstants.BUBBLE_X_ACCELERATION

            if CurrentBubbleXVelocity < -MinigameConstants.BUBBLE_MAX_X_VELOCITY then
                CurrentBubbleXVelocity = -MinigameConstants.BUBBLE_MAX_X_VELOCITY
            end
        end
    else
        if CurrentBubbleXVelocity > 0 then
            CurrentBubbleXVelocity = CurrentBubbleXVelocity - MinigameConstants.BUBBLE_X_ACCELERATION

            if CurrentBubbleXVelocity < 0 then
                CurrentBubbleXVelocity = 0
            end
        elseif CurrentBubbleXVelocity < 0 then
            CurrentBubbleXVelocity = CurrentBubbleXVelocity + MinigameConstants.BUBBLE_X_ACCELERATION

            if CurrentBubbleXVelocity > 0 then
                CurrentBubbleXVelocity = 0
            end
        end
    end
end


local function SpawnEnemy(EntityVariant, YPos, miniwave)
    local spawningPos = Vector(700 + MinigameConstants.X_POSITION_PER_MINIWAVE * miniwave, YPos + rng:RandomInt(4))
    local velocity = Vector.Zero

    if EntityVariant == MinigameEntityVariants.CLAM then
        spawningPos = Vector(MinigameConstants.CLAM_SPAWNING_X + rng:RandomInt(MinigameConstants.CLAM_SPAWNING_X_OFFSET), MinigameConstants.CLAM_SPAWNING_Y)
        velocity = Vector(0, -MinigameConstants.CLAM_VELOCITY)
    end

    local entity = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, EntityVariant, 0, spawningPos, velocity, nil)
    entity:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    entity:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
    entity:GetSprite():Play("Idle", true)
end


local function StartWave()
    Arrow:Remove()
    CurrentBubbleXVelocity = 0
    DistanceTraveled = 0
    CurrentMinigameState = MinigameState.FIGHTING

    if CurrentWave == MinigameConstants.MAX_WAVES then
        local anglerFish = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.ANGLER_FISH, 0, MinigameConstants.ANGLER_FISH_SPAWN, Vector.Zero, nil)
        anglerFish:GetSprite():Play("Idle", true)
        anglerFish:GetSprite():PlayOverlay("IdleTail", true)
        anglerFish:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
        anglerFish:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
        anglerFish.DepthOffset = -100
        anglerFish:GetData().HasPlayedSound = false
    else
        local hasSpawnedEelOrClam = false

        for miniwave = 1, 2, 1 do
            local enemiesToChoose = 3
            if miniwave == 2 then enemiesToChoose = 4 end
            local chosenEnemy = rng:RandomInt(enemiesToChoose)
            local amountToSpawn = 1

            if CurrentWave == 2 or
            CurrentWave == 1 and miniwave == 1 then
                amountToSpawn = 2
            end

            if chosenEnemy == 0 then
                --Fish
                local yInitial = rng:RandomInt(500)
                for _ = 1, MinigameConstants.FISH_AMOUNT + CurrentWave, 1 do
                    SpawnEnemy(MinigameEntityVariants.FISH, yInitial, miniwave)
                end
            elseif chosenEnemy == 1 then
                --Eel
                SFXManager:Play(MinigameSounds.RAWR)
                hasSpawnedEelOrClam = true
                for _ = 1, amountToSpawn, 1 do
                    SpawnEnemy(MinigameEntityVariants.EEL, rng:RandomInt(500), miniwave)
                end
            elseif chosenEnemy == 2 then
                --Cunts
                for _ = 1, amountToSpawn, 1 do
                    local yInitial = rng:RandomInt(500)
                    for _ = 1, MinigameConstants.CUNT_AMOUNT + CurrentWave, 1 do
                        SpawnEnemy(MinigameEntityVariants.CUNT, yInitial, miniwave)
                    end
                end
            elseif chosenEnemy == 3 then
                --Clam
                if hasSpawnedEelOrClam then
                    amountToSpawn = 1
                else
                    amountToSpawn = 2
                end

                hasSpawnedEelOrClam = true
                for _ = 1, amountToSpawn, 1 do
                    SpawnEnemy(MinigameEntityVariants.CLAM, 1, miniwave)
                end
            end
        end

        if not hasSpawnedEelOrClam then
            SpawnEnemy(MinigameEntityVariants.CLAM, 1, 0)
        end
    end

    CurrentWave = CurrentWave + 1
end


local function FinishWave()
    Arrow = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.ARROW, 0, MinigameConstants.ARROW_SPAWNING_POS, Vector.Zero, nil)
    CurrentMinigameState = MinigameState.SWIMMING
    game:ShakeScreen(10)
end


function no_splash:OnUpdate()
    if MinigameTimers.IFramesTimer > 0 then MinigameTimers.IFramesTimer = MinigameTimers.IFramesTimer - 1 end
    if MinigameTimers.BossHealthFlashTimer > 0 then MinigameTimers.BossHealthFlashTimer = MinigameTimers.BossHealthFlashTimer - 1 end

    SpawnBubbles()

    CalculateBubbleVelocity()

    if CurrentMinigameState == MinigameState.SWIMMING then
        Arrow.Velocity = Vector(CurrentBubbleXVelocity, 0)
        DistanceTraveled = DistanceTraveled - CurrentBubbleXVelocity

        if DistanceTraveled >= MinigameConstants.DISTANCE_NEEDED_FOR_WAVE_START then
            StartWave()
        end
    elseif CurrentMinigameState == MinigameState.FIGHTING then
        local isClear = true

        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if entity:IsVulnerableEnemy() and not
            (entity.Type == MinigameEntityTypes.CUSTOM_ENTITY and entity.Variant == MinigameEntityVariants.CLAM) then
                isClear = false
                break
            end
        end

        if isClear then
            for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PROJECTILE)) do
                entity:Remove()
            end
            FinishWave()
        end
    end

    
end
no_splash.callbacks[ModCallbacks.MC_POST_UPDATE] = no_splash.OnUpdate


function no_splash:OnEffectInit(effect)
    if effect.Variant == EffectVariant.TEAR_POOF_A or effect.Variant == EffectVariant.TEAR_POOF_B then
        SFXManager:Stop(SoundEffect.SOUND_TEARIMPACTS)
        SFXManager:Stop(SoundEffect.SOUND_SPLATTER)

        effect:GetSprite():Load("gfx/ns_player_tear_splash.anm2", true)
        effect:GetSprite():Play("Poof", true)
    end
end
no_splash.callbacks[ModCallbacks.MC_POST_EFFECT_INIT] = no_splash.OnEffectInit


local function UpdateBubble(effect)
    if effect.Position.Y < 0 then
        effect:Remove()
    end

    effect.Velocity = Vector(CurrentBubbleXVelocity, effect.Velocity.Y)
end


function no_splash:OnEffectUpdate(effect)
    if effect.Variant == MinigameEntityVariants.BUBBLE then
        UpdateBubble(effect)
    end
end
no_splash.callbacks[ModCallbacks.MC_POST_EFFECT_UPDATE] = no_splash.OnEffectUpdate


local function UpdateFish(fish)
    if fish:GetSprite():IsPlaying("Transition") then
        return
    elseif fish:GetSprite():IsFinished("Transition") then
        fish:GetSprite():Play("Idle", true)
        fish:ClearEntityFlags(EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
    end

    local velocity = MinigameConstants.FISH_VELOCITY

    --Its bone
    if fish.SubType == 1 then velocity = MinigameConstants.BONE_FISH_VELOCITY end

    fish.Velocity = (Isaac.GetPlayer(0).Position - fish.Position):Normalized() * velocity
    fish.FlipX = Isaac.GetPlayer(0).Position.X > fish.Position.X
end


local function UpdateCunt(cunt)
    if not cunt:GetSprite():IsPlaying("Idle") then
        cunt:GetSprite():Play("Idle")
    end

    cunt.Velocity = (Isaac.GetPlayer(0).Position - cunt.Position):Normalized() * MinigameConstants.CUNT_VELOCITY
    cunt.FlipX = Isaac.GetPlayer(0).Position.X > cunt.Position.X
end


local function UpdateEel(eel)
    if eel:GetSprite():IsPlaying("Idle") then
        eel.FlipX = Isaac.GetPlayer(0).Position.X > eel.Position.X
        eel.Velocity = (Isaac.GetPlayer(0).Position - eel.Position):Normalized() * MinigameConstants.EEL_VELOCITY
    else
        eel.Velocity = Vector.Zero
    end

    if eel:IsFrame(MinigameConstants.EEL_SHOOT_COOLDOWN, 0) and (Isaac.GetPlayer(0).Position - eel.Position):Length() < 300 then
        eel:GetSprite():Play("Shoot", true)
        SFXManager:Play(MinigameSounds.ZAP)
    end

    if eel:GetSprite():IsEventTriggered("Shoot") then
        local spawningPos = eel.Position + Vector(10, 0)
        local spawningSpeed = (game:GetPlayer(0).Position - spawningPos):Normalized() * 10
        local projectileType = 2
        local params = ProjectileParams()
        params.BulletFlags = ProjectileFlags.NO_WALL_COLLIDE
        params.Spread = 1
        eel:ToNPC():FireProjectiles(spawningPos, spawningSpeed, projectileType, params)
    end

    if eel:GetSprite():IsFinished("Shoot") then
        eel:GetSprite():Play("Idle", true)
    end
end


---@param clam EntityNPC
local function UpdateClam(clam)
    clam:AddEntityFlags(EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)

    if CurrentMinigameState == MinigameState.SWIMMING then
        clam.Velocity = Vector(0, MinigameConstants.CLAM_VELOCITY)

        if clam.Position.Y > MinigameConstants.CLAM_SPAWNING_Y then
            clam:Remove()
        end

        return
    end

    if clam.Position.Y <= MinigameConstants.CLAM_TARGET_Y then
        clam.Velocity = Vector.Zero
    end

    if clam:IsFrame(MinigameConstants.CLAM_SHOOT_COOLDOWN, 0) and clam.Position.Y <= MinigameConstants.CLAM_TARGET_Y then
        clam:GetSprite():Play("Shoot", true)
        local spawningPos = clam.Position + Vector(0, 5)
        local spawningSpeed = (game:GetPlayer(0).Position - spawningPos):Normalized() * 10
        local projectileType = 0
        local params = ProjectileParams()
        params.BulletFlags = ProjectileFlags.NO_WALL_COLLIDE
        params.Spread = 1
        clam:FireProjectiles(spawningPos, spawningSpeed, projectileType, params)
    end

    if clam:GetSprite():IsFinished("Shoot") then
        clam:GetSprite():Play("Idle", true)
    end
end


---@param anglerFish EntityNPC
---@param anglerFishSpr Sprite
local function CalculateAnglerFishVel(anglerFish, anglerFishSpr)
    if anglerFishSpr:IsPlaying("ProjectileStart") or anglerFishSpr:IsPlaying("ChargeStart") then
        if anglerFishSpr:IsPlaying("ProjectileStart") then
            anglerFish.Velocity = Vector.Zero
        else
            if anglerFish.FlipX then
                anglerFish.Velocity = Vector(-MinigameConstants.ANGLER_FISH_CHARGE_START_VELOCITY, 0)
            else
                anglerFish.Velocity = Vector(MinigameConstants.ANGLER_FISH_CHARGE_START_VELOCITY, 0)
            end
        end

        if game:GetFrameCount() % 2 == 0 then
            anglerFish.Position = anglerFish.Position + Vector(5, 0)
        else
            anglerFish.Position = anglerFish.Position - Vector(5, 0)
        end
    elseif anglerFishSpr:IsPlaying("ProjectileLoop") then
        anglerFish.Velocity = Vector.Zero
    elseif anglerFishSpr:IsPlaying("ChargeLoop") then
        if anglerFish.FlipX then
            anglerFish.Velocity = Vector(MinigameConstants.ANGLER_FISH_CHARGE_VELOCITY, 0)
        else
            anglerFish.Velocity = Vector(-MinigameConstants.ANGLER_FISH_CHARGE_VELOCITY, 0)
        end
    elseif anglerFishSpr:IsPlaying("Idle") then
        if (anglerFish.FlipX and anglerFish.Position.X < MinigameConstants.ANGLER_FISH_NORMAL_ATTACK_LEFT) or
        (not anglerFish.FlipX and anglerFish.Position.X > MinigameConstants.ANGLER_FISH_NORMAL_ATTACK_RIGHT) then
            --Move chuck to his attacking position
            if anglerFish.FlipX then
                anglerFish.Velocity = Vector(MinigameConstants.ANGLER_FISH_VELOCITY, 0)
            else
                 anglerFish.Velocity = Vector(-MinigameConstants.ANGLER_FISH_VELOCITY, 0)
            end
        elseif anglerFish.Position.Y <= game:GetRoom():GetCenterPos().Y then
            anglerFish.Velocity = Vector.Zero
            anglerFish:GetData().IsWaitingForSound = true
        else
            anglerFish.Velocity = Vector(0, -MinigameConstants.ANGLER_FISH_VELOCITY)
        end
    end
end


---@param anglerFish EntityNPC
---@param anglerFishSpr Sprite
local function ManageAttacking(anglerFish, anglerFishSpr)
    if anglerFish:GetData().IsChicaneryMode then return end

    if (anglerFish.FlipX and anglerFish.Position.X < MinigameConstants.ANGLER_FISH_NORMAL_ATTACK_LEFT) or
    (not anglerFish.FlipX and anglerFish.Position.X > MinigameConstants.ANGLER_FISH_NORMAL_ATTACK_RIGHT) then
        return
    end

    if MinigameTimers.AnglerFishAttackTimer > 0 then
        MinigameTimers.AnglerFishAttackTimer = MinigameTimers.AnglerFishAttackTimer - 1
        return
    end

    if not anglerFishSpr:IsPlaying("Idle") then return end

    if anglerFish.HitPoints / anglerFish.MaxHitPoints <= 0.25 then
        anglerFish:GetData().IsChicaneryMode = true
        anglerFishSpr:Play("ChargeStart", true)
        SFXManager:Play(MinigameSounds.CHUCK_DASH_START)
        return
    end

    if AnglerFishAttacksInARow == MinigameConstants.ANGLER_FISH_MAX_ATTACKS_IN_A_ROW then
        anglerFishSpr:Play("ChargeStart", true)
        SFXManager:Play(MinigameSounds.CHUCK_DASH_START)
        AnglerFishAttacksInARow = 0
        return
    end

    if rng:RandomInt(2) == 0 then
        anglerFishSpr:Play("ProjectileStart", true)
        SFXManager:Play(MinigameSounds.HISS)
    else
        anglerFishSpr:Play("SpawnCunts", true)
    end

    AnglerFishAttacksInARow = AnglerFishAttacksInARow + 1
end


---@param anglerFish EntityNPC
local function UpdateAnglerFish(anglerFish)
    local anglerFishSpr = anglerFish:GetSprite()

    CalculateAnglerFishVel(anglerFish, anglerFishSpr)

    if anglerFish.Position.Y <= MinigameConstants.ANGLER_FISH_Y_SOUND and not anglerFish:GetData().HasPlayedSound then
        anglerFish:GetData().HasPlayedSound = true
        SFXManager:Play(MinigameSounds.CHUCK_CHICANERY)
    end

    if anglerFish:GetData().IsWaitingForSound and not SFXManager:IsPlaying(MinigameSounds.CHUCK_CHICANERY) then
        if not anglerFish:GetData().CanDoAttacks then
            anglerFish:GetData().CanDoAttacks = true
            MinigameTimers.AnglerFishAttackTimer = MinigameConstants.ANGLER_FISH_INITIAL_COOLDOWN
        end
    end

    if not anglerFish:GetData().CanDoAttacks then return end

    ManageAttacking(anglerFish, anglerFishSpr)

    if anglerFishSpr:IsFinished("ProjectileStart") then
        anglerFishSpr:Play("ProjectileLoop", true)
    end

    if anglerFishSpr:IsPlaying("ProjectileLoop") then
        local frame = anglerFishSpr:GetFrame()
        if frame % 3 == 0 and frame % 6 == 0 then
            anglerFishSpr:SetOverlayFrame("BlueTail", frame)
        elseif frame % 3 == 0 then
            anglerFishSpr:SetOverlayFrame("WhiteTail", frame)
        end
    end

    if anglerFishSpr:IsFinished("ProjectileLoop") then
        if AnglerFishProjectiles == MinigameConstants.ANGLER_FISH_PROJECTILE_NUMBER then
            AnglerFishProjectiles = 0
            anglerFishSpr:Play("Idle", true)
            anglerFishSpr:PlayOverlay("IdleTail", true)
            MinigameTimers.AnglerFishAttackTimer = MinigameConstants.ANGLER_FISH_ATTACK_COOLDOWN
        else
            anglerFishSpr:Play("ProjectileLoop", true)
        end
    end

    if anglerFishSpr:IsFinished("ChargeStart") then
        anglerFishSpr:Play("ChargeLoop", true)
        anglerFishSpr:PlayOverlay("ChargeTail", true)
        SFXManager:Play(MinigameSounds.CHUCK_DASH)
        game:ShakeScreen(25)
    end

    if anglerFishSpr:IsFinished("SpawnCunts") then
        anglerFishSpr:Play("Idle", true)
        MinigameTimers.AnglerFishAttackTimer = MinigameConstants.ANGLER_FISH_ATTACK_COOLDOWN
    end

    if anglerFishSpr:IsPlaying("ChargeLoop") and
    (anglerFish.Position.X < MinigameConstants.ANGLER_FISH_CHARGE_STOP_LEFT and not anglerFish.FlipX or
    anglerFish.Position.X > MinigameConstants.ANGLER_FISH_CHARGE_STOP_RIGHT and anglerFish.FlipX) then
        anglerFish.FlipX = not anglerFish.FlipX

        if anglerFish:GetData().IsChicaneryMode then
            anglerFish.Position = Vector(anglerFish.Position.X, game:GetPlayer(0).Position.Y)
            SFXManager:Play(MinigameSounds.CHUCK_DASH)
            game:ShakeScreen(25)
        else
            anglerFishSpr:Play("Idle", true)
            anglerFishSpr:PlayOverlay("IdleTail", true)
        end
    end

    if anglerFishSpr:IsEventTriggered("SpawnCunts") then
        SFXManager:Play(MinigameSounds.RAWR)

        for _ = 1, MinigameConstants.BONE_CUNTS_NUMBER, 1 do
            local spawnOffset = Vector(MinigameConstants.ANGLER_FISH_BONE_CUNT_OFFSET.X, MinigameConstants.ANGLER_FISH_BONE_CUNT_OFFSET.Y)
            if not anglerFish.FlipX then spawnOffset.X = -spawnOffset.X end
            local spawningPos = anglerFish.Position + spawnOffset + Vector(rng:RandomInt(5), rng:RandomInt(5))
            local skellyCunt = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.CUNT, 0, spawningPos, Vector.Zero, anglerFish)
            skellyCunt:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
            skellyCunt:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
            skellyCunt:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/ns_skelly_cunt.png")
            skellyCunt:GetSprite():LoadGraphics()
            skellyCunt.DepthOffset = 30
        end
    end

    if anglerFishSpr:IsEventTriggered("ShootProjectiles") then
        SFXManager:Play(MinigameSounds.ZAP)

        local spawnOffset = Vector(MinigameConstants.ANGLER_FISH_PROJECTILE_OFFSET.X, MinigameConstants.ANGLER_FISH_PROJECTILE_OFFSET.Y)
        if not anglerFish.FlipX then spawnOffset.X = -spawnOffset.X end
        local spawningPos = anglerFish.Position + spawnOffset
        local spawningSpeed = (game:GetPlayer(0).Position - spawningPos):Normalized() * 5
        local projectileType = 0
        local params = ProjectileParams()
        params.BulletFlags = ProjectileFlags.NO_WALL_COLLIDE | ProjectileFlags.SMART
        params.Spread = 1
        anglerFish:FireProjectiles(spawningPos, spawningSpeed, projectileType, params)

        AnglerFishProjectiles = AnglerFishProjectiles + 1
    end
end


function no_splash:OnNPCUpdate(entity)
    if entity.Variant == MinigameEntityVariants.FISH then
        UpdateFish(entity)
    elseif entity.Variant == MinigameEntityVariants.CUNT then
        UpdateCunt(entity)
    elseif entity.Variant == MinigameEntityVariants.EEL then
        UpdateEel(entity)
    elseif entity.Variant == MinigameEntityVariants.CLAM then
        UpdateClam(entity)
    elseif entity.Variant == MinigameEntityVariants.ANGLER_FISH then
        UpdateAnglerFish(entity)
    end
end
no_splash.callbacks[ModCallbacks.MC_NPC_UPDATE] = no_splash.OnNPCUpdate


function no_splash:OnEntityDamage(tookDamage, damageAmount, _, _)
    if tookDamage:ToPlayer() then
        if MinigameTimers.IFramesTimer <= 0 then
            PlayerHP = PlayerHP - 1
            SFXManager:Play(MinigameSounds.PLAYER_HIT)
            PlayerHealthUI:Play("Flash", true)
            MinigameTimers.IFramesTimer = MinigameConstants.MAX_PLAYER_IFRAMES
        end

        return false
    elseif tookDamage.Type == MinigameEntityTypes.CUSTOM_ENTITY and tookDamage.Variant == MinigameEntityVariants.FISH and tookDamage.SubType == 0 and 
    damageAmount >= tookDamage.HitPoints then
        if tookDamage:GetSprite():IsPlaying("Transition") then return false end

        local bonerFish = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.FISH, 1, tookDamage.Position, Vector.Zero, nil)
        bonerFish:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/ns_bone_fish.png")
        bonerFish:GetSprite():LoadGraphics()
        bonerFish:GetSprite():Play("Transition", true)
        bonerFish:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
        bonerFish:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
        bonerFish.FlipX = tookDamage.FlipX
        tookDamage:Remove()
    elseif tookDamage.Type == MinigameEntityTypes.CUSTOM_ENTITY and tookDamage.Variant == MinigameEntityVariants.SPIKED_MINE and tookDamage.SubType == 0 and 
    damageAmount >= tookDamage.HitPoints then
        local params = ProjectileParams()
        params.BulletFlags = ProjectileFlags.NO_WALL_COLLIDE
        params.Spread = 1
        tookDamage:ToNPC():FireProjectiles(tookDamage.Position, Vector(10, 0), 8, params)
        tookDamage:Remove()
    elseif tookDamage.Type == MinigameEntityTypes.CUSTOM_ENTITY and 
    (tookDamage.Variant == MinigameEntityVariants.EEL or tookDamage.Variant == MinigameEntityVariants.CUNT or tookDamage.Variant == MinigameEntityVariants.FISH or tookDamage.Variant == MinigameEntityVariants.CLAM) and
    damageAmount >= tookDamage.HitPoints then
        tookDamage:Remove()
    elseif tookDamage.Type == MinigameEntityTypes.CUSTOM_ENTITY and tookDamage.Variant == MinigameEntityVariants.ANGLER_FISH then
        MinigameTimers.BossHealthFlashTimer = MinigameConstants.MAX_BOSS_HEALTH_FLASH_FRAMES
    end
end
no_splash.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG] = no_splash.OnEntityDamage


local function SetUpSpikeProjectile(projectile)
    local pSprite = projectile:GetSprite()
    pSprite:Load("gfx/ns_spike_projectile.anm2", true)

    local pVelocity = projectile.Velocity

    if math.abs(math.abs(pVelocity.X) - math.abs(pVelocity.Y)) > 0.1 then
        --Not diagonal :)
        if math.abs(pVelocity.X) > math.abs(pVelocity.Y) then
            if pVelocity.X > 0 then
                pSprite:Play("Right", true)
            else
                pSprite:Play("Left", true)
            end
        else
            if pVelocity.Y > 0 then
                pSprite:Play("Down", true)
            else
                pSprite:Play("Up", true)
            end
        end
    else
        --Diagonal
        if pVelocity.Y > 0 then
            if pVelocity.X > 0 then
                pSprite:Play("Down-Right", true)
            else
                pSprite:Play("Down-Left", true)
            end
        else
            if pVelocity.X > 0 then
                pSprite:Play("Up-Right", true)
            else
                pSprite:Play("Up-Left", true)
            end
        end
    end
end


---@param projectile EntityProjectile
function no_splash:OnProjectileInit(projectile)
    if projectile.SpawnerType ~= MinigameEntityTypes.CUSTOM_ENTITY then return end

    projectile.DepthOffset = 20

    if projectile.SpawnerVariant == MinigameEntityVariants.EEL or projectile.SpawnerVariant == MinigameEntityVariants.ANGLER_FISH then
        projectile:GetSprite():Load("gfx/ns_eel_projectile.anm2", true)
        projectile:GetSprite():Play("Idle", true)
    elseif projectile.SpawnerVariant == MinigameEntityVariants.CLAM then
        projectile:GetSprite():Load("gfx/ns_pearl_projectile.anm2", true)
        projectile:GetSprite():Play("Idle", true)
    elseif projectile.SpawnerVariant == MinigameEntityVariants.SPIKED_MINE then
        SetUpSpikeProjectile(projectile)
    end
end
no_splash.callbacks[ModCallbacks.MC_POST_PROJECTILE_INIT] = no_splash.OnProjectileInit


function no_splash:OnProjectileUpdate(projectile)
    projectile:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 300, -1, false, false)

    projectile.FallingSpeed = 0
    projectile.FallingAccel = -0.1
end
no_splash.callbacks[ModCallbacks.MC_POST_PROJECTILE_UPDATE] = no_splash.OnProjectileUpdate


function no_splash:OnInput(_, inputHook, buttonAction)
    if CurrentMinigameState ~= MinigameState.SWIMMING then return end

    if buttonAction == ButtonAction.ACTION_UP or buttonAction == ButtonAction.ACTION_DOWN or
     buttonAction == ButtonAction.ACTION_LEFT or buttonAction == ButtonAction.ACTION_RIGHT then
        if inputHook > InputHook.IS_ACTION_TRIGGERED then
            return 0
        else
            return false
        end
    end
end
no_splash.callbacks[ModCallbacks.MC_INPUT_ACTION] = no_splash.OnInput


---@param player EntityPlayer
function no_splash:OnPlayerUpdate(player)
    player:GetData().FakePlayer.Position = player.Position + Vector(0, 0.1)

    local fakePlayerSprite = player:GetData().FakePlayer:GetSprite()

    if (Input.IsActionPressed(ButtonAction.ACTION_LEFT, player.ControllerIndex) or Input.IsActionPressed(ButtonAction.ACTION_RIGHT, player.ControllerIndex)) and not
    (Input.IsActionPressed(ButtonAction.ACTION_LEFT, player.ControllerIndex) and Input.IsActionPressed(ButtonAction.ACTION_RIGHT, player.ControllerIndex)) then
        if Input.IsActionPressed(ButtonAction.ACTION_LEFT, player.ControllerIndex) and not fakePlayerSprite:IsPlaying("Left") then
            fakePlayerSprite:Play("Left", true)
        elseif Input.IsActionPressed(ButtonAction.ACTION_RIGHT, player.ControllerIndex) and not fakePlayerSprite:IsPlaying("Right") then
            fakePlayerSprite:Play("Right", true)
        end
    else
        fakePlayerSprite:Play("Idle", true)
    end

    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_RANGE)
    player:EvaluateItems()
end
no_splash.callbacks[ModCallbacks.MC_POST_PLAYER_UPDATE] = no_splash.OnPlayerUpdate


function no_splash:OnCache(player, cacheFlags)
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
no_splash.callbacks[ModCallbacks.MC_EVALUATE_CACHE] = no_splash.OnCache


function no_splash:OnTearFire(tear)
    SFXManager:Stop(SoundEffect.SOUND_TEARS_FIRE)
    tear:GetSprite():Load("gfx/ns_player_tear.anm2", true)

    if math.abs(tear.Velocity.X) > math.abs(tear.Velocity.Y) then
        if tear.Velocity.X > 0 then
            tear:GetSprite():Play("Right", true)
        else
            tear:GetSprite():Play("Left", true)
        end
    else
        if tear.Velocity.Y > 0 then
            tear:GetSprite():Play("Down", true)
        else
            tear:GetSprite():Play("Up", true)
        end
    end
end
no_splash.callbacks[ModCallbacks.MC_POST_FIRE_TEAR] = no_splash.OnTearFire


function RenderUI()
    if PlayerHealthUI:IsPlaying("Flash") then
        PlayerHealthUI:Update()
    else
        PlayerHealthUI:Play("Idle", true)
        PlayerHealthUI:SetFrame(PlayerHP)
    end
    PlayerHealthUI:Render(MinigameConstants.PLAYER_HEALTH_RENDER_POS, Vector.Zero, Vector.Zero)

    if CurrentMinigameState == MinigameState.FIGHTING then
        CoolTextUI:Play("FIGHT", true)
    else
        CoolTextUI:Play("GO", true)
    end

    CoolTextUI:Render(Vector(Isaac.GetScreenWidth()/2, 20), Vector.Zero, Vector.Zero)

    if #Isaac.FindByType(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.ANGLER_FISH) == 0 then return end

    if MinigameTimers.BossHealthFlashTimer > 0 then
        BossHealthUI:Play("Flash", true)
    else
        BossHealthUI:Play("Idle", true)
    end

    local chuck = Isaac.FindByType(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.ANGLER_FISH)[1]
    BossHealthUI:SetFrame(math.floor(chuck.HitPoints/chuck.MaxHitPoints * 40))
    BossHealthUI:Render(Vector(Isaac.GetScreenWidth() - MinigameConstants.PLAYER_HEALTH_RENDER_POS.X, MinigameConstants.PLAYER_HEALTH_RENDER_POS.Y), Vector.Zero, Vector.Zero)
end


function no_splash:OnRender()
    RenderUI()

    -- RenderFadeOut()

    -- RenderVsScreen()
end
no_splash.callbacks[ModCallbacks.MC_POST_RENDER] = no_splash.OnRender


return no_splash