local ArcadeCabinetVariables = {}

----------------------------------------------
--FANCY REQUIRE (Thanks manaphoenix <3)
----------------------------------------------
local _, err = pcall(require, "")
local modName = err:match("/mods/(.*)/%.lua")
local path = "mods/" .. modName .. "/"

local function loadFile(loc, ...)
    return assert(loadfile(path .. loc .. ".lua"))(...)
end

ArcadeCabinetVariables.ArcadeCabinetVar = Isaac.GetEntityVariantByName("Arcade_Cabinet_BSW")
ArcadeCabinetVariables.ArcadeCabinetSub = {
    SUBTYPE_BLACKSTONEWIELDER = 1,
    SUBTYPE_GUSH = 2,
    SUBTYPE_JUMPINGCOFFING = 3,
    SUBTYPE_NIGHTLIGHT = 4,
    SUBTYPE_NOSPLASH = 5,
    SUBTYPE_THEBLOB = 6,
    SUBTYPE_THEGROUONDBELOW = 7,
    SUBTYPE_TOOUNDERGROUND = 8
}

ArcadeCabinetVariables.ArcadeCabinetSprite = {
    "bsw.png",
    "gush.png",
    "jc.png",
    "nl.png",
    "ns.png",
    "tb.png",
    "tgb.png",
    "tug.png"
}

ArcadeCabinetVariables.ArcadeCabinetRooms = {
    {"40"},
    {"50"},
    {"60"},
    {"70"},
    {"80"},
    {"90"},
    {"100"},
    {"110", "111", "112"}
}

ArcadeCabinetVariables.GameState = {
    NOT_PLAYING = 1,
    FADE_IN = 2,
    TRANSITION = 3,
    PLAYING = 4,
    FADE_OUT = 5
}

ArcadeCabinetVariables.CurrentGameState = ArcadeCabinetVariables.GameState.NOT_PLAYING

ArcadeCabinetVariables.MinigameResult = {
    WIN = 1,
    LOSE = 2
}
ArcadeCabinetVariables.CurrentMinigameResult = nil

ArcadeCabinetVariables.MinigameDoor = nil
ArcadeCabinetVariables.CurrentMinigame = nil
ArcadeCabinetVariables.CurrentScript = nil
ArcadeCabinetVariables.LevelCurses = nil
ArcadeCabinetVariables.OptionsChargeBar = nil
ArcadeCabinetVariables.OptionsFilter = nil
ArcadeCabinetVariables.TransitionScreen = Sprite()
ArcadeCabinetVariables.TransitionFrameCount = -1
ArcadeCabinetVariables.LastRoomCollectibles = {}
ArcadeCabinetVariables.MAX_ID_TMTRAINER = 4294967295
ArcadeCabinetVariables.FadeOutTimer = nil
ArcadeCabinetVariables.BackdropVariant = Isaac.GetEntityVariantByName("minigame backdrop")

return ArcadeCabinetVariables