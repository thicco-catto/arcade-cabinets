local the_ground_below = {}
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

the_ground_below.callbacks = {}
the_ground_below.result = nil
the_ground_below.startingItems = {}

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
    BACKGROUND = Isaac.GetEntityVariantByName("background TGB")
}

-- Constants
local MinigameConstants = {
    BG_SCROLLING_SPEED = 10
}

-- Timers
local MinigameTimers = {
}

-- States
local CurrentMinigameState = 0
local MinigameState = {

    LOSING = 5,
    WINNING = 6,
}

-- UI
local TransitionScreen = Sprite()
TransitionScreen:Load("gfx/minigame_transition.anm2")
TransitionScreen:ReplaceSpritesheet(0, "gfx/effects/holy smokes/hs_vs_screen.png")
TransitionScreen:LoadGraphics()

-- Other variables
local PlayerHP = 0

-- INIT MINIGAME
function the_ground_below:Init()
    -- Reset variables
    the_ground_below.result = nil

    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    -- Backdrop
    local bg = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND, 0, game:GetRoom():GetCenterPos() - Vector(0, 120), Vector.Zero, nil)
    bg.DepthOffset = -1000
    bg:GetSprite():ReplaceSpritesheet(0, "gfx/grid/tgb_rocks_start.png")
    bg:GetSprite():LoadGraphics()

    local bg2 = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND, 0, bg.Position + Vector(0,440), Vector.Zero, nil)
    bg2.DepthOffset = -1000
    bg.Child = bg2

    -- Prepare players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        for _, item in ipairs(the_ground_below.startingItems) do
            player:AddCollectible(item, 0, false)
        end

        --Set the spritesheets
        local playerSprite = player:GetSprite()
        playerSprite:Load("gfx/hs_isaac52.anm2", true)
        playerSprite:ReplaceSpritesheet(1, "gfx/characters/isaac_hs.png")
        playerSprite:ReplaceSpritesheet(4, "gfx/characters/isaac_hs.png")
        playerSprite:ReplaceSpritesheet(12, "gfx/characters/isaac_hs.png")
        playerSprite:LoadGraphics()
    end
end


function the_ground_below:OnEffectUpdate(effect)
    if effect.Variant ~= MinigameEntityVariants.BACKGROUND then return end

    effect.Velocity = Vector(0, -MinigameConstants.BG_SCROLLING_SPEED)

    if effect.Position.Y < (game:GetRoom():GetCenterPos() - Vector(0, 120 + 440)).Y then
        local bg = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND, 0, effect.Child.Position + Vector(0,420), Vector.Zero, nil)
        bg.DepthOffset = -1000
        effect.Child.Child = bg
        effect:Remove()
    end
end
the_ground_below.callbacks[ModCallbacks.MC_POST_EFFECT_UPDATE] = the_ground_below.OnEffectUpdate


function the_ground_below:OnCMD(command, args)
    if command == "vel" then
        print("bg velocity changed")
        MinigameConstants.BG_SCROLLING_SPEED = tonumber(args)
    end

end
the_ground_below.callbacks[ModCallbacks.MC_EXECUTE_CMD] = the_ground_below.OnCMD

return the_ground_below