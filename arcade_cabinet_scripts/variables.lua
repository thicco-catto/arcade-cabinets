local ArcadeCabinetVariables = {}

----------------------------------------------
--FANCY REQUIRE (Thanks manaphoenix <3)
----------------------------------------------
local function loadFile(loc, ...)
    local _, err = pcall(require, "")
    local modName = err:match("/mods/(.*)/%.lua")
    local path = "mods/" .. modName .. "/"
    return assert(loadfile(path .. loc .. ".lua"))(...)
end

--#region Variables corresponding to each minigame
ArcadeCabinetVariables.ArcadeCabinetVariant = {
    VARIANT_BLACKSTONEWIELDER = Isaac.GetEntityVariantByName("Arcade Cabinet BSW"),
    VARIANT_GUSH = Isaac.GetEntityVariantByName("Arcade Cabinet GUSH"),
    VARIANT_HOLYSMOKES = Isaac.GetEntityVariantByName("Arcade Cabinet HS"),
    VARIANT_JUMPINGCOFFING = Isaac.GetEntityVariantByName("Arcade Cabinet JC"),
    VARIANT_NIGHTLIGHT = Isaac.GetEntityVariantByName("Arcade Cabinet NL"),
    VARIANT_NOSPLASH = Isaac.GetEntityVariantByName("Arcade Cabinet NS"),
    VARIANT_THEGROUNDBELOW = Isaac.GetEntityVariantByName("Arcade Cabinet TGB"),
    VARIANT_TOOUNDERGROUND = Isaac.GetEntityVariantByName("Arcade Cabinet TUG")
}

ArcadeCabinetVariables.ArcadeCabinetSprite = {
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_BLACKSTONEWIELDER] = "bsw.png",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_GUSH] = "gush.png",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_HOLYSMOKES] = "hs.png",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_JUMPINGCOFFING] = "jc.png",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NIGHTLIGHT] = "nl.png",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NOSPLASH] = "ns.png",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_THEGROUNDBELOW] = "tgb.png",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_TOOUNDERGROUND] = "tug.png"
}

ArcadeCabinetVariables.ArcadeCabinetRooms = {
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_BLACKSTONEWIELDER] = "40",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_GUSH] = "160",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_HOLYSMOKES] = "160",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_JUMPINGCOFFING] = "170",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NIGHTLIGHT] = "180",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NOSPLASH] = "190",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_THEGROUNDBELOW] = "210",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_TOOUNDERGROUND] = "220"
}

ArcadeCabinetVariables.ArcadeCabinetScripts = {
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_BLACKSTONEWIELDER] = require("arcade_cabinet_scripts/minigames/black_stone_wielder"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_GUSH] = require("arcade_cabinet_scripts/minigames/gush"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_HOLYSMOKES] = require("arcade_cabinet_scripts/minigames/holy_smokes"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_JUMPINGCOFFING] = require("arcade_cabinet_scripts/minigames/jumping_coffing"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NIGHTLIGHT] = require("arcade_cabinet_scripts/minigames/night_light"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NOSPLASH] = require("arcade_cabinet_scripts/minigames/no_splash"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_THEGROUNDBELOW] = require("arcade_cabinet_scripts/minigames/the_ground_below"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_TOOUNDERGROUND] = require("arcade_cabinet_scripts/minigames/too_underground")
}

ArcadeCabinetVariables.ArcadeCabinetItems = {
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_BLACKSTONEWIELDER] = Isaac.GetItemIdByName("BSW minigame"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_GUSH] = Isaac.GetItemIdByName("GUSH minigame"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_HOLYSMOKES] = Isaac.GetItemIdByName("HS minigame"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_JUMPINGCOFFING] = Isaac.GetItemIdByName("JC minigame"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NIGHTLIGHT] = Isaac.GetItemIdByName("NL minigame"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NOSPLASH] = Isaac.GetItemIdByName("NS minigame"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_THEGROUNDBELOW] = Isaac.GetItemIdByName("TGB minigame"),
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_TOOUNDERGROUND] = Isaac.GetItemIdByName("TUG minigame")
}

ArcadeCabinetVariables.ArcadeCabinetMinimapAPIIconFrame = {
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_BLACKSTONEWIELDER] = 0,
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_GUSH] = 1,
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_HOLYSMOKES] = 2,
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_JUMPINGCOFFING] = 3,
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NIGHTLIGHT] = 4,
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NOSPLASH] = 5,
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_THEGROUNDBELOW] = 6,
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_TOOUNDERGROUND] = 7
}

ArcadeCabinetVariables.ArcadeCabinetMinimapAPIIconID = {
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_BLACKSTONEWIELDER] = "black stone wielder",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_GUSH] = "gush",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_HOLYSMOKES] = "holy smokes",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_JUMPINGCOFFING] = "jumping coffing",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NIGHTLIGHT] = "night light",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NOSPLASH] = "no splash",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_THEGROUNDBELOW] = "the ground below",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_TOOUNDERGROUND] = "too underground"
}
--#endregion

--#region Backdrop variants
ArcadeCabinetVariables.BackdropVariant = Isaac.GetEntityVariantByName("minigame backdrop")
ArcadeCabinetVariables.Backdrop1x1Variant = Isaac.GetEntityVariantByName("minigame backdrop 1x1")
ArcadeCabinetVariables.Backdrop1x2Variant = Isaac.GetEntityVariantByName("minigame backdrop 1x2")
ArcadeCabinetVariables.Backdrop2x1Variant = Isaac.GetEntityVariantByName("minigame backdrop 2x1")
ArcadeCabinetVariables.Backdrop2x2Variant = Isaac.GetEntityVariantByName("minigame backdrop 2x2")
--#endregion

--#region Constants for the mod
ArcadeCabinetVariables.MINIGAME_NUM = 8
ArcadeCabinetVariables.RANDOM_CABINET_VARIANT = Isaac.GetEntityVariantByName("Arcade Cabinet RANDOM")
ArcadeCabinetVariables.RANDOM_GLITCH_CABINET_VARIANT = Isaac.GetEntityVariantByName("Arcade Cabinet RANDOM GLITCH")
ArcadeCabinetVariables.CABINET_RADIUS = 22
ArcadeCabinetVariables.CHANCE_FOR_CRANE_TO_CABINET = 5
ArcadeCabinetVariables.CHANCE_FOR_CABINET_EXPLODING = 30
ArcadeCabinetVariables.CHANCE_FOR_CABINET_EXPLODING_LUCKY_FOOT = 20
ArcadeCabinetVariables.MAX_NICE_TRY_FRAMES = 20
ArcadeCabinetVariables.GameState = {
    NOT_PLAYING = 1,
    FADE_IN = 2,
    TRANSITION = 3,
    PLAYING = 4,
    FADE_OUT = 5
}
ArcadeCabinetVariables.MinigameResult = {
    WIN = 1,
    LOSE = 2
}
--#endregion

ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.NOT_PLAYING
ArcadeCabinetVariables.CurrentMinigameResult = nil

ArcadeCabinetVariables.CurrentMinigame = nil
ArcadeCabinetVariables.CurrentScript = nil
ArcadeCabinetVariables.IsCurrentMinigameGlitched = nil
ArcadeCabinetVariables.CurrentMinigameObject = nil

ArcadeCabinetVariables.PreviousRoomIndex = nil
ArcadeCabinetVariables.LevelStage = nil
ArcadeCabinetVariables.LevelStageType = nil
ArcadeCabinetVariables.LevelCurses = nil
ArcadeCabinetVariables.ChallengeType = nil
ArcadeCabinetVariables.OptionsChargeBar = nil
ArcadeCabinetVariables.OptionsActiveCam = nil
ArcadeCabinetVariables.OptionsFilter = nil
ArcadeCabinetVariables.RestorePlayers = false
ArcadeCabinetVariables.TransitionScreen = Sprite()
ArcadeCabinetVariables.TransitionScreen:Load("gfx/minigame_transition.anm2", true)
ArcadeCabinetVariables.TransitionFrameCount = -1
ArcadeCabinetVariables.FadeOutTimer = nil

ArcadeCabinetVariables.MachinesInRun = {}
ArcadeCabinetVariables.IsInRoomAfterMinigame = false
ArcadeCabinetVariables.NiceTryFrameCount = 0
ArcadeCabinetVariables.NiceTryScreen = Sprite()
ArcadeCabinetVariables.NiceTryScreen:Load("gfx/minigame_transition.anm2", true)
ArcadeCabinetVariables.NiceTryScreen:ReplaceSpritesheet(0, "gfx/effects/nice_try_screen.png")
ArcadeCabinetVariables.NiceTryScreen:LoadGraphics()

--Options
ArcadeCabinetVariables.IsShaderActive = 1

return ArcadeCabinetVariables