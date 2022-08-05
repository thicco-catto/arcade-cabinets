local night_light = {}
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

local MinigameMusic = Isaac.GetMusicIdByName("bsw black beat wielder")

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

--Constants
local MinigameConstants = {
    --Wave control
    MAX_HOURS = 6,
    SECONDS_PER_HOUR = 12,
    GHOSTS_PER_HOUR = {
        16,
        22,
        28,
        28,
        32,
        34
    },

    --Timer stuff
    INTIAL_CUTSCENE_MAX_FRAMES = 100,
    WAIT_FOR_WIN_MAX_FRAMES = 60,
    CONFUSION_MAX_FRAMES = 200,
    FUCKY_SPAWN_MAX_TIMER = 100,

    --Entities stuff
    DUST_SPEED = 4,
    FUCKY_SPEED = 10,
    MORNINGSTAR_CHASE_SPEED = 4.2,
    MORNINGSTAR_RETREAT_SPEED = 1.2,

    MAX_CHEATING_COUNTER = 100,

    --GLITCH_STUFF
    GLITCH_MORNING_STAR_CLOSE_SPAWN = 0.4
}

--Timers
local MinigameTimers = {
    InitialCutsceneTimer = 0,
    HourTimer = 0,
    WaitForWinTimer = 0,
    ConfusionTimer = 0,
    FuckySpawnTimer = 0
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
FuckyWarning:Load("gfx/nl_fucky_warning.anm2", true)
local ConfusionEffectOverlay = Sprite()
ConfusionEffectOverlay:Load("gfx/nl_confusion_effect.anm2", true)


--Wave spawning customization
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
    if MinigameTimers.InitialCutsceneTimer > 0 then
        MinigameTimers.InitialCutsceneTimer = MinigameTimers.InitialCutsceneTimer - 1

        if MinigameTimers.InitialCutsceneTimer == 2 then
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
    if MinigameTimers.FuckySpawnTimer <= 0 then return end

    --Spawn fucky
    if MinigameTimers.FuckySpawnTimer == 1 then
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

        if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
            enemy:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/nl_glitch_fucky.png")
            enemy:GetSprite():ReplaceSpritesheet(1, "gfx/enemies/nl_glitch_dust.png")
            enemy:GetSprite():LoadGraphics()
        end
    end

    MinigameTimers.FuckySpawnTimer = MinigameTimers.FuckySpawnTimer - 1
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
    enemy:GetData().TargetVelocity = -spawningOffset:Normalized() * MinigameConstants.DUST_SPEED
    enemy:GetData().ShouldPlayAnimation = animationToPlay
    enemy.FlipX = isFlip
    enemy.Visible = false

    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        enemy:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/nl_glitch_dust.png")
        enemy:GetSprite():ReplaceSpritesheet(1, "gfx/enemies/nl_glitch_dush_fadein_overlay.png")
        enemy:GetSprite():LoadGraphics()
    end
end


local function SpawnEnemies()
    local chosenAxis = rng:RandomInt(4) + 1
    SpawnGhost(chosenAxis)
end


local function SpawnMorningStar()
    if MorningStar then return end

    local chosenCorner = rng:RandomInt(4) + 1
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

    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        cornerPos = cornerPos * MinigameConstants.GLITCH_MORNING_STAR_CLOSE_SPAWN
    end

    cornerPos = game:GetRoom():GetCenterPos() + cornerPos

    MorningStar = Isaac.Spawn(MinigameEntityTypes.CUSTOM_ENEMY, MinigameEntityVariants.CUSTOM_MORNINGSTAR, 0, cornerPos, Vector.Zero, nil):ToNPC()
    MorningStar:GetData().TargetFrame = 0
    MorningStar.State = 3

    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        MorningStar:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/nl_glitch_morningstar.png")
        MorningStar:GetSprite():LoadGraphics()
    end
end


local function UpdatePlaying()
    if MinigameTimers.HourTimer > 0 then
        MinigameTimers.HourTimer = MinigameTimers.HourTimer - 1
    else
        MinigameTimers.HourTimer = MinigameConstants.SECONDS_PER_HOUR * 30
        CurrentHour = CurrentHour + 1

        --Spawn fucky
        if CurrentHour ~= 6 then
            SFXManager:Play(MinigameSounds.TRANSITION)
            MinigameTimers.FuckySpawnTimer = MinigameConstants.FUCKY_SPAWN_MAX_TIMER
            FuckySpawnAxis = rng:RandomInt(4) + 1

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
        if ArcadeCabinetVariables.IsCurrentMinigameGlitched and CurrentHour % 2 == 1 then
            SpawnMorningStar()
        elseif ArcadeCabinetVariables.IsCurrentMinigameGlitched and CurrentHour % 2 == 0 and
        CurrentHour > 0 and CurrentHour < MinigameConstants.MAX_HOURS then
            MorningStar:Remove()
            MorningStar = nil
        elseif CurrentHour == 4 or (CheatingCounter > MinigameConstants.MAX_CHEATING_COUNTER and CurrentHour == 3)
        and not ArcadeCabinetVariables.IsCurrentMinigameGlitched then
            SpawnMorningStar()
        elseif CurrentHour == MinigameConstants.MAX_HOURS then
            CurrentMinigameState = MinigameState.WAIT_FOR_WINNING
            MinigameTimers.WaitForWinTimer = MinigameConstants.WAIT_FOR_WIN_MAX_FRAMES
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

    if MinigameTimers.ConfusionTimer > 0 then
        MinigameTimers.ConfusionTimer = MinigameTimers.ConfusionTimer - 1
    else
        IsPlayerConfused = false
    end

    if MinigameTimers.HourTimer % (math.floor((MinigameConstants.SECONDS_PER_HOUR * 30) / MinigameConstants.GHOSTS_PER_HOUR[CurrentHour + 1])) == 0 then
        SpawnEnemies()
    end
end


local function UpdateWaitingForWin()
    if MinigameTimers.WaitForWinTimer > 0 then
        MinigameTimers.WaitForWinTimer = MinigameTimers.WaitForWinTimer - 1
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
        ArcadeCabinetVariables.CurrentMinigameResult = ArcadeCabinetVariables.MinigameResult.WIN
    end

    FinalCutsceneScreen:Render(Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight()) / 2, Vector.Zero, Vector.Zero)
    FinalCutsceneScreen:Update()
end


local function RenderFadeOut()
    if CurrentMinigameState ~= MinigameState.LOSING then return end

    if FadeOutScreen:IsFinished("Appear") then
        ArcadeCabinetVariables.CurrentMinigameResult = ArcadeCabinetVariables.MinigameResult.LOSE
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
    
    ClockUI:Render(centerPos + Vector(120, 100), Vector.Zero, Vector.Zero)

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
    --Make it visible after appear shit
    entity.Visible = true

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
        entity.Velocity = (game:GetRoom():GetCenterPos() - entity.Position):Normalized() * MinigameConstants.MORNINGSTAR_CHASE_SPEED
    else
        entity.Velocity = (entity.Position - game:GetRoom():GetCenterPos()):Normalized() * MinigameConstants.MORNINGSTAR_RETREAT_SPEED
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
        entity.Velocity = (game:GetRoom():GetCenterPos() - entity.Position):Normalized() * MinigameConstants.FUCKY_SPEED
    end

    CheckIfFuckyHit(entity)
end


function night_light:OnNPCUpdate(entity)
    if entity.Variant == MinigameEntityVariants.CUSTOM_DUST then
        UpdateDust(entity)
    elseif entity.Variant == MinigameEntityVariants.CUSTOM_MORNINGSTAR then
        UpdateMorningStar(entity)
    elseif entity.Variant == MinigameEntityVariants.FUCKY then
        UpdateFucky(entity)
    end
end


function night_light:OnNPCCollision(entity, collider)
    --If its not the playing state dont execute the other code
    if CurrentMinigameState ~= MinigameState.PLAYING then return true end

    if collider:ToPlayer() and entity.Variant == MinigameEntityVariants.CUSTOM_DUST and not entity:GetData().IsDead then
        entity:GetData().IsDead = true
        entity.Velocity = Vector.Zero

        entity:GetSprite():Play("Poof")
        SFXManager:Play(MinigameSounds.DUST_DEATH)
        SFXManager:Play(MinigameSounds.PLAYER_HIT)

        FakePlayer:GetSprite():Play("Hit")
        HeartsUI:Play("Flash", true)
        PlayerHP = PlayerHP - 1
    elseif collider:ToPlayer() and entity.Variant == MinigameEntityVariants.FUCKY and not entity:GetData().IsDead then
        MinigameTimers.ConfusionTimer = MinigameConstants.CONFUSION_MAX_FRAMES
        IsPlayerConfused = true
        SFXManager:Play(MinigameSounds.DUST_DEATH)
        entity:GetSprite():Play("Poof", true)
        entity:GetData().IsDead = true
        entity.Velocity = Vector.Zero
    elseif collider:ToPlayer() and entity.Variant == MinigameEntityVariants.CUSTOM_MORNINGSTAR then
        FakePlayer:GetSprite():Play("Hit")
        SFXManager:Play(MinigameSounds.PLAYER_HIT)
        HeartsUI:Play("Flash", true)
        PlayerHP = 0
    end

    if PlayerHP == 0 then
        FadeOutScreen:Play("Appear", true)
        SFXManager:Play(MinigameSounds.LOSE)
        CurrentMinigameState = MinigameState.LOSING
    end

    return true
end


function night_light:OnPlayerDamage()
    return false
end


--OTHER CALLBACKS
function night_light:OnEntitySpawn(entityType, entityVariant, _, _, _, _, seed)
    if entityType == EntityType.ENTITY_EFFECT and 
    (entityVariant == EffectVariant.TINY_FLY or entityVariant == EffectVariant.POOF01) then
        return {EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_SPLAT, 0, seed}
    end
end


function night_light:OnTinyFlyUpdate(effect)
    effect:Remove() --They should be removed but just in case
end


--INIT MINIGAME
function night_light:AddCallbacks(mod)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, night_light.OnFrameUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, night_light.OnRender)
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, night_light.OnNPCUpdate, MinigameEntityTypes.CUSTOM_ENEMY)
    mod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, night_light.OnNPCCollision, MinigameEntityTypes.CUSTOM_ENEMY)
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, night_light.OnPlayerDamage, EntityType.ENTITY_PLAYER)
    mod:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, night_light.OnEntitySpawn)
    mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, night_light.OnTinyFlyUpdate, EffectVariant.TINY_FLY)
end


function night_light:RemoveCallbacks(mod)
    mod:RemoveCallback(ModCallbacks.MC_POST_UPDATE, night_light.OnFrameUpdate)
    mod:RemoveCallback(ModCallbacks.MC_POST_RENDER, night_light.OnRender)
    mod:RemoveCallback(ModCallbacks.MC_NPC_UPDATE, night_light.OnNPCUpdate)
    mod:RemoveCallback(ModCallbacks.MC_PRE_NPC_COLLISION, night_light.OnNPCCollision)
    mod:RemoveCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, night_light.OnPlayerDamage)
    mod:RemoveCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, night_light.OnEntitySpawn)
    mod:RemoveCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, night_light.OnTinyFlyUpdate)
end


function night_light:Init(mod, variables)
    ArcadeCabinetVariables = variables
    night_light:AddCallbacks(mod)

    local room = game:GetRoom()

    --Reset stuff
    CurrentHour = 0
    IsPlayerConfused = false
    PlayerHP = 3
    CheatingCounter = 0
    MorningStar = nil
    CurrentMinigameState = MinigameState.START_CUTSCENCE

    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    --Reset timers
    for _, timer in pairs(MinigameTimers) do
        timer = 0
    end

    MinigameTimers.HourTimer = MinigameConstants.SECONDS_PER_HOUR * 30
    MinigameTimers.InitialCutsceneTimer = MinigameConstants.INTIAL_CUTSCENE_MAX_FRAMES

    --UI
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        InitialCutsceneScreen:ReplaceSpritesheet(0, "gfx/effects/night light/nl_glitch_initial_cutscene.png")
        InitialCutsceneScreen:ReplaceSpritesheet(1, "gfx/effects/night light/nl_glitch_initial_cutscene.png")
        HeartsUI:ReplaceSpritesheet(0, "gfx/effects/night light/nl_glitch_hearts_ui.png")
        ClockUI:ReplaceSpritesheet(0, "gfx/effects/night light/nl_glitch_clock_ui.png")
        FuckyWarning:Load("gfx/nl_glitch_fucky_warning.anm2", true)
        FinalCutsceneScreen:Load("gfx/nl_glitch_final_cutscene.anm2", true)
    else
        InitialCutsceneScreen:ReplaceSpritesheet(0, "gfx/effects/night light/nl_initial_cutscene.png")
        InitialCutsceneScreen:ReplaceSpritesheet(1, "gfx/effects/night light/nl_initial_cutscene.png")
        HeartsUI:ReplaceSpritesheet(0, "gfx/effects/night light/nl_hearts_ui.png")
        ClockUI:ReplaceSpritesheet(0, "gfx/effects/night light/nl_clock_ui.png")
        FuckyWarning:Load("gfx/nl_fucky_warning.anm2", true)
        FinalCutsceneScreen:Load("gfx/nl_final_cutscene.anm2", true)
    end

    InitialCutsceneScreen:LoadGraphics()
    HeartsUI:LoadGraphics()
    ClockUI:LoadGraphics()
    FuckyWarning:LoadGraphics()

    InitialCutsceneScreen:Play("Idle", true)
    HeartsUI:Play("Idle", true)
    ClockUI:Play("Idle", true)
    ConfusionEffectOverlay:Play("Idle", true)

    --Transition
    SFXManager:Play(MinigameSounds.TRANSITION)

    --Backdrop
    local backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop2x2Variant, 0, room:GetCenterPos(), Vector.Zero, nil)
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        backdrop:GetSprite():ReplaceSpritesheet(0, "gfx/backdrop/glitched_nl_backdrop.png")
    else
        backdrop:GetSprite():ReplaceSpritesheet(0, "gfx/backdrop/nl_backdrop.png")
    end
    backdrop:GetSprite():LoadGraphics()
    backdrop.DepthOffset = -500

    --Fake player
    FakePlayer = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.FAKE_PLAYER, 0, room:GetCenterPos(), Vector.Zero, nil)
    LightBeam = Isaac.Spawn(EntityType.ENTITY_EFFECT, MinigameEntityVariants.FAKE_PLAYER, 0, room:GetCenterPos(), Vector.Zero, nil)
    LightBeam:GetSprite():Load("gfx/nl_light_beam.anm2", false)
    if ArcadeCabinetVariables.IsCurrentMinigameGlitched then
        LightBeam:GetSprite():ReplaceSpritesheet(0, "gfx/characters/nl_glitch_lightbeam.png")
    end
    LightBeam:GetSprite():LoadGraphics()
    LightBeam:GetSprite():Play("IdleDown", true)
    LightBeam.DepthOffset = -200


    --Prepare players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        player.Position = room:GetCenterPos()
        player.ControlsEnabled = false
        player.Visible = false
    end
end


return night_light