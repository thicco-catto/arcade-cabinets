local black_stone_wielder = {}
local game = Game()
local rng = RNG()
local SFXManager = SFXManager()
local MusicManager = MusicManager()
local ArcadeCabinetVariables

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
    WHIPPER_DEATH = Isaac.GetEntityVariantByName("whipper death BSW"),

    GLITCH_TILE = Isaac.GetEntityVariantByName("glitch tile BSW")
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
    MAX_TRANSITION_FRAMES = 70,
    MAX_WAITING_FRAMES = 100,

    --Glitch stuff
    GLITCHED_HEAD_SPRITESHEETS = {
        "bsw_glitch_whipper_head.png",
        "bsw_glitch_snapper_head.png",
        "bsw_glitch_lunatic_head.png"
    },
    GLITCHED_BODY_SPRITESHEETS = {
        "bsw_glitch_whipper_body.png",
        "bsw_glitch_snapper_body.png",
        "bsw_glitch_lunatic_body.png"
    },
    GLITCHED_CHANCE_OF_SHY_RUNE = 50,
    GLITCHED_DISTANCE_FOR_SHY_RUNE = 120,

    GLITCH_NUM_GLITCH_TILES = 20,
    GLITCH_TILE_FRAME_NUM = 9,
    GLITCH_TILE_CHANGE_FRAMES = 10,
    GLITCH_TILE_CHANGING_CHANCE = 10,
}

--Timers
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
TransitionScreen:Load("gfx/minigame_transition.anm2", true)

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


local function SpawnRune(wasShy)
    local position = GetPositionForRune(game:GetPlayer(0).Position)
    LastRunePosition = position
    CurrentRune = Isaac.Spawn(EntityType.ENTITY_PICKUP, MinigameEntityVariants.RUNE_SHARD, 0, position, Vector.Zero, nil)
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        CurrentRune:GetSprite():Load("gfx/bsw_glitch_rune.anm2", true)
    end
    CurrentRune:GetSprite():Play("Appear", true)

    CurrentRune:GetData().IsShyRune = ArcadeCabinetVariables.IsCurrentMinigameGlitched and
    MinigameConstants.GLITCHED_CHANCE_OF_SHY_RUNE >= rng:RandomInt(100) and not wasShy

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
        local wasShy = CurrentRune:GetData().WasShyRune
        CurrentRune:Remove()
        if RuneCount < 3 then SpawnRune(wasShy) else CurrentRune = nil end
    end
end


local function PrepareTransition()
    MusicManager:Pause()
    MusicManager:Disable()
    SFXManager:Play(MinigameSounds.NEW_LEVEL)

    local transitionSprite = "gfx/effects/black stone wielder/bsw_transition" .. CurrentLevel .. ".png"

    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        transitionSprite = "gfx/effects/black stone wielder/bsw_glitch_transition.png"
    end

    TransitionScreen:ReplaceSpritesheet(0, transitionSprite)
    TransitionScreen:ReplaceSpritesheet(1, transitionSprite)
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


local function SpawnGlitchTiles()
    if not ArcadeCabinetVariables.IsCurrentMinigameGlitched then return end
    local room = game:GetRoom()

    local possibleGlitchTiles = {}
    for i = 0, 134, 1 do
        table.insert(possibleGlitchTiles, i)
    end

    for _ = 1, MinigameConstants.GLITCH_NUM_GLITCH_TILES, 1 do
        local chosen = rng:RandomInt(#possibleGlitchTiles) + 1
        local gridIndex = possibleGlitchTiles[chosen]
        table.remove(possibleGlitchTiles, chosen)

        local gridEntity = room:GetGridEntity(gridIndex)
        local isPillar = gridEntity and gridEntity:GetType() == GridEntityType.GRID_ROCK_ALT

        local glitchTile = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.GLITCH_TILE, 0, room:GetGridPosition(gridIndex), Vector.Zero, nil)

        if isPillar then
            glitchTile:GetSprite():Play("Pillar", true)
            glitchTile:GetData().ChosenFrame = 0
        else
            glitchTile:GetSprite():Play("Idle", true)
            glitchTile:GetData().ChosenFrame = rng:RandomInt(MinigameConstants.GLITCH_TILE_FRAME_NUM)
            glitchTile:GetSprite():SetFrame(glitchTile:GetData().ChosenFrame)
        end

        glitchTile:GetData().ChagingTile = rng:RandomInt(100) < MinigameConstants.GLITCH_TILE_CHANGING_CHANCE and not isPillar
        glitchTile:GetData().RandomOffset = rng:RandomInt(MinigameConstants.GLITCH_TILE_CHANGE_FRAMES)
        glitchTile.DepthOffset = -200
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
            local isGlitchBackdrop = ""
            if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
                isGlitchBackdrop = "glitched_"
            end
            backdrop:GetSprite():ReplaceSpritesheet(0, "gfx/backdrop/" .. isGlitchBackdrop .. "bsw_backdrop" .. CurrentLevel .. ".png")
            backdrop:GetSprite():LoadGraphics()
            backdrop.DepthOffset = -3000

            SpawnGlitchTiles()

            local numEnemies = MinigameConstants.ENEMIES_PER_LEVEL[CurrentLevel]
            for _ = 1, numEnemies, 1 do
                local room = game:GetRoom()
                local pos = room:FindFreePickupSpawnPosition(room:GetCenterPos(), 0, true)
                local whipper = Isaac.Spawn(EntityType.ENTITY_WHIPPER, CurrentLevel - 1, 0, pos, Vector.Zero, nil)
                whipper:ClearEntityFlags(EntityFlag.FLAG_APPEAR)

                if CurrentLevel == 3 then
                    whipper = whipper:ToNPC()
                    whipper:MakeChampion(whipper.InitSeed, ChampionColor.BLUE)
                    whipper:SetColor(Color(1, 1, 1), 10, -10, false, true)
                    whipper.SpriteScale = Vector.One
                end
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
            local deathEffect = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.WHIPPER_DEATH, 0, entity.Position, Vector.Zero, nil)
            if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
                deathEffect:GetSprite():Load("gfx/bsw_glitch_whipper_death.anm2", true)
                deathEffect:GetSprite():ReplaceSpritesheet(1, "gfx/enemies/" .. MinigameConstants.GLITCHED_HEAD_SPRITESHEETS[CurrentLevel])
                deathEffect:GetSprite():ReplaceSpritesheet(2, "gfx/enemies/" .. MinigameConstants.GLITCHED_BODY_SPRITESHEETS[CurrentLevel])
            else
                deathEffect:GetSprite():ReplaceSpritesheet(1, "gfx/enemies/" .. MinigameConstants.HEAD_SPRITESHEETS[CurrentLevel])
                deathEffect:GetSprite():ReplaceSpritesheet(2, "gfx/enemies/" .. MinigameConstants.BODY_SPRITESHEETS[CurrentLevel])
            end
            deathEffect:GetSprite():LoadGraphics()
            deathEffect:GetSprite():Play("Idle", true)
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

            for _, entity in ipairs(Isaac.GetRoomEntities()) do
                if entity:IsVulnerableEnemy() then
                    entity:Remove()
                end
            end
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


--NPC CALLBACKS
function black_stone_wielder:OnNPCInit(entity)
    if entity.Variant == 0 then
        entity:GetSprite():Load("gfx/bsw_whipper.anm2", false)

        if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
            entity:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/bsw_glitch_whipper_body.png")
            entity:GetSprite():ReplaceSpritesheet(1, "gfx/enemies/bsw_glitch_whipper_head.png")
            entity:GetSprite():ReplaceSpritesheet(2, "gfx/enemies/bsw_glitch_whipper_body.png")
        end

        entity:GetSprite():LoadGraphics()
    elseif entity.Variant == 1 then
        entity:GetSprite():Load("gfx/bsw_snapper.anm2", false)

        if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
            entity:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/bsw_glitch_snapper_body.png")
            entity:GetSprite():ReplaceSpritesheet(1, "gfx/enemies/bsw_glitch_snapper_head.png")
            entity:GetSprite():ReplaceSpritesheet(2, "gfx/enemies/bsw_glitch_snapper_body.png")
        end

        entity:GetSprite():LoadGraphics()
    elseif entity.Variant == 2 then
        entity:GetSprite():Load("gfx/bsw_lunatic.anm2", false)

        if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
            entity:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/bsw_glitch_lunatic_body.png")
            entity:GetSprite():ReplaceSpritesheet(1, "gfx/enemies/bsw_glitch_lunatic_head.png")
            entity:GetSprite():ReplaceSpritesheet(2, "gfx/enemies/bsw_glitch_lunatic_body.png")
        end

        entity:GetSprite():LoadGraphics()
    end
end


---@param entity EntityNPC
function black_stone_wielder:OnNPCUpdate(entity)
    if entity.Variant == 2 then
        entity:SetColor(Color(1, 1, 1), 10, -10, false, true)
        entity.Scale = 1
    end
end


function black_stone_wielder:OnPlayerDamage(player)
    if MinigameTimers.IFramesTimer <= 0 then
        HitPlayer(player:ToPlayer())
    end
    return false
end


function black_stone_wielder:OnEntityCollision()
    if CurrentMinigameState == MinigameState.LOSING then
        return true
    end
end


--PICKUP CALLBACKS
function black_stone_wielder:OnPickupUpdate(pickup)
    if not pickup:GetData().IsShyRune or pickup:GetSprite():IsPlaying("Disappear") then return end

    for i = 0, game:GetNumPlayers(), 1 do
        local player = game:GetPlayer(i)
        if (player.Position - pickup.Position):Length() < MinigameConstants.GLITCHED_DISTANCE_FOR_SHY_RUNE then
            MinigameTimers.RuneTimeoutTimer = 0
            pickup:GetSprite():Play("Disappear", true)
            pickup:GetData().IsShyRune = false
            pickup:GetData().WasShyRune = true
            break
        end
    end
end


function black_stone_wielder:OnPickupCollision(_, collider)
    if not collider:ToPlayer() or CurrentMinigameState ~= MinigameState.PLAYING then return end

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


--OTHER CALLBACKS
function black_stone_wielder:OnTearUpdate(tear)
    tear:Remove()
end


function black_stone_wielder:OnEntitySpawn(entityType, entityVariant, _, _, _, _, seed)
    if entityType == EntityType.ENTITY_EFFECT and 
    (entityVariant == EffectVariant.TINY_FLY or entityVariant == EffectVariant.POOF01) then
        return {EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_SPLAT, 0, seed}
    end
end


function black_stone_wielder:OnTinyFlyUpdate(effect)
    effect:Remove() --They should be removed but just in case
end


---@param effect EntityEffect
function black_stone_wielder:OnWhipperDeathUpdate(effect)
    --Only player 1 can use the rune
    local UsePlayer = game:GetPlayer(0)

    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        if effect:GetSprite():IsFinished("Idle") then
            effect:GetSprite():Play("Loop", true)
        end

        if MinigameState ~= MinigameState.WINNING then
            UsePlayer:GetSprite():SetFrame(10)
            UsePlayer.Velocity = Vector.Zero
        end
    else
        if effect:GetSprite():IsFinished("Idle") then
            effect:Remove()

            --The skull animation has ended
            UsePlayer.ControlsEnabled = true
            UsePlayer:StopExtraAnimation("Pickup")
        else
            --The skull animation is going
            UsePlayer:GetSprite():SetFrame(10)
            UsePlayer.Velocity = Vector.Zero
        end
    end
end


---@param tile EntityEffect
function black_stone_wielder:OnGlitchTileUpdate(tile)
    local data = tile:GetData()
    if (game:GetFrameCount() + data.RandomOffset) % MinigameConstants.GLITCH_TILE_CHANGE_FRAMES == 0 and data.ChagingTile then
        local maxFrames = MinigameConstants.GLITCH_TILE_FRAME_NUM
        local newFrame = rng:RandomInt(maxFrames - 1)
        if newFrame >= data.ChosenFrame then
            newFrame = newFrame + 1
        end
        data.ChosenFrame = newFrame
    end

    tile:GetSprite():SetFrame(data.ChosenFrame)
end


--INIT MINIGAME
function black_stone_wielder:AddCallbacks(mod)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, black_stone_wielder.OnFrameUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, black_stone_wielder.OnRender)
    mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, black_stone_wielder.OnNPCInit, EntityType.ENTITY_WHIPPER)
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, black_stone_wielder.OnNPCUpdate, EntityType.ENTITY_WHIPPER)
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, black_stone_wielder.OnPlayerDamage, EntityType.ENTITY_PLAYER)
    mod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, black_stone_wielder.OnEntityCollision)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, black_stone_wielder.OnPickupUpdate, MinigameEntityVariants.RUNE_SHARD)
    mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, black_stone_wielder.OnPickupCollision, MinigameEntityVariants.RUNE_SHARD)
    mod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, black_stone_wielder.OnTearUpdate)
    mod:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, black_stone_wielder.OnEntitySpawn)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, black_stone_wielder.OnTinyFlyUpdate, EffectVariant.TINY_FLY)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, black_stone_wielder.OnWhipperDeathUpdate, MinigameEntityVariants.WHIPPER_DEATH)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, black_stone_wielder.OnGlitchTileUpdate, MinigameEntityVariants.GLITCH_TILE)
end


function black_stone_wielder:RemoveCallbacks(mod)
    mod:RemoveCallback(ModCallbacks.MC_POST_UPDATE, black_stone_wielder.OnFrameUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_RENDER, black_stone_wielder.OnRender)
    mod:RemoveCallback(ModCallbacks.MC_POST_NPC_INIT, black_stone_wielder.OnNPCInit)
    mod:RemoveCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, black_stone_wielder.OnPlayerDamage)
    mod:RemoveCallback(ModCallbacks.MC_PRE_NPC_COLLISION, black_stone_wielder.OnEntityCollision)
    mod:RemoveCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, black_stone_wielder.OnPickupCollision)
    mod:RemoveCallback(ModCallbacks.MC_POST_TEAR_UPDATE, black_stone_wielder.OnTearUpdate)
    mod:RemoveCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, black_stone_wielder.OnEntitySpawn)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, black_stone_wielder.OnTinyFlyUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, black_stone_wielder.OnWhipperDeathUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, black_stone_wielder.OnGlitchTileUpdate)
end


function black_stone_wielder:Init(mod, variables)
    ArcadeCabinetVariables = variables
    black_stone_wielder:AddCallbacks(mod)

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

    --UI
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        BgUI:ReplaceSpritesheet(0, "gfx/effects/black stone wielder/bsw_glitch_ui_bg.png")
        BgUI:ReplaceSpritesheet(1, "gfx/effects/black stone wielder/bsw_glitch_level_ui.png")
        BgUI:ReplaceSpritesheet(2, "gfx/effects/black stone wielder/bsw_glitch_level_ui.png")

        RuneUI:ReplaceSpritesheet(0, "gfx/effects/black stone wielder/bsw_glitch_rune_ui.png")
        HeartsUI:ReplaceSpritesheet(0, "gfx/effects/black stone wielder/bsw_glitch_hearts_ui.png")
    else
        BgUI:ReplaceSpritesheet(0, "gfx/effects/black stone wielder/bsw_ui_bg.png")
        BgUI:ReplaceSpritesheet(1, "gfx/effects/black stone wielder/bsw_level_ui.png")
        BgUI:ReplaceSpritesheet(2, "gfx/effects/black stone wielder/bsw_level_ui.png")

        RuneUI:ReplaceSpritesheet(0, "gfx/effects/black stone wielder/bsw_rune_ui.png")
        HeartsUI:ReplaceSpritesheet(0, "gfx/effects/black stone wielder/bsw_hearts_ui.png")
    end
    BgUI:LoadGraphics()
    RuneUI:LoadGraphics()
    HeartsUI:LoadGraphics()


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
end


return black_stone_wielder