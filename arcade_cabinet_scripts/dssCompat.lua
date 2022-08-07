local dssCompat = {}
local SaveManager

local ArcadeCabinetVariables

dssCompat.menusavedata = nil

function dssCompat.GetSaveData()
    if not dssCompat.menusavedata then
        dssCompat.menusavedata = SaveManager:GetMenuData()
    end

    return dssCompat.menusavedata
end

function dssCompat.StoreSaveData()
    SaveManager:SaveMenuData(dssCompat.menusavedata)
end

-- Change this variable to match your mod. The standard is "Dead Sea Scrolls (Mod Name)"
local DSSModName = "Dead Sea Scrolls (Arcade Cabinets)"

-- DSSCoreVersion determines which menu controls the mod selection menu that allows you to enter other mod menus.
-- Don't change it unless you really need to and make sure if you do that you can handle mod selection and global mod options properly.
local DSSCoreVersion = 4

-- Every MenuProvider function below must have its own implementation in your mod, in order to handle menu save data.
local MenuProvider = {}

function MenuProvider.SaveSaveData()
    SaveManager:SaveData()
end

function MenuProvider.GetPaletteSetting()
    return dssCompat.GetSaveData().MenuPalette
end

function MenuProvider.SavePaletteSetting(var)
    dssCompat.GetSaveData().MenuPalette = var
end

function MenuProvider.GetHudOffsetSetting()
    if not REPENTANCE then
        return dssCompat.GetSaveData().HudOffset
    else
        return Options.HUDOffset * 10
    end
end

function MenuProvider.SaveHudOffsetSetting(var)
    if not REPENTANCE then
        dssCompat.GetSaveData().HudOffset = var
    end
end

function MenuProvider.GetGamepadToggleSetting()
    return dssCompat.GetSaveData().GamepadToggle
end

function MenuProvider.SaveGamepadToggleSetting(var)
    dssCompat.GetSaveData().GamepadToggle = var
end

function MenuProvider.GetMenuKeybindSetting()
    return dssCompat.GetSaveData().MenuKeybind
end

function MenuProvider.SaveMenuKeybindSetting(var)
    dssCompat.GetSaveData().MenuKeybind = var
end

function MenuProvider.GetMenusNotified()
    return dssCompat.GetSaveData().MenusNotified
end

function MenuProvider.SaveMenusNotified(var)
    dssCompat.GetSaveData().MenusNotified = var
end

function MenuProvider.GetMenusPoppedUp()
    return dssCompat.GetSaveData().MenusPoppedUp
end

function MenuProvider.SaveMenusPoppedUp(var)
    dssCompat.GetSaveData().MenusPoppedUp = var
end

local DSSInitializerFunction = include("arcade_cabinet_scripts.arcadecabinetsmenucore")

-- This function returns a table that some useful functions and defaults are stored on
local dssmod = DSSInitializerFunction(DSSModName, DSSCoreVersion, MenuProvider)


-- Adding a Menu


-- Creating a menu like any other DSS menu is a simple process.
-- You need a "Directory", which defines all of the pages ("items") that can be accessed on your menu, and a "DirectoryKey", which defines the state of the menu.
local exampledirectory = {
    -- The keys in this table are used to determine button destinations.
    main = {
        -- "title" is the big line of text that shows up at the top of the page!
        title = 'arcade cabinets',

        -- "buttons" is a list of objects that will be displayed on this page. The meat of the menu!
        buttons = {
            -- The simplest button has just a "str" tag, which just displays a line of text.
            
            -- The "action" tag can do one of three pre-defined actions:
            --- "resume" closes the menu, like the resume game button on the pause menu. Generally a good idea to have a button for this on your main page!
            --- "back" backs out to the previous menu item, as if you had sent the menu back input
            --- "openmenu" opens a different dss menu, using the "menu" tag of the button as the name
            {str = 'resume game', action = 'resume'},

            -- The "dest" option, if specified, means that pressing the button will send you to that page of your menu.
            -- If using the "openmenu" action, "dest" will pick which item of that menu you are sent to.
            {str = 'settings', dest = 'settings'},

            -- A few default buttons are provided in the table returned from DSSInitializerFunction.
            -- They're buttons that handle generic menu features, like changelogs, palette, and the menu opening keybind
            -- They'll only be visible in your menu if your menu is the only mod menu active; otherwise, they'll show up in the outermost Dead Sea Scrolls menu that lets you pick which mod menu to open.
            -- This one leads to the changelogs menu, which contains changelogs defined by all mods.
            dssmod.changelogsButton,
        },

        -- A tooltip can be set either on an item or a button, and will display in the corner of the menu while a button is selected or the item is visible with no tooltip selected from a button.
        -- The object returned from DSSInitializerFunction contains a default tooltip that describes how to open the menu, at "menuOpenToolTip"
        -- It's generally a good idea to use that one as a default!
        tooltip = dssmod.menuOpenToolTip
    },
    settings = {
        title = 'settings',
        buttons = {
            -- These buttons are all generic menu handling buttons, provided in the table returned from DSSInitializerFunction
            -- They'll only show up if your menu is the only mod menu active
            -- You should generally include them somewhere in your menu, so that players can change the palette or menu keybind even if your mod is the only menu mod active.
            -- You can position them however you like, though!
            dssmod.gamepadToggleButton,
            dssmod.menuKeybindButton,
            dssmod.paletteButton,

            {
                -- Creating gaps in your page can be done simply by inserting a blank button.
                -- The "nosel" tag will make it impossible to select, so it'll be skipped over when traversing the menu, while still rendering!
                str = '',
                fsize = 2,
                nosel = true
            },
            {
                str = 'crt shader',

                -- The "choices" tag on a button allows you to create a multiple-choice setting
                choices = {'fancy', 'basic', 'none'},
                -- The "setting" tag determines the default setting, by list index. EG "1" here will result in the default setting being "choice a"
                setting = 1,

                -- "variable" is used as a key to story your setting; just set it to something unique for each setting!
                variable = 'shaderactive',
                
                -- When the menu is opened, "load" will be called on all settings-buttons
                -- The "load" function for a button should return what its current setting should be
                -- This generally means looking at your mod's save data, and returning whatever setting you have stored
                load = function()
                    return dssCompat.GetSaveData().shaderactive or 1
                end,

                -- When the menu is closed, "store" will be called on all settings-buttons
                -- The "store" function for a button should save the button's setting (passed in as the first argument) to save data!
                store = function(var)
                    ArcadeCabinetVariables.IsShaderActive = var
                    dssCompat.GetSaveData().shaderactive = var
                    dssCompat.StoreSaveData()
                end,

                -- A simple way to define tooltips is using the "strset" tag, where each string in the table is another line of the tooltip
                tooltip = {strset = {'configure', 'my options', 'please!'}}
            },
        }
    }
}

local exampledirectorykey = {
    Item = exampledirectory.main, -- This is the initial item of the menu, generally you want to set it to your main item
    Main = 'main', -- The main item of the menu is the item that gets opened first when opening your mod's menu.

    -- These are default state variables for the menu; they're important to have in here, but you don't need to change them at all.
    Idle = false,
    MaskAlpha = 1,
    Settings = {},
    SettingsChanged = false,
    Path = {},
}

DeadSeaScrollsMenu.AddMenu("Arcade Cabinets", {
    -- The Run, Close, and Open functions define the core loop of your menu
    -- Once your menu is opened, all the work is shifted off to your mod running these functions, so each mod can have its own independently functioning menu.
    -- The DSSInitializerFunction returns a table with defaults defined for each function, as "runMenu", "openMenu", and "closeMenu"
    -- Using these defaults will get you the same menu you see in Bertran and most other mods that use DSS
    -- But, if you did want a completely custom menu, this would be the way to do it!
    
    -- This function runs every render frame while your menu is open, it handles everything! Drawing, inputs, etc.
    Run = dssmod.runMenu,
    -- This function runs when the menu is opened, and generally initializes the menu.
    Open = dssmod.openMenu,
    -- This function runs when the menu is closed, and generally handles storing of save data / general shut down.
    Close = dssmod.closeMenu,

    Directory = exampledirectory,
    DirectoryKey = exampledirectorykey
})

-- There are a lot more features that DSS supports not covered here, like sprite insertion and scroller menus, that you'll have to look at other mods for reference to use.
-- But, this should be everything you need to create a simple menu for configuration or other simple use cases!

function dssCompat:Init(variables, save)
    ArcadeCabinetVariables = variables
    SaveManager = save
end

return dssCompat