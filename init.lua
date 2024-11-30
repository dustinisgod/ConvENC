local mq = require('mq')
local utils = require('utils')
local commands = require('commands')
local gui = require('gui')
local nav = require('nav')
local spells = require('spells')
local mez = require('mez')
local tash = require('tash')
local slow = require('slow')
local cripple = require('cripple')

local class = mq.TLO.Me.Class()
if class ~= "Enchanter" then
    print("This script is only for Enchanters.")
    mq.exit()
end

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local currentLevel = mq.TLO.Me.Level()

utils.PluginCheck()

mq.cmd('/squelch /assist off')

mq.imgui.init('controlGUI', gui.controlGUI)

commands.init()
commands.initALL()

local startupRun = false
local function checkBotOn(currentLevel)
    if gui.botOn and not startupRun then
        nav.setCamp()
        spells.startup(currentLevel)
        startupRun = true  -- Set flag to prevent re-running
        printf("Bot has been turned on. Running spells.startup.")
        local buffer = require('buffer')
        local selfbuffer = require('selfbuffer')
        if gui.buffsOn then
            buffer.buffRoutine()
        end
        if gui.buffsOn and gui.selfshield then
            selfbuffer.selfbuffRoutine()
        end
    elseif not gui.botOn and startupRun then
        -- Optional: Reset the flag if bot is turned off
        startupRun = false
        printf("Bot has been turned off. Ready to run spells.startup again.")
    end
end

local toggleboton = false
local function returnChaseToggle()
    -- Check if bot is on and return-to-camp is enabled, and only set camp if toggleboton is false
    if gui.botOn and gui.returnToCamp and not toggleboton then
        nav.setCamp()
        toggleboton = true
    elseif not gui.botOn and toggleboton then
        -- Clear camp if bot is turned off after being on
        nav.clearCamp()
        toggleboton = false
    end
end

utils.loadMezConfig()
utils.loadTashConfig()
utils.loadSlowConfig()
utils.loadCrippleConfig()

while gui.controlGUI do

    returnChaseToggle()

    if gui.botOn then

        checkBotOn(currentLevel)

        utils.monitorNav()

        if gui.sitMed then
            utils.sitMed()
        end

        if gui.mezOn then
            mez.mezRoutine()
        end

        if gui.tashOn then
            tash.tashRoutine()
        end

        if gui.slowOn then
            slow.slowRoutine()
        end

        if gui.crippleOn then
            cripple.crippleRoutine()
        end

        if gui.buffsOn then
            utils.monitorBuffs()
         end

        local newLevel = mq.TLO.Me.Level()
        if newLevel ~= currentLevel then
            printf(string.format("Level has changed from %d to %d. Updating spells.", currentLevel, newLevel))
            spells.startup(newLevel)
            currentLevel = newLevel
        end
    end

    mq.doevents()
    mq.delay(50)
end