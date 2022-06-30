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
}

local MinigameEntityVariants = {
    FAKE_PLAYER = Isaac.GetEntityVariantByName("fake player NL"),
    BUBBLE = Isaac.GetEntityVariantByName("bubble NS"),
    BACKGROUND = Isaac.GetEntityVariantByName("background TGB"),
}

-- Constants
local MinigameConstants = {
    --Bubble stuff
    MIN_BUBBLE_SPAWN_TIMER_FRAMES = 7,
    RANDOM_FRAMES_BUBBLE_SPAWN_TIMER = 10,
    BUBBLE_Y_SPAWN_POSITION = 500,
    BUBBLE_MAX_X_SPAWN_POSITION = 600,
    BUBBLE_Y_VELOCITY = 2.5,
    BUBBLE_Y_VELOCITY_RANDOM_OFFSET = 1,
    BUBBLE_X_ACCELERATION = 0.1,
    BUBBLE_MAX_X_VELOCITY = 2
}

-- Timers
local MinigameTimers = {
    BubbleSpawnTimer = 0
}

-- States
local CurrentMinigameState = 0
local MinigameState = {

    LOSING = 5,
    WINNING = 6,
}

-- UI
local TransitionScreen = Sprite()
TransitionScreen:Load("gfx/minigame_transition.anm2", true)

--Other Variables
local CurrentBubbleXVelocity = 0

function no_splash:Init()
    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    local overlay = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND, 0, game:GetRoom():GetCenterPos(), Vector.Zero, nil)
    overlay:GetSprite():Load("gfx/ns_overlay.anm2", true)
    overlay:GetSprite():Play("Idle", true)
    overlay.DepthOffset = 1000

    local bg = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND, 0, game:GetRoom():GetCenterPos(), Vector.Zero, nil)
    bg:GetSprite():Load("gfx/ns_bg.anm2", true)
    bg:GetSprite():Play("Idle", true)
    bg.DepthOffset = -1000

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
    (Input.IsActionPressed(ButtonAction.ACTION_LEFT, 0) and Input.IsActionPressed(ButtonAction.ACTION_RIGHT, 0)) then
        if Input.IsActionPressed(ButtonAction.ACTION_LEFT, 0) then
            CurrentBubbleXVelocity = CurrentBubbleXVelocity - MinigameConstants.BUBBLE_X_ACCELERATION

            if CurrentBubbleXVelocity < -MinigameConstants.BUBBLE_MAX_X_VELOCITY then
                CurrentBubbleXVelocity = -MinigameConstants.BUBBLE_MAX_X_VELOCITY
            end
        end

        if Input.IsActionPressed(ButtonAction.ACTION_RIGHT, 0) then
            CurrentBubbleXVelocity = CurrentBubbleXVelocity + MinigameConstants.BUBBLE_X_ACCELERATION

            if CurrentBubbleXVelocity > MinigameConstants.BUBBLE_MAX_X_VELOCITY then
                CurrentBubbleXVelocity = MinigameConstants.BUBBLE_MAX_X_VELOCITY
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
end
no_splash.callbacks[ModCallbacks.MC_POST_UPDATE] = no_splash.OnUpdate


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


function no_splash:OnInput(_, inputHook, buttonAction)
    if buttonAction == ButtonAction.ACTION_UP or buttonAction == ButtonAction.ACTION_DOWN or
     buttonAction == ButtonAction.ACTION_LEFT or buttonAction == ButtonAction.ACTION_RIGHT or
     buttonAction == ButtonAction.ACTION_SHOOTLEFT or buttonAction == ButtonAction.ACTION_SHOOTRIGHT or
     buttonAction == ButtonAction.ACTION_SHOOTUP or buttonAction == ButtonAction.ACTION_SHOOTDOWN then
        if inputHook > InputHook.IS_ACTION_TRIGGERED then
            return 0
        else
            return false
        end
    end
end
no_splash.callbacks[ModCallbacks.MC_INPUT_ACTION] = no_splash.OnInput

function no_splash:OnPlayerUpdate(player)
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


return no_splash