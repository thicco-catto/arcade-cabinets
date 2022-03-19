local jumping_coffing = {}
local game = Game()
local SFXManager = SFXManager()
jumping_coffing.callbacks = {}
jumping_coffing.result = nil

----------------------------------------------
--FANCY REQUIRE (Thanks manaphoenix <3)
----------------------------------------------
local _, err = pcall(require, "")
local modName = err:match("/mods/(.*)/%.lua")
local path = "mods/" .. modName .. "/"

local function loadFile(loc, ...)
    return assert(loadfile(path .. loc .. ".lua"))(...)
end

local bannedSounds = {
    SoundEffect.SOUND_TEARS_FIRE,
    SoundEffect.SOUND_BLOODSHOOT,
    SoundEffect.SOUND_MEAT_IMPACTS,
    SoundEffect.SOUND_SUMMON_POOF,
    SoundEffect.SOUND_DOOR_HEAVY_CLOSE,
    SoundEffect.SOUND_DEATH_BURST_SMALL,
    SoundEffect.SOUND_MEATY_DEATHS,
    SoundEffect.SOUND_ANGRY_GURGLE
}

local replacementSounds = {
    [SoundEffect.SOUND_SHELLGAME] = Isaac.GetSoundIdByName("jc sword swing"),
    [SoundEffect.SOUND_SWORD_SPIN] = Isaac.GetSoundIdByName("jc sword spin"),
    [SoundEffect.SOUND_INSECT_SWARM_LOOP] = Isaac.GetSoundIdByName("jc fly buzz")
}

local minigameStates = {
    WAVE_TRANSITION_SCREEN = 1,
    PLAYING_WAVE = 2,
    WAITING_FOR_TRANSITION = 3,
    WINNING = 4,
    LOSING = 5
}
local currentMinigameState = minigameStates.WAVE_TRANSITION_SCREEN
local wave = 1

local minigameHP = 3
local iFrames = 0

local spawningPositions = {
    Vector(140, 190),
    Vector(140, 600),
    Vector(1000, 600),
    Vector(1000, 190)
}

local miniWavesLeftWave = {
    3,
    8,
    8
}

local waveEnemyToSpawnFrames = {
    40,
    30,
    40
}

jumping_coffing.startingItems = {
    CollectibleType.COLLECTIBLE_SPIRIT_SWORD,
    CollectibleType.COLLECTIBLE_ISAACS_HEART
}

local ArcadeCabinetVariables = loadFile("scripts/variables")
local TargetVariant = Isaac.GetEntityVariantByName("target JC")
local BloodSplatVariant = Isaac.GetEntityVariantByName("bloodsplat JC")

local minigameSounds = {
    NEW_WAVE = Isaac.GetSoundIdByName("jc new wave"),
    THIRD_WAVE = Isaac.GetSoundIdByName("jc third wave"),
    PLAYER_HURT = Isaac.GetSoundIdByName("jc player hurt"),
    GAPER_GRUNT = Isaac.GetSoundIdByName("jc grunt"),
    GAPER_DEATH = Isaac.GetSoundIdByName("jc gaper death"),
    FLY_DEATH = Isaac.GetSoundIdByName("jc fly death"),
    BOSS_DEATH = Isaac.GetSoundIdByName("jc boss death"),
    SPECIAL_ATTACK = Isaac.GetSoundIdByName("jc special attack"),
    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}

local TargetEntity = nil

local heartsUI = Sprite()
heartsUI:Load("gfx/jc_hearts_ui.anm2", true)

local chargeFrames = 0
local maxChargeFrames = 43
local chargeBarUI = Sprite()
chargeBarUI:Load("gfx/jc_charge_bar.anm2")
chargeBarUI.FlipX = true

local WaveTransitionScreen = Sprite()
WaveTransitionScreen:Load("gfx/minigame_transition.anm2")

local transitionFrames = -1

local miniWavesLeft = 0
local enemyToSpawnFrames = -1
local RestingFrames = -1

local LastBossCorner = nil
local HasSpawnedFirstBoss = false
local FinishedBossWave = false


function jumping_coffing:Init()
    local room = game:GetRoom()

    --Reset variables
    jumping_coffing.result = nil
    minigameHP = 3
    currentMinigameState = minigameStates.WAVE_TRANSITION_SCREEN
    iFrames = 0
    miniWavesLeft = 0
    FinishedBossWave = false
    HasSpawnedFirstBoss = false
    wave = 1
    transitionFrames = -1
    RestingFrames = -1
    enemyToSpawnFrames = -1
    iFrames = 0


    --Set the transition screen
    WaveTransitionScreen:ReplaceSpritesheet(0, "gfx/effects/jumping coffing/transition1.png")
    WaveTransitionScreen:ReplaceSpritesheet(1, "gfx/effects/jumping coffing/transition1.png")
    WaveTransitionScreen:LoadGraphics()
    transitionFrames = 70
    SFXManager:Play(minigameSounds.NEW_WAVE)

    --Spawn the backdrop and target
    Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, ArcadeCabinetVariables.BackdropVariant, 0, Vector(52, 126), Vector.Zero, nil)
    TargetEntity = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, TargetVariant, 0, room:GetCenterPos(), Vector.Zero, nil)
    TargetEntity:GetSprite():Play("DeadBoss", true)

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


local function LoseMinigame()
    currentMinigameState = minigameStates.LOSING
    SFXManager:Play(minigameSounds.LOSE)

    local playerNum = game:GetNumPlayers()
    for i = 0, playerNum - 1, 1 do
        local player = game:GetPlayer(i)
        player:PlayExtraAnimation("Sad")
        player.ControlsEnabled = false
    end

    WaveTransitionScreen:Play("Appear", true)
end


local function WinMinigame()
    currentMinigameState = minigameStates.WINNING
    SFXManager:Play(minigameSounds.WIN)

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
    for _, sound in ipairs(bannedSounds) do
        if SFXManager:IsPlaying(sound) then SFXManager:Stop(sound) end
    end

    --Replace sounds to be changed
    for originalSound, replacement in pairs(replacementSounds) do
        if SFXManager:IsPlaying(originalSound) then
            SFXManager:Stop(originalSound)
            SFXManager:Play(replacement)
        end
    end

    --Play grunts
    if #Isaac.FindByType(EntityType.ENTITY_GAPER, -1, -1) > 0 and not SFXManager:IsPlaying(minigameSounds.GAPER_GRUNT) then
        SFXManager:Play(minigameSounds.GAPER_GRUNT)
    end
end


local function UpdateTransitionScreen()
    local room = game:GetRoom()

    transitionFrames = transitionFrames - 1
  
    if transitionFrames == 2 then
        --Set all the variables before we change the state so it looks good
        miniWavesLeft = miniWavesLeftWave[wave]

        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)
            player.Position = room:GetCenterPos() + Vector(math.random(-50, 50), math.random(-50, 50))
        end

        enemyToSpawnFrames = 20
    elseif transitionFrames == 0 then
        --Change state and enable controls
        currentMinigameState = minigameStates.PLAYING_WAVE

        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            local player = game:GetPlayer(i)
            player.ControlsEnabled = true
        end
    end
end


local function CalculateTwitchyCorners()
    local twitchyCorners = {}

    if wave == 2 then
        --Special waves at 2, 4, 6 and final
        if miniWavesLeft == 7 then
            --First special wave (33% to spawn a twitchy)
            if math.random() <= 0.33 then
                twitchyCorners[math.random(1, 4)] = true
            end
        elseif miniWavesLeft == 5 then
            --Second special wave (1 guranteed and 50% to spawn another)
            local guaranteedCorner = math.random(1, 4)
            twitchyCorners[guaranteedCorner] = true

            if math.random() <= 0.5 then
                local randomCorner = math.random(1, 3)
                if randomCorner >= guaranteedCorner then randomCorner = randomCorner + 1 end
                twitchyCorners[randomCorner] = true
            end
        elseif miniWavesLeft == 3 then
            --Third special wave (50% to spawn a twitchy)
            if math.random() <= 0.5 then
                twitchyCorners[math.random(1, 4)] = true
            end
        elseif miniWavesLeft == 1 then
            --Last special wave (2 guaranteed, 50% to spawn another and 20% to spawn yet another)
            local remainingChoices = {1, 2, 3, 4}
            local aux = {}

            local guaranteedCorner = math.random(1, 4)
            twitchyCorners[guaranteedCorner] = true

            for _, value in ipairs(remainingChoices) do
                if guaranteedCorner ~= value then aux[#aux+1] = value end
            end
            remainingChoices = aux
            aux = {}

            local guaranteedCorner2 = remainingChoices[math.random(1, 3)]
            twitchyCorners[guaranteedCorner2] = true
            for _, value in ipairs(remainingChoices) do
                if guaranteedCorner2 ~= value then aux[#aux+1] = value end
            end
            remainingChoices = aux
            aux = {}

            if math.random() <= 0.5 then
                local randomCorner = remainingChoices[math.random(1, 2)]
                twitchyCorners[randomCorner] = true
                for _, value in ipairs(remainingChoices) do
                    if randomCorner ~= value then aux[#aux+1] = value end
                end
                remainingChoices = aux
                aux = {}

                if math.random() <= 0.2 then
                    twitchyCorners[remainingChoices[1]] = true
                end
            end
        end

        enemyToSpawnFrames = 60
    elseif wave == 3 then
        --Special waves at 2, 4, 6 y 8
        if miniWavesLeft == 7 or miniWavesLeft == 5 or miniWavesLeft == 3 or miniWavesLeft == 1 then
            --Special waves guarantee a twitchy
            if math.random() <= 0.33 then
                twitchyCorners[math.random(1, 4)] = true
            end
        end

        enemyToSpawnFrames = 40
    end

    return twitchyCorners
end


local function SpawnEnemies()
    local twitchyCorners = {}

    twitchyCorners = CalculateTwitchyCorners()

    --Spawn pseudowave miniwave
    for i = 1, 4, 1 do
        if twitchyCorners[i] then
            local enemy = Isaac.Spawn(EntityType.ENTITY_TWITCHY, 0, 0, spawningPositions[i] + Vector(math.random(-50, 50), math.random(-50, 50)), Vector(0, 0), nil)
            enemy:GetSprite():Load("gfx/jc_twitchy.anm2", true)
            enemy.Target = TargetEntity
            enemy.HitPoints = 10
        end

        if not twitchyCorners[i] or math.random() <= 0.5 then
            local enemy = Isaac.Spawn(EntityType.ENTITY_GAPER, 3, math.random(5), spawningPositions[i] + Vector(math.random(-50, 50), math.random(-50, 50)), Vector(0, 0), nil)
            enemy:GetSprite():Load("gfx/jc_rotten_gaper" .. enemy.SubType .. ".anm2", true)
            enemy.Target = TargetEntity
        end
    end
end


local function SpawnBosses()
    if not HasSpawnedFirstBoss and #Isaac.FindByType(EntityType.ENTITY_GAPER, -1, -1) <= 8 then
        LastBossCorner = math.random(4)
        local boss = Isaac.Spawn(EntityType.ENTITY_GAPER_L2, 0, 0, spawningPositions[LastBossCorner] + Vector(math.random(-50, 50), math.random(-50, 50)), Vector(0, 0), nil)
        boss:GetSprite():Load("gfx/jc_level_2_gaper.anm2", true)
        boss.Target = TargetEntity
        boss.HitPoints = 120
        boss:GetData().framesUntilSpecialAttack = 100
        boss:GetData().specialAttackFrames = 0
        boss:GetData().spawningCorner = LastBossCorner

        HasSpawnedFirstBoss = true
    elseif not FinishedBossWave and HasSpawnedFirstBoss and (#Isaac.FindByType(EntityType.ENTITY_GAPER_L2, -1, -1) == 0 or Isaac.FindByType(EntityType.ENTITY_GAPER_L2, -1, -1)[1].HitPoints <= 36) then
        local chosenCorner = math.random(3)
        if chosenCorner >= LastBossCorner then chosenCorner = chosenCorner + 1 end
        local boss = Isaac.Spawn(EntityType.ENTITY_GAPER_L2, 0, 0, spawningPositions[chosenCorner] + Vector(math.random(-50, 50), math.random(-50, 50)), Vector(0, 0), nil)
        boss:GetSprite():Load("gfx/jc_level_2_gaper.anm2", true)
        boss.Target = TargetEntity
        boss.HitPoints = 120
        boss:GetData().framesUntilSpecialAttack = 100
        boss:GetData().specialAttackFrames = 0
        boss:GetData().spawningCorner = chosenCorner

        FinishedBossWave = true
    end
end


local function UpdatePlayingWave()
    if miniWavesLeft > 0 then
        enemyToSpawnFrames = enemyToSpawnFrames - 1

        if enemyToSpawnFrames == 0 then
            SpawnEnemies()
            enemyToSpawnFrames = waveEnemyToSpawnFrames[wave]
            miniWavesLeft = miniWavesLeft - 1
        end
    else
        if wave == 3 then
            SpawnBosses()
        end

        if #Isaac.FindByType(EntityType.ENTITY_GAPER, -1, -1) == 0 and #Isaac.FindByType(EntityType.ENTITY_TWITCHY, -1, -1) == 0 and
        #Isaac.FindByType(EntityType.ENTITY_GAPER_L2, -1, -1) == 0 and #Isaac.FindByType(EntityType.ENTITY_ATTACKFLY, -1, -1) == 0 then
            if wave == 3 then
                --Clean room and third wave so win the game
                WinMinigame()
            else
                --Clean room and no more enemies to spawn go to rest
                currentMinigameState = minigameStates.WAITING_FOR_TRANSITION
                RestingFrames = 60
            end
        end
    end
end


local function UpdateWaiting()
    RestingFrames = RestingFrames - 1

    if RestingFrames == 0 then
        --The rest is over so start the next transition
        currentMinigameState = minigameStates.WAVE_TRANSITION_SCREEN
        wave = wave + 1
        WaveTransitionScreen:ReplaceSpritesheet(0, "gfx/effects/jumping coffing/transition" .. wave .. ".png")
        WaveTransitionScreen:LoadGraphics()

        if wave == 2 then
            transitionFrames = 70
            SFXManager:Play(minigameSounds.NEW_WAVE)
        else
            transitionFrames = 180
            SFXManager:Play(minigameSounds.THIRD_WAVE)
        end
        
        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            game:GetPlayer(i).ControlsEnabled = false
        end
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
            entity:MakeChampion(1, ChampionColor.YELLOW)
            entity.HitPoints = previousHP
            SFXManager:Play(minigameSounds.SPECIAL_ATTACK)
            entity:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 300, -1, false, false)
            entity:GetSprite():ReplaceSpritesheet(0, "gfx/enemies/jc_lv2_gaper_champion.png")
            entity:GetSprite():ReplaceSpritesheet(1, "gfx/enemies/jc_lv2_gaper_champion.png")
            entity:GetSprite():LoadGraphics()

            --Spawn flies
            local flyCorner = entity:GetData().spawningCorner + 2

            if flyCorner > 4 then flyCorner = (flyCorner % 4) + 1 end
            
            for i = 1, 15, 1 do
                local fly = Isaac.Spawn(EntityType.ENTITY_ATTACKFLY, 0, 0, spawningPositions[flyCorner], Vector.Zero, nil)
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

            entity:Remove()
        end
    end
end


function jumping_coffing:OnUpdate()

    ManageSFX()

    --Chargebar
    if currentMinigameState == minigameStates.PLAYING_WAVE or currentMinigameState == minigameStates.WAITING_FOR_TRANSITION then
        if Input.IsActionPressed(ButtonAction.ACTION_SHOOTLEFT, 0) or Input.IsActionPressed(ButtonAction.ACTION_SHOOTRIGHT, 0) or
        Input.IsActionPressed(ButtonAction.ACTION_SHOOTUP, 0) or Input.IsActionPressed(ButtonAction.ACTION_SHOOTDOWN, 0) then
            chargeFrames = chargeFrames + 1
        else
            chargeFrames = 0
        end
    end

    --Remove bloodsplats
    for _, effect in ipairs(Isaac.FindByType(EntityType.ENTITY_GENERIC_PROP, BloodSplatVariant, -1)) do
        if effect:GetSprite():IsFinished("Idle") then effect:Remove() end
    end

    --Manage special attack for bosses
    for _, boss in ipairs(Isaac.FindByType(EntityType.ENTITY_GAPER_L2, -1, -1)) do
        BossSpecialAttack(boss)
    end

    -- for i = 1, 870, 1 do
    --     if SFXManager:IsPlaying(i) then print(i) end
    -- end

    if iFrames > 0 then iFrames = iFrames - 1 end

    if transitionFrames > 0 then transitionFrames = transitionFrames - 1 end

    if currentMinigameState == minigameStates.WAVE_TRANSITION_SCREEN then
        UpdateTransitionScreen()
    elseif currentMinigameState == minigameStates.PLAYING_WAVE then
        UpdatePlayingWave()
    elseif currentMinigameState == minigameStates.WAITING_FOR_TRANSITION then
        UpdateWaiting()
    elseif currentMinigameState == minigameStates.WINNING then
        UpdateWinning()
    end
end
jumping_coffing.callbacks[ModCallbacks.MC_POST_UPDATE] = jumping_coffing.OnUpdate


function jumping_coffing:OnFamiliarUpdate(FamiliarEnt)
    if FamiliarEnt.Variant ~= FamiliarVariant.ISAACS_HEART then return end

    --Move isaac's heart very very far away
    FamiliarEnt.Position = Vector(-99999999, -99999999)
end
jumping_coffing.callbacks[ModCallbacks.MC_FAMILIAR_UPDATE] = jumping_coffing.OnFamiliarUpdate


local function KillEnemy(entity)
    entity:Remove()
    local bloodsplat = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, BloodSplatVariant, 0, entity.Position, Vector.Zero, nil)

    if entity.Type == EntityType.ENTITY_GAPER_L2 then
        --Death of boss
        SFXManager:Play(minigameSounds.BOSS_DEATH)

        bloodsplat:GetSprite():Load("gfx/jc_bloodsplat_big.anm2", true)
        bloodsplat:GetSprite():Play("Idle", true)

        local deadBoss = Isaac.Spawn(EntityType.ENTITY_GENERIC_PROP, TargetVariant, 0, entity.Position + Vector(0, -0.01), Vector.Zero, nil)
        deadBoss:GetSprite():Load("gfx/jc_dead_boss.anm2", true)
    elseif entity.Type == EntityType.ENTITY_ATTACKFLY then
        --Fly death
        SFXManager:Play(minigameSounds.FLY_DEATH)
        bloodsplat:GetSprite():Load("gfx/jc_fly_death.anm2", true)
        bloodsplat:GetSprite():Play("Idle", true)
    else
        --Gaper/twitchy death
        SFXManager:Play(minigameSounds.GAPER_DEATH)
        bloodsplat:GetSprite():Play("Idle", true)
    end
end


function jumping_coffing:OnEntityDamage(tookDamage, damageAmount, damageflags, source)
    if tookDamage:ToPlayer() then return end

    if damageflags == DamageFlag.DAMAGE_COUNTDOWN then
        --Negate contact damage (DamageFlag.DAMAGE_COUNTDOWN is damage flag for contact damage)
        return false
    end

    if tookDamage.Type == EntityType.ENTITY_GAPER_L2 and damageAmount < tookDamage.HitPoints then
        --Knockback and sfx for bosses
        tookDamage:AddVelocity((source.Position - tookDamage.Position)* -0.3)
        SFXManager:Play(minigameSounds.GAPER_DEATH)

        tookDamage:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 6, -1, false, false)
    else
        --Kill everything else
        KillEnemy(tookDamage)
    end
end
jumping_coffing.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG] = jumping_coffing.OnEntityDamage


function jumping_coffing:OnEntityUpdate(entity)
    if entity.Type == EntityType.ENTITY_GENERIC_PROP or iFrames > 0 then return end

    local room = game:GetRoom()

    if entity.Position:Distance(room:GetCenterPos()) < 20 then
        minigameHP = minigameHP - 1

        if minigameHP == 0 then
            LoseMinigame()
        end

        if entity.Type == EntityType.ENTITY_GAPER_L2 then
            entity:AddVelocity((entity.Position - room:GetCenterPos()) * 5)
        else
            KillEnemy(entity)
        end

        iFrames = 60
        heartsUI:Play("Damage", true)
        SFXManager:Play(minigameSounds.PLAYER_HURT)

        local playerNum = game:GetNumPlayers()
        for i = 0, playerNum - 1, 1 do
            game:GetPlayer(i):PlayExtraAnimation("Hit")
        end
    end
end
jumping_coffing.callbacks[ModCallbacks.MC_NPC_UPDATE] = jumping_coffing.OnEntityUpdate


function jumping_coffing:OnEntityInit(entity)
    if entity.Type ~= EntityType.ENTITY_SMALL_MAGGOT then return end

    entity:Remove()
end
jumping_coffing.callbacks[ModCallbacks.MC_POST_NPC_INIT] = jumping_coffing.OnEntityInit


local function RenderUI()
    --Render hearts
    if heartsUI:IsPlaying("Damage") then
        heartsUI:Update()
    else
        heartsUI:Play("Idle", true)
        heartsUI:SetFrame(minigameHP)
    end
    heartsUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) - Vector(160, 120), Vector.Zero, Vector.Zero)

    --Render charge bar
    local chargeRate = (chargeFrames / maxChargeFrames) * 10
    if chargeRate >= 11 then chargeRate = 11 end

    if chargeRate == 11 then
        if chargeBarUI:IsPlaying("MaxCharge") then
            chargeBarUI:Update()
        else
            chargeBarUI:Play("MaxCharge")
        end
    else
        chargeBarUI:Play("Idle", true)
        chargeBarUI:SetFrame(math.floor(chargeRate))
    end
    chargeBarUI:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) + Vector(200, 0), Vector.Zero, Vector.Zero)
end


local function RenderWaveTransition()
    if currentMinigameState ~= minigameStates.WAVE_TRANSITION_SCREEN then return end

    WaveTransitionScreen:Play("Idle", true)
    WaveTransitionScreen:SetFrame(0)
    WaveTransitionScreen:Render(Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2), Vector.Zero, Vector.Zero)
end


local function RenderFadeOut()
    if currentMinigameState ~= minigameStates.WINNING and currentMinigameState ~= minigameStates.LOSING then return end

    if WaveTransitionScreen:IsFinished("Appear") then
        if currentMinigameState == minigameStates.WINNING then
            jumping_coffing.result = ArcadeCabinetVariables.MinigameResult.WIN
        else
            jumping_coffing.result = ArcadeCabinetVariables.MinigameResult.LOSE
        end
    end

    if SFXManager:IsPlaying(minigameSounds.WIN) then
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


function jumping_coffing:OnKnife(knife)
    local data = knife:GetData()
    if currentMinigameState ~= minigameStates.PLAYING_WAVE and currentMinigameState ~= minigameStates.WAITING_FOR_TRANSITION then
        knife:Remove()
        chargeFrames = 0
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


function jumping_coffing:OnEffect(entityType, entityVariant, _, _, _, _, seed)
    if entityType == EntityType.ENTITY_EFFECT and 
    (entityVariant == EffectVariant.POOF01 or entityVariant == EffectVariant.TINY_FLY or entityVariant == EffectVariant.FLY_EXPLOSION) then
        return {EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_SPLAT, 0, seed}
    end
end
jumping_coffing.callbacks[ModCallbacks.MC_PRE_ENTITY_SPAWN] = jumping_coffing.OnEffect

return jumping_coffing