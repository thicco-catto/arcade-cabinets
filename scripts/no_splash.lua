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
    BUBBLE = Isaac.GetEntityVariantByName("bubble NS"),
    BACKGROUND = Isaac.GetEntityVariantByName("background TGB"),
}

-- Constants
local MinigameConstants = {
    --Bubble stuff
    MIN_BUBBLE_SPAWN_TIMER_FRAMES = 7,
    RANDOM_FRAMES_BUBBLE_SPAWN_TIMER = 10,
    BUBBLE_Y_SPAWN_POSITION = 600,
    BUBBLE_MAX_X_SPAWN_POSITION = 600,
    BUBBLE_Y_VELOCITY = 4,
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
end


local function SpawnBubbles()
    if MinigameTimers.BubbleSpawnTimer > 0 then
        MinigameTimers.BubbleSpawnTimer = MinigameTimers.BubbleSpawnTimer - 1
        return
    end

    MinigameTimers.BubbleSpawnTimer = MinigameConstants.MIN_BUBBLE_SPAWN_TIMER_FRAMES + rng:RandomInt(MinigameConstants.RANDOM_FRAMES_BUBBLE_SPAWN_TIMER)

    local xPosition = rng:RandomInt(MinigameConstants.BUBBLE_MAX_X_SPAWN_POSITION)
    local bubble = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BUBBLE, 0, Vector(xPosition, MinigameConstants.BUBBLE_Y_SPAWN_POSITION), Vector(0, -MinigameConstants.BUBBLE_Y_VELOCITY), nil)
    local bubbleSize = rng:RandomInt(3) + 1
    bubble:GetSprite():Play("Idle" .. bubbleSize, true)
    bubble.DepthOffset = -500
end


function no_splash:OnUpdate()
    SpawnBubbles()
end
no_splash.callbacks[ModCallbacks.MC_POST_UPDATE] = no_splash.OnUpdate


return no_splash