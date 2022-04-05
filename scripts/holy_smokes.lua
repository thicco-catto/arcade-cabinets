local holy_smokes = {}
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

holy_smokes.callbacks = {}
holy_smokes.result = nil
holy_smokes.startingItems = {
    CollectibleType.COLLECTIBLE_ISAACS_HEART,
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

local MinigameSounds = {
    WIN = Isaac.GetSoundIdByName("arcade cabinet win"),
    LOSE = Isaac.GetSoundIdByName("arcade cabinet lose")
}

local MinigameMusic = Isaac.GetMusicIdByName("bsw black beat wielder")

--Entities
local MinigameEntityVariants = {
}

--Constants
local MinigameConstants = {
}

--Timers
local MinigameTimers = {
}

--States
local CurrentMinigameState = 0
local MinigameState = {
}

--UI

--Other variables

function holy_smokes:Init()
    print("Init holy smokes")
end


function holy_smokes:OnEntityDamage(tookDamage, _, damageflags, _)
    if tookDamage:ToPlayer() then
        return false
    end


end
holy_smokes.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG] = holy_smokes.OnEntityDamage

return holy_smokes