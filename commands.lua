local mq = require 'mq'
local gui = require 'gui'
local nav = require 'nav'
local utils = require 'utils'

local commands = {}

local DEBUG_MODE = true
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

-- Existing functions

local function setExit()
    print("Closing..")
    gui.isOpen = false
end

local function setSave()
    gui.saveConfig()
end

-- Helper function for on/off commands
local function setToggleOption(option, value, name)
    if value == "on" then
        gui[option] = true
        print(name .. " is now enabled.")
    elseif value == "off" then
        gui[option] = false
        print(name .. " is now disabled.")
    else
        print("Usage: /convENC " .. name .. " on/off")
    end
end

-- Helper function for numeric value commands
local function setNumericOption(option, value, name)
    if value == "" then
        print("Usage: /convENC " .. name .. " <number>")
        return
    end
    if not string.match(value, "^%d+$") then
        print("Error: " .. name .. " must be a number with no letters or symbols.")
        return
    end
    gui[option] = tonumber(value)
    print(name .. " set to", gui[option])
end

-- On/Off Commands
local function setBotOnOff(value) setToggleOption("botOn", value, "Bot") end
local function setSwitchWithMA(value) setToggleOption("switchWithMA", value, "Switch with MA") end
local function setBuffGroup(value) setToggleOption("buffGroup", value, "Buff Group") end
local function setBuffRaid(value) setToggleOption("buffRaid", value, "Buff Raid") end
local function setBuffs(value) setToggleOption("buffsOn", value, "Buffs") end
local function sethastebuff(value) setToggleOption("hastebuff", value, "Haste Buff") end
local function setmanaregenbuff(value) setToggleOption("manaregenbuff", value, "Mana Regen Buff") end
local function setintwisbuff(value) setToggleOption("intwisbuff", value, "Int/Wis Buff") end
local function setmagicresistbuff(value) setToggleOption("magicresistbuff", value, "Magic Resist Buff") end
local function setTash(value) setToggleOption("tashOn", value, "Tash") end
local function setSlow(value) setToggleOption("slowOn", value, "Slow") end
local function setCripple(value) setToggleOption("crippleOn", value, "Cripple") end
local function setMez(value) setToggleOption("mezOn", value, "Mez") end
local function setTashMez(value) setToggleOption("mezTashOn", value, "Tash Mez") end

-- Numeric Commands
local function setMezRadius(value) setNumericOption("mezRadius", value, "MezRadius") end
local function setMezStopPercent(value) setNumericOption("mezStopPercent", value, "MezStopPct") end
local function setMezAmount(value) setNumericOption("mezAmount", value, "MezAmount") end
local function setSitMedOnOff(value) setToggleOption("sitMed", value, "Sit to Med") end

local function setBuffsOn(value)
    setToggleOption("buffsOn", value, "Buffs On")
end

-- Combined function for setting main assist, range, and percent
local function setAssist(name, range, percent)
    if name then
        utils.setMainAssist(name)
        print("Main Assist set to", name)
    else
        print("Error: Main Assist name is required.")
        return
    end

    -- Set the assist range if provided
    if range and string.match(range, "^%d+$") then
        gui.assistRange = tonumber(range)
        print("Assist Range set to", gui.assistRange)
    else
        print("Assist Range not provided or invalid. Current range:", gui.assistRange)
    end

    -- Set the assist percent if provided
    if percent and string.match(percent, "^%d+$") then
        gui.assistPercent = tonumber(percent)
        print("Assist Percent set to", gui.assistPercent)
    else
        print("Assist Percent not provided or invalid. Current percent:", gui.assistPercent)
    end
end

local function setChaseOnOff(value)
    if value == "" then
        print("Usage: /convENC Chase <targetName> <distance> or /convENC Chase off/on")
    elseif value == 'on' then
        gui.chaseOn = true
        gui.returnToCamp = false
        gui.pullOn = false
        print("Chase enabled.")
    elseif value == 'off' then
        gui.chaseOn = false
        print("Chase disabled.")
    else
        -- Split value into targetName and distance
        local targetName, distanceStr = value:match("^(%S+)%s*(%S*)$")
        
        if not targetName then
            print("Invalid input. Usage: /convENC Chase <targetName> <distance>")
            return
        end
        
        -- Convert distance to a number, if it's provided
        local distance = tonumber(distanceStr)
        
        -- Check if distance is valid
        if not distance then
            print("Invalid distance provided. Usage: /convENC Chase <targetName> <distance> or /convENC Chase off")
            return
        end
        
        -- Pass targetName and valid distance to setChaseTargetAndDistance
        nav.setChaseTargetAndDistance(targetName, distance)
    end
end

-- Combined function for setting camp, return to camp, and chase
local function setCampHere(value1)
    if value1 == "on" then
        gui.chaseOn = false
        gui.campLocation = nav.setCamp()
        gui.returnToCamp = true
        gui.campDistance = gui.campDistance or 10
        print("Camp location set to current spot. Return to Camp enabled with default distance:", gui.campDistance)
    elseif value1 == "off" then
        -- Disable return to camp
        gui.returnToCamp = false
        print("Return To Camp disabled.")
    elseif tonumber(value1) then
        gui.chaseOn = false
        gui.campLocation = nav.setCamp()
        gui.returnToCamp = true
        gui.campDistance = tonumber(value1)
        print("Camp location set with distance:", gui.campDistance)
    else
        print("Error: Invalid command. Usage: /convENC camphere <distance>, /convENC camphere on, /convENC camphere off")
    end
end

local function setMezIgnore(scope, action)
    -- Check for a valid target name
    local targetName = mq.TLO.Target.CleanName()
    if not targetName then
        print("Error: No target selected. Please target a mob to modify the mez ignore list.")
        return
    end

    -- Determine if the scope is global or zone-specific
    local isGlobal = (scope == "global")

    if action == "add" then
        utils.addMobToMezIgnoreList(targetName, isGlobal)
        local scopeText = isGlobal and "global quest NPC ignore list" or "mez ignore list for the current zone"
        print(string.format("'%s' has been added to the %s.", targetName, scopeText))

    elseif action == "remove" then
        utils.removeMobFromMezIgnoreList(targetName, isGlobal)
        local scopeText = isGlobal and "global quest NPC ignore list" or "mez ignore list for the current zone"
        print(string.format("'%s' has been removed from the %s.", targetName, scopeText))

    else
        print("Error: Invalid action. Usage: /convENC mezignore zone/global add/remove")
    end
end


local function commandHandler(command, ...)
    -- Convert command and arguments to lowercase for case-insensitive matching
    command = string.lower(command)
    local args = {...}
    for i, arg in ipairs(args) do
        args[i] = string.lower(arg)
    end

    if command == "exit" then
        setExit()
    elseif command == "bot" then
        setBotOnOff(args[1])
    elseif command == "save" then
        setSave()
    elseif command == "assist" then
        setAssist(args[1], args[2], args[3])
    elseif command == "switchwithma" then
        setSwitchWithMA(args[1])
    elseif command == "camphere" then
        setCampHere(args[1])
    elseif command == "chase" then
        local chaseValue = args[1]
        if args[2] then
            chaseValue = chaseValue .. " " .. args[2]
        end
        setChaseOnOff(chaseValue)
    elseif command == "mez" then
        setMez(args[1])
    elseif command == "mezradius" then
        setMezRadius(args[1])
    elseif command == "tashmez" then
        setTashMez(args[1])
    elseif command == "mezstoppercent" then
        setMezStopPercent(args[1])
    elseif command == "mezamount" then
        setMezAmount(args[1])
    elseif command == "mezignore" then
        setMezIgnore(args[1], args[2])
    elseif command == "sitmed" then
        setSitMedOnOff(args[1])
    elseif command == "buffs" then
        setBuffs(args[1])
    elseif command == "buffgroup" then
        setBuffGroup(args[1])
    elseif command == "buffraid" then
        setBuffRaid(args[1])
    elseif command == "haste" then
        sethastebuff(args[1])
    elseif command == "manaregen" then
        setmanaregenbuff(args[1])
    elseif command == "intwis" then
        setintwisbuff(args[1])
    elseif command == "magicresist" then
        setmagicresistbuff(args[1])
    elseif command == "tash" then
        setTash(args[1])
    elseif command == "slow" then
        setSlow(args[1])
    elseif command == "cripple" then
        setCripple(args[1])
    end
end

function commands.init()
    -- Single binding for the /convENC command
    mq.bind('/convENC', function(command, ...)
        commandHandler(command, ...)
    end)
end

function commands.initALL()
    -- Single binding for the /convBRD command
    mq.bind('/convALL', function(command, ...)
        commandHandler(command, ...)
    end)
end

return commands