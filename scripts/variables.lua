local ArcadeCabinetVariables = {}

ArcadeCabinetVariables.ArcadeCabinetVariant = {
    VARIANT_BLACKSTONEWIELDER = Isaac.GetEntityVariantByName("Arcade Cabinet BSW"),
    VARIANT_GUSH = Isaac.GetEntityVariantByName("Arcade Cabinet GUSH"),
    VARIANT_HOLYSMOKES = Isaac.GetEntityVariantByName("Arcade Cabinet HS"),
    VARIANT_JUMPINGCOFFING = Isaac.GetEntityVariantByName("Arcade Cabinet JC"),
    VARIANT_NIGHTLIGHT = Isaac.GetEntityVariantByName("Arcade Cabinet NL"),
    VARIANT_NOSPLASH = Isaac.GetEntityVariantByName("Arcade Cabinet NS"),
    VARIANT_THEBLOB = Isaac.GetEntityVariantByName("Arcade Cabinet TB"),
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
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_THEBLOB] = "tb.png",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_THEGROUNDBELOW] = "tgb.png",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_TOOUNDERGROUND] = "tug.png"
}

ArcadeCabinetVariables.ArcadeCabinetRooms = {
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_BLACKSTONEWIELDER] = "40",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_GUSH] = "50",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_HOLYSMOKES] = "60",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_JUMPINGCOFFING] = "70",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NIGHTLIGHT] = "80",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_NOSPLASH] = "90",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_THEBLOB] = "100",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_THEGROUNDBELOW] = "110",
    [ArcadeCabinetVariables.ArcadeCabinetVariant.VARIANT_TOOUNDERGROUND] = "120"
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
ArcadeCabinetVariables.Backdrop1x1Variant = Isaac.GetEntityVariantByName("minigame backdrop 1x1")
ArcadeCabinetVariables.Backdrop1x2Variant = Isaac.GetEntityVariantByName("minigame backdrop 1x2")
ArcadeCabinetVariables.Backdrop2x2Variant = Isaac.GetEntityVariantByName("minigame backdrop 2x2")

return ArcadeCabinetVariables