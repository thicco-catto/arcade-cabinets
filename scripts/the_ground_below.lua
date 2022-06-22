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
    BACKGROUND = Isaac.GetEntityVariantByName("background TGB"),

    KEEPER = Isaac.GetEntityVariantByName("keeper TGB")
}

-- Constants
local MinigameConstants = {
    BG_SCROLLING_SPEED = 10,
    BG_SPAWNING_OFFSET = 420,
    BG_TO_SPAWN_THRESHOLD = 560,

    NUM_BG_TO_CHANGE_TO_BRICK = 10,

    --Hanging keepers attack
    KEEPER_SPAWNING_POS = Vector(800, 500),
    KEEPER_TARGET_POS = Vector(550, 400),
    KEEPER_VELOCITY = 4,
    NUM_KEEPER_SHOTS = 10,
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

        player.Position = Vector(player.Position.X, 300)
    end
end


local function StartHangingKeeperAttack()
    local targetVelocity = (MinigameConstants.KEEPER_TARGET_POS - MinigameConstants.KEEPER_SPAWNING_POS):Normalized() * MinigameConstants.KEEPER_VELOCITY
    local rightKeeper = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.KEEPER, 0, MinigameConstants.KEEPER_SPAWNING_POS, targetVelocity, nil)
    rightKeeper:GetData().KeeperShotsFired = 0
    rightKeeper:GetData().SpawningPos = MinigameConstants.KEEPER_SPAWNING_POS

    local spawningPos2 = Vector(game:GetRoom():GetCenterPos().X - (MinigameConstants.KEEPER_SPAWNING_POS.X - game:GetRoom():GetCenterPos().X), MinigameConstants.KEEPER_SPAWNING_POS.Y)
    local targetPos2 = Vector(game:GetRoom():GetCenterPos().X - (MinigameConstants.KEEPER_TARGET_POS.X - game:GetRoom():GetCenterPos().X), MinigameConstants.KEEPER_TARGET_POS.Y)
    targetVelocity = (targetPos2 - spawningPos2):Normalized() * MinigameConstants.KEEPER_VELOCITY
    local leftKeeper = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.KEEPER, 0, spawningPos2, targetVelocity, nil)
    leftKeeper:GetData().KeeperShotsFired = 0
    leftKeeper:GetData().SpawningPos = spawningPos2
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


function the_ground_below:OnEffectUpdate(effect)
    if effect.Variant == MinigameEntityVariants.BACKGROUND then 
        UpdateBackground(effect)
    elseif effect.Variant == MinigameEntityVariants.KEEPER then
        UpdateKeeper(effect)
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

    local screenPos = Isaac.WorldToScreen(projectile.Position)
    if (screenPos.X < 0 or screenPos.X > Isaac.GetScreenWidth()) and
    (screenPos.Y < 0 or screenPos.Y > Isaac.GetScreenHeight()) then
        projectile:Remove()
    end
end
the_ground_below.callbacks[ModCallbacks.MC_POST_PROJECTILE_UPDATE] = the_ground_below.OnProjectileUpdate


function the_ground_below:OnRender()
    -- RenderUI()

    -- RenderWaveTransition()

    -- RenderFadeOut()

    Isaac.RenderText(spawnedBgNum, 50, 50, 1, 1, 1, 255)
end
the_ground_below.callbacks[ModCallbacks.MC_POST_RENDER] = the_ground_below.OnRender

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

        if CurrentAttack == MinigameAttack.HANGING_KEEPERS then
            StartHangingKeeperAttack()
        end
    end

end
the_ground_below.callbacks[ModCallbacks.MC_EXECUTE_CMD] = the_ground_below.OnCMD

return the_ground_below