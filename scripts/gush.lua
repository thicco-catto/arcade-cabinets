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
    ONE_WAY = Isaac.GetEntityVariantByName("one way GUSH"),
    COLLAPSING = Isaac.GetEntityVariantByName("collapsing GUSH"),
    SPIKE = Isaac.GetEntityVariantByName("spike GUSH"),
    SPAWN = Isaac.GetEntityVariantByName("spawn GUSH"),
    EXIT = Isaac.GetEntityVariantByName("exit GUSH"),
    BUTTON = Isaac.GetEntityVariantByName("button GUSH"),

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
    SKIP_ONE_WAYS_FRAMES = 14,
    COLLAPSING_PLATFORM_TIMER = 20,

    JUMPING_STRENGTH = 13,
    EXTRA_JUMP_FRAMES = 15,
    EXTRA_JUMP_REDUCED_GRAVITY = 0.01,
    EXTRA_JUMP_STRENGTH = 0.6,

    TERMINAL_VELOCITY = 20,
    GRAVITY_STRENGTH = 1.1,

    DISTANCE_FROM_PLAYER_TO_FLOOR = 10,
    DISTANCE_FROM_PLAYER_TO_WALL = 6,
    DISTANCE_FROM_PLAYER_TO_BUTTON = 2,

    MAX_LEVEL = 5,
    ROOM_POOL = {
        --Easy rooms
        EASY = {
            50,
            51,
            52,
            53,
            54
        },
        
        --Medium rooms
        MEDIUM = {
            55,
            56,
            57,
            58,
            59,
            60,
            61,
            62,
            63,
            64,
            65,
            66,
            67,
            68,
            69
        },
    
        --Hard rooms
        HARD = {
            70,
            71,
            72,
            73,
            74
        }
    },

    MAX_INTRO_SCREEN_TIMER = 50,
}

--Timers
local MinigameTimers = {
    IntroTimer = 0
}

--States
local MinigameStates = {
    INTRO_SCREEN = 0,
    PLAYING = 1,
    DYING = 2,
    EXITING = 3,
    TRANSITION_SCREEN = 4,

    WINNING = 5,
    LOSING = 6
}
local CurrentMinigameState = 0

--UI
local WaveTransitionScreen = Sprite()
WaveTransitionScreen:Load("gfx/minigame_transition.anm2", true)
WaveTransitionScreen:ReplaceSpritesheet(0, "gfx/effects/gush/gush_intro_screen.png")
WaveTransitionScreen:ReplaceSpritesheet(1, "gfx/effects/gush/gush_intro_screen.png")
WaveTransitionScreen:LoadGraphics()

--Other variables
local IsExtraJumpStrength = true
local RoomPlatforms = {}
local RoomOneWays = {}
local RoomCollapsings = {}
local RoomSpikes = {}
local RoomSpawn = nil
local RoomExit = nil
local RoomButton = nil

local CollapsingPlatforms = {}
local CollapsingPlatformsToSpawn = {}

local Backdrop = nil

local CurrentLevel = 1
local PlayerHP = 5

local VisitedRooms = {}


local function FillGridList(gridList, entityVariant)
    for _, grid in ipairs(Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, entityVariant, 0)) do
        gridList[game:GetRoom():GetClampedGridIndex(grid.Position)] = grid
    end
end


local function FindGrid()
    RoomPlatforms = {}
    RoomOneWays = {}
    RoomCollapsings = {}
    RoomSpikes = {}

    FillGridList(RoomPlatforms, MinigameEntityVariants.PLATFORM)
    FillGridList(RoomOneWays, MinigameEntityVariants.ONE_WAY)
    FillGridList(RoomCollapsings, MinigameEntityVariants.COLLAPSING)
    FillGridList(RoomSpikes, MinigameEntityVariants.SPIKE)

    RoomSpawn = Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.SPAWN, 0)[1]

    RoomExit = Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.EXIT, 0)[1]

    RoomButton = Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.BUTTON, 0)[1]
end


local function GoToNextRoom()
    local RoomPoolToChooseFrom = {}

    if CurrentLevel == 1 then
        RoomPoolToChooseFrom = MinigameConstants.ROOM_POOL.EASY
    elseif CurrentLevel == MinigameConstants.MAX_LEVEL then
        RoomPoolToChooseFrom = MinigameConstants.ROOM_POOL.HARD
    else
        RoomPoolToChooseFrom = MinigameConstants.ROOM_POOL.MEDIUM
    end

    local aux = {}
    for _, room in ipairs(RoomPoolToChooseFrom) do
        if not VisitedRooms[room] then
            table.insert(aux, room)
        end
    end
    RoomPoolToChooseFrom = aux

    local chosenRoom = RoomPoolToChooseFrom[rng:RandomInt(#RoomPoolToChooseFrom) + 1]
    VisitedRooms[chosenRoom] = true
    Isaac.ExecuteCommand("goto s.isaacs." .. chosenRoom)
end


local function PrepareForRoom()
    CollapsingPlatformsToSpawn = {}
    CollapsingPlatforms = {}

    FindGrid()

    local room = game:GetRoom()
    local backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop2x2Variant, 0, room:GetCenterPos(), Vector(0, 0), nil)
    backdrop:GetSprite():ReplaceSpritesheet(0, "gfx/backdrop/gush_backdrop" .. game:GetLevel():GetCurrentRoomDesc().Data.Variant .. ".png")
    backdrop:GetSprite():LoadGraphics()
    backdrop.DepthOffset = -1000

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        player.Position = RoomSpawn.Position
        local fakePlayer = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.PLAYER, 0, player.Position, Vector.Zero, player)
        player:GetData().FakePlayer = fakePlayer
        player:GetData().IsExiting = false
    end
end


--INIT
function gush:Init()
    local room = game:GetRoom()

    --Reset variables
    gush.result = nil
    PlayerHP = 3
    CurrentLevel = 5
    CollapsingPlatforms = {}
    VisitedRooms = {}

    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    GoToNextRoom()

    --Reset timers
    for _, timer in pairs(MinigameTimers) do
        timer = 0
    end

    --Intro stuff
    WaveTransitionScreen:Play("Idle", true)
    CurrentMinigameState = MinigameStates.INTRO_SCREEN
    MinigameTimers.IntroTimer = MinigameConstants.MAX_INTRO_SCREEN_TIMER

    --Spawn the backdrop
    Backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop2x2Variant, 0, room:GetCenterPos(), Vector.Zero, nil)
    Backdrop:GetSprite():ReplaceSpritesheet(0, "gfx/backdrop/gush_backdrop1.png")
    Backdrop:GetSprite():LoadGraphics()
    Backdrop.Visible = false
    Backdrop.DepthOffset = -500

    --Play music
    MusicManager:Play(MinigameMusic, 1)
    MusicManager:UpdateVolume()
    MusicManager:Pause()

    --Set up players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        player.ControlsEnabled = false
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
    end
end


--UPDATE CALLBACKS
function gush:OnInput(_, inputHook, buttonAction)
    if buttonAction == ButtonAction.ACTION_UP or buttonAction == ButtonAction.ACTION_DOWN or
     buttonAction == ButtonAction.ACTION_SHOOTLEFT or buttonAction == ButtonAction.ACTION_SHOOTRIGHT or
     buttonAction == ButtonAction.ACTION_SHOOTUP or buttonAction == ButtonAction.ACTION_SHOOTDOWN then
        if inputHook > InputHook.IS_ACTION_TRIGGERED then
            return 0
        else
            return false
        end
    end
end
gush.callbacks[ModCallbacks.MC_INPUT_ACTION] = gush.OnInput


local function TryCollapsePlatform(gridIndex)
    local collapsing = RoomCollapsings[gridIndex]
    if not collapsing then return end
    if collapsing:GetData().CollapseTimer then return end

    collapsing:GetData().CollapseTimer = MinigameConstants.COLLAPSING_PLATFORM_TIMER
    CollapsingPlatforms[game:GetRoom():GetClampedGridIndex(collapsing.Position)] = collapsing
    collapsing:GetSprite():Play("Collapse", true)
    collapsing:GetSprite():SetFrame(4)
end


local function GetPlatformsPlayerIsStanding(platformTable, player)
    local room = game:GetRoom()
    local gridIndexLeft = room:GetClampedGridIndex(player.Position - Vector(MinigameConstants.OFFSET_TO_CHECK_FOR_FLOOR, 0))
    local gridIndexRight = room:GetClampedGridIndex(player.Position + Vector(MinigameConstants.OFFSET_TO_CHECK_FOR_FLOOR, 0))
    local standingPlatforms = {}

    if platformTable[gridIndexLeft + MinigameConstants.GRID_OFFSET_TO_GET_UNDER] and not (RoomPlatforms[gridIndexLeft] or RoomCollapsings[gridIndexLeft])then
        table.insert(standingPlatforms, gridIndexLeft + MinigameConstants.GRID_OFFSET_TO_GET_UNDER)
    end

    if platformTable[gridIndexRight + MinigameConstants.GRID_OFFSET_TO_GET_UNDER] and not (RoomPlatforms[gridIndexRight] or RoomCollapsings[gridIndexRight])then
        table.insert(standingPlatforms, gridIndexRight + MinigameConstants.GRID_OFFSET_TO_GET_UNDER)
    end

    return standingPlatforms
end


local function IsPlayerOnFloor(player)
    local isOnPlatform = #GetPlatformsPlayerIsStanding(RoomPlatforms, player) > 0
    local isOnOneWay = (#GetPlatformsPlayerIsStanding(RoomOneWays, player) > 0) and not player:GetData().SkipOneWays
    local isOnCollapsing = #GetPlatformsPlayerIsStanding(RoomCollapsings, player) > 0

    for _, gridIndex in ipairs(GetPlatformsPlayerIsStanding(RoomCollapsings, player)) do
        TryCollapsePlatform(gridIndex)
    end

    return isOnPlatform or isOnOneWay or isOnCollapsing
end


local function IsPlayerGrounded(player)
    return math.abs(player.Velocity.Y) < MinigameConstants.JUMPING_SPEED_THRESHOLD and IsPlayerOnFloor(player)
end


local function CanPlayerJump(player)
    return (IsPlayerGrounded(player) or player:GetData().CoyoteTime) and player.ControlsEnabled
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

    if not RoomPlatforms[playerGridIndex - MinigameConstants.GRID_OFFSET_TO_GET_UNDER] and not RoomPlatforms[playerGridIndex] and 
    not RoomCollapsings[playerGridIndex - MinigameConstants.GRID_OFFSET_TO_GET_UNDER] and not RoomCollapsings[playerGridIndex] then return end

    if playerClampedPos.Y - player.Position.Y >= MinigameConstants.DISTANCE_FROM_PLAYER_TO_FLOOR and player.Velocity.Y < 0 then
        TryCollapsePlatform(playerGridIndex - MinigameConstants.GRID_OFFSET_TO_GET_UNDER)

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

    if (RoomPlatforms[playerGridIndex + 1] or RoomCollapsings[playerGridIndex + 1]) and
    player.Position.X - playerClampedPos.X >= MinigameConstants.DISTANCE_FROM_PLAYER_TO_WALL then
        TryCollapsePlatform(playerGridIndex + 1)

        player.Position = Vector(playerClampedPos.X + MinigameConstants.DISTANCE_FROM_PLAYER_TO_WALL, player.Position.Y)
    end

    if (RoomPlatforms[playerGridIndex - 1] or RoomCollapsings[playerGridIndex - 1]) and
    playerClampedPos.X - player.Position.X >= MinigameConstants.DISTANCE_FROM_PLAYER_TO_WALL then
        TryCollapsePlatform(playerGridIndex - 1)

        player.Position = Vector(playerClampedPos.X - MinigameConstants.DISTANCE_FROM_PLAYER_TO_WALL, player.Position.Y)
    end
end


local function CheckIfPlayerHitSpike(player)
    local room = game:GetRoom()
    local playerGridIndex = room:GetClampedGridIndex(player.Position)

    if RoomSpikes[playerGridIndex] then
        player.Position = RoomSpawn.Position
        player.Velocity = Vector.Zero

        for _, gridIndex in ipairs(CollapsingPlatformsToSpawn) do
            local position = room:GetGridPosition(gridIndex)
            Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.COLLAPSING, 0, position, Vector.Zero, nil)
        end

        for _, collapsing in pairs(RoomCollapsings) do
            collapsing:GetSprite():Play("Idle", true)
            collapsing:GetData().CollapseTimer = nil
        end

        CollapsingPlatforms = {}
        CollapsingPlatformsToSpawn = {}
        RoomCollapsings = {}
        FillGridList(RoomCollapsings, MinigameEntityVariants.COLLAPSING)
    end
end


local function CheckIfPlayerIsInPortal(player)
    if player:GetData().IsExiting or not RoomExit then return end

    local room = game:GetRoom()
    local playerGridIndex = room:GetClampedGridIndex(player.Position)
    local exitGridIndex = room:GetClampedGridIndex(RoomExit.Position)

    if playerGridIndex == exitGridIndex then
        player:GetData().IsExiting = true
        CurrentLevel = CurrentLevel + 1
        GoToNextRoom()
    end
end


local function CheckIfPlayerIsPressingButton(player)
    if not RoomButton or player.Velocity.Y < MinigameConstants.JUMPING_SPEED_THRESHOLD then return end

    local room = game:GetRoom()
    local gridIndexLeft = room:GetClampedGridIndex(player.Position - Vector(MinigameConstants.OFFSET_TO_CHECK_FOR_FLOOR, 0))
    local gridIndexRight = room:GetClampedGridIndex(player.Position + Vector(MinigameConstants.OFFSET_TO_CHECK_FOR_FLOOR, 0))
    local gridIndexButton = room:GetClampedGridIndex(RoomButton.Position)

    if (gridIndexLeft == gridIndexButton or gridIndexRight == gridIndexButton) and
    player.Position.Y - RoomButton.Position.Y > MinigameConstants.DISTANCE_FROM_PLAYER_TO_BUTTON then
        RoomButton:GetSprite():Play("Pressed", true)
        RoomButton = nil
    end
end


local function ManageFakePlayer(player)
    local fakePlayer = player:GetData().FakePlayer
    if not fakePlayer then return end
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


function gush:OnPlayerUpdate(player)
    local gravity

    player.Visible = false --Do this here because it sucks

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

    if Input.IsActionTriggered(ButtonAction.ACTION_DOWN, player.ControllerIndex) then
        player:GetData().SkipOneWays = MinigameConstants.SKIP_ONE_WAYS_FRAMES
    end

    if player:GetData().JumpBuffer then
        player:GetData().JumpBuffer = player:GetData().JumpBuffer - 1
        if player:GetData().JumpBuffer == 0 then player:GetData().JumpBuffer = nil end
    end
    if player:GetData().CoyoteTime then
        player:GetData().CoyoteTime = player:GetData().CoyoteTime - 1
        if player:GetData().CoyoteTime == 0 then player:GetData().CoyoteTime = nil end
    end
    if player:GetData().SkipOneWays then
        player:GetData().SkipOneWays = player:GetData().SkipOneWays - 1
        if player:GetData().SkipOneWays == 0 then player:GetData().SkipOneWays = nil end
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

    if RoomExit then
        CheckIfPlayerIsInPortal(player)
    else
        CheckIfPlayerIsPressingButton(player)
    end

    ManageFakePlayer(player)
end
gush.callbacks[ModCallbacks.MC_POST_PLAYER_UPDATE] = gush.OnPlayerUpdate


local function UpdatePlaying()
    for _, collapsing in pairs(CollapsingPlatforms) do
        collapsing:GetData().CollapseTimer = collapsing:GetData().CollapseTimer - 1
        collapsing:GetSprite():SetFrame(math.ceil((collapsing:GetData().CollapseTimer / MinigameConstants.COLLAPSING_PLATFORM_TIMER) * 4))

        if collapsing:GetData().CollapseTimer == 0 then
            local gridIndex = game:GetRoom():GetClampedGridIndex(collapsing.Position)

            RoomCollapsings[gridIndex] = nil
            CollapsingPlatforms[gridIndex] = nil
            table.insert(CollapsingPlatformsToSpawn, gridIndex)
            collapsing:Remove()
        end
    end
end


function gush:OnFrameUpdate()
    if CurrentMinigameState == MinigameStates.INTRO_SCREEN then
        MinigameTimers.IntroTimer = MinigameTimers.IntroTimer - 1

        if MinigameTimers.IntroTimer == 0 then
            CurrentMinigameState = MinigameStates.PLAYING

            local playerNum = game:GetNumPlayers()
            for i = 0, playerNum - 1, 1 do
                local player = game:GetPlayer(i)
                player.ControlsEnabled = true
            end
        end
    elseif CurrentMinigameState == MinigameStates.PLAYING then
        UpdatePlaying()
    end
end
gush.callbacks[ModCallbacks.MC_POST_UPDATE] = gush.OnFrameUpdate


local function RenderWaveTransition()
    if CurrentMinigameState ~= MinigameStates.INTRO_SCREEN then return end

    WaveTransitionScreen:SetFrame(0)
    WaveTransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
end


function gush:OnRender()
    -- RenderUI()

    RenderWaveTransition()

    -- RenderFadeOut()
end
gush.callbacks[ModCallbacks.MC_POST_RENDER] = gush.OnRender


function gush:OnNewRoom()
    PrepareForRoom()
end
gush.callbacks[ModCallbacks.MC_POST_NEW_ROOM] = gush.OnNewRoom


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
        print(CollapsingPlatforms[tonumber(args)])

        for key, value in pairs(CollapsingPlatforms) do
            print(key .. " -> " .. value)
        end
    elseif command == "bg" then
        if #args == 0 then
            print("Changed visibility of backdrop")
            Backdrop.Visible = not Backdrop.Visible

            for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, -1, -1)) do
                if entity.Variant ~= Backdrop.Variant and entity.Variant ~= MinigameEntityVariants.COLLAPSING then
                    entity.Visible = not entity.Visible
                end
            end
        else
            print("Changed to backdrop " .. args[1])
            Backdrop:GetSprite():ReplaceSpritesheet(0, "gfx/backdrop/gush_backdrop" .. args[1] .. ".png")
            Backdrop:GetSprite():LoadGraphics()
        end
    end
end
gush.callbacks[ModCallbacks.MC_EXECUTE_CMD] = gush.OnCMD


local function shallowCopy(tab)
    return {table.unpack(tab)}
  end
  
  local function includes(tab, val)
    for _, v in pairs(tab) do
      if val == v then return true end
    end
    return false
  end
  
  function dump(o, depth, seen)
    depth = depth or 0
    seen = seen or {}
  
    if depth > 50 then return '' end -- prevent infloops
  
    if type(o) == 'userdata' then -- handle custom isaac types
      if includes(seen, tostring(o)) then return '(circular)' end
      if not getmetatable(o) then return tostring(o) end
      local t = getmetatable(o).__type
  
      if t == 'Entity' or t == 'EntityBomb' or t == 'EntityEffect' or t == 'EntityFamiliar' or t == 'EntityKnife' or t == 'EntityLaser' or t == 'EntityNPC' or t == 'EntityPickup' or t == 'EntityPlayer' or t == 'EntityProjectile' or t == 'EntityTear' then
        return t .. ': ' .. (o.Type or '0') .. '.' .. (o.Variant or '0') .. '.' .. (o.SubType or '0')
      elseif t == 'EntityRef' then
        return t .. ' -> ' .. dump(o.Ref, depth, seen)
      elseif t == 'EntityPtr' then
        return t .. ' -> ' .. dump(o.Entity, depth, seen)
      elseif t == 'GridEntity' or t == 'GridEntityDoor' or t == 'GridEntityPit' or t == 'GridEntityPoop' or t == 'GridEntityPressurePlate' or t == 'GridEntityRock' or t == 'GridEntitySpikes' or t == 'GridEntityTNT' then
        return t .. ': ' .. o:GetType() .. '.' .. o:GetVariant() .. '.' .. o.VarData .. ' at ' .. dump(o.Position, depth, seen)
      elseif t == 'GridEntityDesc' then
        return t .. ' -> ' .. o.Type .. '.' .. o.Variant .. '.' .. o.VarData
      elseif t == 'Vector' then
        return t .. '(' .. o.X .. ', ' .. o.Y .. ')'
      elseif t == 'Color' or t == "const Color" then
        return t .. '(' .. o.R .. ', ' .. o.G .. ', ' .. o.B .. ', ' .. o.RO .. ', ' .. o.GO .. ', ' .. o.BO .. ')'
      elseif t == 'Level' then
        return t .. ': ' .. o:GetName()
      elseif t == 'RNG' then
        return t .. ': ' .. o:GetSeed()
      elseif t == 'Sprite' then
        return t .. ': ' .. o:GetFilename() .. ' - ' .. (o:IsPlaying(o:GetAnimation()) and 'playing' or 'stopped at') .. ' ' .. o:GetAnimation() .. ' f' .. o:GetFrame()
      elseif t == 'TemporaryEffects' then
        local list = o:GetEffectsList()
        local tab = {}
        for i = 0, #list - 1 do
          table.insert(tab, list:Get(i))
        end
        return dump(tab, depth, seen)
      else
        local newt = {}
        for k,v in pairs(getmetatable(o)) do
          if type(k) ~= 'userdata' and k:sub(1, 2) ~= '__' then newt[k] = v end
        end
  
        return 'userdata ' .. dump(newt, depth, seen)
      end
    elseif type(o) == 'table' then -- handle tables
      if includes(seen, tostring(o)) then return '(circular)' end
      table.insert(seen, tostring(o))
      local s = '{\n'
      local first = true
      for k,v in pairs(o) do
        if not first then
          s = s .. ',\n'
        end
        s = s .. string.rep('  ', depth + 1)
  
        if type(k) ~= 'number' then
          table.insert(seen, tostring(v))
          s = s .. dump(k, depth + 1, shallowCopy(seen)) .. ' = ' .. dump(v, depth + 1, shallowCopy(seen))
        else
          s = s .. dump(v, depth + 1, shallowCopy(seen))
        end
        first = false
      end
      if first then return '{}' end
      return s .. '\n' .. string.rep('  ', depth) .. '}'
    elseif type(o) == 'string' then -- anything else resolves pretty easily
      return '"' .. o .. '"'
    else
      return tostring(o)
    end
  end

return gush