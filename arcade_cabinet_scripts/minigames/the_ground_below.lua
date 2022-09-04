local the_ground_below = {}
local game = Game()
local rng = RNG()
local SFXManager = SFXManager()
local MusicManager = MusicManager()
local ArcadeCabinetVariables

-- Sounds
local MinigameSounds = {
    INTRO = Isaac.GetSoundIdByName("tgb intro"),
    PLAYER_HIT = Isaac.GetSoundIdByName("bsw player hit"),
    BUZZ = Isaac.GetSoundIdByName("tgb buzz"),
    COUGH = Isaac.GetSoundIdByName("tgb cough"),
    SHOOT = Isaac.GetSoundIdByName("tgb shoot"),
    SPLAT = Isaac.GetSoundIdByName("tgb splat"),

    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}

local MinigameMusic = Isaac.GetMusicIdByName("bsw black beat wielder")

-- Entities
local MinigameEntityVariants = {
    BACKGROUND = Isaac.GetEntityVariantByName("background TGB"),
    PLAYER = Isaac.GetEntityVariantByName("player TGB"),

    HORF = Isaac.GetEntityVariantByName("horf TGB"),
    KEEPER = Isaac.GetEntityVariantByName("keeper TGB"),
    FLY = Isaac.GetEntityVariantByName("fly TGB"),
    DUKE = Isaac.GetEntityVariantByName("duke TGB"),

    GLITCH_TILE = Isaac.GetEntityVariantByName("glitch tile TGB")
}

-- Constants
local MinigameConstants = {
    HEARTS_UI_RENDER_POS = Vector(70, 40),

    MAX_INTRO_TIMER_FRAMES = 50, --Frames the intro last
    MAX_I_FRAMES = 20,  --Player i frames

    --BG system
    BG_SCROLLING_SPEED = 10, --Bg scrolling speed
    BG_SPAWNING_OFFSET = 420,   --Y pos the first bg spawns
    BG_TO_SPAWN_THRESHOLD = 560,    --How down the next bg should spawn

    --Wave system
    MAX_FALLING_TIMER_FRAMES = 15,  --Frames between an attack and the next
    NUM_WAVES_PER_CHAPTER = {   --Waves per chapter, to add more numbers here (always followed by comma)
        3,
        3,
    },
    HORF_CHANCE_PER_CHAPTER = { --Chance to replace a fly for a horf in each wave per chapter. Add a number for each chapter
        33,
        33,
    },
    KEEPER_CHANCE_PER_CHAPTER = {   --Chance to replace a fly for a keeper in each wave per chapter. Add a number for each chapter
        0,
        0,
    },

    --Horfs attack
    HORF_SPAWNING_POS = Vector(550, 540), --What position the horfs spawn in (the 2nd horf is just mirrored)
    HORF_TARGET_Y = -20,    --Y position the horfs need to reach to end the atacks
    HORF_VELOCITY = 2,  --Self explanatory
    HORF_SHOT_COOLDOWN = 30,    --Frames between shooting
    HORF_SAFE_DISTANCE = 50,    --Distance from the player the horfs will not shoot (it only accounts for the y position)
    HORF_HITBOX_RADIUS = 30,    --Self explanatory

    --Hanging keepers attack
    KEEPER_SPAWNING_POS = Vector(800, 500), --What position the keepers spawn in (the 2nd keeper is just mirrored)
    KEEPER_TARGET_POS = Vector(550, 400),   --Position the keepers need to reach to shoot
    KEEPER_VELOCITY = 4,    --Self explanatory
    NUM_KEEPER_SHOTS = 6,   --Number of triple shots the keepers will make
    KEEPER_SHOT_COOLDOWN = 40,  --Same as horf

    --Random flies attack
    FLY_VELOCITY = 4.5, --Self explanatory
    FLY_Y_SPAWN = 500,  --Y Position the flies will spawn in
    FLY_HITBOX_RADIUS = 20, --Self explanatory
    NUM_FLY_LINES = 6,  --Number of fly lines per fly attack
    MAX_FLY_LINE_TIMER_FRAMES = 35, --Frames between each fly line

    --Duke of flies attack
    DUKE_SPAWNING_POS = Vector(550, 540),   --Self explanatory
    DUKE_TARGET_POS = Vector(610, 400), --Position the duke needs to reach to start coughing
    DUKE_DESPAWN = Vector(900, 200),    --Position the duke needs to reach to end the attack
    DUKE_VELOCITY = 3,  --Self explanatory
    DUKE_SPAWN_FLY_COOLDOWN = 40,   --Frames between each cough
    DUKE_NUM_FLY_ROUNDS = 3,    --Number of coughs
    DUKE_FLY_SPAWN_OFFSET = 10, --An offsef so the flies spawn in his mouth
    DUKE_FLY_VELOCITY = 14,  --Fly velocity while getting to their respective position in the line

    --Ending cutscene
    PLAYER_FALL_VELOCITY = 10,
    PLAYER_Y_DESPAWN = 600,
    CUTSCENE_PLAYER_Y_SPAWN = 0,
    CUTSCENE_PLAYER_Y_SPLAT = 320,
    FLOOR_Y_SPAWN = 280,
    MAX_SPLAT_FRAMES = 30,

    --Glitch stuff
    GLITCH_FLY_CHANGE_Y_POS = 400,  --Y distance to the player the flies will change positions

    GLITCH_EXTRA_CHANCE_FOR_COOL_ATTACKS = 15,  --This chance will be added to whatever the horf/keeper replace attack is

    GLITCH_NUM_GLITCH_TILES = 40,
    GLITCH_TILE_FRAME_NUM = 4,
    GLITCH_TILE_CHANGE_FRAMES = 10,
    GLITCH_TILE_CHANGING_CHANCE = 10,
}

-- Timers
local MinigameTimers = {
    IntroScreenTimer = 0,
    FallingTimer = 0,
    FlyLineToSpawnTimer = 0,
    IFramesTimer = 0,
}

-- States
local CurrentMinigameState = 0
local MinigameState = {
    INTRO = 1,
    FALLING = 2,
    ATTACK = 3,
    SPLATTING = 4,

    LOSING = 5,
    WINNING = 6,
}

local CurrentAttack = 0
local MinigameAttack = {
    HORFS = 1,
    HANGING_KEEPERS = 2,
    FLIES = 3,
    DUKE_OF_FLIES = 4
}

-- UI
local TransitionScreen = Sprite()
TransitionScreen:Load("gfx/minigame_transition.anm2", true)
TransitionScreen:ReplaceSpritesheet(0, "gfx/effects/the ground below/tgb_intro.png")
TransitionScreen:ReplaceSpritesheet(1, "gfx/effects/the ground below/tgb_intro.png")
TransitionScreen:LoadGraphics()

local HeartsUI = Sprite()
HeartsUI:Load("gfx/tgb_hearts_ui.anm2", true)

-- Other variables
local PlayerHP = 0

local CurrentWave = 0
local CurrentChapter = 0

local FlyLineNum = 0

local spawnedBgNum = 0
local currentBgType = "rocks"
local nextBgChange = -10

local function FinishAttack()
    MinigameTimers.FallingTimer = MinigameConstants.MAX_FALLING_TIMER_FRAMES

    if CurrentAttack == MinigameAttack.DUKE_OF_FLIES then
        if CurrentChapter > #MinigameConstants.NUM_WAVES_PER_CHAPTER then
            for _, bg in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND)) do
                bg.Velocity = Vector.Zero
            end

            local playerNum = game:GetNumPlayers()
            for i = 0, playerNum - 1, 1 do
                local player = game:GetPlayer(i)
                player:GetData().FakePlayer.Velocity = Vector(0, MinigameConstants.PLAYER_FALL_VELOCITY)
                player.Velocity = Vector.Zero
                player.ControlsEnabled = false
            end

            CurrentMinigameState = MinigameState.SPLATTING
            return
        end

        nextBgChange = spawnedBgNum + 1

        if currentBgType == "rocks" then
            currentBgType = "bricks"
        else
            currentBgType = "rocks"
        end
    end

    CurrentMinigameState = MinigameState.FALLING
end


local function DealDamage(player)
    if MinigameTimers.IFramesTimer > 0 then return end

    SFXManager:Play(MinigameSounds.PLAYER_HIT)
    HeartsUI:Play("Flash", true)
    player:GetData().FakePlayer:GetSprite():Play("Hurt", true)
    MinigameTimers.IFramesTimer = MinigameConstants.MAX_I_FRAMES

    PlayerHP = PlayerHP - 1

    if PlayerHP == 0 then
        CurrentMinigameState = MinigameState.LOSING
        SFXManager:Play(MinigameSounds.LOSE)
        TransitionScreen:Play("Appear", true)

        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)

            player.Velocity = Vector.Zero
            player.ControlsEnabled = false
        end
    end
end


local function IsPositionOnScreen(pos)
    pos = Isaac.WorldToScreen(pos)
    return pos.X > 0 and pos.X < Isaac.GetScreenWidth() and
    pos.Y > 0 and pos.Y < Isaac.GetScreenHeight()
end


local function StartHorfAttack()
    local horf1 = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.HORF, 0, MinigameConstants.HORF_SPAWNING_POS, Vector(0, -MinigameConstants.HORF_VELOCITY), nil)
    horf1:GetData().SpawningFrame = game:GetFrameCount() + 10

    local spawningPos2 = Vector(game:GetRoom():GetCenterPos().X - (MinigameConstants.HORF_SPAWNING_POS.X - game:GetRoom():GetCenterPos().X), MinigameConstants.HORF_SPAWNING_POS.Y)
    local horf2 = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.HORF, 0, spawningPos2, Vector(0, -MinigameConstants.HORF_VELOCITY), nil)
    horf2:GetData().SpawningFrame = game:GetFrameCount() + 10

    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        horf1:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/tgb_glitch_horf.png")
        horf1:GetSprite():LoadGraphics()

        horf2:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/tgb_glitch_horf.png")
        horf2:GetSprite():LoadGraphics()
    end
end


local function StartHangingKeeperAttack()
    local spawningPos = MinigameConstants.KEEPER_SPAWNING_POS
    local targetPos = MinigameConstants.KEEPER_TARGET_POS
    if rng:RandomInt(2) == 0 then
        spawningPos = Vector(game:GetRoom():GetCenterPos().X - (MinigameConstants.KEEPER_SPAWNING_POS.X - game:GetRoom():GetCenterPos().X), MinigameConstants.KEEPER_SPAWNING_POS.Y)
        targetPos = Vector(game:GetRoom():GetCenterPos().X - (MinigameConstants.KEEPER_TARGET_POS.X - game:GetRoom():GetCenterPos().X), MinigameConstants.KEEPER_TARGET_POS.Y)
    end
    local targetVelocity = (targetPos - spawningPos):Normalized() * MinigameConstants.KEEPER_VELOCITY
    local keeper = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.KEEPER, 0, spawningPos, targetVelocity, nil)
    keeper:GetData().KeeperShotsFired = 0
    keeper:GetData().SpawningPos = spawningPos
    keeper:GetData().SpawningFrame = game:GetFrameCount() + 30

    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        keeper:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/tgb_glitch_keeper.png")
        keeper:GetSprite():ReplaceSpritesheet(1, "gfx/enemies/tgb_glitch_keeper_rope.png")
        keeper:GetSprite():LoadGraphics()
    end
end


local function SpawnLineFlies()
    local room = game:GetRoom()

    local freeGridLocation = 47 + rng:RandomInt(10)
    local nextFreeGridLocation
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        local freeLocationOffset = rng:RandomInt(4) - 2
        if freeLocationOffset >= 0 then
            freeLocationOffset = freeLocationOffset + 1
        end
        nextFreeGridLocation = freeGridLocation + freeLocationOffset
    end

    for i = 46, 58, 1 do
        if i ~= freeGridLocation then
            local randomOffset = RandomVector() * Vector(2, 3.2)
            local spawningPos = Vector(room:GetGridPosition(i).X, MinigameConstants.FLY_Y_SPAWN) + randomOffset
            local fly = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.FLY, 0, spawningPos, Vector(0, -MinigameConstants.FLY_VELOCITY), nil)
            fly:GetData().LineNum = FlyLineNum

            if nextFreeGridLocation and i == nextFreeGridLocation then
                fly:GetData().MoveToGrid = freeGridLocation
            end

            if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
                fly:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/tgb_glitch_fly.png")
                fly:GetSprite():LoadGraphics()
            end
        end
    end
end


local function StartRandomFlyAttack()
    FlyLineNum = 1
    MinigameTimers.FlyLineToSpawnTimer = MinigameConstants.MAX_FLY_LINE_TIMER_FRAMES
    SpawnLineFlies()
end


local function StartDukeAttack()
    local dukeVelocity = (MinigameConstants.DUKE_TARGET_POS - MinigameConstants.DUKE_SPAWNING_POS):Normalized() * MinigameConstants.DUKE_VELOCITY
    local duke = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.DUKE, 0, MinigameConstants.DUKE_SPAWNING_POS, dukeVelocity, nil)
    duke:GetData().NumFlyLinesSpawned = 0
    duke:GetData().SpawningFrame = game:GetFrameCount() - 10

    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        duke:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/tgb_glitch_duke.png")
        duke:GetSprite():LoadGraphics()
    end
end


local function ChangeBgSprite(bg)
    --Default is rocks mid, so nil for that
    local newSprite = nil
    local bgTypeForThis = currentBgType

    --Flip bg type if the change is yet to happen
    if spawnedBgNum <= nextBgChange then
        if currentBgType == "rocks" then
            bgTypeForThis = "bricks"
        else
            bgTypeForThis = "rocks"
        end
    end

    local glitchPrefix = ""
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        glitchPrefix = "glitch_"
    end

    if spawnedBgNum == nextBgChange then
        newSprite = "gfx/grid/tgb_" .. glitchPrefix .. bgTypeForThis .. "_end.png"
    elseif spawnedBgNum == nextBgChange + 1 then
        newSprite = "gfx/grid/tgb_" .. glitchPrefix .. "pitch_black.png"
    elseif spawnedBgNum == nextBgChange + 2 then
        newSprite = "gfx/grid/tgb_" .. glitchPrefix .. bgTypeForThis .. "_start.png"
    elseif spawnedBgNum < nextBgChange or spawnedBgNum > nextBgChange + 2 then
        newSprite = "gfx/grid/tgb_" .. glitchPrefix .. bgTypeForThis .. "_mid.png"
    end

    if not newSprite then return end

    bg:GetSprite():ReplaceSpritesheet(0, newSprite)
    bg:GetSprite():LoadGraphics()
end


local function SpawnNextBg(currentBg)
    local bg = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND, 0, currentBg.Child.Position + Vector(0, MinigameConstants.BG_SPAWNING_OFFSET), Vector.Zero, nil)
    bg.DepthOffset = -1000
    currentBg.Child.Child = bg
    spawnedBgNum = spawnedBgNum + 1

    ChangeBgSprite(bg)
end


function the_ground_below:OnUpdateBackground(effect)
    if CurrentMinigameState == MinigameState.SPLATTING or CurrentMinigameState == MinigameState.WINNING then return end

    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        effect.Velocity = Vector.Zero
    else
        effect.Velocity = Vector(0, -MinigameConstants.BG_SCROLLING_SPEED)
    end

    if effect.Position.Y < (game:GetRoom():GetCenterPos() - Vector(0, MinigameConstants.BG_TO_SPAWN_THRESHOLD)).Y then
        SpawnNextBg(effect)
        effect:Remove()
    end
end


function the_ground_below:OnUpdateHorf(effect)
    if (game:GetFrameCount() - effect:GetData().SpawningFrame) % MinigameConstants.HORF_SHOT_COOLDOWN == 0 and
    math.abs(effect.Position.Y - Isaac.GetPlayer(0).Position.Y) > MinigameConstants.HORF_SAFE_DISTANCE and
    IsPositionOnScreen(effect.Position) then
        effect:GetSprite():Play("Shoot", true)
    end

    if effect:GetSprite():IsEventTriggered("Shoot") then
        local dummy = Isaac.Spawn(997, 10, 0, effect.Position + Vector(0, 0.1), Vector.Zero, nil)
        local spawningPos = dummy.Position
        local spawningSpeed = (game:GetPlayer(0).Position - spawningPos):Normalized() * 10
        local params = ProjectileParams()
        params.BulletFlags = ProjectileFlags.NO_WALL_COLLIDE
        params.Spread = 1
        dummy:ToNPC():FireProjectiles(spawningPos, spawningSpeed, 0, params)
        dummy:Remove()

        SFXManager:Play(MinigameSounds.SHOOT)
    end

    if effect:GetSprite():IsFinished("Shoot") then
        effect:GetSprite():Play("Idle")
    end

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        if player.Position:Distance(effect.Position) < MinigameConstants.HORF_HITBOX_RADIUS then
            DealDamage(player)
        end
    end

    if effect.Position.Y < MinigameConstants.HORF_TARGET_Y then
        FinishAttack()

        effect:Remove()
    end
end


function the_ground_below:OnUpdateKeeper(effect)
    if (game:GetFrameCount() - effect:GetData().SpawningFrame) % MinigameConstants.KEEPER_SHOT_COOLDOWN == 0 and
     effect.Velocity:Length() < 0.1 then
        effect:GetData().KeeperShotsFired = effect:GetData().KeeperShotsFired + 1

        if effect:GetData().KeeperShotsFired == MinigameConstants.NUM_KEEPER_SHOTS then
            effect.Velocity = (effect:GetData().SpawningPos - effect.Position):Normalized() * MinigameConstants.KEEPER_VELOCITY
        else
            effect:GetSprite():Play("Shoot", true)
        end
    end

    if effect:GetSprite():IsEventTriggered("Shoot") then
        local dummy = Isaac.Spawn(997, 10, 0, effect.Position + Vector(0, 0.1), Vector.Zero, nil)
        local spawningPos = dummy.Position
        local spawningSpeed = (game:GetPlayer(0).Position - spawningPos):Normalized() * 10
        local params = ProjectileParams()
        params.BulletFlags = ProjectileFlags.NO_WALL_COLLIDE
        params.Spread = 1
        dummy:ToNPC():FireProjectiles(spawningPos, spawningSpeed, 2, params)
        dummy:Remove()

        SFXManager:Play(MinigameSounds.SHOOT)
    end

    if effect:GetSprite():IsFinished("Shoot") then
        effect:GetSprite():Play("Idle")
    end

    if effect.Position.Y < MinigameConstants.KEEPER_TARGET_POS.Y and effect:GetData().KeeperShotsFired == 0 then
        effect.Velocity = Vector.Zero
    end

    if effect.Position.Y > effect:GetData().SpawningPos.Y then
        FinishAttack()
        effect:Remove()
    end
end


function the_ground_below:OnFlyUpdate(effect)
    if not SFXManager:IsPlaying(MinigameSounds.BUZZ) then
        SFXManager:Play(MinigameSounds.BUZZ)
    end

    if effect:GetData().TargetPosition then
        if effect.Position.X <= effect:GetData().TargetPosition then
            effect.Velocity = Vector.Zero

            if effect:GetData().IsLastFly then
                for _, fly in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, MinigameEntityVariants.FLY)) do
                    fly.Velocity = Vector(0, -1) * MinigameConstants.FLY_VELOCITY
                end
            end

            effect:GetData().TargetPosition = nil
        end
    end

    if effect:GetData().MoveToGrid and effect.Position.Y <= MinigameConstants.GLITCH_FLY_CHANGE_Y_POS then
        local gridPos = game:GetRoom():GetGridPosition(effect:GetData().MoveToGrid)
        effect.Position = Vector(gridPos.X, effect.Position.Y)

        effect:GetData().MoveToGrid = nil
    end

    if effect.Position.Y < 0 then
        if effect:GetData().LineNum and effect:GetData().LineNum == MinigameConstants.NUM_FLY_LINES then
            FinishAttack()
        end

        effect:Remove()
    end

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        if player.Position:Distance(effect.Position) < MinigameConstants.FLY_HITBOX_RADIUS then
            DealDamage(player)
        end
    end
end


function the_ground_below:OnDukeUpdate(effect)
    if (game:GetFrameCount() - effect:GetData().SpawningFrame) % MinigameConstants.DUKE_SPAWN_FLY_COOLDOWN == 0 and effect.Velocity:Length() < 0.1 then
        if effect:GetData().NumFlyLinesSpawned == MinigameConstants.DUKE_NUM_FLY_ROUNDS then
            effect.Velocity = (MinigameConstants.DUKE_DESPAWN - effect.Position):Normalized() * MinigameConstants.DUKE_VELOCITY
        else
            effect:GetData().NumFlyLinesSpawned = effect:GetData().NumFlyLinesSpawned + 1
            effect:GetSprite():Play("Shoot", true)
        end
    end

    if effect:GetSprite():IsEventTriggered("SpawnFlies") then
        local room = game:GetRoom()

        local freeGridLocation = 47 + rng:RandomInt(10)

        for i = 46, 58, 1 do
            if i ~= freeGridLocation then
                local randomOffset = RandomVector() * Vector(2, 3.2)
                local spawningPos = effect.Position + Vector(0, MinigameConstants.DUKE_FLY_SPAWN_OFFSET) + randomOffset
                local fly = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.FLY, 0, spawningPos, Vector(-1, 0) * MinigameConstants.DUKE_FLY_VELOCITY, nil)

                fly:GetData().TargetPosition = room:GetGridPosition(i).X

                if i == 46 then
                    fly:GetData().IsLastFly = true
                end

                if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
                    fly:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/tgb_glitch_fly.png")
                    fly:GetSprite():LoadGraphics()
                end
            end
        end

        SFXManager:Play(MinigameSounds.COUGH)
    end

    if effect:GetSprite():IsFinished("Shoot") then
        effect:GetSprite():Play("Idle", true)
    end

    if effect.Position.Y < MinigameConstants.DUKE_TARGET_POS.Y and effect:GetData().NumFlyLinesSpawned == 0 then
        effect.Velocity = Vector.Zero
    end

    if effect.Position.X > MinigameConstants.DUKE_DESPAWN.X then
        FinishAttack()
        effect:Remove()
    end
end


function the_ground_below:OnUpdateCutscenePlayer(effect)
    if not effect:GetData().IsCutscenePlayer then return end

    if effect.Position.Y > MinigameConstants.CUTSCENE_PLAYER_Y_SPLAT and not effect:GetData().SplatFrame then
        SFXManager:Play(MinigameSounds.SPLAT)
        effect.Velocity = Vector.Zero
        effect:GetSprite():Play("Splat", true)
        effect:GetData().SplatFrame = game:GetFrameCount()
    elseif effect:GetData().SplatFrame then
        if game:GetFrameCount() - effect:GetData().SplatFrame == MinigameConstants.MAX_SPLAT_FRAMES then
            effect:GetSprite():Play("Happy", true)

            SFXManager:Play(MinigameSounds.WIN)
            TransitionScreen:Play("Appear", true)
            CurrentMinigameState = MinigameState.WINNING
        end
    end
end


function the_ground_below:OnUpdateBulletPoof(poof)
    poof:Remove()
    SFXManager:Stop(SoundEffect.SOUND_TEARIMPACTS)
end


function the_ground_below:OnTinyFlyUpdate(fly)
    fly:Remove()
end


---@param tile EntityEffect
function the_ground_below:OnGlitchTileUpdate(tile)
    local data = tile:GetData()
    if data.ChagingTile and (game:GetFrameCount() + data.RandomOffset) % MinigameConstants.GLITCH_TILE_CHANGE_FRAMES == 0 then
        local maxFrames = MinigameConstants.GLITCH_TILE_FRAME_NUM
        local newFrame = rng:RandomInt(maxFrames - 1)
        if newFrame >= data.ChosenFrame then
            newFrame = newFrame + 1
        end
        data.ChosenFrame = newFrame
    end

    tile:GetSprite():SetFrame(data.ChosenFrame)
end


function the_ground_below:OnProjectileInit(projectile)
    projectile:GetSprite():Load("gfx/tgb_projectile.anm2", false)
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        projectile:GetSprite():ReplaceSpritesheet(0, "gfx/effects/the ground below/tgb_glitch_projectile.png")
    end
    projectile:GetSprite():LoadGraphics()
    projectile:GetSprite():Play("Idle", true)
end


function the_ground_below:OnProjectileUpdate(projectile)
    if projectile.Color.A < 1 then
        projectile:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 300, -1, false, false)
    end

    projectile.FallingSpeed = 0
    projectile.FallingAccel = -0.1

    if not IsPositionOnScreen(projectile.Position) then
        projectile:Remove()
    end
end


local function UpdateIntro()
    MinigameTimers.IntroScreenTimer = MinigameTimers.IntroScreenTimer - 1

    if MinigameTimers.IntroScreenTimer == 0 then
        CurrentMinigameState = MinigameState.FALLING

        -- Backdrop
        local bg = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND, 0, game:GetRoom():GetCenterPos() - Vector(0, 120), Vector.Zero, nil)
        bg.DepthOffset = -5000
        if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
            bg.Position = Vector(bg.Position.X, bg.Position.Y - 20)
            bg.Velocity = Vector.Zero
            bg:GetSprite():ReplaceSpritesheet(0, "gfx/grid/tgb_glitch_pitch_black.png")
        else
            bg:GetSprite():ReplaceSpritesheet(0, "gfx/grid/tgb_rocks_start.png")
        end
        bg:GetSprite():LoadGraphics()

        local bg2 = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND, 0, bg.Position + Vector(0,440), Vector.Zero, nil)
        bg2.DepthOffset = -5000
        bg.Child = bg2
        if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
            bg2.Position = Vector(bg2.Position.X, bg2.Position.Y - 20)
            bg2.Velocity = Vector.Zero
            bg2:GetSprite():ReplaceSpritesheet(0, "gfx/grid/tgb_glitch_pitch_black.png")
        else
            bg2:GetSprite():ReplaceSpritesheet(0, "gfx/grid/tgb_rocks_mid.png")
        end
        bg2:GetSprite():LoadGraphics()

        spawnedBgNum = 2

        for i = 0, game:GetNumPlayers() - 1, 1 do
            local player = game:GetPlayer(i)
            player.ControlsEnabled = true
        end
    end
end


local function UpdateFalling()
    MinigameTimers.FallingTimer = MinigameTimers.FallingTimer - 1

    if MinigameTimers.FallingTimer == 0 then
        CurrentMinigameState = MinigameState.ATTACK

        if CurrentWave > MinigameConstants.NUM_WAVES_PER_CHAPTER[CurrentChapter] then
            CurrentChapter = CurrentChapter + 1
            CurrentWave = 1
            CurrentAttack = MinigameAttack.DUKE_OF_FLIES
            StartDukeAttack()
        else
            local extraGlitchChance = 0
            if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
                extraGlitchChance = MinigameConstants.GLITCH_EXTRA_CHANCE_FOR_COOL_ATTACKS
            end

            if ((CurrentChapter > 1 or CurrentWave > 1) and
            rng:RandomInt(100) < (MinigameConstants.HORF_CHANCE_PER_CHAPTER[CurrentChapter]) + extraGlitchChance) or
            (CurrentChapter == 1 and CurrentWave == MinigameConstants.NUM_WAVES_PER_CHAPTER[CurrentChapter]) then
                if (rng:RandomInt(100) < (MinigameConstants.KEEPER_CHANCE_PER_CHAPTER[CurrentChapter] + extraGlitchChance) and
                not (CurrentChapter == 1 and CurrentWave == MinigameConstants.NUM_WAVES_PER_CHAPTER[CurrentChapter])) or
                (CurrentChapter == 2 and CurrentWave == MinigameConstants.NUM_WAVES_PER_CHAPTER[CurrentChapter]) then
                    CurrentAttack = MinigameAttack.HANGING_KEEPERS
                    StartHangingKeeperAttack()
                else
                    CurrentAttack = MinigameAttack.HORFS
                    StartHorfAttack()
                end
            else
                CurrentAttack = MinigameAttack.FLIES
                StartRandomFlyAttack()
            end
            CurrentWave = CurrentWave + 1
        end
    end
end


local function UpdateFlyAttack()
    if FlyLineNum >= MinigameConstants.NUM_FLY_LINES then return end

    MinigameTimers.FlyLineToSpawnTimer = MinigameTimers.FlyLineToSpawnTimer - 1

    if MinigameTimers.FlyLineToSpawnTimer == 0 then
        MinigameTimers.FlyLineToSpawnTimer = MinigameConstants.MAX_FLY_LINE_TIMER_FRAMES
        FlyLineNum = FlyLineNum + 1
        SpawnLineFlies()
    end
end


function the_ground_below:OnFrameUpdate()
    if MinigameTimers.IFramesTimer > 0 then MinigameTimers.IFramesTimer = MinigameTimers.IFramesTimer - 1 end

    if CurrentMinigameState == MinigameState.INTRO then
        UpdateIntro()
    elseif CurrentMinigameState == MinigameState.FALLING then
        UpdateFalling()
    elseif CurrentMinigameState == MinigameState.ATTACK then
        if CurrentAttack == MinigameAttack.FLIES then
            UpdateFlyAttack()
        end
    end
end


local function RenderUI()
    if not HeartsUI:IsPlaying("Flash") then
        HeartsUI:Play("Idle", true)
        HeartsUI:SetFrame(PlayerHP)
    else
        HeartsUI:Update()
    end

    HeartsUI:Render(MinigameConstants.HEARTS_UI_RENDER_POS, Vector.Zero, Vector.Zero)
end


local function RenderTransition()
    if CurrentMinigameState ~= MinigameState.INTRO then return end

    TransitionScreen:Play("Idle", true)
    TransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
end


local function RenderFadeOut()
    if CurrentMinigameState ~= MinigameState.LOSING and CurrentMinigameState ~= MinigameState.WINNING then return end

    if TransitionScreen:IsFinished("Appear") then
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


function the_ground_below:OnRender()
    RenderUI()

    RenderTransition()

    RenderFadeOut()
end


function the_ground_below:OnPlayerUpdate(player)
    if not player:GetData().FakePlayer then return end

    if CurrentMinigameState == MinigameState.SPLATTING then

        if player:GetData().FakePlayer.Position.Y > MinigameConstants.PLAYER_Y_DESPAWN then

            local playerNum = game:GetNumPlayers()
            for i = 0, playerNum - 1, 1 do
                local player = game:GetPlayer(i)
                player:GetData().FakePlayer:Remove()
                player:GetData().FakePlayer = nil
            end

            local cutscenePlayer = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.PLAYER, 0, Vector(game:GetRoom():GetCenterPos().X, MinigameConstants.CUTSCENE_PLAYER_Y_SPAWN), Vector(0, MinigameConstants.PLAYER_FALL_VELOCITY), nil)
            cutscenePlayer:GetData().IsCutscenePlayer = true

            for _, bg in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND)) do
                bg:Remove()
            end

            local floor = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.BACKGROUND, 0, Vector(game:GetRoom():GetCenterPos().X, MinigameConstants.FLOOR_Y_SPAWN), Vector.Zero, nil)
            if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
                floor:GetSprite():ReplaceSpritesheet(0, "gfx/grid/tgb_glitch_floor.png")
            else
                floor:GetSprite():ReplaceSpritesheet(0, "gfx/grid/tgb_floor.png")
            end
            floor:GetSprite():LoadGraphics()
            floor.DepthOffset = -500
        end

        return
    end

    player:GetData().FakePlayer.Position = player.Position + Vector(0, 1)

    if player:GetData().FakePlayer:GetSprite():IsFinished("Hurt") then
        player:GetData().FakePlayer:GetSprite():Play("Idle", true)
    end

    if CurrentMinigameState == MinigameState.LOSING then
        player:GetData().FakePlayer:GetSprite():SetFrame(2)
    end
end


function the_ground_below:OnEffectInit(effect)
    SFXManager:Stop(SoundEffect.SOUND_TEARIMPACTS)
    SFXManager:Stop(SoundEffect.SOUND_SPLATTER)
    effect.Visible = false
end


function the_ground_below:OnPlayerDamage(player)
    DealDamage(player:ToPlayer())

    return false
end


function the_ground_below:OnInput(_, inputHook, buttonAction)
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


-- INIT MINIGAME
local function SpawnGlitchTiles()
    if not ArcadeCabinetVariables.IsCurrentMinigameGlitched then return end
    local room = game:GetRoom()

    local possibleGlitchTiles = {}
    for i = 0, 149, 1 do
        table.insert(possibleGlitchTiles, i)
    end

    for _ = 1, MinigameConstants.GLITCH_NUM_GLITCH_TILES, 1 do
        local chosen = rng:RandomInt(#possibleGlitchTiles) + 1
        local gridIndex = possibleGlitchTiles[chosen]
        table.remove(possibleGlitchTiles, chosen)

        local glitchTile = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.GLITCH_TILE, 0, room:GetGridPosition(gridIndex), Vector.Zero, nil)

        glitchTile:GetSprite():Play("Idle", true)
        glitchTile:GetData().ChosenFrame = rng:RandomInt(MinigameConstants.GLITCH_TILE_FRAME_NUM)
        glitchTile:GetSprite():SetFrame(glitchTile:GetData().ChosenFrame)
        glitchTile:GetData().ChagingTile = rng:RandomInt(100) < MinigameConstants.GLITCH_TILE_CHANGING_CHANCE
        glitchTile:GetData().RandomOffset = rng:RandomInt(MinigameConstants.GLITCH_TILE_CHANGE_FRAMES)
        glitchTile.DepthOffset = -100
    end
end


function the_ground_below:AddCallbacks(mod)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnUpdateBackground, MinigameEntityVariants.BACKGROUND)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnUpdateHorf, MinigameEntityVariants.HORF)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnUpdateKeeper, MinigameEntityVariants.KEEPER)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnFlyUpdate, MinigameEntityVariants.FLY)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnDukeUpdate, MinigameEntityVariants.DUKE)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnUpdateCutscenePlayer, MinigameEntityVariants.PLAYER)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnUpdateBulletPoof, EffectVariant.BULLET_POOF)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnTinyFlyUpdate, EffectVariant.TINY_FLY)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnGlitchTileUpdate, MinigameEntityVariants.GLITCH_TILE)

    mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, the_ground_below.OnProjectileInit)
    mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, the_ground_below.OnProjectileUpdate)

    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, the_ground_below.OnFrameUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, the_ground_below.OnRender)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, the_ground_below.OnPlayerUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, the_ground_below.OnEffectInit, EffectVariant.BULLET_POOF)
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, the_ground_below.OnPlayerDamage, EntityType.ENTITY_PLAYER)
    mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, the_ground_below.OnInput)
end


function the_ground_below:RemoveCallbacks(mod)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnUpdateBackground)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnUpdateHorf)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnUpdateKeeper)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnFlyUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnDukeUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnUpdateCutscenePlayer)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnUpdateBulletPoof)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnTinyFlyUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, the_ground_below.OnGlitchTileUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, the_ground_below.OnProjectileInit)
    mod:RemoveCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, the_ground_below.OnProjectileUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_UPDATE, the_ground_below.OnFrameUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_RENDER, the_ground_below.OnRender)
    mod:RemoveCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, the_ground_below.OnPlayerUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_INIT, the_ground_below.OnEffectInit)
    mod:RemoveCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, the_ground_below.OnPlayerDamage)
    mod:RemoveCallback(ModCallbacks.MC_INPUT_ACTION, the_ground_below.OnInput)
end


function the_ground_below:Init(mod, variables)
    ArcadeCabinetVariables = variables
    the_ground_below:AddCallbacks(mod)

    -- Reset variables
    MinigameTimers.FallingTimer = MinigameConstants.MAX_FALLING_TIMER_FRAMES
    MinigameTimers.IntroScreenTimer = MinigameConstants.MAX_INTRO_TIMER_FRAMES
    MinigameTimers.IFramesTimer = 0
    PlayerHP = 3
    CurrentMinigameState = MinigameState.INTRO
    CurrentWave = 1
    CurrentChapter = 1
    spawnedBgNum = 0
    nextBgChange = -10
    currentBgType = "rocks"

    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    SFXManager:Play(MinigameSounds.INTRO)

    SpawnGlitchTiles()

    --UI
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        HeartsUI:ReplaceSpritesheet(0, "gfx/effects/the ground below/tgb_glitch_hearts.png")
    else
        HeartsUI:ReplaceSpritesheet(0, "gfx/effects/the ground below/tgb_hearts.png")
    end

    HeartsUI:LoadGraphics()

    -- Prepare players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        --Set the spritesheets
        local playerSprite = player:GetSprite()
        playerSprite:Load("gfx/hs_isaac52.anm2", true)
        playerSprite:ReplaceSpritesheet(1, "gfx/characters/isaac_hs.png")
        playerSprite:ReplaceSpritesheet(4, "gfx/characters/isaac_hs.png")
        playerSprite:ReplaceSpritesheet(12, "gfx/characters/isaac_hs.png")
        playerSprite:LoadGraphics()

        player.Position = Vector(player.Position.X, 230)

        player.Visible = false
        player:GetData().FakePlayer = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.PLAYER, 0, player.Position + Vector(0, 1), Vector.Zero, nil)
    end
end


return the_ground_below