local night_light = {}
local game = Game()
local SFXManager = SFXManager()
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
night_light.startingItems = {
    CollectibleType.COLLECTIBLE_ISAACS_HEART,
}
night_light.callbacks = {}
night_light.result = nil

--Sounds
local BannedSounds = {
    SoundEffect.SOUND_TEARS_FIRE,
    SoundEffect.SOUND_BLOODSHOOT,
    SoundEffect.SOUND_MEAT_IMPACTS,
    SoundEffect.SOUND_SUMMON_POOF,
    SoundEffect.SOUND_DOOR_HEAVY_CLOSE,
    SoundEffect.SOUND_DEATH_BURST_SMALL,
    SoundEffect.SOUND_MEATY_DEATHS,
    SoundEffect.SOUND_ANGRY_GURGLE
}

local MinigameSounds = {
    TURN_1 = Isaac.GetSoundIdByName("nl turn 1"),
    TURN_2 = Isaac.GetSoundIdByName("nl turn 2"),
    DUST_DEATH = Isaac.GetSoundIdByName("nl ghost death"),
    ALARM = Isaac.GetSoundIdByName("nl alarm"),
    TRANSITION = Isaac.GetSoundIdByName("nl transition"),
    PLAYER_HIT = Isaac.GetSoundIdByName("bsw player hit"),

    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}

--Entities
local MinigameEntityTypes = {
    CUSTOM_ENEMY = Isaac.GetEntityTypeByName("custom dust NL")
}

local MinigameEntityVariants = {
    FAKE_PLAYER = Isaac.GetEntityVariantByName("fake player NL"),
    CUSTOM_DUST = Isaac.GetEntityVariantByName("custom dust NL"),
    CUSTOM_MORNINGSTAR = Isaac.GetEntityVariantByName("custom morningstar NL"),
    FUCKY = Isaac.GetEntityVariantByName("fucky NL")
}

--States
local CurrentMinigameState = 0
local MinigameState = {
    PLAYING = 0,
    START_CUTSCENCE = 1,
    FINISH_CUTSCENE = 2,
    WAIT_FOR_WINNING = 3,
    LOSING = 4
}

--Timers
local InitialCutsceneTimer = 0
local HourTimer = 0
local WaitForWinTimer = 0
local ConfusionTimer = 0
local FuckySpawnTimer = 0

--UI
local InitialCutsceneScreen = Sprite()
InitialCutsceneScreen:Load("gfx/nl_initial_cutscene.anm2", true)
local FinalCutsceneScreen = Sprite()
FinalCutsceneScreen:Load("gfx/nl_final_cutscene.anm2", true)
local FadeOutScreen = Sprite()
FadeOutScreen:Load("gfx/minigame_transition.anm2", true)
local HeartsUI = Sprite()
HeartsUI:Load("gfx/nl_hearts_ui.anm2", true)
local ClockUI = Sprite()
ClockUI:Load("gfx/nl_clock_ui.anm2", true)
local FuckyWarning = Sprite()
FuckyWarning:Load("gfx/nl_fucky.anm2", true)
local ConfusionEffectOverlay = Sprite()
ConfusionEffectOverlay:Load("gfx/nl_confusion_effect.anm2", true)


--Wave spawning customization
local SecondsPerHour = 12
local GhostsPerWave = {
    16,
    22,
    28,
    28,
    32,
    34
}
local LastSpawnedAxis = 5

local PlayerHP = 0
local IsPlayerConfused = false
local CurrentHour = 0
local FakePlayer = nil
local LightBeam = nil
local MorningStar = nil
local CheatingCounter = 0
local FuckySpawnAxis = 0
local AlarmSoundTimes = 10


function night_light:Init()
    local room = game:GetRoom()

    --Reset stuff
    night_light.result = nil
    CurrentHour = 0
    HourTimer = SecondsPerHour * 30
    FuckySpawnTimer = 0
    InitialCutsceneTimer = 100
    CurrentMinigameState = MinigameState.START_CUTSCENCE
    IsPlayerConfused = false
    PlayerHP = 3
    CheatingCounter = 0
    MorningStar = nil

    --UI
    InitialCutsceneScreen:Play("Idle", true)
    HeartsUI:Play("Idle", true)
    ClockUI:Play("Idle", true)
    ConfusionEffectOverlay:Play("Idle", true)

    --Transition
    SFXManager:Play(MinigameSounds.TRANSITION)

    --Backdrop
    local backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.BackdropVariant, 0, room:GetCenterPos(), Vector.Zero, nil)
    backdrop:GetSprite():Load("gfx/backdrop/nl_backdrop.anm2", true)
    backdrop.DepthOffset = -500

    --Fake player
    FakePlayer = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.FAKE_PLAYER, 0, room:GetCenterPos(), Vector.Zero, nil)
    LightBeam = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.FAKE_PLAYER, 0, room:GetCenterPos(), Vector.Zero, nil)
    LightBeam:GetSprite():Load("gfx/nl_light_beam.anm2", true)
    LightBeam.DepthOffset = -200


    --Prepare players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        player.Position = room:GetCenterPos()
        player.ControlsEnabled = false

        for _, item in ipairs(night_light.startingItems) do
            player:AddCollectible(item, 0, false)
        end

        local playerSprite = player:GetSprite()
        for o = 0, playerSprite:GetLayerCount() - 1, 1 do
            playerSprite:ReplaceSpritesheet(o, "cant find this?? skill issue")
        end
        playerSprite:LoadGraphics()
    end

    for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.ISAACS_HEART, -1)) do
        entity.Position = Vector(-99999999, -99999999)
    end
end


--UPDATE CALLBACKS
local function ManageSFX()
    --Alarm clock
    if CurrentMinigameState == MinigameState.WAIT_FOR_WINNING or CurrentMinigameState == MinigameState.FINISH_CUTSCENE then
        if not SFXManager:IsPlaying(MinigameSounds.ALARM) and AlarmSoundTimes > 0 then
            AlarmSoundTimes = AlarmSoundTimes - 1

            if AlarmSoundTimes == 0 then
                FinalCutsceneScreen:Play("BlinkLoop")
                SFXManager:Play(MinigameSounds.WIN)
            else
                SFXManager:Play(MinigameSounds.ALARM)
            end
        end
    end

    --Completely stop banned sounds
    for _, sound in ipairs(BannedSounds) do
        if SFXManager:IsPlaying(sound) then SFXManager:Stop(sound) end
    end

    --Replace sounds to be changed
    -- for originalSound, replacement in pairs(ReplacementSounds) do
    --     if SFXManager:IsPlaying(originalSound) then
    --         SFXManager:Stop(originalSound)
    --         SFXManager:Play(replacement)
    --     end
    -- end
end


local function UpdateInitialCutscene()
    if InitialCutsceneTimer > 0 then
        InitialCutsceneTimer = InitialCutsceneTimer - 1

        if InitialCutsceneTimer == 2 then
            Options.CameraStyle = 2
        end
    else
        CurrentMinigameState = MinigameState.PLAYING
    end
end


local function ManagePlayerAnimations()
    local isPressingAnything = false

    if IsPlayerConfused then
        if Input.IsActionPressed(ButtonAction.ACTION_LEFT, 0) then
            isPressingAnything = true

            if not FakePlayer:GetSprite():IsPlaying("IdleRight") then
                SFXManager:Play(MinigameSounds.TURN_2)
                CheatingCounter = CheatingCounter + 1
            end

            FakePlayer:GetSprite():Play("IdleRight", true)
            LightBeam:GetSprite():Play("IdleRight", true)

        elseif Input.IsActionPressed(ButtonAction.ACTION_RIGHT, 0) then
            isPressingAnything = true

            if not FakePlayer:GetSprite():IsPlaying("IdleLeft") then
                SFXManager:Play(MinigameSounds.TURN_1)
                CheatingCounter = CheatingCounter + 1
            end

            FakePlayer:GetSprite():Play("IdleLeft", true)
            LightBeam:GetSprite():Play("IdleLeft", true)

        elseif Input.IsActionPressed(ButtonAction.ACTION_UP, 0) then
            isPressingAnything = true

            if not FakePlayer:GetSprite():IsPlaying("IdleDown") then
                SFXManager:Play(MinigameSounds.TURN_1)
                CheatingCounter = CheatingCounter + 1
            end

            FakePlayer:GetSprite():Play("IdleDown", true)
            LightBeam:GetSprite():Play("IdleDown", true)

        elseif Input.IsActionPressed(ButtonAction.ACTION_DOWN, 0) then
            isPressingAnything = true

            if not FakePlayer:GetSprite():IsPlaying("IdleUp") then
                SFXManager:Play(MinigameSounds.TURN_2)
                CheatingCounter = CheatingCounter + 1
            end

            FakePlayer:GetSprite():Play("IdleUp", true)
            LightBeam:GetSprite():Play("IdleUp", true)
        end
    else
        if Input.IsActionPressed(ButtonAction.ACTION_LEFT, 0) then
            isPressingAnything = true

            if not FakePlayer:GetSprite():IsPlaying("IdleLeft") then
                SFXManager:Play(MinigameSounds.TURN_2)
                CheatingCounter = CheatingCounter + 1
            end

            FakePlayer:GetSprite():Play("IdleLeft", true)
            LightBeam:GetSprite():Play("IdleLeft", true)

        elseif Input.IsActionPressed(ButtonAction.ACTION_RIGHT, 0) then
            isPressingAnything = true

            if not FakePlayer:GetSprite():IsPlaying("IdleRight") then
                SFXManager:Play(MinigameSounds.TURN_1)
                CheatingCounter = CheatingCounter + 1
            end

            FakePlayer:GetSprite():Play("IdleRight", true)
            LightBeam:GetSprite():Play("IdleRight", true)

        elseif Input.IsActionPressed(ButtonAction.ACTION_UP, 0) then
            isPressingAnything = true

            if not FakePlayer:GetSprite():IsPlaying("IdleUp") then
                SFXManager:Play(MinigameSounds.TURN_1)
                CheatingCounter = CheatingCounter + 1
            end

            FakePlayer:GetSprite():Play("IdleUp", true)
            LightBeam:GetSprite():Play("IdleUp", true)

        elseif Input.IsActionPressed(ButtonAction.ACTION_DOWN, 0) then
            isPressingAnything = true

            if not FakePlayer:GetSprite():IsPlaying("IdleDown") then
                SFXManager:Play(MinigameSounds.TURN_2)
                CheatingCounter = CheatingCounter + 1
            end

            FakePlayer:GetSprite():Play("IdleDown", true)
            LightBeam:GetSprite():Play("IdleDown", true)
        end
    end

    return isPressingAnything
end


local function ManageMorningStarState(isPressingAnything)
    if not MorningStar then return end

    local targetState = isPressingAnything and 4 or 3

    if targetState ~= MorningStar.State then
        if targetState == 3 then
           MorningStar:GetData().TargetFrame = MorningStar:GetSprite():GetFrame()
           MorningStar:GetSprite():Play("Idle", true)
        else
            MorningStar:GetSprite():Play("Move", true)
            MorningStar:GetSprite():SetFrame(MorningStar:GetData().TargetFrame)
        end
    end

    MorningStar.State = targetState
end


local function ManageInputs()
    local isPressingAnything = ManagePlayerAnimations()

    ManageMorningStarState(isPressingAnything)
end


local function ManageSpawningFucky()
    if FuckySpawnTimer <= 0 then return end

    --Spawn fucky
    if FuckySpawnTimer == 1 then
        local spawningOffset = nil
        local animationToPlay = nil

        if FuckySpawnAxis == 1 then
            spawningOffset = Vector(-500, 0)
            animationToPlay = "MoveRight"
        elseif FuckySpawnAxis == 2 then
            spawningOffset = Vector(500, 0)
            animationToPlay = "MoveLeft"
        elseif FuckySpawnAxis == 3 then
            spawningOffset = Vector(0, 500)
            animationToPlay = "MoveUp"
        else
            spawningOffset = Vector(0, -500)
            animationToPlay = "MoveDown"
        end

        local enemy = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENEMY, MinigameEntityVariants.FUCKY, 0, game:GetRoom():GetCenterPos() + spawningOffset, Vector.Zero, nil)
        enemy:GetSprite():Play(animationToPlay, true)
        enemy.DepthOffset = 100
    end

    FuckySpawnTimer = FuckySpawnTimer - 1
end


local function SpawnGhost(ChosenAxis)
    local room = game:GetRoom()
    local spawningOffset = nil
    local animationToPlay = nil
    local isFlip = false

    --Check if the axis repeats
    if ChosenAxis == LastSpawnedAxis then ChosenAxis = ((ChosenAxis + 1) % 4) + 1 end
    LastSpawnedAxis = ChosenAxis

    --Parse spawning pos
    if ChosenAxis == 1 then
        spawningOffset = Vector(500, 0)
        animationToPlay = "WalkHori"
        isFlip = true
    elseif ChosenAxis == 2 then
        spawningOffset = Vector(-500, 0)
        animationToPlay = "WalkHori"
    elseif ChosenAxis == 3 then
        spawningOffset = Vector(0, 500)
        animationToPlay = "WalkUp"
    else
        spawningOffset = Vector(0, -500)
        animationToPlay = "WalkDown"
    end

    local SpawningPos = room:GetCenterPos() + spawningOffset

    --Acutally spawn the dust
    local enemy = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENEMY, MinigameEntityVariants.CUSTOM_DUST, 0, SpawningPos, Vector.Zero, nil)
    enemy:GetData().TargetVelocity = -spawningOffset:Normalized() * 4
    enemy:GetData().ShouldPlayAnimation = animationToPlay
    enemy.FlipX = isFlip
end


local function SpawnEnemies()
    local chosenAxis = math.random(4)
    SpawnGhost(chosenAxis)
end


local function SpawnMorningStar()
    if MorningStar then return end

    local chosenCorner = math.random(4)
    local cornerPos

    if chosenCorner == 1 then
        cornerPos = Vector(500, 500)
    elseif chosenCorner == 2 then
        cornerPos = Vector(-500, 500)
    elseif chosenCorner == 3 then
        cornerPos = Vector(500, -500)
    else
        cornerPos = Vector(-500, -500)
    end

    cornerPos = game:GetRoom():GetCenterPos() + cornerPos

    MorningStar = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENEMY, MinigameEntityVariants.CUSTOM_MORNINGSTAR, 0, cornerPos, Vector.Zero, nil):ToNPC()
    MorningStar:GetData().TargetFrame = 0
    MorningStar.State = 3
end


local function UpdatePlaying()
    if HourTimer > 0 then
        HourTimer = HourTimer - 1
    else
        HourTimer = SecondsPerHour * 30
        CurrentHour = CurrentHour + 1

        --Spawn fucky
        if CurrentHour ~= 6 then
            SFXManager:Play(MinigameSounds.TRANSITION)
            FuckySpawnTimer = 100
            FuckySpawnAxis = math.random(4)

            local animationToPlay = nil
            if FuckySpawnAxis == 1 then
                animationToPlay = "WarnRight"
            elseif FuckySpawnAxis == 2 then
                animationToPlay = "WarnLeft"
            elseif FuckySpawnAxis == 3 then
                animationToPlay = "WarnDown"
            elseif FuckySpawnAxis == 4 then
                animationToPlay = "WarnUp"
            end

            FuckyWarning:Play(animationToPlay, true)
        end

        --Spawn morning star
        if CurrentHour == 4 or (CheatingCounter > 100 and CurrentHour == 3) then
            SpawnMorningStar()
        elseif CurrentHour == 6 then
            CurrentMinigameState = MinigameState.WAIT_FOR_WINNING
            WaitForWinTimer = 60
            FinalCutsceneScreen:Play("Start", true)
            FakePlayer:GetSprite():Play("IdleDown", true)
            LightBeam:GetSprite():Play("IdleDown", true)
            ClockUI:Play("Flash", true)
            AlarmSoundTimes = 3
            return
        end
    end

    if not FakePlayer:GetSprite():IsPlaying("Hit") then
        if FakePlayer:GetSprite():IsFinished("Hit") then
            FakePlayer:GetSprite():Play(LightBeam:GetSprite():GetAnimation())
        end

        ManageInputs()
    end

    ManageSpawningFucky()

    if ConfusionTimer > 0 then
        ConfusionTimer = ConfusionTimer - 1
    else
        IsPlayerConfused = false
    end

    if HourTimer % (math.floor((SecondsPerHour * 30) / GhostsPerWave[CurrentHour + 1])) == 0 then
        SpawnEnemies()
    end
end


local function UpdateWaitingForWin()
    if WaitForWinTimer > 0 then
        WaitForWinTimer = WaitForWinTimer - 1
    else
        CurrentMinigameState = MinigameState.FINISH_CUTSCENE
    end
end


function night_light:OnFrameUpdate()
    ManageSFX()

    if CurrentMinigameState == MinigameState.START_CUTSCENCE then
        UpdateInitialCutscene()
    elseif CurrentMinigameState == MinigameState.PLAYING then
        UpdatePlaying()
    elseif CurrentMinigameState == MinigameState.WAIT_FOR_WINNING then
        UpdateWaitingForWin()
    end
end
night_light.callbacks[ModCallbacks.MC_POST_UPDATE] = night_light.OnFrameUpdate


local function RenderInitialCutscene()
    if CurrentMinigameState ~= MinigameState.START_CUTSCENCE then return end

    InitialCutsceneScreen:Render(Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight()) / 2, Vector.Zero, Vector.Zero)
end


local function RenderFinalCutscene()
    if CurrentMinigameState ~= MinigameState.FINISH_CUTSCENE then return end

    if FinalCutsceneScreen:IsFinished("Start") then
        FinalCutsceneScreen:Play("ClockLoop")
    end

    if not SFXManager:IsPlaying(MinigameSounds.WIN) and FinalCutsceneScreen:IsPlaying("BlinkLoop") then
        FinalCutsceneScreen:Play("FadeIn")
    end

    if FinalCutsceneScreen:IsFinished("FadeIn") then
        night_light.result = ArcadeCabinetVariables.MinigameResult.WIN
    end

    FinalCutsceneScreen:Render(Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight()) / 2, Vector.Zero, Vector.Zero)
    FinalCutsceneScreen:Update()
end


local function RenderFadeOut()
    if CurrentMinigameState ~= MinigameState.LOSING then return end

    if FadeOutScreen:IsFinished("Appear") then
        night_light.result = ArcadeCabinetVariables.MinigameResult.LOSE
    end

    FadeOutScreen:Render(Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight()) / 2, Vector.Zero, Vector.Zero)
    FadeOutScreen:Update()
end


local function RenderUI()
    local centerPos = Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight()) / 2

    --Hearts
    if HeartsUI:IsPlaying("Flash") then
            HeartsUI:Update()
    else
        HeartsUI:Play("Idle")
        HeartsUI:SetFrame(PlayerHP)
    end

    HeartsUI:Render(centerPos + Vector(-150, -100), Vector.Zero, Vector.Zero)

    --Clock
    if CurrentMinigameState == MinigameState.WAIT_FOR_WINNING then
        ClockUI:Update()
    else
        ClockUI:SetFrame(CurrentHour)
    end
    
    ClockUI:Render(centerPos + Vector(-120, 100), Vector.Zero, Vector.Zero)

end


local function RenderFuckyWarning()
    local pos = Vector(0, 0)
    local anim = FuckyWarning:GetAnimation()

    if anim == "WarnLeft" then
        pos = Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight() / 2)
    elseif anim == "WarnRight" then
        pos = Vector(0, Isaac.GetScreenHeight() / 2)
    elseif anim == "WarnDown" then
        pos = Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight())
    elseif anim == "WarnUp" then
        pos = Vector(Isaac.GetScreenWidth() / 2, 0)
    end
    
    FuckyWarning:Render(pos, Vector.Zero, Vector.Zero)
    FuckyWarning:Update()
end


local function RenderConfusionEffect()
    if not IsPlayerConfused then return end

    local centerPos = Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight()) / 2

    ConfusionEffectOverlay:Render(centerPos, Vector.Zero, Vector.Zero)
    ConfusionEffectOverlay:Update()
end


function night_light:OnRender()
    RenderUI()

    RenderFuckyWarning()

    RenderConfusionEffect()

    RenderInitialCutscene()

    RenderFinalCutscene()

    RenderFadeOut()
end
night_light.callbacks[ModCallbacks.MC_POST_RENDER] = night_light.OnRender


--NPC CALLBACKS
local function ManageDustOverlay(entity)
    entity:GetSprite():PlayOverlay("FadeIn", true)

    --Set frame depending on distance to the player
    local centerPos = game:GetRoom():GetCenterPos()
    local distance = centerPos:Distance(entity.Position)
    local frame = math.ceil(((distance-120)/75) * 10)

    entity:GetSprite():SetOverlayFrame("FadeIn", frame)
end


local function CheckIfDustHit(entity)
    local direction = entity:GetData().TargetVelocity:Normalized()
    local fakeSprite = LightBeam:GetSprite()

    if (direction.X == 1 and fakeSprite:IsPlaying("IdleLeft")) or (direction.X == -1 and fakeSprite:IsPlaying("IdleRight")) or
    (direction.Y == 1 and fakeSprite:IsPlaying("IdleUp")) or (direction.Y == -1 and fakeSprite:IsPlaying("IdleDown")) then
        if entity.Position:Distance(game:GetRoom():GetCenterPos()) < 100 then
            entity:GetSprite():Play("Poof", true)
            SFXManager:Play(MinigameSounds.DUST_DEATH)
            entity:GetSprite():SetOverlayFrame("FadeIn", 0)
            entity.Velocity = Vector.Zero
        end
    end
end


local function UpdateDust(entity)
    if entity:GetSprite():IsFinished("Poof") then
        entity:Remove()
        return
    end

    --If is playing the poof dont move
    if entity:GetSprite():IsPlaying("Poof") then return end

    --Fix for not playing their animation wtf
    if not entity:GetSprite():IsPlaying(entity:GetData().ShouldPlayAnimation) then
        entity:GetSprite():Play(entity:GetData().ShouldPlayAnimation, true)
    end

    --Set speed
    if CurrentMinigameState == MinigameState.PLAYING then
        entity.Velocity = entity:GetData().TargetVelocity
    else
        entity.Velocity = Vector.Zero
    end

    --Make invisible if too far
    if entity.Position:Distance(game:GetRoom():GetCenterPos()) > 200 then
        entity:SetColor(Color(1, 1, 1, 0), 2, 1, false, false)
    end

    ManageDustOverlay(entity)

    CheckIfDustHit(entity)
end


local function ManageMorningStarAnimation(entity)
    if entity.State == 3 then
        entity:GetSprite():SetFrame(entity:GetData().TargetFrame)
    end
end


local function ManageMorningStarVelocity(entity)
    if CurrentMinigameState ~= MinigameState.PLAYING then
        entity.Velocity = Vector.Zero
    elseif entity:ToNPC().State == 4 then
        entity.Velocity = (game:GetRoom():GetCenterPos() - entity.Position):Normalized() * 4.2
    else
        entity.Velocity = (entity.Position - game:GetRoom():GetCenterPos()):Normalized() * 0.6
    end
end


local function UpdateMorningStar(entity)
    ManageMorningStarAnimation(entity)

    ManageMorningStarVelocity(entity)
end


local function CheckIfFuckyHit(entity)
    if entity:GetData().IsDead then return end

    local direction = (game:GetRoom():GetCenterPos() - entity.Position):Normalized()
    local fakeSprite = LightBeam:GetSprite()

    if (direction.X == 1 and fakeSprite:IsPlaying("IdleLeft")) or (direction.X == -1 and fakeSprite:IsPlaying("IdleRight")) or
    (direction.Y == 1 and fakeSprite:IsPlaying("IdleUp")) or (direction.Y == -1 and fakeSprite:IsPlaying("IdleDown")) then
        if entity.Position:Distance(game:GetRoom():GetCenterPos()) < 100 then
            entity:GetSprite():Play("Poof", true)
            entity:GetData().IsDead = true
            SFXManager:Play(MinigameSounds.DUST_DEATH)
        end
    end
end


local function UpdateFucky(entity)
    if entity:GetSprite():IsFinished("Poof") then entity:Remove(); return end

    if entity:GetData().IsDead then
        entity.Velocity = Vector.Zero
    else
        entity.Velocity = (game:GetRoom():GetCenterPos() - entity.Position):Normalized() * 10
    end

    CheckIfFuckyHit(entity)
end


function night_light:OnNPCUpdate(entity)
    if entity.Type ~= MinigameEntityTypes.CUSTOM_ENEMY then return end

    if entity.Variant == MinigameEntityVariants.CUSTOM_DUST then UpdateDust(entity); return end

    if entity.Variant == MinigameEntityVariants.CUSTOM_MORNINGSTAR then UpdateMorningStar(entity); return end

    if entity.Variant == MinigameEntityVariants.FUCKY then UpdateFucky(entity); return end
end
night_light.callbacks[ModCallbacks.MC_NPC_UPDATE] = night_light.OnNPCUpdate


function night_light:OnNPCCollision(entity, collider)
    if entity.Type ~= MinigameEntityTypes.CUSTOM_ENEMY then return end

    --If its not the playing state dont execute the other code
    if CurrentMinigameState ~= MinigameState.PLAYING then return true end

    if collider:ToPlayer() and entity.Variant == MinigameEntityVariants.CUSTOM_DUST and not entity:GetData().IsDead then
        entity:GetData().IsDead = true

        entity:GetSprite():Play("Poof")
        SFXManager:Play(MinigameSounds.DUST_DEATH)
        SFXManager:Play(MinigameSounds.PLAYER_HIT)

        FakePlayer:GetSprite():Play("Hit")
        HeartsUI:Play("Flash", true)
        PlayerHP = PlayerHP - 1
    elseif collider:ToPlayer() and entity.Variant == MinigameEntityVariants.FUCKY and not entity:GetData().IsDead then
        ConfusionTimer = 200
        IsPlayerConfused = true
        SFXManager:Play(MinigameSounds.DUST_DEATH)
        entity:GetSprite():Play("Poof", true)
        entity:GetData().IsDead = true
    elseif collider:ToPlayer() and entity.Variant == MinigameEntityVariants.CUSTOM_MORNINGSTAR then
        FakePlayer:GetSprite():Play("Hit")
        SFXManager:Play(MinigameSounds.PLAYER_HIT)
        HeartsUI:Play("Flash", true)
        PlayerHP = 0
    end

    if PlayerHP == 0 then
        FadeOutScreen:Play("Appear")
        SFXManager:Play(MinigameSounds.LOSE)
        CurrentMinigameState = MinigameState.LOSING
    end

    return true
end
night_light.callbacks[ModCallbacks.MC_PRE_NPC_COLLISION] = night_light.OnNPCCollision


function night_light:OnEntityDamage(tookDamage, _, damageflags, _)
    if tookDamage:ToPlayer() then return end

    if damageflags == DamageFlag.DAMAGE_COUNTDOWN then
        --Negate contact damage (DamageFlag.DAMAGE_COUNTDOWN is damage flag for contact damage)
        return false
    end
end
night_light.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG] = night_light.OnEntityDamage


--OTHER CALLBACKS
function night_light:OnFamiliarUpdate(FamiliarEnt)
    if FamiliarEnt.Variant ~= FamiliarVariant.ISAACS_HEART then return end

    --Move isaac's heart very very far away
    FamiliarEnt.Position = Vector(-99999999, -99999999)
end
night_light.callbacks[ModCallbacks.MC_FAMILIAR_UPDATE] = night_light.OnFamiliarUpdate


function night_light:OnEntitySpawn(entityType, entityVariant, _, _, _, _, seed)
    if entityType == EntityType.ENTITY_EFFECT and 
    (entityVariant == EffectVariant.TINY_FLY or entityVariant == EffectVariant.POOF01) then
        return {EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_SPLAT, 0, seed}
    end
end
night_light.callbacks[ModCallbacks.MC_PRE_ENTITY_SPAWN] = night_light.OnEntitySpawn


function night_light:EffectUpdate(effect)
    if effect.Variant == EffectVariant.TINY_FLY then
        effect:Remove() --They should be removed but just in case
    end
end
night_light.callbacks[ModCallbacks.MC_POST_EFFECT_UPDATE] = night_light.EffectUpdate

return night_light