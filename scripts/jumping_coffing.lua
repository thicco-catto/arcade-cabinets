local jumping_coffing = {}
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

jumping_coffing.callbacks = {}
jumping_coffing.result = nil
jumping_coffing.startingItems = {
    CollectibleType.COLLECTIBLE_SPIRIT_SWORD,
}

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

local ReplacementSounds = {
    [SoundEffect.SOUND_SHELLGAME] = Isaac.GetSoundIdByName("jc sword swing"),
    [SoundEffect.SOUND_SWORD_SPIN] = Isaac.GetSoundIdByName("jc sword spin"),
    [SoundEffect.SOUND_INSECT_SWARM_LOOP] = Isaac.GetSoundIdByName("jc fly buzz")
}

local MinigameSounds = {
    NEW_WAVE = Isaac.GetSoundIdByName("jc new wave"),
    THIRD_WAVE = Isaac.GetSoundIdByName("jc third wave"),
    PLAYER_HURT = Isaac.GetSoundIdByName("jc player hurt"),
    GAPER_GRUNT = Isaac.GetSoundIdByName("jc grunt"),
    GAPER_DEATH = Isaac.GetSoundIdByName("jc gaper death"),
    TWITCHY_JUMP = Isaac.GetSoundIdByName("jc twitchy jump"),
    FLY_DEATH = Isaac.GetSoundIdByName("jc fly death"),
    BOSS_DEATH = Isaac.GetSoundIdByName("jc boss death"),
    SPECIAL_ATTACK = Isaac.GetSoundIdByName("jc special attack"),
    SPECIAL_ATTACK_END = Isaac.GetSoundIdByName("jc special attack end"),
    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}

local MinigameMusic = Isaac.GetMusicIdByName("jc corpse beat")

--Entities
local MinigameEntityVariants = {
    TARGET = Isaac.GetEntityVariantByName("target JC"),
    BLOODSPLAT = Isaac.GetEntityVariantByName("bloodsplat JC")
}

--Constants
local MinigameConstants = {
    SPAWNING_POSITIONS = {
        Vector(140, 190),
        Vector(140, 600),
        Vector(1000, 600),
        Vector(1000, 190)
    },
    MINIWAVES_PER_WAVE = {
        4,
        4,
        8
    },
    FRAMES_BETWEEN_MINIWAVES_PER_WAVE = {
        40,
        30,
        40
    },

    TRANSITION_FRAMES_PER_WAVE = {
        35,
        35,
        110
    },
    RESTING_BETWEEN_WAVES_FRAMES = 60,

    MAX_PLAYER_IFRAMES = 60,
    MAX_SPIRIT_SWORD_CHARGE = 43
}

--Timers
local MinigameTimers = {
    TransitionTimer = 0,
    MiniwaveTimer = 0,
    RestingTimer = 0,
    IFramesTimer = 0
}

--States
local MinigameStates = {
    WAVE_TRANSITION_SCREEN = 1,
    PLAYING_WAVE = 2,
    WAITING_FOR_TRANSITION = 3,
    WINNING = 4,
    LOSING = 5
}
local CurrentMinigameState = MinigameStates.WAVE_TRANSITION_SCREEN

--UI
local WaveTransitionScreen = Sprite()
WaveTransitionScreen:Load("gfx/minigame_transition.anm2")
local HeartsUI = Sprite()
HeartsUI:Load("gfx/jc_hearts_ui.anm2", true)
local ChargeBarUI = Sprite()
ChargeBarUI:Load("gfx/jc_charge_bar.anm2")
ChargeBarUI.FlipX = true

--Other variables
local CurrentWave = 1
local PlayerHP = 3
local MiniWavesLeft = 0

local TargetEntity = nil

local ChargeFrames = 0

--Spawning boss stuff
local LastBossCorner = nil
local HasSpawnedFirstBoss = false
local FinishedBossWave = false

--INIT
function jumping_coffing:Init()
    local room = game:GetRoom()

    --Reset variables
    jumping_coffing.result = nil
    PlayerHP = 3
    CurrentMinigameState = MinigameStates.WAVE_TRANSITION_SCREEN
    MinigameTimers.IFramesTimer = 0
    MiniWavesLeft = 0
    FinishedBossWave = false
    HasSpawnedFirstBoss = false
    CurrentWave = 1

    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    --Reset timers
    for _, timer in pairs(MinigameTimers) do
        timer = 0
    end

    --Set the transition screen
    WaveTransitionScreen:ReplaceSpritesheet(0, "gfx/effects/jumping coffing/transition1.png")
    WaveTransitionScreen:ReplaceSpritesheet(1, "gfx/effects/jumping coffing/transition1.png")
    WaveTransitionScreen:LoadGraphics()
    MinigameTimers.TransitionTimer = MinigameConstants.TRANSITION_FRAMES_PER_WAVE[CurrentWave]
    SFXManager:Play(MinigameSounds.NEW_WAVE)

    --Spawn the backdrop
    local backdrop = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.Backdrop2x2Variant, 0, room:GetCenterPos(), Vector.Zero, nil)
    backdrop.DepthOffset = -1000

    --Spawn target
    TargetEntity = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.TARGET, 0, room:GetCenterPos(), Vector.Zero, nil)
    TargetEntity:GetSprite():Play("DeadBoss", true)

    --Play music
    MusicManager:Play(MinigameMusic, 1)
    MusicManager:UpdateVolume()
    MusicManager:Pause()

    --Set up players
    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)

        for _, item in ipairs(jumping_coffing.startingItems) do
            player:AddCollectible(item, 0, false)
        end

        --Set spritesheet
        local playerSprite = player:GetSprite()
        playerSprite:Load("gfx/isaac52.anm2", true)
        playerSprite:ReplaceSpritesheet(1, "gfx/characters/isaac_jc.png")
        playerSprite:ReplaceSpritesheet(4, "gfx/characters/isaac_jc.png")
        playerSprite:ReplaceSpritesheet(12, "gfx/characters/isaac_jc.png")
        playerSprite:LoadGraphics()

        --Make sure the controls are off
        player.ControlsEnabled = false
    end
end


--UPDATE CALLBACKS
local function LoseMinigame()
    CurrentMinigameState = MinigameStates.LOSING
    SFXManager:Play(MinigameSounds.LOSE)

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        player:PlayExtraAnimation("Sad")
        player.ControlsEnabled = false
        player.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
    end

    WaveTransitionScreen:Play("Appear", true)
end


local function WinMinigame()
    CurrentMinigameState = MinigameStates.WINNING
    SFXManager:Play(MinigameSounds.WIN)

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        player.ControlsEnabled = false
        player:PlayExtraAnimation("Happy")
    end

    WaveTransitionScreen:Play("Appear", true)
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

    --Play grunts
    if #Isaac.FindByType(EntityType.ENTITY_GAPER, -1, -1) > 0 and not SFXManager:IsPlaying(MinigameSounds.GAPER_GRUNT) then
        SFXManager:Play(MinigameSounds.GAPER_GRUNT)
    end
end


local function UpdateTransitionScreen()
    local room = game:GetRoom()

    MinigameTimers.TransitionTimer = MinigameTimers.TransitionTimer - 1

    if MinigameTimers.TransitionTimer == (MinigameConstants.TRANSITION_FRAMES_PER_WAVE[CurrentWave] - 5) then
        --Move players before we actually change the state so it looks good
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)
            player.Position = room:GetCenterPos() + Vector(rng:RandomInt(101) - 50, rng:RandomInt(101) - 50)
        end
    elseif MinigameTimers.TransitionTimer == 0 then
        --Set states and corresponding variables
        CurrentMinigameState = MinigameStates.PLAYING_WAVE
        MinigameTimers.MiniwaveTimer = MinigameConstants.FRAMES_BETWEEN_MINIWAVES_PER_WAVE[CurrentWave]
        MiniWavesLeft = MinigameConstants.MINIWAVES_PER_WAVE[CurrentWave]

        MusicManager:Resume()

        --Give control back
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)
            player.ControlsEnabled = true
        end
    end
end


local function CalculateTwitchyCorners()
    local twitchyCorners = {}

    if CurrentWave == 2 then
        --Special waves at 2, 4, 6 and final
        if MiniWavesLeft == 7 then
            --First special CurrentWave (33% to spawn a twitchy)
            if rng:RandomFloat() <= 0.33 then
                twitchyCorners[rng:RandomInt(4) + 1] = true
            end
        elseif MiniWavesLeft == 5 then
            --Second special CurrentWave (1 guranteed and 50% to spawn another)
            local guaranteedCorner = rng:RandomInt(4) + 1
            twitchyCorners[guaranteedCorner] = true

            if rng:RandomFloat() <= 0.5 then
                local randomCorner = rng:RandomInt(3) + 1
                if randomCorner >= guaranteedCorner then randomCorner = randomCorner + 1 end
                twitchyCorners[randomCorner] = true
            end
        elseif MiniWavesLeft == 3 then
            --Third special CurrentWave (50% to spawn a twitchy)
            if rng:RandomFloat() <= 0.5 then
                twitchyCorners[rng:RandomInt(4) + 1] = true
            end
        elseif MiniWavesLeft == 1 then
            --Last special CurrentWave (2 guaranteed, 50% to spawn another and 20% to spawn yet another)
            local remainingChoices = {1, 2, 3, 4}
            local aux = {}

            local guaranteedCorner = rng:RandomInt(4) + 1
            twitchyCorners[guaranteedCorner] = true

            for _, value in ipairs(remainingChoices) do
                if guaranteedCorner ~= value then aux[#aux+1] = value end
            end
            remainingChoices = aux
            aux = {}

            local guaranteedCorner2 = remainingChoices[rng:RandomInt(3) + 1]
            twitchyCorners[guaranteedCorner2] = true
            for _, value in ipairs(remainingChoices) do
                if guaranteedCorner2 ~= value then aux[#aux+1] = value end
            end
            remainingChoices = aux
            aux = {}

            if rng:RandomFloat() <= 0.5 then
                local randomCorner = remainingChoices[rng:RandomInt(2) + 1]
                twitchyCorners[randomCorner] = true
                for _, value in ipairs(remainingChoices) do
                    if randomCorner ~= value then aux[#aux+1] = value end
                end
                remainingChoices = aux
                aux = {}

                if rng:RandomFloat() <= 0.2 then
                    twitchyCorners[remainingChoices[1]] = true
                end
            end
        end

        MinigameTimers.MiniwaveTimer = 60
    elseif CurrentWave == 3 then
        --Special waves at 2, 4, 6 y 8
        if MiniWavesLeft == 7 or MiniWavesLeft == 5 or MiniWavesLeft == 3 or MiniWavesLeft == 1 then
            --Special waves guarantee a twitchy
            if rng:RandomFloat() <= 0.33 then
                twitchyCorners[rng:RandomInt(4) + 1] = true
            end
        end

        MinigameTimers.MiniwaveTimer = 40
    end

    return twitchyCorners
end


local function SpawnEnemies()
    local twitchyCorners = {}

    twitchyCorners = CalculateTwitchyCorners()

    --Spawn pseudowave miniwave
    for i = 1, 4, 1 do
        if twitchyCorners[i] then
            local enemy = Isaac.Spawn(EntityType.ENTITY_TWITCHY, 0, 0, MinigameConstants.SPAWNING_POSITIONS[i] + Vector(rng:RandomInt(101) - 50, rng:RandomInt(101) - 50), Vector(0, 0), nil)
            enemy:GetSprite():Load("gfx/jc_twitchy.anm2", true)
            enemy.Target = TargetEntity
            enemy.HitPoints = 10
        end

        if not twitchyCorners[i] or rng:RandomFloat() <= 0.5 then
            local enemy = Isaac.Spawn(EntityType.ENTITY_GAPER, 3, rng:RandomInt(5) + 1, MinigameConstants.SPAWNING_POSITIONS[i] + Vector(rng:RandomInt(101) - 50, rng:RandomInt(101) - 50), Vector(0, 0), nil)
            enemy:GetSprite():Load("gfx/jc_rotten_gaper" .. enemy.SubType .. ".anm2", true)
            enemy.Target = TargetEntity
        end
    end
end


local function SpawnBoss(chosenCorner)
    local boss = Isaac.Spawn(EntityType.ENTITY_GAPER_L2, 0, 0, MinigameConstants.SPAWNING_POSITIONS[chosenCorner] + Vector(rng:RandomInt(101) - 50, rng:RandomInt(101) - 50), Vector(0, 0), nil)
    boss:GetSprite():Load("gfx/jc_level_2_gaper.anm2", true)
    boss.Target = TargetEntity
    boss.HitPoints = 120
    boss:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
    boss:GetData().framesUntilSpecialAttack = 100
    boss:GetData().specialAttackFrames = 0
    boss:GetData().spawningCorner = chosenCorner
end


local function SpawnBosses()
    if not HasSpawnedFirstBoss and #Isaac.FindByType(EntityType.ENTITY_GAPER, -1, -1) <= 8 then
        LastBossCorner = rng:RandomInt(4) + 1
        SpawnBoss(LastBossCorner)
        HasSpawnedFirstBoss = true
    elseif not FinishedBossWave and HasSpawnedFirstBoss and (#Isaac.FindByType(EntityType.ENTITY_GAPER_L2, -1, -1) == 0 or Isaac.FindByType(EntityType.ENTITY_GAPER_L2, -1, -1)[1].HitPoints <= 36) then
        local chosenCorner = rng:RandomInt(3) + 1
        if chosenCorner >= LastBossCorner then chosenCorner = chosenCorner + 1 end
        SpawnBoss(chosenCorner)
        FinishedBossWave = true
    end
end


local function UpdatePlayingWave()
    if MiniWavesLeft > 0 then
        MinigameTimers.MiniwaveTimer = MinigameTimers.MiniwaveTimer - 1

        if MinigameTimers.MiniwaveTimer == 0 then
            SpawnEnemies()
            MinigameTimers.MiniwaveTimer = MinigameConstants.FRAMES_BETWEEN_MINIWAVES_PER_WAVE[CurrentWave]
            MiniWavesLeft = MiniWavesLeft - 1
        end
    else
        if CurrentWave == 3 then
            SpawnBosses()
        end

        if #Isaac.FindByType(EntityType.ENTITY_GAPER, -1, -1) == 0 and #Isaac.FindByType(EntityType.ENTITY_TWITCHY, -1, -1) == 0 and
        #Isaac.FindByType(EntityType.ENTITY_GAPER_L2, -1, -1) == 0 and #Isaac.FindByType(EntityType.ENTITY_ATTACKFLY, -1, -1) == 0 then
            if CurrentWave == 3 then
                --Clean room and third CurrentWave so win the game
                MusicManager:VolumeSlide(0, 1)
                WinMinigame()
            else
                --Clean room and no more enemies to spawn go to rest
                CurrentMinigameState = MinigameStates.WAITING_FOR_TRANSITION
                MinigameTimers.RestingTimer = MinigameConstants.RESTING_BETWEEN_WAVES_FRAMES
            end
        end
    end
end


local function UpdateWaiting()
    MinigameTimers.RestingTimer = MinigameTimers.RestingTimer - 1

    if MinigameTimers.RestingTimer == 0 then
        --The rest is over so start the next transition
        CurrentMinigameState = MinigameStates.WAVE_TRANSITION_SCREEN
        CurrentWave = CurrentWave + 1
        WaveTransitionScreen:ReplaceSpritesheet(0, "gfx/effects/jumping coffing/transition" .. CurrentWave .. ".png")
        WaveTransitionScreen:LoadGraphics()

        MusicManager:Pause()

        MinigameTimers.TransitionTimer = MinigameConstants.TRANSITION_FRAMES_PER_WAVE[CurrentWave]
        if CurrentWave == 2 then
            SFXManager:Play(MinigameSounds.NEW_WAVE)
        else
            SFXManager:Play(MinigameSounds.THIRD_WAVE)
        end
        
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            game:GetPlayer(i).ControlsEnabled = false
        end
    end
end


local function UpdateLosing()
    local playerNum = game:GetNumPlayers()

    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        player:GetSprite():SetFrame(5)
    end
end


local function UpdateWinning()
    local playerNum = game:GetNumPlayers()

    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        player:GetSprite():SetFrame(10)
    end
end


local function BossSpecialAttack(entity)
    if entity.Type ~= EntityType.ENTITY_GAPER_L2 then return end
    if not entity:GetData().framesUntilSpecialAttack then return end

    entity = entity:ToNPC()

    if entity:GetData().framesUntilSpecialAttack > 0 then
        entity:GetData().framesUntilSpecialAttack =  entity:GetData().framesUntilSpecialAttack - 1

        if entity:GetData().framesUntilSpecialAttack == 0 then
            --Start of special attack
            entity:GetData().specialAttackFrames = 200

            local previousHP = entity.HitPoints
            --entity:MakeChampion(1, ChampionColor.YELLOW)
            entity.HitPoints = previousHP
            SFXManager:Play(MinigameSounds.SPECIAL_ATTACK)
            entity:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 300, -1, false, false)
            entity:GetSprite():Load("gfx/jc_level_2_gaper_special_attack.anm2", true)
            entity:GetSprite():PlayOverlay("Head", true)

            --Spawn flies
            local flyCorner = entity:GetData().spawningCorner + 2

            if flyCorner > 4 then flyCorner = (flyCorner % 4) + 1 end

            for i = 1, 15, 1 do
                local fly = Isaac.Spawn(EntityType.ENTITY_ATTACKFLY, 0, 0, MinigameConstants.SPAWNING_POSITIONS[flyCorner], Vector.Zero, nil)
                fly.Target = TargetEntity
                fly:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/jc_fly.png")
                fly:GetSprite():LoadGraphics()
            end
        end
    else
        if entity:GetData().specialAttackFrames > 0 then
            entity:GetData().specialAttackFrames = entity:GetData().specialAttackFrames - 1

            --Start blinking if the attack is gonna end soon
            if entity:GetData().specialAttackFrames <= 20 then
                if entity:GetData().specialAttackFrames % 10 == 0 then
                    entity:SetColor(Color(1, 1, 1, 0, 255, 255, 255), 5, -2, false, false)
                end
            end
        else
            --End of special attack
            local previousHP = entity.HitPoints
            local newEntity = Isaac.Spawn(entity.Type, entity.Variant, entity.SubType, entity.Position, entity.Velocity, nil)
            newEntity:GetSprite():Load("gfx/jc_level_2_gaper.anm2", true)
            newEntity.Target = TargetEntity
            newEntity.HitPoints = previousHP
            newEntity:GetData().framesUntilSpecialAttack = 100
            newEntity:GetData().specialAttackFrames = 0
            newEntity:GetData().spawningCorner = entity:GetData().spawningCorner
            newEntity:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)

            entity:Remove()

            SFXManager:Play(MinigameSounds.SPECIAL_ATTACK_END)
        end
    end
end


function jumping_coffing:OnUpdate()

    ManageSFX()

    --Chargebar
    if CurrentMinigameState == MinigameStates.PLAYING_WAVE or CurrentMinigameState == MinigameStates.WAITING_FOR_TRANSITION then
        if (Input.IsActionPressed(ButtonAction.ACTION_SHOOTLEFT, 0) or Input.IsActionPressed(ButtonAction.ACTION_SHOOTRIGHT, 0) or
        Input.IsActionPressed(ButtonAction.ACTION_SHOOTUP, 0) or Input.IsActionPressed(ButtonAction.ACTION_SHOOTDOWN, 0)) and
        #Isaac.FindByType(EntityType.ENTITY_KNIFE, -1, -1) ~= 0 then
            ChargeFrames = ChargeFrames + 1
        else
            ChargeFrames = 0
        end
    end

    --Remove bloodsplats
    for _, effect in ipairs(Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.BLOODSPLAT, -1)) do
        if effect:GetSprite():IsFinished("Idle") then effect:Remove() end
    end

    --Manage special attack for bosses
    for _, boss in ipairs(Isaac.FindByType(EntityType.ENTITY_GAPER_L2, -1, -1)) do
        BossSpecialAttack(boss)
    end

    -- for i = 1, 870, 1 do
    --     if SFXManager:IsPlaying(i) then print(i) end
    -- end

    if MinigameTimers.IFramesTimer > 0 then MinigameTimers.IFramesTimer = MinigameTimers.IFramesTimer - 1 end

    --States logic
    if CurrentMinigameState == MinigameStates.WAVE_TRANSITION_SCREEN then
        UpdateTransitionScreen()
    elseif CurrentMinigameState == MinigameStates.PLAYING_WAVE then
        UpdatePlayingWave()
    elseif CurrentMinigameState == MinigameStates.WAITING_FOR_TRANSITION then
        UpdateWaiting()
    elseif CurrentMinigameState == MinigameStates.LOSING then
        UpdateLosing()
    elseif CurrentMinigameState == MinigameStates.WINNING then
        UpdateWinning()
    end
end
jumping_coffing.callbacks[ModCallbacks.MC_POST_UPDATE] = jumping_coffing.OnUpdate


local function RenderUI()
    --Render hearts
    if HeartsUI:IsPlaying("Damage") then
        HeartsUI:Update()
    else
        HeartsUI:Play("Idle", true)
        HeartsUI:SetFrame(PlayerHP)
    end
    HeartsUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) - Vector(190, 120), Vector.Zero, Vector.Zero)

    --Render charge bar
    local chargeRate = (ChargeFrames / MinigameConstants.MAX_SPIRIT_SWORD_CHARGE) * 10
    if chargeRate >= 11 then chargeRate = 11 end

    if chargeRate == 11 then
        if ChargeBarUI:IsPlaying("MaxCharge") then
            ChargeBarUI:Update()
        else
            ChargeBarUI:Play("MaxCharge")
        end
    else
        ChargeBarUI:Play("Idle", true)
        ChargeBarUI:SetFrame(math.floor(chargeRate))
    end
    ChargeBarUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) + Vector(200, 0), Vector.Zero, Vector.Zero)
end


local function RenderWaveTransition()
    if CurrentMinigameState ~= MinigameStates.WAVE_TRANSITION_SCREEN then return end

    WaveTransitionScreen:Play("Idle", true)
    WaveTransitionScreen:SetFrame(0)
    WaveTransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
end


local function RenderFadeOut()
    if CurrentMinigameState ~= MinigameStates.WINNING and CurrentMinigameState ~= MinigameStates.LOSING then return end

    if WaveTransitionScreen:IsFinished("Appear") then
        if CurrentMinigameState == MinigameStates.WINNING then
            jumping_coffing.result = ArcadeCabinetVariables.MinigameResult.WIN
        else
            jumping_coffing.result = ArcadeCabinetVariables.MinigameResult.LOSE
        end
    end

    if SFXManager:IsPlaying(MinigameSounds.WIN) then
        WaveTransitionScreen:SetFrame(0)
    end

    WaveTransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
    WaveTransitionScreen:Update()
end


function jumping_coffing:OnRender()
    RenderUI()

    RenderWaveTransition()

    RenderFadeOut()
end
jumping_coffing.callbacks[ModCallbacks.MC_POST_RENDER] = jumping_coffing.OnRender


--NPC CALLBACKS
local function KillEnemy(entity)
    entity:Remove()
    local bloodsplat = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.BLOODSPLAT, 0, entity.Position, Vector.Zero, nil)

    if entity.Type == EntityType.ENTITY_GAPER_L2 then
        --Death of boss
        SFXManager:Play(MinigameSounds.BOSS_DEATH)

        bloodsplat:GetSprite():Load("gfx/jc_bloodsplat_big.anm2", true)

        local deadBoss = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, MinigameEntityVariants.TARGET, 0, entity.Position + Vector(0, -0.01), Vector.Zero, nil)
        deadBoss:GetSprite():Load("gfx/jc_dead_boss.anm2", true)
    elseif entity.Type == EntityType.ENTITY_ATTACKFLY then
        --Fly death
        SFXManager:Play(MinigameSounds.FLY_DEATH)
        bloodsplat:GetSprite():Load("gfx/jc_fly_death.anm2", true)
    else
        --Gaper/twitchy death
        SFXManager:Play(MinigameSounds.GAPER_DEATH)

        --Special time? kill effect
        if rng:RandomInt(1000) < 5 then
            bloodsplat:GetSprite():Load("gfx/jc_bloodsplat_time.anm2", true)
        end
    end

    bloodsplat:GetSprite():Play("Idle", true)
end


function jumping_coffing:OnEntityInit(entity)
    if entity.Type ~= EntityType.ENTITY_SMALL_MAGGOT then return end

    entity:Remove()
end
jumping_coffing.callbacks[ModCallbacks.MC_POST_NPC_INIT] = jumping_coffing.OnEntityInit


local function CheckForTwitchyJump(entity)
    if entity:GetSprite():IsPlaying("Jump") and entity:GetSprite():GetFrame() == 0 then
        SFXManager:Play(MinigameSounds.TWITCHY_JUMP)
    end
end


local function CheckIfEnemyHit(entity)
    local room = game:GetRoom()

    if entity.Position:Distance(room:GetCenterPos()) < 20 then
        PlayerHP = PlayerHP - 1

        if PlayerHP == 0 then
            LoseMinigame()
        end

        if entity.Type == EntityType.ENTITY_GAPER_L2 then
            entity:AddVelocity((entity.Position - room:GetCenterPos()) * 5)
        else
            KillEnemy(entity)
        end

        MinigameTimers.IFramesTimer = MinigameConstants.MAX_PLAYER_IFRAMES
        HeartsUI:Play("Damage", true)
        SFXManager:Play(MinigameSounds.PLAYER_HURT)

        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            game:GetPlayer(i):PlayExtraAnimation("Hit")
        end
    end
end


function jumping_coffing:OnEntityUpdate(entity)
    if entity.Type == EntityType.ENTITY_GENERIC_PROP then return end

    if entity.Type == EntityType.ENTITY_TWITCHY then
        CheckForTwitchyJump(entity)
    end

    if MinigameTimers.IFramesTimer <= 0 then
        CheckIfEnemyHit(entity)
    end
    
end
jumping_coffing.callbacks[ModCallbacks.MC_NPC_UPDATE] = jumping_coffing.OnEntityUpdate


function jumping_coffing:OnEntityDamage(tookDamage, damageAmount, damageflags, source)
    if tookDamage:ToPlayer() then return false end

    if tookDamage.Type == EntityType.ENTITY_GAPER_L2 and damageAmount < tookDamage.HitPoints then
        --Knockback and sfx for bosses
        tookDamage:AddVelocity((source.Position - tookDamage.Position)* -0.3)
        SFXManager:Play(MinigameSounds.GAPER_DEATH)

        tookDamage:SetColor(Color(1, 1, 1, 0, 0, 0, 0), 3, -5, false, false)
    else
        --Kill everything else
        KillEnemy(tookDamage)
    end
end
jumping_coffing.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG] = jumping_coffing.OnEntityDamage


--OTHER CALLBACKS
function jumping_coffing:EffectUpdate(effect)
    if effect.Variant == EffectVariant.TINY_FLY then
        effect:Remove() --They should be removed but just in case
    end
end
jumping_coffing.callbacks[ModCallbacks.MC_POST_EFFECT_UPDATE] = jumping_coffing.EffectUpdate


function jumping_coffing:OnKnife(knife)
    local data = knife:GetData()
    if CurrentMinigameState ~= MinigameStates.PLAYING_WAVE and CurrentMinigameState ~= MinigameStates.WAITING_FOR_TRANSITION then
        knife:Remove()
        ChargeFrames = 0
    end

    if data.CustomSprite then return end

    local player = knife.Parent
	if (not player) or (player.Type ~= EntityType.ENTITY_PLAYER) then return end

    local sprite = knife:GetSprite()
	if Isaac.GetPlayer(0):HasCollectible(CollectibleType.COLLECTIBLE_SPIRIT_SWORD) then
        local anim = sprite:GetAnimation()
        sprite:Load("gfx/jc_spirit_sword.anm2", true)
        sprite:Play(anim)
        data.CustomSprite = true
    end
end
jumping_coffing.callbacks[ModCallbacks.MC_POST_KNIFE_UPDATE] = jumping_coffing.OnKnife


function jumping_coffing:OnTear(tear)
    tear:Remove()
end
jumping_coffing.callbacks[ModCallbacks.MC_POST_TEAR_UPDATE] = jumping_coffing.OnTear


function jumping_coffing:OnProjectile(projectile)
    projectile:Remove()
end
jumping_coffing.callbacks[ModCallbacks.MC_POST_PROJECTILE_UPDATE] = jumping_coffing.OnProjectile


function jumping_coffing:OnEffectSpawn(entityType, entityVariant, _, _, _, _, seed)
    if entityType == EntityType.ENTITY_EFFECT and 
    (entityVariant == EffectVariant.POOF01 or entityVariant == EffectVariant.TINY_FLY or entityVariant == EffectVariant.FLY_EXPLOSION) then
        return {EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_SPLAT, 0, seed}
    end
end
jumping_coffing.callbacks[ModCallbacks.MC_PRE_ENTITY_SPAWN] = jumping_coffing.OnEffectSpawn

return jumping_coffing