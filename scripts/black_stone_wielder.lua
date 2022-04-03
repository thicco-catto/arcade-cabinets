local black_stone_wielder = {}
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

black_stone_wielder.callbacks = {}
black_stone_wielder.result = nil
black_stone_wielder.startingItems = {
    CollectibleType.COLLECTIBLE_ISAACS_HEART,
}

--Sounds
local BannedSounds = {
    SoundEffect.SOUND_TEARS_FIRE,
    SoundEffect.SOUND_BLOODSHOOT,
    SoundEffect.SOUND_MEAT_IMPACTS,
    SoundEffect.SOUND_SUMMON_POOF,
    SoundEffect.SOUND_DOOR_HEAVY_CLOSE,
}

local ReplacementSounds = {
    [SoundEffect.SOUND_WHIP] = Isaac.GetSoundIdByName("jc sword swing"),
    [SoundEffect.SOUND_WHIP_HIT] = Isaac.GetSoundIdByName("jc sword swing"),
}

local MinigameSounds = {
    RUNE_PICKUP = Isaac.GetSoundIdByName("bsw rune pickup"),
    NEW_LEVEL = Isaac.GetSoundIdByName("bsw new level"),
    PLAYER_HIT = Isaac.GetSoundIdByName("bsw player hit"),
    WHIP_HIT = Isaac.GetSoundIdByName("bsw whip hit"),
    RUNE_POPPED = Isaac.GetSoundIdByName("bsw rune popped"),
    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}

local MinigameMusic = Isaac.GetMusicIdByName("bsw black beat wielder")

--Entities
local MinigameEntityVariants = {
    RUNE_SHARD = Isaac.GetEntityVariantByName("rune BSW"),
    WHIPPER_DEATH = Isaac.GetEntityVariantByName("whipper death BSW")
}

--Constants
local MinigameConstants = {
    ENEMIES_PER_LEVEL = {
        3,
        3,
        2
    },

    --For the smoke cloud
    HEAD_SPRITESHEETS = {
        "bsw_whipper_head.png",
        "bsw_snapper_head.png",
        "bsw_lunatic_head.png"
    },
    BODY_SPRITESHEETS = {
        "bsw_whipper_body.png",
        "bsw_snapper_body.png",
        "bsw_lunatic_body.png"
    },

    RUNE_ITEM = Isaac.GetItemIdByName("BSW rune"),
    MAX_PLAYER_IFRAMES = 30,
    MAX_RUNE_TIMEOUT_FRAMES = 200,
    MAX_TRANSITION_FRAMES = 100,
    MAX_WAITING_FRAMES = 100
}

--Timer
local MinigameTimers = {
    TransitionTimer = 0,
    WaitingTimer = 0,
    RuneTimeoutTimer = 0,
    IFramesTimer = 0
}

--States
local MinigameState = {
    PLAYING = 1,
    WAITING_FOR_TRANSITION = 2,
    TRANSITION = 3,
    LOSING = 4,
    WINNING = 5
}
local CurrentMinigameState = MinigameState.PLAYING

--UI
local BgUI = Sprite()
BgUI:Load("gfx/bsw_bg_ui.anm2", true)
local RuneUI = Sprite()
RuneUI:Load("gfx/bsw_rune_ui.anm2", true)
local HeartsUI = Sprite()
HeartsUI:Load("gfx/bsw_hearts_ui.anm2", true)
local RuneUse = Sprite()
RuneUse:Load("gfx/bsw_rune_use.anm2", true)
local TransitionScreen = Sprite()
TransitionScreen:Load("gfx/minigame_transition.anm2")

--Other variables
local PlayerHP = 3
local CurrentLevel = 1

--Rune stuff
local PossibleSpawningPositions = {}
local LastRunePosition = nil
local CurrentRune = nil
local RuneCount = 0


local function GetPositionForRune(playerPos)
    local ViableSpawningPositions = {}

    for _, position in ipairs(PossibleSpawningPositions) do
        if playerPos:Distance(position) >= 200 and LastRunePosition:Distance(position) >= 100 then
            ViableSpawningPositions[#ViableSpawningPositions+1] = position
        end
    end

    return ViableSpawningPositions[rng:RandomInt(#ViableSpawningPositions) + 1]
end


local function SpawnRune()
    local position = GetPositionForRune(game:GetPlayer(0).Position)
    LastRunePosition = position
    CurrentRune = Isaac.Spawn(EntityType.ENTITY_PICKUP, MinigameEntityVariants.RUNE_SHARD, 0, position, Vector.Zero, nil)
    CurrentRune:GetSprite():Play("Appear", true)

    MinigameTimers.RuneTimeoutTimer = MinigameConstants.MAX_RUNE_TIMEOUT_FRAMES
end


local function DespawnRune()
    if not CurrentRune then return end

    if MinigameTimers.RuneTimeoutTimer > 0 then
        if MinigameTimers.RuneTimeoutTimer == 60 then
            CurrentRune:GetSprite():Play("Flash", true)
        end

        MinigameTimers.RuneTimeoutTimer = MinigameTimers.RuneTimeoutTimer - 1
        return
    end

    if CurrentRune:GetSprite():IsPlaying("Flash") then
        CurrentRune:GetSprite():Play("Disappear", true)
    elseif CurrentRune:GetSprite():IsFinished("Disappear") then
        CurrentRune:Remove()
        if RuneCount < 3 then SpawnRune() else CurrentRune = nil end
    end
end


local function PrepareTransition()
    MusicManager:Pause()
    MusicManager:Disable()
    SFXManager:Play(MinigameSounds.NEW_LEVEL)

    TransitionScreen:ReplaceSpritesheet(0, "gfx/effects/black stone wielder/transition" .. CurrentLevel .. ".png")
    TransitionScreen:ReplaceSpritesheet(1, "gfx/effects/black stone wielder/transition" .. CurrentLevel .. ".png")
    TransitionScreen:LoadGraphics()

    MinigameTimers.TransitionTimer = MinigameConstants.MAX_TRANSITION_FRAMES
    CurrentMinigameState = MinigameState.TRANSITION

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        player.ControlsEnabled = false
    end
end


local function HitPlayer(player)
    PlayerHP = PlayerHP - 1
    MinigameTimers.IFramesTimer = MinigameConstants.MAX_PLAYER_IFRAMES
    HeartsUI:Play("Flash")
    SFXManager:Play(MinigameSounds.PLAYER_HIT)

    player:PlayExtraAnimation("Hit")

    if PlayerHP == 0 then
        CurrentMinigameState = MinigameState.LOSING
        SFXManager:Play(MinigameSounds.LOSE)
        TransitionScreen:Play("Appear")

        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            game:GetPlayer(i):PlayExtraAnimation("Hit")
            game:GetPlayer(i).ControlsEnabled = false
        end
    end
end


--INIT MINIGAME
function black_stone_wielder:Init()
    --Restart stuff
    black_stone_wielder.result = nil
    LastRunePosition = game:GetPlayer(0).Position
    CurrentLevel = 1
    RuneCount = 0
    CurrentMinigameState = MinigameState.TRANSITION
    PlayerHP = 3

    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    --Reset timers
    for _, timer in pairs(MinigameTimers) do
        timer = 0
    end

    MusicManager:Play(MinigameMusic, 1)
    MusicManager:UpdateVolume()

    --Transition
    PrepareTransition()

    --Posible spawning positions
    local room = game:GetRoom()
    for i = 16, 119, 1 do
        if not room:GetGridEntity(i) or room:GetGridEntity(i):GetType() == GridEntityType.GRID_SPIDERWEB then
            PossibleSpawningPositions[#PossibleSpawningPositions+1] = room:GetGridPosition(i)
        end
    end

    --Prepare players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        for _, item in ipairs(black_stone_wielder.startingItems) do
            player:AddCollectible(item, 0, false)
        end

        --Set the spritesheets
        local playerSprite = player:GetSprite()
        playerSprite:Load("gfx/isaac52.anm2", true)
        playerSprite:ReplaceSpritesheet(1, "gfx/characters/isaac_bsw.png")
        playerSprite:ReplaceSpritesheet(4, "gfx/characters/isaac_bsw.png")
        playerSprite:ReplaceSpritesheet(12, "gfx/characters/isaac_bsw.png")
        playerSprite:LoadGraphics()

        player.Position = Vector(80, 290)

        local costume = Isaac.GetCostumeIdByPath("gfx/costumes/bsw_robes.anm2")
        player:AddNullCostume(costume)
    end

    for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.ISAACS_HEART, -1)) do
        entity.Position = Vector(-99999999, -99999999)
    end
end


--UPDATE CALLBACKS
local function UpdateTransition()
    if MinigameTimers.TransitionTimer > 0 then
        MinigameTimers.TransitionTimer = MinigameTimers.TransitionTimer - 1

        local roomId = 39 + CurrentLevel

        if MinigameTimers.TransitionTimer == 50 and CurrentLevel ~= 1 and roomId ~= game:GetLevel():GetCurrentRoomDesc().Data.Variant then
            Isaac.ExecuteCommand("goto s.isaacs." .. roomId)

        elseif MinigameTimers.TransitionTimer == 49 then
            --Play music again coz game is dumb
            MusicManager:Enable()
            MusicManager:Play(MinigameMusic, 1)
            MusicManager:UpdateVolume()
            MusicManager:Pause()
        elseif MinigameTimers.TransitionTimer == 1 then
            --Backdrop
            local backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop1x1Variant, 0, game:GetRoom():GetCenterPos(), Vector.Zero, nil)
            backdrop:GetSprite():ReplaceSpritesheet(0, "gfx/backdrop/bsw_backdrop" .. CurrentLevel .. ".png")
            backdrop:GetSprite():LoadGraphics()
            backdrop.DepthOffset = -1000

            local numEnemies = MinigameConstants.ENEMIES_PER_LEVEL[CurrentLevel]
            for _ = 1, numEnemies, 1 do
                local room = game:GetRoom()
                local pos = room:FindFreePickupSpawnPosition(room:GetCenterPos(), 0, true)
                Isaac.Spawn(EntityType.ENTITY_WHIPPER, CurrentLevel - 1, 0, pos, Vector.Zero, nil)
            end
        end
    else
        SpawnRune()

        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)

            player.ControlsEnabled = true
        end

        MusicManager:Resume()

        CurrentMinigameState = MinigameState.PLAYING
    end
end


local function CheckUseRune()
    if RuneCount < 3 then return end

    if Input.IsActionPressed(ButtonAction.ACTION_ITEM, 0) or Input.IsActionPressed(ButtonAction.ACTION_PILLCARD, 0) then
        --Remove enemies
        for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_WHIPPER, -1, -1)) do
            entity:Remove()
            local deathEffect = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.WHIPPER_DEATH, 0, entity.Position, Vector.Zero, nil)
            deathEffect:GetSprite():Play("Idle", true)
            deathEffect:GetSprite():ReplaceSpritesheet(1, "gfx/enemies/" .. MinigameConstants.HEAD_SPRITESHEETS[CurrentLevel])
            deathEffect:GetSprite():ReplaceSpritesheet(2, "gfx/enemies/" .. MinigameConstants.BODY_SPRITESHEETS[CurrentLevel])
            deathEffect:GetSprite():LoadGraphics()
        end

        RuneCount = 0
        MinigameTimers.WaitingTimer = MinigameConstants.MAX_WAITING_FRAMES
        CurrentMinigameState = MinigameState.WAITING_FOR_TRANSITION

        SFXManager:Play(MinigameSounds.RUNE_POPPED)

        local UsePlayer = game:GetPlayer(0) --Shitty way of doing it but fuck you
        UsePlayer:PlayExtraAnimation("Pickup")
        UsePlayer.ControlsEnabled = false
        UsePlayer.Velocity = Vector.Zero
    end
end


local function UpdateWaitForTransition()
    for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.WHIPPER_DEATH, -1)) do
        local UsePlayer = game:GetPlayer(0)
        if entity:GetSprite():IsFinished("Idle") then --Why tf is IsFinished not working ?????
            entity:Remove()

            --The skull animation has ended
            UsePlayer.ControlsEnabled = true
            UsePlayer:StopExtraAnimation("Pickup")
        else
            --The skull animation is going
            --if UsePlayer:GetSprite():GetFrame() > 10 then UsePlayer:GetSprite():SetFrame(10) end
            UsePlayer:GetSprite():SetFrame(10)

            UsePlayer.Velocity = Vector.Zero
        end
    end

    if MinigameTimers.WaitingTimer > 0 then
        MinigameTimers.WaitingTimer = MinigameTimers.WaitingTimer - 1
    else

        if CurrentLevel == 3 then
            CurrentMinigameState = MinigameState.WINNING
            SFXManager:Play(MinigameSounds.WIN)
            TransitionScreen:Play("Appear")

            local playerNum = game:GetNumPlayers()
            for i = 0, playerNum - 1, 1 do
                game:GetPlayer(i):PlayExtraAnimation("Happy")
                game:GetPlayer(i):GetSprite():SetFrame(10)
            end
        else
            CurrentLevel = CurrentLevel + 1
            PrepareTransition()
        end
    end
end


local function CheckForEnemyAttack()
    if not SFXManager:IsPlaying(SoundEffect.SOUND_WHIP_HIT) or MinigameTimers.IFramesTimer > 0 or
    CurrentMinigameState ~= MinigameState.PLAYING then return end

    --TODO: Find out who got hit
    --Temporary solution: multiplayer doesnt exist
    HitPlayer(game:GetPlayer(0))
end


local function ManageSFX()
    --Completely stop banned sounds
    for _, sound in ipairs(BannedSounds) do
        if SFXManager:IsPlaying(sound) then SFXManager:Stop(sound) end
    end

    --Replace sounds to be changed
    for originalSound, replacement in pairs(ReplacementSounds) do
        if SFXManager:IsPlaying(originalSound) then
            SFXManager:Stop(originalSound)
            SFXManager:Play(replacement)
        end
    end
end


local function UpdateFinishing()
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        game:GetPlayer(i):GetSprite():SetFrame(6)
    end
end


function black_stone_wielder:OnFrameUpdate()
    CheckForEnemyAttack()

    ManageSFX()

    --Invincibility frames
    if MinigameTimers.IFramesTimer > 0 then MinigameTimers.IFramesTimer = MinigameTimers.IFramesTimer - 1 end

    --Delete colors
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        player:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 300, -1, false, false)
    end

    if CurrentMinigameState == MinigameState.TRANSITION then
        UpdateTransition()
    elseif CurrentMinigameState == MinigameState.PLAYING then
        DespawnRune()
        CheckUseRune()
    elseif CurrentMinigameState == MinigameState.WAITING_FOR_TRANSITION then
        UpdateWaitForTransition()
    elseif CurrentMinigameState == MinigameState.WINNING or CurrentMinigameState == MinigameState.LOSING then
        UpdateFinishing()
    end
end
black_stone_wielder.callbacks[ModCallbacks.MC_POST_UPDATE] = black_stone_wielder.OnFrameUpdate


local function RenderTransition()
    if CurrentMinigameState ~= MinigameState.TRANSITION then return end

    TransitionScreen:Play("Idle", true)
    TransitionScreen:SetFrame(0)
    TransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
end


local function RenderFadeOut()
    if CurrentMinigameState ~= MinigameState.LOSING and CurrentMinigameState ~= MinigameState.WINNING then return end

    if TransitionScreen:IsFinished("Appear") then
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)

            local costume = Isaac.GetCostumeIdByPath("gfx/costumes/bsw_robes.anm2")
            player:TryRemoveNullCostume(costume)
        end

        if CurrentMinigameState == MinigameState.WINNING then
            black_stone_wielder.result = ArcadeCabinetVariables.MinigameResult.WIN
        else
            black_stone_wielder.result = ArcadeCabinetVariables.MinigameResult.LOSE
        end
    end

    if SFXManager:IsPlaying(MinigameSounds.WIN) then
        TransitionScreen:SetFrame(0)
    end

    TransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
    TransitionScreen:Update()
end


local function RenderFloatingRune()
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        if player:GetSprite():IsPlaying("Pickup") then
            RuneUse:Play("Idle")
            RuneUse:Render(Isaac.WorldToScreen(player.Position) - Vector(0, 25), Vector.Zero, Vector.Zero)
        end
    end
end


local function RenderUI()
    --Background
    BgUI:Play("Idle")
    BgUI:SetFrame(CurrentLevel - 1)
    BgUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) - Vector(0, -120), Vector.Zero, Vector.Zero)

    --HeartsUI
    if HeartsUI:IsPlaying("Flash") then
        HeartsUI:Update()
    else
        HeartsUI:Play("Idle")
        HeartsUI:SetFrame(PlayerHP)
    end

    HeartsUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) - Vector(142, -120), Vector.Zero, Vector.Zero)

    --Rune UI
    if not RuneUI:IsPlaying("Idle" .. RuneCount) and not RuneUI:IsPlaying("Flash") then RuneUI:Play("Idle" .. RuneCount) end

    RuneUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) - Vector(-143, -120), Vector.Zero, Vector.Zero)
    RuneUI:Update()
end


function black_stone_wielder:OnRender()
    RenderUI()

    RenderFloatingRune()

    RenderFadeOut()

    RenderTransition()
end
black_stone_wielder.callbacks[ModCallbacks.MC_POST_RENDER] = black_stone_wielder.OnRender


--NPC CALLBACKS
function black_stone_wielder:OnNPCInit(entity)
    if entity.Type ~= EntityType.ENTITY_WHIPPER then return end

    if entity.Variant == 0 then
        entity:GetSprite():Load("gfx/bsw_whipper.anm2", true)
    elseif entity.Variant == 1 then
        entity:GetSprite():Load("gfx/bsw_snapper.anm2", true)
    elseif entity.Variant == 2 then
        entity:GetSprite():Load("gfx/bsw_lunatic.anm2", true)
    end
end
black_stone_wielder.callbacks[ModCallbacks.MC_POST_NPC_INIT] = black_stone_wielder.OnNPCInit


function black_stone_wielder:OnNPCUpdate(entity)
    if entity.Type ~= EntityType.ENTITY_WHIPPER then return end

    local minDistance = 1000000
    local closestPlayer = nil

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        if entity.Position:Distance(player.Position) < minDistance then
            minDistance = entity.Position:Distance(player.Position)
            closestPlayer = player
        end
    end

    --Leave this here just in case
    -- if minDistance > 200 then
    --     entity.Pathfinder:Reset()
    --     entity.Pathfinder:FindGridPath(closestPlayer.Position, 1, 0, false)
    -- end
end
black_stone_wielder.callbacks[ModCallbacks.MC_NPC_UPDATE] = black_stone_wielder.OnNPCUpdate


function black_stone_wielder:OnEntityDamage(tookDamage, _, damageflags, _)
    if tookDamage:ToPlayer() then return end

    if damageflags == DamageFlag.DAMAGE_COUNTDOWN then
        --Negate contact damage (DamageFlag.DAMAGE_COUNTDOWN is damage flag for contact damage)
        return false
    end
end
black_stone_wielder.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG] = black_stone_wielder.OnEntityDamage


function black_stone_wielder:OnEntityCollision(entity, collider)
    if entity.Type == EntityType.ENTITY_GENERIC_PROP then return end

    if CurrentMinigameState == MinigameState.LOSING then
        return true
    else
        if not collider:ToPlayer() or MinigameTimers.IFramesTimer > 0 then return end

        HitPlayer(collider:ToPlayer())
    end
end
black_stone_wielder.callbacks[ModCallbacks.MC_PRE_NPC_COLLISION] = black_stone_wielder.OnEntityCollision


--PICKUP CALLBACKS
function black_stone_wielder:OnPickupCollision(pickup, collider)
    if pickup.Variant == MinigameEntityVariants.RUNE_SHARD and collider:ToPlayer() and CurrentMinigameState == MinigameState.PLAYING then
        if CurrentRune:GetSprite():IsPlaying("Idle") or CurrentRune:GetSprite():IsPlaying("Flash") then
            CurrentRune:GetSprite():Play("Disappear")
            CurrentRune:GetSprite():SetFrame(8)

            SFXManager:Play(MinigameSounds.RUNE_PICKUP)

            --Reset timeout so new rune appears
            MinigameTimers.RuneTimeoutTimer = 0
            RuneCount = RuneCount + 1

            RuneUI:Play("Flash", true)

            --If the player has collected all runes charge actives
            local playerNum = game:GetNumPlayers()
            for i = 0, playerNum - 1, 1 do
                local player = game:GetPlayer(i)
                player:SetActiveCharge(1)
                player:SetActiveCharge(1, ActiveSlot.SLOT_POCKET)
            end
        end

        return true
    end
end
black_stone_wielder.callbacks[ModCallbacks.MC_PRE_PICKUP_COLLISION] = black_stone_wielder.OnPickupCollision


--OTHER CALLBACKS
function black_stone_wielder:OnTear(tear)
    tear:Remove()
end
black_stone_wielder.callbacks[ModCallbacks.MC_POST_TEAR_UPDATE] = black_stone_wielder.OnTear


function black_stone_wielder:OnFamiliarUpdate(FamiliarEnt)
    if FamiliarEnt.Variant ~= FamiliarVariant.ISAACS_HEART then return end

    --Move isaac's heart very very far away
    FamiliarEnt.Position = Vector(-99999999, -99999999)
end
black_stone_wielder.callbacks[ModCallbacks.MC_FAMILIAR_UPDATE] = black_stone_wielder.OnFamiliarUpdate


function black_stone_wielder:OnEntitySpawn(entityType, entityVariant, _, _, _, _, seed)
    if entityType == EntityType.ENTITY_EFFECT and 
    (entityVariant == EffectVariant.TINY_FLY or entityVariant == EffectVariant.POOF01) then
        return {EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_SPLAT, 0, seed}
    end
end
black_stone_wielder.callbacks[ModCallbacks.MC_PRE_ENTITY_SPAWN] = black_stone_wielder.OnEntitySpawn


function black_stone_wielder:EffectUpdate(effect)
    if effect.Variant == EffectVariant.TINY_FLY then
        effect:Remove() --They should be removed but just in case
    end
end
black_stone_wielder.callbacks[ModCallbacks.MC_POST_EFFECT_UPDATE] = black_stone_wielder.EffectUpdate


return black_stone_wielder