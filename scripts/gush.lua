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
    PLATFORM = Isaac.GetEntityVariantByName("platform GUSH"),
    PLAYER = Isaac.GetEntityVariantByName("player GUSH"),
}

--Constants
local MinigameConstants = {
    JUMPING_SPEED_THRESHOLD = 0.17,
    TOP_JUMPING_SPEED_THRESHOLD = 2.5,
    GRID_OFFSET_TO_GET_UNDER = 28,
    JUMPING_STRENGTH = 15,
    EXTRA_JUMP_FRAMES = 15,
    EXTRA_JUMP_REDUCED_GRAVITY = 0.01,
    EXTRA_JUMP_STRENGTH = 2,

    TERMINAL_VELOCITY = 15,
    GRAVITY_STRENGTH = 0.7,

    DISTANCE_FROM_PLAYER_TO_PLATFORM = 10
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

local IsExtraJumpStrength = false
local RoomPlatforms = {}


local function FindPlatforms()
    RoomPlatforms = {}
    local room = game:GetRoom()
    local foundPlatforms = Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.PLATFORM, 0)

    for _, platform in ipairs(foundPlatforms) do
        RoomPlatforms[room:GetClampedGridIndex(platform.Position)] = true
    end
end


--INIT
function gush:Init()
    local room = game:GetRoom()

    --Reset variables
    gush.result = nil

    FindPlatforms()

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

        player:GetData().IsGrounded = false
        player:GetData().ExtraJumpFrames = 0

        player.Visible = false
        local fakePlayer = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.PLAYER, 0, player.Position, Vector.Zero, player)
        player:GetData().FakePlayer = fakePlayer
    end
end


--UPDATE CALLBACKS
function gush:OnInput(_, inputHook, buttonAction)
    if buttonAction == ButtonAction.ACTION_UP or buttonAction == ButtonAction.ACTION_DOWN then
        if inputHook > InputHook.IS_ACTION_TRIGGERED then
            return 0
        else
            return false
        end
    end
end
gush.callbacks[ModCallbacks.MC_INPUT_ACTION] = gush.OnInput


local function IsPlayerOnFloor(player)
    local room = game:GetRoom()
    local gridIndex = room:GetClampedGridIndex(player.Position)
    local collisionClass = room:GetGridCollision(gridIndex + MinigameConstants.GRID_OFFSET_TO_GET_UNDER)

    return collisionClass == GridCollisionClass.COLLISION_WALL or RoomPlatforms[gridIndex + MinigameConstants.GRID_OFFSET_TO_GET_UNDER]
end


local function IsPlayerGrounded(player)
    return math.abs(player.Velocity.Y) < MinigameConstants.JUMPING_SPEED_THRESHOLD and IsPlayerOnFloor(player)
end


local function MakePlayerStandOnFloor(player)
    if not IsPlayerOnFloor(player) then return false end

    local room = game:GetRoom()
    local playerGridIndex = room:GetClampedGridIndex(player.Position)
    local playerClampedPos = room:GetGridPosition(playerGridIndex)

    if player.Position.Y - playerClampedPos.Y >= MinigameConstants.DISTANCE_FROM_PLAYER_TO_PLATFORM and 
     player.Velocity.Y >= 0 then
        player.Position = Vector(player.Position.X,playerClampedPos.Y + MinigameConstants.DISTANCE_FROM_PLAYER_TO_PLATFORM)
        player.Velocity = Vector(player.Velocity.X, 0)

        return true
    end

    return false
end


local function ApplyGravity(player, gravity)
    gravity = gravity or MinigameConstants.GRAVITY_STRENGTH

    player.Velocity = player.Velocity + Vector(0, gravity)

    if player.Velocity.Y > MinigameConstants.TERMINAL_VELOCITY then
        player.Velocity = Vector(player.Velocity.X, MinigameConstants.TERMINAL_VELOCITY)
    end
end


local function ManageFakePlayer(player)
    local fakePlayer = player:GetData().FakePlayer
    local fakePlayerSprite = fakePlayer:GetSprite()

    fakePlayer.Position = player.Position + Vector(0, 1)

    
    if player.Velocity.Y < 0 and fakePlayerSprite:IsFinished("StartJump") then
        fakePlayerSprite:Play("JumpLoop", true)
    elseif math.abs(player.Velocity.Y) < MinigameConstants.TOP_JUMPING_SPEED_THRESHOLD and not IsPlayerOnFloor(player) then
        fakePlayerSprite:Play("EndJump", true)
    elseif player.Velocity.Y > 0 and not fakePlayerSprite:IsPlaying("FallLoop") then
        fakePlayerSprite:Play("FallLoop", true)
    elseif IsPlayerGrounded(player) and fakePlayerSprite:IsPlaying("FallLoop") then
        fakePlayerSprite:Play("TouchGround", true)
    elseif fakePlayerSprite:IsFinished("TouchGround") then
        fakePlayerSprite:Play("Idle", true)
    end
end


function gush:PlayerUpdate(player)
    local gravity

    if Input.IsActionPressed(ButtonAction.ACTION_ITEM, player.ControllerIndex) then
        if IsPlayerGrounded(player) then
            player.Velocity = player.Velocity - Vector(0, MinigameConstants.JUMPING_STRENGTH)
            player:GetData().ExtraJumpFrames = MinigameConstants.EXTRA_JUMP_FRAMES

            player:GetData().FakePlayer:GetSprite():Play("StartJump", true)

            if not IsExtraJumpStrength then
                gravity = MinigameConstants.EXTRA_JUMP_REDUCED_GRAVITY
            end
        elseif player:GetData().ExtraJumpFrames > 0 then
            player:GetData().ExtraJumpFrames = player:GetData().ExtraJumpFrames - 1

            if IsExtraJumpStrength then
                player.Velocity = player.Velocity - Vector(0, MinigameConstants.EXTRA_JUMP_STRENGTH)
            else
                gravity = MinigameConstants.EXTRA_JUMP_REDUCED_GRAVITY
            end
        end
    else
        player:GetData().ExtraJumpFrames = 0
    end

    local shouldIgnoreGravity = MakePlayerStandOnFloor(player)

    if not shouldIgnoreGravity then
        ApplyGravity(player, gravity)
    end

    ManageFakePlayer(player)
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

    Isaac.RenderText("Jump strength: " .. MinigameConstants.JUMPING_STRENGTH, 10, 30, 1, 1, 1, 255)
    Isaac.RenderText("Extra jump frames: " .. MinigameConstants.EXTRA_JUMP_FRAMES, 10, 40, 1, 1, 1, 255)
    if IsExtraJumpStrength then
        Isaac.RenderText("Extra jump strength: " .. MinigameConstants.EXTRA_JUMP_STRENGTH, 10, 50, 1, 1, 1, 255)
    else
        Isaac.RenderText("Extra jump reduced gravity: " .. MinigameConstants.EXTRA_JUMP_REDUCED_GRAVITY, 10, 50, 1, 1, 1, 255)
    end

    Isaac.RenderText("Gravity strength: " .. MinigameConstants.GRAVITY_STRENGTH, 10, 70, 1, 1, 1, 255)
    Isaac.RenderText("Terminal velocity: " .. MinigameConstants.TERMINAL_VELOCITY, 10, 80, 1, 1, 1, 255)

end
gush.callbacks[ModCallbacks.MC_POST_RENDER] = gush.OnRender


-- function gush:OnEffectUpdate(effect)
--     if effect.Variant == MinigameEntityVariants.PLAYER then
--         effect.Position = effect.Parent.Position
--     end
-- end
-- gush.callbacks[ModCallbacks.MC_POST_EFFECT_UPDATE] = gush.OnEffectUpdate

local function mysplit (inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end


function gush:OnCMD(command, args)
    args = mysplit(args)
    if command == "changejump" then
        IsExtraJumpStrength = not IsExtraJumpStrength

        if IsExtraJumpStrength then
            print("Jumping mode changed to extra strength")
        else
            print("Jumping mode changed to reduced gravity")
        end

    elseif command == "change" then

        if args[1] == "js" then
            MinigameConstants.JUMPING_STRENGTH = tonumber(args[2])
            print("Changed jump strength to " .. MinigameConstants.JUMPING_STRENGTH)

        elseif args[1] == "ejf" then
            MinigameConstants.EXTRA_JUMP_FRAMES = tonumber(args[2])
            print("Changed gravity strength to " .. MinigameConstants.EXTRA_JUMP_FRAMES)

        elseif args[1] == "ejs" then
            MinigameConstants.EXTRA_JUMP_STRENGTH = tonumber(args[2])
            print("Changed extra jump strength to " .. MinigameConstants.EXTRA_JUMP_STRENGTH)

        elseif args[1] == "ejrg" then
            MinigameConstants.EXTRA_JUMP_REDUCED_GRAVITY = tonumber(args[2])
            print("Changed extra jump reduced gravity to " .. MinigameConstants.EXTRA_JUMP_REDUCED_GRAVITY)

        elseif args[1] == "gs" then
            MinigameConstants.GRAVITY_STRENGTH = tonumber(args[2])
            print("Changed gravity strength to " .. MinigameConstants.GRAVITY_STRENGTH)

        elseif args[1] == "tv" then
            MinigameConstants.TERMINAL_VELOCITY = tonumber(args[2])
            print("Changed terminal velocity to " .. MinigameConstants.TERMINAL_VELOCITY)
        end
    elseif command == "floor" then
        print(RoomPlatforms[tonumber(args)])
    end
end
gush.callbacks[ModCallbacks.MC_EXECUTE_CMD] = gush.OnCMD


return gush