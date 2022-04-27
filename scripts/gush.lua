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
    SPIKE = Isaac.GetEntityVariantByName("spike GUSH"),
    SPAWN = Isaac.GetEntityVariantByName("spawn GUSH"),
    PLAYER = Isaac.GetEntityVariantByName("player GUSH"),
}

--Constants
local MinigameConstants = {
    JUMPING_SPEED_THRESHOLD = 0.17,
    TOP_JUMPING_SPEED_THRESHOLD = 2.5, --Only for visual animation
    HORIZONTAL_SPEED_THRESHOLD = 0.5, --Only for visual animation
    OFFSET_TO_CHECK_FOR_FLOOR = 10,
    GRID_OFFSET_TO_GET_UNDER = 28,

    JUMP_BUFFER_FRAMES = 7,
    COYOTE_TIME_FRAMES = 7,

    JUMPING_STRENGTH = 13,
    EXTRA_JUMP_FRAMES = 15,
    EXTRA_JUMP_REDUCED_GRAVITY = 0.01,
    EXTRA_JUMP_STRENGTH = 0.6,

    TERMINAL_VELOCITY = 20,
    GRAVITY_STRENGTH = 1.1,

    DISTANCE_FROM_PLAYER_TO_FLOOR = 10,
    DISTANCE_FROM_PLAYER_TO_WALL = 6
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
RoomPlatforms = {}
RoomSpikes = {}
RoomSpawn = nil


local function FindGrid()
    RoomPlatforms = {}
    local room = game:GetRoom()

    local foundPlatforms = Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.PLATFORM, 0)
    for _, platform in ipairs(foundPlatforms) do
        RoomPlatforms[room:GetClampedGridIndex(platform.Position)] = true
    end

    local foundSpikes = Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.SPIKE, 0)

    for _, spike in ipairs(foundSpikes) do
        RoomSpikes[room:GetClampedGridIndex(spike.Position)] = true
    end

    RoomSpawn = Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.SPAWN, 0)[1]
end


--INIT
function gush:Init()
    local room = game:GetRoom()

    --Reset variables
    gush.result = nil

    FindGrid()

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
    local gridIndexLeft = room:GetClampedGridIndex(player.Position - Vector(MinigameConstants.OFFSET_TO_CHECK_FOR_FLOOR, 0))
    local gridIndexRight = room:GetClampedGridIndex(player.Position + Vector(MinigameConstants.OFFSET_TO_CHECK_FOR_FLOOR, 0))

    return (RoomPlatforms[gridIndexLeft + MinigameConstants.GRID_OFFSET_TO_GET_UNDER] and not RoomPlatforms[gridIndexLeft]) or
        (RoomPlatforms[gridIndexRight + MinigameConstants.GRID_OFFSET_TO_GET_UNDER] and not RoomPlatforms[gridIndexRight])
end


local function IsPlayerGrounded(player)
    return math.abs(player.Velocity.Y) < MinigameConstants.JUMPING_SPEED_THRESHOLD and IsPlayerOnFloor(player)
end


local function CanPlayerJump(player)
    return IsPlayerGrounded(player) or player:GetData().CoyoteTime
end


local function Jump(player)
    player.Velocity = player.Velocity - Vector(0, MinigameConstants.JUMPING_STRENGTH)
    player:GetData().ExtraJumpFrames = MinigameConstants.EXTRA_JUMP_FRAMES

    player:GetData().FakePlayer:GetSprite():Play("StartJump", true)

    if not IsExtraJumpStrength then
        gravity = MinigameConstants.EXTRA_JUMP_REDUCED_GRAVITY
    end
end


local function ExtraJump(player)
    player:GetData().ExtraJumpFrames = player:GetData().ExtraJumpFrames - 1

    if IsExtraJumpStrength then
        player.Velocity = player.Velocity - Vector(0, MinigameConstants.EXTRA_JUMP_STRENGTH)
    end
end


local function MakePlayerStandOnFloor(player)
    if not IsPlayerOnFloor(player) then return false end

    local room = game:GetRoom()
    local playerGridIndex = room:GetClampedGridIndex(player.Position)
    local playerClampedPos = room:GetGridPosition(playerGridIndex)

    if player.Position.Y - playerClampedPos.Y >= MinigameConstants.DISTANCE_FROM_PLAYER_TO_FLOOR and 
     player.Velocity.Y >= 0 then
        player.Position = Vector(player.Position.X, playerClampedPos.Y + MinigameConstants.DISTANCE_FROM_PLAYER_TO_FLOOR)
        player.Velocity = Vector(player.Velocity.X, 0)

        return true
    end

    return false
end


local function MakePlayerHitCeiling(player)
    local room = game:GetRoom()
    local playerGridIndex = room:GetClampedGridIndex(player.Position)
    local playerClampedPos = room:GetGridPosition(playerGridIndex)

    if not RoomPlatforms[playerGridIndex - MinigameConstants.GRID_OFFSET_TO_GET_UNDER] and not RoomPlatforms[playerGridIndex] then return end

    if playerClampedPos.Y - player.Position.Y >= MinigameConstants.DISTANCE_FROM_PLAYER_TO_FLOOR and
     player.Velocity.Y < 0 then
        player.Position = Vector(player.Position.X, playerClampedPos.Y - MinigameConstants.DISTANCE_FROM_PLAYER_TO_FLOOR)
        player.Velocity = Vector(player.Velocity.X, 0)

        return true
    end
end


local function ApplyGravity(player, gravity)
    gravity = gravity or MinigameConstants.GRAVITY_STRENGTH

    player.Velocity = player.Velocity + Vector(0, gravity)

    if player.Velocity.Y > MinigameConstants.TERMINAL_VELOCITY then
        player.Velocity = Vector(player.Velocity.X, MinigameConstants.TERMINAL_VELOCITY)
    end
end


local function MakePlayerHitWall(player)
    local room = game:GetRoom()
    local playerGridIndex = room:GetClampedGridIndex(player.Position)
    local playerClampedPos = room:GetGridPosition(playerGridIndex)

    if RoomPlatforms[playerGridIndex + 1] and
    player.Position.X - playerClampedPos.X >= MinigameConstants.DISTANCE_FROM_PLAYER_TO_WALL then
        player.Position = Vector(playerClampedPos.X + MinigameConstants.DISTANCE_FROM_PLAYER_TO_WALL, player.Position.Y)
    end

    if RoomPlatforms[playerGridIndex - 1] and
    playerClampedPos.X - player.Position.X >= MinigameConstants.DISTANCE_FROM_PLAYER_TO_WALL then
        player.Position = Vector(playerClampedPos.X - MinigameConstants.DISTANCE_FROM_PLAYER_TO_WALL, player.Position.Y)
    end
end


local function CheckIfPlayerHitSpike(player)
    local room = game:GetRoom()
    local playerGridIndex = room:GetClampedGridIndex(player.Position)

    if RoomSpikes[playerGridIndex] then
        player.Position = RoomSpawn.Position
        player.Velocity = Vector.Zero
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
    elseif IsPlayerGrounded(player) and not fakePlayerSprite:IsPlaying("TouchGround") then
        if math.abs(player.Velocity.X) < MinigameConstants.HORIZONTAL_SPEED_THRESHOLD then
            fakePlayerSprite:Play("Idle", true)
        elseif player.Velocity.X < 0 and not fakePlayerSprite:IsPlaying("MoveLeft") then
            fakePlayerSprite:Play("MoveLeft", true)
        elseif player.Velocity.X > 0 and not fakePlayerSprite:IsPlaying("MoveRight") then
            fakePlayerSprite:Play("MoveRight", true)
        end
    end
end


function gush:PlayerUpdate(player)
    local gravity

    if player:GetData().WasGrounded and not IsPlayerGrounded(player) and player.Velocity.Y >= 0 then
        player:GetData().CoyoteTime = MinigameConstants.COYOTE_TIME_FRAMES
    elseif not player:GetData().WasGrounded and IsPlayerGrounded(player) then
        player:GetData().FakePlayer:GetSprite():Play("TouchGround", true)
    end
    player:GetData().WasGrounded = IsPlayerGrounded(player)

    if Input.IsActionTriggered(ButtonAction.ACTION_ITEM, player.ControllerIndex) or player:GetData().JumpBuffer then
        if CanPlayerJump(player) then
            Jump(player)
        elseif Input.IsActionTriggered(ButtonAction.ACTION_ITEM, player.ControllerIndex) then
            --Check the input again for false positives
            player:GetData().JumpBuffer = MinigameConstants.JUMP_BUFFER_FRAMES
        end
    end

    if Input.IsActionPressed(ButtonAction.ACTION_ITEM, player.ControllerIndex) then
        if player:GetData().ExtraJumpFrames > 0 then
            ExtraJump(player)
            gravity = MinigameConstants.EXTRA_JUMP_REDUCED_GRAVITY
        end
    else
        player:GetData().ExtraJumpFrames = 0
    end

    if player:GetData().JumpBuffer then
        player:GetData().JumpBuffer = player:GetData().JumpBuffer - 1
        if player:GetData().JumpBuffer == 0 then player:GetData().JumpBuffer = nil end
    end
    if player:GetData().CoyoteTime then
        player:GetData().CoyoteTime = player:GetData().CoyoteTime - 1
        if player:GetData().CoyoteTime == 0 then player:GetData().CoyoteTime = nil end
    end

    if MakePlayerHitCeiling(player) then
        player:GetData().ExtraJumpFrames = 0
    end

    local shouldIgnoreGravity = MakePlayerStandOnFloor(player)

    if not shouldIgnoreGravity then
        ApplyGravity(player, gravity)
    end

    MakePlayerHitWall(player)

    CheckIfPlayerHitSpike(player)

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