local the_blob = {}
local game = Game()

----------------------------------------------
--FANCY REQUIRE (Thanks manaphoenix <3)
----------------------------------------------
local _, err = pcall(require, "")
local modName = err:match("/mods/(.*)/%.lua")
local path = "mods/" .. modName .. "/"

local function loadFile(loc, ...)
    return assert(loadfile(path .. loc .. ".lua"))(...)
end

local ArcadeCabinetVariables = loadFile("scripts/variables")

function the_blob:Init()
    print("Init the blob")
end

the_blob.callbacks = {
}

return the_blob