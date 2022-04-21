local gush = {}
local game = Game()
local rng = RNG()
local SFXManager = SFXManager()
local MusicManager = MusicManager()
----------------------------------------------
--FANCY REQUIRE (Thanks manaphoenix <3)
----------------------------------------------
local function loadFile(loc, ...)
    local _, err = pcall(require, "")
    local modName = err:match("/mods/(.*)/%.lua")
    local path = "mods/" .. modName .. "/"

    return assert(loadfile(path .. loc .. ".lua"))(...)
end
local ArcadeCabinetVariables = loadFile("scripts/variables")

gush.callbacks = {}
gush.result = nil
gush.startingItems = {
}

--Sounds
local BannedSounds = {
}

local ReplacementSounds = {
}

local MinigameSounds = {
}

local MinigameMusic = Isaac.GetMusicIdByName("jc corpse beat")

--Entities
local MinigameEntityVariants = {
}

--Constants
local MinigameConstants = {
    JUMPING_SPEED_THRESHOLD = 0.17,
    GRID_OFFSET_TO_GET_UNDER = 28,
    JUMPING_STRENGTH = 7
}

--Timers
local MinigameTimers = {
}

--States
local MinigameStates = {
    WINNING = 4,
    LOSING = 5
}
local CurrentMinigameState = 0

--UI
local WaveTransitionScreen = Sprite()
WaveTransitionScreen:Load("gfx/minigame_transition.anm2")

--INIT
function gush:Init()
    local room = game:GetRoom()

    --Reset variables
    gush.result = nil

    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    --Reset timers
    for _, timer in pairs(MinigameTimers) do
        timer = 0
    end

    --Spawn the backdrop
    -- local backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop2x2Variant, 0, room:GetCenterPos(), Vector.Zero, nil)
    -- backdrop.DepthOffset = -1000

    --Play music
    MusicManager:Play(MinigameMusic, 1)
    MusicManager:UpdateVolume()
    MusicManager:Pause()

    --Set up players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        for _, item in ipairs(gush.startingItems) do
            player:AddCollectible(item, 0, false)
        end

        --Set spritesheet
        -- local playerSprite = player:GetSprite()
        -- playerSprite:Load("gfx/isaac52.anm2", true)
        -- playerSprite:ReplaceSpritesheet(1, "gfx/characters/isaac_jc.png")
        -- playerSprite:ReplaceSpritesheet(4, "gfx/characters/isaac_jc.png")
        -- playerSprite:ReplaceSpritesheet(12, "gfx/characters/isaac_jc.png")
        -- playerSprite:LoadGraphics()
    end
end


--UPDATE CALLBACKS
local function IsPlayerOnFloor(player)
    local room = game:GetRoom()
    local gridIndex = room:GetClampedGridIndex(player.Position)
    local collisionClass = room:GetGridCollision(gridIndex + MinigameConstants.GRID_OFFSET_TO_GET_UNDER)

    if collisionClass == GridCollisionClass.COLLISION_SOLID or collisionClass == GridCollisionClass.COLLISION_WALL then
        print(collisionClass .. " yay")
    else
        print(collisionClass .. " nay")
    end

    return collisionClass == GridCollisionClass.COLLISION_SOLID or collisionClass == GridCollisionClass.COLLISION_WALL
end

function gush:PlayerUpdate(player)
    player:GetData().IsGrounded = math.abs(player.Velocity.Y) < MinigameConstants.JUMPING_SPEED_THRESHOLD

    if Input.IsActionPressed(ButtonAction.ACTION_ITEM, player.ControllerIndex) and
     player:GetData().IsGrounded and IsPlayerOnFloor(player) then
        player.Velocity = player.Velocity + Vector(0, -MinigameConstants.JUMPING_STRENGTH)
    end
end
gush.callbacks[ModCallbacks.MC_POST_PLAYER_UPDATE] = gush.PlayerUpdate


function gush:OnRender()
    -- RenderUI()

    -- RenderWaveTransition()

    -- RenderFadeOut()

    -- local playerNum = game:GetNumPlayers()
    -- for i = 0, playerNum - 1, 1 do
    --     local player = game:GetPlayer(i)
    --     local pos = Isaac.WorldToScreen(player.Position)

    --     local ground = ", false"
    --     if player:GetData().IsGrounded then
    --         ground = ", true"
    --     end

    --     Isaac.RenderText(player.Velocity.Y .. ground, pos.X, pos.Y, 1, 1, 1, 255)
    -- end

    -- local room = game:GetRoom()
    -- for i = 18, 419, 1 do
    --     local gridcollision = room:GetGridCollision(i)
    --     local pos = Isaac.WorldToScreen(room:GetGridPosition(i))

    --     Isaac.RenderText(gridcollision, pos.X, pos.Y, 1, 1, 1, 255)
    -- end
end
gush.callbacks[ModCallbacks.MC_POST_RENDER] = gush.OnRender

return gush