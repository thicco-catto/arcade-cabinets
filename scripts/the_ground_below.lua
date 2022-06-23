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
    PLAYER_HIT = Isaac.GetSoundIdByName("bsw player hit"),

    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}

local MinigameMusic = Isaac.GetMusicIdByName("bsw black beat wielder")

-- Entities
local MinigameEntityTypes = {
}

local MinigameEntityVariants = {
    BACKGROUND = Isaac.GetEntityVariantByName("background TGB"),
    PLAYER = Isaac.GetEntityVariantByName("player TGB"),

    HORF = Isaac.GetEntityVariantByName("horf TGB"),
    KEEPER = Isaac.GetEntityVariantByName("keeper TGB"),
    FLY = Isaac.GetEntityVariantByName("fly TGB"),
}

-- Constants
local MinigameConstants = {
    BG_SCROLLING_SPEED = 10,
    BG_SPAWNING_OFFSET = 420,
    BG_TO_SPAWN_THRESHOLD = 560,

    NUM_BG_TO_CHANGE_TO_BRICK = 10,

    --Horfs attack
    HORF_SPAWNING_POS = Vector(550, 540),
    HORF_TARGET_Y = -20,
    HORF_VELOCITY = 2,
    HORF_SHOT_COOLDOWN = 30,
    HORF_SAFE_DISTANCE = 40,

    --Hanging keepers attack
    KEEPER_SPAWNING_POS = Vector(800, 500),
    KEEPER_TARGET_POS = Vector(550, 400),
    KEEPER_VELOCITY = 4,
    NUM_KEEPER_SHOTS = 6,

    --Random flies attack
    FLY_VELOCITY = 4.5,
    FLY_Y_SPAWN = 500,
    FLY_HITBOX_RADIUS = 30,
}

-- Timers
local MinigameTimers = {
}

-- States
local CurrentMinigameState = 0
local MinigameState = {
    INTRO = 1,
    FALLING = 2,
    ATTACK = 3,

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
TransitionScreen:ReplaceSpritesheet(0, "gfx/effects/holy smokes/hs_vs_screen.png")
TransitionScreen:LoadGraphics()

-- Other variables
local PlayerHP = 0
local spawnedBgNum = 0

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

    spawnedBgNum = 2

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

        player.Position = Vector(player.Position.X, 230)

        player.Visible = false
        player:GetData().FakePlayer = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.PLAYER, 0, player.Position + Vector(0, 1), Vector.Zero, nil)
    end
end


local function IsPositionOnScreen(pos)
    pos = Isaac.WorldToScreen(pos)
    return pos.X > 0 and pos.X < Isaac.GetScreenWidth() and
    pos.Y > 0 and pos.Y < Isaac.GetScreenHeight()
end


local function StartHorfAttack()
    Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.HORF, 0, MinigameConstants.HORF_SPAWNING_POS, Vector(0, -MinigameConstants.HORF_VELOCITY), nil)

    local spawningPos2 = Vector(game:GetRoom():GetCenterPos().X - (MinigameConstants.HORF_SPAWNING_POS.X - game:GetRoom():GetCenterPos().X), MinigameConstants.HORF_SPAWNING_POS.Y)
    Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.HORF, 0, spawningPos2, Vector(0, -MinigameConstants.HORF_VELOCITY), nil)
end


local function StartHangingKeeperAttack()
    local targetVelocity = (MinigameConstants.KEEPER_TARGET_POS - MinigameConstants.KEEPER_SPAWNING_POS):Normalized() * MinigameConstants.KEEPER_VELOCITY
    local rightKeeper = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.KEEPER, 0, MinigameConstants.KEEPER_SPAWNING_POS, targetVelocity, nil)
    rightKeeper:GetData().KeeperShotsFired = 0
    rightKeeper:GetData().SpawningPos = MinigameConstants.KEEPER_SPAWNING_POS

    local spawningPos2 = Vector(game:GetRoom():GetCenterPos().X - (MinigameConstants.KEEPER_SPAWNING_POS.X - game:GetRoom():GetCenterPos().X), MinigameConstants.KEEPER_SPAWNING_POS.Y)
    local targetPos2 = Vector(game:GetRoom():GetCenterPos().X - (MinigameConstants.KEEPER_TARGET_POS.X - game:GetRoom():GetCenterPos().X), MinigameConstants.KEEPER_TARGET_POS.Y)
    local targetVelocity2 = (targetPos2 - spawningPos2):Normalized() * MinigameConstants.KEEPER_VELOCITY
    local leftKeeper = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.KEEPER, 0, spawningPos2, targetVelocity2, nil)
    leftKeeper:GetData().KeeperShotsFired = 0
    leftKeeper:GetData().SpawningPos = spawningPos2
end


local function StartRandomFlyAttack()
    local room = game:GetRoom()

    local freeGridLocation = 47 + rng:RandomInt(10)

    for i = 46, 58, 1 do
        if i ~= freeGridLocation then
            local randomOffset = RandomVector() * Vector(2, 3.2)
            local spawningPos = Vector(room:GetGridPosition(i).X, MinigameConstants.FLY_Y_SPAWN) + randomOffset
            Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.FLY, 0, spawningPos, Vector(0, -MinigameConstants.FLY_VELOCITY), nil)
        end
    end
end


local function ChangeBgSprite(bg)
    --Default is rocks mid, so nil for that
    local newSprite = nil

    if spawnedBgNum == MinigameConstants.NUM_BG_TO_CHANGE_TO_BRICK then
        newSprite = "gfx/grid/tgb_rocks_end.png"
    elseif spawnedBgNum == MinigameConstants.NUM_BG_TO_CHANGE_TO_BRICK + 1 then
        newSprite = "gfx/grid/tgb_pitch_black.png"
    elseif spawnedBgNum == MinigameConstants.NUM_BG_TO_CHANGE_TO_BRICK + 2 then
        newSprite = "gfx/grid/tgb_bricks_start.png"
    elseif spawnedBgNum > MinigameConstants.NUM_BG_TO_CHANGE_TO_BRICK + 2 then
        newSprite = "gfx/grid/tgb_bricks_mid.png"
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


local function UpdateBackground(effect)
    effect.Velocity = Vector(0, -MinigameConstants.BG_SCROLLING_SPEED)

    if effect.Position.Y < (game:GetRoom():GetCenterPos() - Vector(0, MinigameConstants.BG_TO_SPAWN_THRESHOLD)).Y then
        SpawnNextBg(effect)
        effect:Remove()
    end
end


local function UpdateHorf(effect)
    if effect:IsFrame(MinigameConstants.HORF_SHOT_COOLDOWN, 0) and
    math.abs(effect.Position.Y - Isaac.GetPlayer(0).Position.Y) > MinigameConstants.HORF_SAFE_DISTANCE and
    IsPositionOnScreen(effect.Position) then
        effect:GetSprite():Play("Shoot", true)
    end

    if effect:GetSprite():IsEventTriggered("Shoot") then
        local dummy = Isaac.Spawn(997, 10, 0, effect.Position + Vector(0, 0.1), Vector.Zero, nil)
        local spawningPos = dummy.Position + Vector(0, 25)
        local spawningSpeed = (game:GetPlayer(0).Position - spawningPos):Normalized() * 10
        local params = ProjectileParams()
        params.BulletFlags = ProjectileFlags.NO_WALL_COLLIDE
        params.Spread = 1
        dummy:ToNPC():FireProjectiles(spawningPos, spawningSpeed, 0, params)
        dummy:Remove()
    end

    if effect:GetSprite():IsFinished("Shoot") then
        effect:GetSprite():Play("Idle")
    end

    if effect.Position.Y < MinigameConstants.HORF_TARGET_Y then
        effect:Remove()
    end
end


local function UpdateKeeper(effect)
    if effect.Velocity:Length() < 0.1 and effect:IsFrame(40, 0) then
        effect:GetData().KeeperShotsFired = effect:GetData().KeeperShotsFired + 1

        if effect:GetData().KeeperShotsFired == MinigameConstants.NUM_KEEPER_SHOTS then
            effect.Velocity = (effect:GetData().SpawningPos - effect.Position):Normalized() * MinigameConstants.KEEPER_VELOCITY
        else
            effect:GetSprite():Play("Shoot", true)
        end
    end

    if effect:GetSprite():IsEventTriggered("Shoot") then
        local dummy = Isaac.Spawn(997, 10, 0, effect.Position + Vector(0, 0.1), Vector.Zero, nil)
        local spawningPos = dummy.Position + Vector(0, 25)
        local spawningSpeed = (game:GetPlayer(0).Position - spawningPos):Normalized() * 10
        local params = ProjectileParams()
        params.BulletFlags = ProjectileFlags.NO_WALL_COLLIDE
        params.Spread = 1
        dummy:ToNPC():FireProjectiles(spawningPos, spawningSpeed, 2, params)
        dummy:Remove()
    end

    if effect:GetSprite():IsFinished("Shoot") then
        effect:GetSprite():Play("Idle")
    end

    if effect.Position.Y < MinigameConstants.KEEPER_TARGET_POS.Y and effect:GetData().KeeperShotsFired == 0 then
        effect.Velocity = Vector.Zero
    end

    if effect.Position.Y > effect:GetData().SpawningPos.Y then
        effect:Remove()
    end
end


local function UpdateFly(effect)
    if effect.Position.Y < 0 then
        effect:Remove()
    end

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        if player.Position:Distance(effect.Position) < MinigameConstants.FLY_HITBOX_RADIUS then
            SFXManager:Play(MinigameSounds.PLAYER_HIT)
        end
    end
end


function the_ground_below:OnEffectUpdate(effect)
    if effect.Variant == MinigameEntityVariants.BACKGROUND then
        UpdateBackground(effect)
    elseif effect.Variant == MinigameEntityVariants.HORF then
        UpdateHorf(effect)
    elseif effect.Variant == MinigameEntityVariants.KEEPER then
        UpdateKeeper(effect)
    elseif effect.Variant == MinigameEntityVariants.FLY then
        UpdateFly(effect)
    end
end
the_ground_below.callbacks[ModCallbacks.MC_POST_EFFECT_UPDATE] = the_ground_below.OnEffectUpdate


function the_ground_below:OnProjectileInit(projectile)
    projectile:GetSprite():Load("gfx/hs_satan_projectile.anm2", true)
    projectile:GetSprite():Play("Idle", true)
end
the_ground_below.callbacks[ModCallbacks.MC_POST_PROJECTILE_INIT] = the_ground_below.OnProjectileInit


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
the_ground_below.callbacks[ModCallbacks.MC_POST_PROJECTILE_UPDATE] = the_ground_below.OnProjectileUpdate


function the_ground_below:OnRender()
    -- RenderUI()

    -- RenderWaveTransition()

    -- RenderFadeOut()

    --Isaac.RenderText(spawnedBgNum, 50, 50, 1, 1, 1, 255)

    for _, eff in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, MinigameEntityVariants.HORF)) do
        local pos = Isaac.WorldToScreen(eff.Position)
        local str = "false"
        if IsPositionOnScreen(eff.Position) then str = "true" end
        Isaac.RenderText(str, pos.X, 100, 1, 1, 1, 255)
    end
end
the_ground_below.callbacks[ModCallbacks.MC_POST_RENDER] = the_ground_below.OnRender


function the_ground_below:OnPlayerUpdate(player)
    player:GetData().FakePlayer.Position = player.Position + Vector(0, 1)
end
the_ground_below.callbacks[ModCallbacks.MC_POST_PLAYER_UPDATE] = the_ground_below.OnPlayerUpdate


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
the_ground_below.callbacks[ModCallbacks.MC_INPUT_ACTION] = the_ground_below.OnInput


function the_ground_below:OnCMD(command, args)
    if command == "vel" then
        print("bg velocity changed")
        MinigameConstants.BG_SCROLLING_SPEED = tonumber(args)
    elseif command == "att" then
        print("Attack set to " .. args)
		CurrentAttack = tonumber(args)
        CurrentMinigameState = MinigameState.ATTACK

        if CurrentAttack == MinigameAttack.HORFS then
            StartHorfAttack()
        elseif CurrentAttack == MinigameAttack.HANGING_KEEPERS then
            StartHangingKeeperAttack()
        elseif CurrentAttack == MinigameAttack.FLIES then
            StartRandomFlyAttack()
        end
    end

end
the_ground_below.callbacks[ModCallbacks.MC_EXECUTE_CMD] = the_ground_below.OnCMD

return the_ground_below