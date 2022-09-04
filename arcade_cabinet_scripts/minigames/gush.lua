local gush = {}
local game = Game()
local rng = RNG()
local SFXManager = SFXManager()
local MusicManager = MusicManager()
local ArcadeCabinetVariables

--Sounds
local MinigameSounds = {
    JUMP = Isaac.GetSoundIdByName("gush jump"),
    PLAYER_DEATH = Isaac.GetSoundIdByName("gush player death"),

    TRANSITION = Isaac.GetSoundIdByName("gush transition"),

    COLLAPSE_PLATFORM = Isaac.GetSoundIdByName("hs open crack"),

    SAW_WALL_HIT = Isaac.GetSoundIdByName("gush saw wall hit"),
    SAW_VROOM = Isaac.GetSoundIdByName("gush saw vroom"),
    FIRE_LASER = Isaac.GetSoundIdByName("hs open crack"),
    END_EXPLOSION = Isaac.GetSoundIdByName("gush explosion"),
    BIG_EXPLOSION = Isaac.GetSoundIdByName("gush big explosion"),

    PUS_MAN = Isaac.GetSoundIdByName("gush pus man"),

    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
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

    MACHINE = Isaac.GetEntityVariantByName("machine GUSH"),
    END_EXPLOSION = Isaac.GetEntityVariantByName("end explosion HS"),

    PLAYER = Isaac.GetEntityVariantByName("player GUSH"),

    PUS_MAN = Isaac.GetEntityVariantByName("pus man GUSH"),
    GLITCH_TILE = Isaac.GetEntityVariantByName("glitch tile GUSH")
}

--Constants
local MinigameConstants = {
    JUMPING_SPEED_THRESHOLD = 0.17,
    TOP_JUMPING_SPEED_THRESHOLD = 2.5, --Only for visual animation
    HORIZONTAL_SPEED_THRESHOLD = 0.5, --Only for visual animation
    OFFSET_TO_CHECK_FOR_FLOOR = 10,
    GRID_OFFSET_TO_GET_UNDER_SMALL = 15,
    GRID_OFFSET_TO_GET_UNDER_BIG = 28,

    JUMP_BUFFER_FRAMES = 7,
    COYOTE_TIME_FRAMES = 7,
    SKIP_ONE_WAYS_FRAMES = 8,
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

    MAX_LEVEL = 3,
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
    ANIMATED_ROOMS = {
        [51] = true,
        [54] = true,
        [55] = true,
        [56] = true,
        [57] = true,
        [58] = true,
        [61] = true,
        [63] = true,
        [64] = true,
        [65] = true,
        [66] = true,
        [69] = true,
        [71] = true,
        [72] = true,
        [74] = true
    },
    ANIMATED_ROOMS_LONG = {
        [52] = true
    },

    SAW_VELOCITY_ANGLE_THRESHOLD_TO_HIT = 5,

    MACHINE_ROOM = 75,
    MACHINE_SPAWN_OFFSET = Vector(160, 30),
    FRAMES_BETWEEN_END_EXPLOSIONS = 7,
    MAX_END_EXPLOSIONS = 5,
    NUM_EXPLOSION_TO_BIG_EXPLOSION = 25,
    EXPLOSION_NUM_IN_BIG_EXPLOSION = 12,

    MAX_INTRO_SCREEN_TIMER = 45,
    MAX_TRANSITION_SCREEN_TIMER = 45,

    --Glitched stuff
    GLITCH_INTRO_ROOM = 80,
    GLITCH_MAX_LEVEL = 4,
    GLITCH_ROOM_POOL = {
        81,
        82,
        83,
        84,
        85,
        86,
        87,
        88
    },
    GLITCH_PUS_MAN_SPAWN_X = {
        [80] = -200,
        [81] = -200,
        [82] = -200,
        [83] = -200,
        [84] = -200,
        [85] = -200,
        [86] = -200,
        [87] = -200,
        [88] = -200,
    },
    GLITCH_PUS_MAN_VELOCITY = {
        [80] = 4,
        [81] = 4,
        [82] = 4,
        [83] = 4,
        [84] = 4,
        [85] = 4,
        [86] = 4,
        [87] = 4,
        [88] = 4,
    },
    GLITCH_PUS_MAN_SIZE = 200,
    GLITCH_NUM_GLITCH_TILES = 35,
    GLITCH_TILE_FRAME_NUM = {
        ["Platform"] = 8,
        ["Spike"] = 4,
        ["Idle"] = 7
    },
    GLITCH_TILE_CHANGE_FRAMES = 10,
    GLITCH_TILE_CHANGING_CHANCE = 10,
}

--Timers
local MinigameTimers = {
    IntroTimer = 0,
    TransitionScreenTimer = 0
}

--States
local MinigameState = {
    INTRO_SCREEN = 0,
    PLAYING = 1,
    DYING = 2,
    EXITING = 3,
    TRANSITION_SCREEN = 4,
    MACHINE_DYING = 5,
    WAITING_FOR_PUS_MAN = 6,

    WINNING = 7,
    LOSING = 8
}
local CurrentMinigameState = 0

--UI
local TransitionScreen = Sprite()
TransitionScreen:Load("gfx/minigame_transition.anm2", false)

local HealthUI = Sprite()
HealthUI:Load("gfx/gush_ui.anm2", true)

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
local EndExplosionsCounter = 0


local function FillGridList(gridList, entityVariant)
    for _, grid in ipairs(Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, entityVariant, 0)) do
        if ArcadeCabinetVariables.IsCurrentMinigameGlitched and entityVariant == MinigameEntityVariants.COLLAPSING then
            grid:GetSprite():ReplaceSpritesheet(0, "gfx/grid/gush_glitch_collapsing.png")
            grid:GetSprite():LoadGraphics()
        end
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
    if RoomExit then
        RoomExit.DepthOffset = -200
        RoomExit:GetSprite():Play("Closed", true)

        if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
            RoomExit:GetSprite():Load("gfx/gush_glitch_exit.anm2", true)
            RoomExit:GetSprite():Play("Idle", true)
        end
    end

    RoomButton = Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.BUTTON, 0)[1]
end


local function PlaceGlitchTiles()
    if not ArcadeCabinetVariables.IsCurrentMinigameGlitched then return end

    local room = game:GetRoom()

    local numOneWays = 0
    for _, _ in ipairs(RoomOneWays) do
        numOneWays = numOneWays + 1
    end

    local possibleGlitchTiles = {}
    for i = 0, 251, 1 do
        if not RoomOneWays[i] then
            table.insert(possibleGlitchTiles, i)
        end
    end

    for _ = 1, MinigameConstants.GLITCH_NUM_GLITCH_TILES, 1 do
        local chosen = rng:RandomInt(#possibleGlitchTiles) + 1
        local gridIndex = possibleGlitchTiles[chosen]
        table.remove(possibleGlitchTiles, chosen)

        local glitchTile = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.GLITCH_TILE, 0, room:GetGridPosition(gridIndex), Vector.Zero, nil)

        local chosenAnimation = "Idle"
        if RoomPlatforms[gridIndex] then
            chosenAnimation = "Platform"
        elseif RoomSpikes[gridIndex] then
            chosenAnimation = "Spike"
        end

        glitchTile:GetSprite():Play(chosenAnimation, true)
        glitchTile:GetData().ChosenFrame = rng:RandomInt(MinigameConstants.GLITCH_TILE_FRAME_NUM[chosenAnimation])
        glitchTile:GetSprite():SetFrame(glitchTile:GetData().ChosenFrame)
        glitchTile:GetData().ChagingTile = rng:RandomInt(100) < MinigameConstants.GLITCH_TILE_CHANGING_CHANCE
        glitchTile:GetData().RandomOffset = rng:RandomInt(MinigameConstants.GLITCH_TILE_CHANGE_FRAMES)
        glitchTile.DepthOffset = -200
    end
end


local function StartTransitionScreen()
    CurrentMinigameState = MinigameState.TRANSITION_SCREEN
    MinigameTimers.TransitionScreenTimer = MinigameConstants.MAX_TRANSITION_SCREEN_TIMER
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        TransitionScreen:ReplaceSpritesheet(0, "gfx/effects/gush/gush_glitch_transition.png")
    else
        TransitionScreen:ReplaceSpritesheet(0, "gfx/effects/gush/gush_transition" .. CurrentLevel .. ".png")
    end
    TransitionScreen:LoadGraphics()
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        player.ControlsEnabled = false
    end
end


local function GoToNextRoom()
    local RoomPoolToChooseFrom = {}

    if CurrentLevel == 1 then
        if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
            Isaac.ExecuteCommand("goto s.isaacs." .. MinigameConstants.GLITCH_INTRO_ROOM)
            SFXManager:Stop(SoundEffect.SOUND_DOOR_HEAVY_CLOSE)
            SFXManager:Stop(SoundEffect.SOUND_DOOR_HEAVY_OPEN)
            return
        end

        RoomPoolToChooseFrom = MinigameConstants.ROOM_POOL.EASY
    elseif ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        RoomPoolToChooseFrom = MinigameConstants.GLITCH_ROOM_POOL
    elseif CurrentLevel == MinigameConstants.MAX_LEVEL + 1 then
        Isaac.ExecuteCommand("goto s.isaacs." .. MinigameConstants.MACHINE_ROOM)
        SFXManager:Stop(SoundEffect.SOUND_DOOR_HEAVY_CLOSE)
        SFXManager:Stop(SoundEffect.SOUND_DOOR_HEAVY_OPEN)
        return
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
    SFXManager:Stop(SoundEffect.SOUND_DOOR_HEAVY_CLOSE)
    SFXManager:Stop(SoundEffect.SOUND_DOOR_HEAVY_OPEN)
end


local function PrepareForRoom()
    CollapsingPlatformsToSpawn = {}
    CollapsingPlatforms = {}

    FindGrid()

    PlaceGlitchTiles()

    local room = game:GetRoom()
    local backdropVariant = game:GetLevel():GetCurrentRoomDesc().Data.Variant
    local backdrop

    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop2x1Variant, 0, room:GetCenterPos(), Vector(0, 0), nil)
    elseif backdropVariant == MinigameConstants.MACHINE_ROOM then
        backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop1x1Variant, 0, room:GetCenterPos(), Vector(0, 0), nil)

        local machine = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.MACHINE, 0, room:GetCenterPos() + MinigameConstants.MACHINE_SPAWN_OFFSET, Vector.Zero, nil)
        machine.DepthOffset = -200
    else
        backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop2x2Variant, 0, room:GetCenterPos(), Vector(0, 0), nil)

        if MinigameConstants.ANIMATED_ROOMS[backdropVariant] then
            backdrop:GetSprite():Load("gfx/backdrop/gush_backdrop_2x2.anm2", false)
        elseif MinigameConstants.ANIMATED_ROOMS_LONG[backdropVariant] then
            backdrop:GetSprite():Load("gfx/backdrop/gush_long_backdrop_2x2.anm2", false)
        end
    end

    backdrop:GetSprite():ReplaceSpritesheet(0, "gfx/backdrop/gush_backdrop" .. backdropVariant .. ".png")
    backdrop:GetSprite():LoadGraphics()
    backdrop.DepthOffset = -5000

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        player.Position = RoomSpawn.Position
        local fakePlayer = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.PLAYER, 0, player.Position, Vector.Zero, player)
        player:GetData().FakePlayer = fakePlayer
        player:GetData().IsExiting = false
    end
end


local function GetGridIndexUnder(room)
    local shape = room:GetRoomShape()

    if shape == RoomShape.ROOMSHAPE_1x1 then
        return MinigameConstants.GRID_OFFSET_TO_GET_UNDER_SMALL
    else
        return MinigameConstants.GRID_OFFSET_TO_GET_UNDER_BIG
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


local function TryCollapsePlatform(gridIndex)
    local collapsing = RoomCollapsings[gridIndex]
    if not collapsing then return end
    if collapsing:GetData().CollapseTimer then return end

    collapsing:GetData().CollapseTimer = MinigameConstants.COLLAPSING_PLATFORM_TIMER
    CollapsingPlatforms[game:GetRoom():GetClampedGridIndex(collapsing.Position)] = collapsing
    collapsing:GetSprite():Play("Collapse", true)
    collapsing:GetSprite():SetFrame(4)
    SFXManager:Play(MinigameSounds.COLLAPSE_PLATFORM)
end


local function GetPlatformsPlayerIsStanding(platformTable, player)
    local room = game:GetRoom()
    local gridIndexLeft = room:GetClampedGridIndex(player.Position - Vector(MinigameConstants.OFFSET_TO_CHECK_FOR_FLOOR, 0))
    local gridIndexRight = room:GetClampedGridIndex(player.Position + Vector(MinigameConstants.OFFSET_TO_CHECK_FOR_FLOOR, 0))
    local standingPlatforms = {}

    if platformTable[gridIndexLeft + GetGridIndexUnder(room)] and not (RoomPlatforms[gridIndexLeft] or RoomCollapsings[gridIndexLeft])then
        table.insert(standingPlatforms, gridIndexLeft + GetGridIndexUnder(room))
    end

    if platformTable[gridIndexRight + GetGridIndexUnder(room)] and not (RoomPlatforms[gridIndexRight] or RoomCollapsings[gridIndexRight])then
        table.insert(standingPlatforms, gridIndexRight + GetGridIndexUnder(room))
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
    SFXManager:Play(MinigameSounds.JUMP)

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

    if not RoomPlatforms[playerGridIndex - GetGridIndexUnder(room)] and not RoomPlatforms[playerGridIndex] and 
    not RoomCollapsings[playerGridIndex - GetGridIndexUnder(room)] and not RoomCollapsings[playerGridIndex] then return end

    if playerClampedPos.Y - player.Position.Y >= MinigameConstants.DISTANCE_FROM_PLAYER_TO_FLOOR and player.Velocity.Y < 0 then
        TryCollapsePlatform(playerGridIndex - GetGridIndexUnder(room))

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

    if (RoomPlatforms[playerGridIndex + 1] or RoomCollapsings[playerGridIndex + 1] or room:GetGridCollision(playerGridIndex + 1) > 0) and
    player.Position.X - playerClampedPos.X >= MinigameConstants.DISTANCE_FROM_PLAYER_TO_WALL then
        TryCollapsePlatform(playerGridIndex + 1)

        player.Position = Vector(playerClampedPos.X + MinigameConstants.DISTANCE_FROM_PLAYER_TO_WALL, player.Position.Y)
    end

    if (RoomPlatforms[playerGridIndex - 1] or RoomCollapsings[playerGridIndex - 1] or room:GetGridCollision(playerGridIndex - 1) > 0) and
    playerClampedPos.X - player.Position.X >= MinigameConstants.DISTANCE_FROM_PLAYER_TO_WALL then
        TryCollapsePlatform(playerGridIndex - 1)

        player.Position = Vector(playerClampedPos.X - MinigameConstants.DISTANCE_FROM_PLAYER_TO_WALL, player.Position.Y)
    end
end


local function KillPlayers(player)
    if CurrentMinigameState ~= MinigameState.PLAYING then return end

    player:GetData().FakePlayer:GetSprite():Play("Die", true)

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        player.Velocity = Vector.Zero
        player.ControlsEnabled = false
        player:AddEntityFlags(EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
    end

    PlayerHP = PlayerHP - 1

    if PlayerHP == 0 then
        CurrentMinigameState = MinigameState.LOSING
        SFXManager:Play(MinigameSounds.LOSE)
        TransitionScreen:Play("Appear")
    else
        SFXManager:Play(MinigameSounds.PLAYER_DEATH)
        CurrentMinigameState = MinigameState.DYING
    end
end


local function SpawnGusMan()
    local currentLevelId = game:GetLevel():GetCurrentRoomDesc().Data.Variant
    local spawnPos = Vector(MinigameConstants.GLITCH_PUS_MAN_SPAWN_X[currentLevelId], 280)
    local pusman = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.PUS_MAN, 0, spawnPos, Vector(MinigameConstants.GLITCH_PUS_MAN_VELOCITY[currentLevelId], 0), nil)
    pusman.DepthOffset = 500
end


local function RespawnPlayers()
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        player.Position = RoomSpawn.Position
        player.Velocity = Vector.Zero
        player:GetData().ExtraJumpFrames = 0
        player.ControlsEnabled = true
        player:ClearEntityFlags(EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)

        if i == 0 then
            player:UseActiveItem(CollectibleType.COLLECTIBLE_D7, false, false, true, false)
        end
    end

    local room = game:GetRoom()

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
    CurrentMinigameState = MinigameState.PLAYING

    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        local currentLevelId = game:GetLevel():GetCurrentRoomDesc().Data.Variant
        local pusman = Isaac.FindByType(EntityType.ENTITY_EFFECT, MinigameEntityVariants.PUS_MAN)[1]
        pusman.Position = Vector(MinigameConstants.GLITCH_PUS_MAN_SPAWN_X[currentLevelId], pusman.Position.Y)
    end
end


local function CheckIfPlayerHitSpike(player)
    local room = game:GetRoom()
    local playerGridIndex = room:GetClampedGridIndex(player.Position)

    if RoomSpikes[playerGridIndex] then
        KillPlayers(player)
    end
end


---@param player EntityPlayer
local function CheckIfPussyManAtePlayer(player)
    if CurrentMinigameState == MinigameState.WINNING then return end

    for _, pusman in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, MinigameEntityVariants.PUS_MAN)) do
        if player.Position:Distance(pusman.Position) <= MinigameConstants.GLITCH_PUS_MAN_SIZE then
            if player:GetData().HasToBeEatenByPusMan then
                pusman:GetSprite():Stop()
                pusman.Velocity = Vector.Zero
                CurrentMinigameState = MinigameState.WINNING
                SFXManager:Play(MinigameSounds.WIN)
                TransitionScreen:Play("Appear", true)

                local playerNum = game:GetNumPlayers()
                for i = 0, playerNum - 1, 1 do
                    local player = game:GetPlayer(i)
                    player:GetData().FakePlayer:GetSprite():Play("Win", true)
                end
            else
                KillPlayers(player)
            end
        end
    end
end


local function CheckIfPlayerIsInDoor(player)
    if CurrentMinigameState ~= MinigameState.PLAYING or not RoomExit then return end

    local room = game:GetRoom()
    local playerGridIndex = room:GetClampedGridIndex(player.Position)
    local exitGridIndex = room:GetClampedGridIndex(RoomExit.Position)

    if playerGridIndex ~= exitGridIndex and playerGridIndex ~= exitGridIndex - 1 then return end

    if Input.IsActionTriggered(ButtonAction.ACTION_UP, player.ControllerIndex) or
    Input.IsActionTriggered(ButtonAction.ACTION_ITEM, player.ControllerIndex) then
        if RoomExit:GetSprite():IsPlaying("Idle") then
            CurrentLevel = CurrentLevel + 1
            RoomExit:GetSprite():Play("Open", true)
            SFXManager:Play(MinigameSounds.TRANSITION)
            game:ShakeScreen(10)
        elseif RoomExit:GetSprite():IsFinished("Open") then
            StartTransitionScreen()
            GoToNextRoom()
        end
    end

    return true
end


---@param player EntityPlayer
local function CheckIfPlayerIsTouchingExit(player)
    if CurrentMinigameState ~= MinigameState.PLAYING or not RoomExit then return end

    local room = game:GetRoom()
    local playerGridIndex = room:GetClampedGridIndex(player.Position)
    local exitGridIndex = room:GetClampedGridIndex(RoomExit.Position)

    if playerGridIndex == exitGridIndex then
        CurrentLevel = CurrentLevel + 1

        if CurrentLevel == MinigameConstants.GLITCH_MAX_LEVEL + 1 then
            CurrentMinigameState = MinigameState.WAITING_FOR_PUS_MAN
            player:GetData().HasToBeEatenByPusMan = true

            local playerNum = game:GetNumPlayers()
            for i = 0, playerNum - 1, 1 do
                game:GetPlayer(i).Velocity = Vector.Zero
                game:GetPlayer(i).ControlsEnabled = false
            end

            return true
        end

        StartTransitionScreen()
        GoToNextRoom()

        return true
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

        CurrentMinigameState = MinigameState.MACHINE_DYING

        Isaac.FindByType(EntityType.ENTITY_EFFECT, MinigameEntityVariants.MACHINE)[1]:GetSprite():Play("Dying", true)
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)
            player.ControlsEnabled = false
        end
    end
end


local function ManageFakePlayer(player)
    local fakePlayer = player:GetData().FakePlayer
    if not fakePlayer then return end
    local fakePlayerSprite = fakePlayer:GetSprite()

    fakePlayer.Position = player.Position + Vector(0, 1)

    if fakePlayerSprite:IsPlaying("Win") and fakePlayerSprite:GetFrame() > 7 then
        fakePlayerSprite:SetFrame(7)
        return
    elseif fakePlayerSprite:IsPlaying("Win") then return end

    if fakePlayerSprite:IsFinished("Die") then
        if PlayerHP == 0 then
            fakePlayerSprite:Play("Die", true)
            return
        else
            RespawnPlayers()
        end
    elseif fakePlayerSprite:IsPlaying("Die") then return end

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

    if CurrentMinigameState == MinigameState.MACHINE_DYING then
        if fakePlayerSprite:GetAnimation() == "Idle" then
            --Bit of a hack, but coz the player is still,
            --they'll try to play the idle animation non stop so no need for setFrame
            fakePlayerSprite:Play("MoveRight", true)
        end
    end
end


function gush:OnPlayerUpdate(player)
    local gravity
    local isInDoor

    player.Visible = false --Do this here because it sucks

    if RoomExit then
        if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
            isInDoor = CheckIfPlayerIsTouchingExit(player)
        else
            isInDoor = CheckIfPlayerIsInDoor(player)
        end
    else
        CheckIfPlayerIsPressingButton(player)
    end

    if CurrentMinigameState == MinigameState.DYING or CurrentMinigameState == MinigameState.LOSING then
        --Keep the players floating and still while they are dying
        ManageFakePlayer(player)
        return
    end

    --If the player is not moving left or right (not pressing left or right or pressing both) stop their x movement
    if (not Input.IsActionPressed(ButtonAction.ACTION_LEFT, player.ControllerIndex) and not Input.IsActionPressed(ButtonAction.ACTION_RIGHT, player.ControllerIndex)) or
    (Input.IsActionPressed(ButtonAction.ACTION_LEFT, player.ControllerIndex) and Input.IsActionPressed(ButtonAction.ACTION_RIGHT, player.ControllerIndex)) or
    CurrentMinigameState ~= MinigameState.PLAYING then
        player.Velocity = Vector(0, player.Velocity.Y)
    end


    if player:GetData().WasGrounded and not IsPlayerGrounded(player) and player.Velocity.Y >= 0 then
        player:GetData().CoyoteTime = MinigameConstants.COYOTE_TIME_FRAMES
    elseif not player:GetData().WasGrounded and IsPlayerGrounded(player) then
        player:GetData().FakePlayer:GetSprite():Play("TouchGround", true)
    end
    player:GetData().WasGrounded = IsPlayerGrounded(player)

    if (Input.IsActionTriggered(ButtonAction.ACTION_ITEM, player.ControllerIndex) or
    Input.IsActionTriggered(ButtonAction.ACTION_SHOOTDOWN, player.ControllerIndex) or 
    player:GetData().JumpBuffer) and not isInDoor then
        if CanPlayerJump(player) then
            Jump(player)
        elseif Input.IsActionTriggered(ButtonAction.ACTION_ITEM, player.ControllerIndex) or
        Input.IsActionTriggered(ButtonAction.ACTION_SHOOTDOWN, player.ControllerIndex) then
            --Check the input again for false positives
            player:GetData().JumpBuffer = MinigameConstants.JUMP_BUFFER_FRAMES
        end
    end

    if Input.IsActionPressed(ButtonAction.ACTION_ITEM, player.ControllerIndex) or
    Input.IsActionPressed(ButtonAction.ACTION_SHOOTDOWN, player.ControllerIndex) then
        if not player:GetData().ExtraJumpFrames then
            player:GetData().ExtraJumpFrames = 0
        end

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

    local shouldIgnoreGravity = MakePlayerStandOnFloor(player) or CurrentMinigameState == MinigameState.WAITING_FOR_PUS_MAN or CurrentMinigameState == MinigameState.WINNING

    if not shouldIgnoreGravity then
        ApplyGravity(player, gravity)
    end

    MakePlayerHitWall(player)

    CheckIfPlayerHitSpike(player)

    CheckIfPussyManAtePlayer(player)

    ManageFakePlayer(player)
end


local function ManageCollapsings()
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


local function IsPositionOnScreen(pos)
    return pos.X > 0 and pos.X < Isaac.GetScreenWidth() and
    pos.Y > 0 and pos.Y < Isaac.GetScreenHeight()
end


local function PlayVroomSound()
    if SFXManager:IsPlaying(MinigameSounds.SAW_VROOM) then return end

    local SawOnScreen = false

    for _, saw in ipairs(Isaac.FindByType(EntityType.ENTITY_DEATHS_HEAD)) do
        local sawScreenPos = Isaac.WorldToScreen(saw.Position)
        if IsPositionOnScreen(sawScreenPos) then
            SawOnScreen = true
        end
    end

    for _, saw in ipairs(Isaac.FindByType(EntityType.ENTITY_SPIKEBALL)) do
        local sawScreenPos = Isaac.WorldToScreen(saw.Position)
        if IsPositionOnScreen(sawScreenPos) then
            SawOnScreen = true
        end
    end

    if SawOnScreen then
        SFXManager:Play(MinigameSounds.SAW_VROOM)
    end
end


local function SpawnExplosion()
    local spawningPos = Isaac.FindByType(EntityType.ENTITY_EFFECT, MinigameEntityVariants.MACHINE)[1].Position
    spawningPos = spawningPos + Vector(rng:RandomInt(100) - 50, rng:RandomInt(100) - 50)

    local explosion = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.END_EXPLOSION, 0, spawningPos, Vector.Zero, nil)
    explosion:GetSprite():Play("Idle", true)

    game:ShakeScreen(4)
    SFXManager:Play(MinigameSounds.END_EXPLOSION)

    return explosion
end


local function RemoveEndExplosions()
    for _, explosion in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, MinigameEntityVariants.END_EXPLOSION, 0)) do
        if explosion:GetSprite():IsFinished("Idle") then
            if CurrentMinigameState == MinigameState.WINNING and explosion:GetData().IsLastExplosion then
                SFXManager:Play(MinigameSounds.WIN)
                TransitionScreen:Play("Appear", true)

                local playerNum = game:GetNumPlayers()
                for i = 0, playerNum - 1, 1 do
                    local player = game:GetPlayer(i)
                    player:GetData().FakePlayer:GetSprite():Play("Win", true)
                end
            end

            explosion:Remove()
        end
    end
end


local function SpawnEndExplosions()
    if #Isaac.FindByType(EntityType.ENTITY_EFFECT, MinigameEntityVariants.END_EXPLOSION, 0) >= MinigameConstants.MAX_END_EXPLOSIONS or
    game:GetFrameCount() % MinigameConstants.FRAMES_BETWEEN_END_EXPLOSIONS ~= 0 and not (rng:RandomFloat() <= 0.01) then return end

    if EndExplosionsCounter >= MinigameConstants.NUM_EXPLOSION_TO_BIG_EXPLOSION then
        for i = 1, MinigameConstants.EXPLOSION_NUM_IN_BIG_EXPLOSION, 1 do
            local explosion = SpawnExplosion()
            if i == MinigameConstants.EXPLOSION_NUM_IN_BIG_EXPLOSION then
                explosion:GetData().IsLastExplosion = true
            end

            CurrentMinigameState = MinigameState.WINNING
            local machine = Isaac.FindByType(EntityType.ENTITY_EFFECT, MinigameEntityVariants.MACHINE)[1]
            machine:GetSprite():Play("Destroyed", true)
        end
        SFXManager:Play(MinigameSounds.BIG_EXPLOSION)
    else
        SpawnExplosion()
        EndExplosionsCounter = EndExplosionsCounter + 1
    end
end


function gush:OnFrameUpdate()
    if CurrentMinigameState == MinigameState.INTRO_SCREEN then
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            game:GetPlayer(i).ControlsEnabled = false
        end

        MinigameTimers.IntroTimer = MinigameTimers.IntroTimer - 1

        if MinigameTimers.IntroTimer == 0 then
            SFXManager:Play(MinigameSounds.TRANSITION)
            StartTransitionScreen()
        end

    elseif CurrentMinigameState == MinigameState.TRANSITION_SCREEN then
        MinigameTimers.TransitionScreenTimer = MinigameTimers.TransitionScreenTimer - 1

        if MinigameTimers.TransitionScreenTimer == 0 then
            CurrentMinigameState = MinigameState.PLAYING

            if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
                SpawnGusMan()
            end

            local playerNum = game:GetNumPlayers()
            for i = 0, playerNum - 1, 1 do
                local player = game:GetPlayer(i)
                player.ControlsEnabled = true
                if i == 0 then player:UseActiveItem(CollectibleType.COLLECTIBLE_D7, false, false, true, false) end
            end
        end
    elseif CurrentMinigameState == MinigameState.PLAYING then
        ManageCollapsings()
        PlayVroomSound()
    elseif CurrentMinigameState == MinigameState.DYING or CurrentMinigameState == MinigameState.LOSING or 
    CurrentMinigameState == MinigameState.WAITING_FOR_PUS_MAN then
        ManageCollapsings()
    elseif CurrentMinigameState == MinigameState.MACHINE_DYING then
        RemoveEndExplosions()
        SpawnEndExplosions()
    elseif CurrentMinigameState == MinigameState.WINNING then
        RemoveEndExplosions()
    end
end


local function RenderUI()
    if CurrentMinigameState == MinigameState.INTRO_SCREEN or CurrentMinigameState == MinigameState.TRANSITION_SCREEN then return end

    HealthUI:Play("Idle", true)

    if CurrentMinigameState == MinigameState.DYING or CurrentMinigameState == MinigameState.LOSING then
        HealthUI:PlayOverlay("Break", true)
        HealthUI:SetFrame(PlayerHP)
    else
        HealthUI:RemoveOverlay()
        HealthUI:SetFrame(PlayerHP - 1)
    end

    HealthUI:Render(Vector(Isaac.GetScreenWidth()/2, 13), Vector.Zero, Vector.Zero)
end


local function RenderWaveTransition()
    if CurrentMinigameState ~= MinigameState.INTRO_SCREEN and CurrentMinigameState ~= MinigameState.TRANSITION_SCREEN then return end

    TransitionScreen:SetFrame(0)
    TransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
end


local function RenderFadeOut()
    if CurrentMinigameState ~= MinigameState.LOSING and CurrentMinigameState ~= MinigameState.WINNING then return end
    if not Isaac.GetPlayer(0):GetData().FakePlayer:GetSprite():IsPlaying("Win") and CurrentMinigameState ~= MinigameState.LOSING then return end

    if TransitionScreen:IsFinished("Appear") then
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)
            player:ClearEntityFlags(EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
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


function gush:OnRender()
    RenderUI()

    RenderWaveTransition()

    RenderFadeOut()
end


function gush:OnNewRoom()
    SFXManager:Stop(SoundEffect.SOUND_DOOR_HEAVY_CLOSE)
    SFXManager:Stop(SoundEffect.SOUND_DOOR_HEAVY_OPEN)
    PrepareForRoom()
end


function gush:OnBrimstoneHeadInit(head)
    head:GetSprite():Load("gfx/gush_brimstone_head.anm2", true)
end


function gush:OnNerveUpdate(nerve)
    nerve.Visible = false
end


function gush:OnSawInit(saw)
    saw:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    saw:GetSprite():Load("gfx/gush_saw.anm2", false)
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        saw:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/gush_glitch_saw.png")
    end
    saw:GetSprite():LoadGraphics()
end


function gush:OnSawUpdate(saw)
    if CurrentMinigameState ~= MinigameState.PLAYING then
        saw.Velocity = Vector.Zero
        return
    end

    local data = saw:GetData()
    local currentVelocityAngle = saw.Velocity:GetAngleDegrees()

    if data.LastVelocityAngle and math.abs(currentVelocityAngle - data.LastVelocityAngle) >= MinigameConstants.SAW_VELOCITY_ANGLE_THRESHOLD_TO_HIT then
        SFXManager:Play(MinigameSounds.SAW_WALL_HIT)
    end

    data.LastVelocityAngle = currentVelocityAngle
end


function gush:OnPlayerDamage(player)
    KillPlayers(player:ToPlayer())
    return false
end


function gush:OnLaserInit(laser)
    laser:GetSprite():ReplaceSpritesheet(0, "gfx/effects/gush/gush_laser.png")
    laser:GetSprite():ReplaceSpritesheet(1, "gfx/effects/gush/gush_laser.png")
    laser:GetSprite():LoadGraphics()

    SFXManager:Play(MinigameSounds.FIRE_LASER)

    SFXManager:Stop(SoundEffect.SOUND_BLOOD_LASER)
    SFXManager:Stop(SoundEffect.SOUND_BLOOD_LASER_LARGE)
end


function gush:OnLaserUpdate(laser)
    if laser.SpriteScale.X < 1 then
        laser:Remove()
    end

    SFXManager:Stop(SoundEffect.SOUND_BLOOD_LASER)
    SFXManager:Stop(SoundEffect.SOUND_BLOOD_LASER_LARGE)
end


function gush:OnRemovableEffect(effect)
    effect:Remove()
end


---@param tile EntityEffect
function gush:OnGlitchTileUpdate(tile)
    local data = tile:GetData()
    if (game:GetFrameCount() + data.RandomOffset) % MinigameConstants.GLITCH_TILE_CHANGE_FRAMES == 0 and data.ChagingTile then
        local maxFrames = MinigameConstants.GLITCH_TILE_FRAME_NUM[tile:GetSprite():GetAnimation()]
        local newFrame = rng:RandomInt(maxFrames - 1)
        if newFrame >= data.ChosenFrame then
            newFrame = newFrame + 1
        end
        data.ChosenFrame = newFrame
    end

    tile:GetSprite():SetFrame(data.ChosenFrame)
end


---@param pusman EntityEffect
function gush:OnPusManUpdate(pusman)
    if pusman:GetSprite():IsEventTriggered("PlaySound") then
        SFXManager:Play(MinigameSounds.PUS_MAN)
    end
end


function gush:PreEntitySpawn(entityType, entityVariant, _, _, _, _, seed)
    if entityType == EntityType.ENTITY_EFFECT and 
    (entityVariant == EffectVariant.TINY_FLY or entityVariant == EffectVariant.LASER_IMPACT) then
        return {EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_SPLAT, 0, seed}
    end
end


--INIT
function gush:AddCallbacks(mod)
    mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, gush.OnInput)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, gush.OnPlayerUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, gush.OnFrameUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, gush.OnRender)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, gush.OnNewRoom)
    mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, gush.OnBrimstoneHeadInit, EntityType.ENTITY_BRIMSTONE_HEAD)
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, gush.OnNerveUpdate, EntityType.ENTITY_NERVE_ENDING)
    mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, gush.OnSawInit, EntityType.ENTITY_SPIKEBALL)
    mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, gush.OnSawInit, EntityType.ENTITY_DEATHS_HEAD)
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, gush.OnSawUpdate, EntityType.ENTITY_SPIKEBALL)
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, gush.OnSawUpdate, EntityType.ENTITY_DEATHS_HEAD)
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, gush.OnPlayerDamage, EntityType.ENTITY_PLAYER)
    mod:AddCallback(ModCallbacks.MC_POST_LASER_INIT, gush.OnLaserInit)
    mod:AddCallback(ModCallbacks.MC_POST_LASER_UPDATE, gush.OnLaserUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, gush.OnRemovableEffect, EffectVariant.TINY_FLY)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, gush.OnRemovableEffect, EffectVariant.LASER_IMPACT)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, gush.OnRemovableEffect, EffectVariant.WATER_SPLASH)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, gush.OnRemovableEffect, EffectVariant.TINY_FLY)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, gush.OnRemovableEffect, EffectVariant.LASER_IMPACT)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, gush.OnRemovableEffect, EffectVariant.WATER_SPLASH)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, gush.OnGlitchTileUpdate, MinigameEntityVariants.GLITCH_TILE)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, gush.OnPusManUpdate, MinigameEntityVariants.PUS_MAN)
    mod:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, gush.PreEntitySpawn)
end


function gush:RemoveCallbacks(mod)
    mod:RemoveCallback(ModCallbacks.MC_INPUT_ACTION, gush.OnInput)
    mod:RemoveCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, gush.OnPlayerUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_UPDATE, gush.OnFrameUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_RENDER, gush.OnRender)
    mod:RemoveCallback(ModCallbacks.MC_POST_NEW_ROOM, gush.OnNewRoom)
    mod:RemoveCallback(ModCallbacks.MC_POST_NPC_INIT, gush.OnBrimstoneHeadInit)
    mod:RemoveCallback(ModCallbacks.MC_NPC_UPDATE, gush.OnNerveUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_NPC_INIT, gush.OnSawInit)
    mod:RemoveCallback(ModCallbacks.MC_POST_NPC_INIT, gush.OnSawInit)
    mod:RemoveCallback(ModCallbacks.MC_NPC_UPDATE, gush.OnSawUpdate)
    mod:RemoveCallback(ModCallbacks.MC_NPC_UPDATE, gush.OnSawUpdate)
    mod:RemoveCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, gush.OnPlayerDamage)
    mod:RemoveCallback(ModCallbacks.MC_POST_LASER_INIT, gush.OnLaserInit)
    mod:RemoveCallback(ModCallbacks.MC_POST_LASER_UPDATE, gush.OnLaserUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_INIT, gush.OnRemovableEffect)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_INIT, gush.OnRemovableEffect)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_INIT, gush.OnRemovableEffect)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, gush.OnRemovableEffect)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, gush.OnRemovableEffect)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, gush.OnRemovableEffect)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, gush.OnGlitchTileUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, gush.OnPusManUpdate)
    mod:RemoveCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, gush.PreEntitySpawn)
end


function gush:Init(mod, variables)
    gush:AddCallbacks(mod)
    ArcadeCabinetVariables = variables

    --Reset variables
    PlayerHP = 4
    CurrentLevel = 1
    CollapsingPlatforms = {}
    VisitedRooms = {}
    EndExplosionsCounter = 0

    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    GoToNextRoom()

    --Reset timers
    for _, timer in pairs(MinigameTimers) do
        timer = 0
    end

    --UI
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        HealthUI:ReplaceSpritesheet(1, "gfx/effects/gush/gush_glitch_hearts_ui.png")
    else
        HealthUI:ReplaceSpritesheet(1, "gfx/effects/gush/gush_hearts_ui.png")
    end
    HealthUI:LoadGraphics()

    --Intro stuff
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        TransitionScreen:ReplaceSpritesheet(0, "gfx/effects/gush/gush_glitch_intro_screen.png")
    else
        TransitionScreen:ReplaceSpritesheet(0, "gfx/effects/gush/gush_intro_screen.png")
        TransitionScreen:ReplaceSpritesheet(1, "gfx/effects/gush/gush_intro_screen.png")
    end
    TransitionScreen:LoadGraphics()
    TransitionScreen:Play("Idle", true)
    CurrentMinigameState = MinigameState.INTRO_SCREEN
    MinigameTimers.IntroTimer = MinigameConstants.MAX_INTRO_SCREEN_TIMER

    --Play music
    MusicManager:Play(MinigameMusic, 1)
    MusicManager:UpdateVolume()
    MusicManager:Pause()

    --Set up players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        player.ControlsEnabled = false

        player:GetData().IsGrounded = false
        player:GetData().ExtraJumpFrames = 0
    end
end


return gush