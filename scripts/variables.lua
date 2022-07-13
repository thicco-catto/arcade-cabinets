local ArcadeCabinetVariables = {}

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

ArcadeCabinetVariables.ArcadeCabinetScripts = nil

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

ArcadeCabinetVariables.CabinetRadius = 20
ArcadeCabinetVariables.MinigameDoor = nil
ArcadeCabinetVariables.CurrentMinigame = nil
ArcadeCabinetVariables.CurrentScript = nil
ArcadeCabinetVariables.IsCurrentMinigameGlitched = nil
ArcadeCabinetVariables.LevelCurses = nil
ArcadeCabinetVariables.OptionsChargeBar = nil
ArcadeCabinetVariables.OptionsActiveCam = nil
ArcadeCabinetVariables.OptionsFilter = nil
ArcadeCabinetVariables.RepositionPlayers = false
ArcadeCabinetVariables.TransitionScreen = Sprite()
ArcadeCabinetVariables.TransitionScreen:Load("gfx/minigame_transition.anm2", true)
ArcadeCabinetVariables.TransitionFrameCount = -1
ArcadeCabinetVariables.LastRoomCollectibles = {}
ArcadeCabinetVariables.MAX_ID_TMTRAINER = 4294967295
ArcadeCabinetVariables.FadeOutTimer = nil
ArcadeCabinetVariables.BackdropVariant = Isaac.GetEntityVariantByName("minigame backdrop")
ArcadeCabinetVariables.Backdrop1x1Variant = Isaac.GetEntityVariantByName("minigame backdrop 1x1")
ArcadeCabinetVariables.Backdrop1x2Variant = Isaac.GetEntityVariantByName("minigame backdrop 1x2")
ArcadeCabinetVariables.Backdrop2x1Variant = Isaac.GetEntityVariantByName("minigame backdrop 2x1")
ArcadeCabinetVariables.Backdrop2x2Variant = Isaac.GetEntityVariantByName("minigame backdrop 2x2")

return ArcadeCabinetVariables