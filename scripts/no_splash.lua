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
    SPIKED_MINE = Isaac.GetEntityVariantByName("spiked mine NS"),
}

-- Constants
local MinigameConstants = {
    ARROW_SPAWNING_POS = Vector(400, 200),

    --Wave stuff
    MAX_WAVES = 3,
    DISTANCE_NEEDED_FOR_WAVE_START = 450,

    --Bubble stuff
    MIN_BUBBLE_SPAWN_TIMER_FRAMES = 7,
    RANDOM_FRAMES_BUBBLE_SPAWN_TIMER = 10,
    BUBBLE_Y_SPAWN_POSITION = 500,
    BUBBLE_MAX_X_SPAWN_POSITION = 600,
    BUBBLE_Y_VELOCITY = 2.5,
    BUBBLE_Y_VELOCITY_RANDOM_OFFSET = 1,
    BUBBLE_X_ACCELERATION = 0.1,
    BUBBLE_MAX_X_VELOCITY = 2,

    --Fish stuff
    FISH_VELOCITY = 3.5,
    BONE_FISH_VELOCITY = 5,

    --Cunt stuff
    CUNT_VELOCITY = 4,

    --Eel stuff
    EEL_VELOCITY = 3,
    EEL_SHOOT_COOLDOWN = 60,
}

-- Timers
local MinigameTimers = {
    BubbleSpawnTimer = 0
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

--Other Variables
local CurrentBubbleXVelocity = 0
local DistanceTraveled = 0
local CurrentWave = 0
local Arrow = nil


function no_splash:Init()
    --Reset variables
    CurrentWave = 0
    DistanceTraveled = 0
    no_splash.result = nil

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


function no_splash:OnUpdate()
    SpawnBubbles()

    CalculateBubbleVelocity()

    Arrow.Velocity = Vector(CurrentBubbleXVelocity, 0)
    DistanceTraveled = DistanceTraveled - CurrentBubbleXVelocity

    if DistanceTraveled >= MinigameConstants.DISTANCE_NEEDED_FOR_WAVE_START then
        CurrentBubbleXVelocity = 0
        CurrentMinigameState = MinigameState.FIGHTING
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

    if eel:IsFrame(MinigameConstants.EEL_SHOOT_COOLDOWN, 0) then
        eel:GetSprite():Play("Shoot", true)
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


function no_splash:OnNPCUpdate(entity)
    if entity.Variant == MinigameEntityVariants.FISH then
        UpdateFish(entity)
    elseif entity.Variant == MinigameEntityVariants.CUNT then
        UpdateCunt(entity)
    elseif entity.Variant == MinigameEntityVariants.EEL then
        UpdateEel(entity)
    end
end
no_splash.callbacks[ModCallbacks.MC_NPC_UPDATE] = no_splash.OnNPCUpdate


function no_splash:OnEntityDamage(tookDamage, damageAmount, _, _)
    if tookDamage:ToPlayer() then
        return false
    elseif tookDamage.Type == MinigameEntityTypes.CUSTOM_ENTITY and tookDamage.Variant == MinigameEntityVariants.FISH and tookDamage.SubType == 0 and 
    damageAmount >= tookDamage.HitPoints then
        if tookDamage:GetSprite():IsPlaying("Transition") then return false end

        local bonerFish = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENTITY, MinigameEntityVariants.FISH, 1, tookDamage.Position, Vector.Zero, nil)
        bonerFish:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/ns_bone_fish.png")
        bonerFish:GetSprite():LoadGraphics()
        bonerFish:GetSprite():Play("Transition", true)
        bonerFish:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
        bonerFish:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE | EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
        bonerFish.FlipX = tookDamage.FlipX
        tookDamage:Remove()
    elseif tookDamage.Type == MinigameEntityTypes.CUSTOM_ENTITY and tookDamage.Variant == MinigameEntityVariants.EEL and
    damageAmount >= tookDamage.HitPoints then
        tookDamage:Remove()
    end
end
no_splash.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG] = no_splash.OnEntityDamage


function no_splash:OnProjectileInit(projectile)
    if projectile.SpawnerType == MinigameEntityTypes.CUSTOM_ENTITY and projectile.SpawnerVariant == MinigameEntityVariants.EEL then
        projectile:GetSprite():Load("gfx/ns_eel_projectile.anm2", true)
        projectile:GetSprite():Play("Idle", true)
    end
end
no_splash.callbacks[ModCallbacks.MC_POST_PROJECTILE_INIT] = no_splash.OnProjectileInit


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
end
no_splash.callbacks[ModCallbacks.MC_POST_PLAYER_UPDATE] = no_splash.OnPlayerUpdate


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


function no_splash:OnRender()
    -- RenderUI()

    -- RenderFadeOut()

    -- RenderVsScreen()

    Isaac.RenderText(DistanceTraveled, 50, 50, 1, 1, 1, 1)
end
no_splash.callbacks[ModCallbacks.MC_POST_RENDER] = no_splash.OnRender


return no_splash