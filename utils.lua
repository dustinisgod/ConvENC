local mq = require('mq')
local gui = require('gui')
local nav = require('nav')

local utils = {}

utils.IsUsingDanNet = true
utils.IsUsingTwist = false
utils.IsUsingCast = true
utils.IsUsingMelee = false

utils.mezConfig = {}
local mezConfigPath = mq.configDir .. '/' .. 'Conv_mez_ignore_list.lua'

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

function utils.PluginCheck()
    if utils.IsUsingDanNet then
        if not mq.TLO.Plugin('mq2dannet').IsLoaded() then
            printf("Plugin \ayMQ2DanNet\ax is required. Loading it now.")
            mq.cmd('/plugin mq2dannet noauto')
        end
        -- turn off fullname mode in DanNet
        if mq.TLO.DanNet.FullNames() then
            mq.cmd('/dnet fullnames off')
        end
        if utils.IsUsingTwist then
            if not mq.TLO.Plugin('mq2twist').IsLoaded() then
                printf("Plugin \ayMQ2Twist\ax is required. Loading it now.")
                mq.cmd('/plugin mq2twist noauto')
            end
        end
        if utils.IsUsingCast then
            if not mq.TLO.Plugin('mq2cast').IsLoaded() then
                printf("Plugin \ayMQ2Cast\ax is required. Loading it now.")
                mq.cmd('/plugin mq2cast noauto')
            end
        end
        if not utils.IsUsingMelee then
            if mq.TLO.Plugin('mq2melee').IsLoaded() then
                printf("Plugin \ayMQ2Melee\ax is not recommended. Unloading it now.")
                mq.cmd('/plugin mq2melee unload')
            end
        end
    end
end

-- Helper function to check if the target is in campQueue
function utils.isTargetInCampQueue(targetID)
    local pull = require('pull')
    for _, mob in ipairs(pull.campQueue) do
        if mob.ID() == targetID then
            return true
        end
    end
    return false
end

local lastNavTime = 0

function utils.monitorNav()

    if gui.botOn and (gui.chaseOn or gui.returnToCamp) and not gui.pullOn then
        if not gui then
            printf("Error: gui is nil")
            return
        end

        local currentTime = os.time()

        if gui.returnToCamp and (currentTime - lastNavTime >= 5) then
            debugPrint("DEBUG: Checking camp distance...")
            nav.checkCampDistance()
            lastNavTime = currentTime
        elseif gui.chaseOn and (currentTime - lastNavTime >= 2) then
            debugPrint("DEBUG: Chasing...")
            nav.chase()
            lastNavTime = currentTime
        end
    else
        return
    end
end

utils.nextBuffTime = 0  -- Global variable to track next scheduled time

function utils.monitorBuffs()
    if not gui or not gui.botOn or not gui.buffsOn then
        debugPrint("DEBUG: Bot is off or gui is nil.")
        return
    end

    local buffer = require('buffer')
    local currentTime = os.time()

    if (gui.intwisbuff or gui.manaRegen or gui.hastebuff or gui.magicresistbuff or gui.selfshield) and (currentTime >= utils.nextBuffTime) then
        if mq.TLO.Me.PctMana() > 20 then
            debugPrint("DEBUG: Running buff routine...")
            buffer.buffRoutine()
            utils.nextBuffTime = currentTime + 240  -- Schedule next run in 240 seconds
        end
    end
end


function utils.sitMed()
    if not (gui.botOn and gui.sitMed) then return end
    if mq.TLO.Me.PctMana() >= 100 or mq.TLO.Me.Mount() then return end
    if mq.TLO.Me.PctHPs() < 90 then return end
    if mq.TLO.Me.Casting() or mq.TLO.Me.Moving() then return end
    if not mq.TLO.Me.Sitting() then
        debugPrint("DEBUG: Sitting to meditate...")
        mq.cmd('/sit')
        mq.delay(100)
    end
end

function utils.setMainAssist(charName)
    if charName and charName ~= "" then
        -- Remove spaces, numbers, and symbols
        charName = charName:gsub("[^%a]", "")
        
        -- Capitalize the first letter and make the rest lowercase
        charName = charName:sub(1, 1):upper() .. charName:sub(2):lower()

        gui.mainAssist = charName
    end
end

-- Utility function to check if a table contains a given value
function utils.tableContains(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

local hasLoggedError = false

function utils.referenceLocation(range)
    range = range or 100  -- Set a default range if none is provided

    -- Determine reference location based on returnToCamp or chaseOn settings
    local referenceLocation
    if gui.returnToCamp then
        nav.campLocation = nav.campLocation or {x = 0, y = 0, z = 0}  -- Initialize campLocation with a default if needed
        referenceLocation = {x = nav.campLocation.x, y = nav.campLocation.y, z = nav.campLocation.z}
    elseif gui.chaseOn then
        local mainAssistSpawn = mq.TLO.Spawn(gui.mainAssist)
        if mainAssistSpawn() then
            referenceLocation = {x = mainAssistSpawn.X(), y = mainAssistSpawn.Y(), z = mainAssistSpawn.Z()}
        else
            if not hasLoggedError then
                hasLoggedError = true
            end
            return {}  -- Return an empty table if no valid main assist found
        end
    else
        if not hasLoggedError then
            hasLoggedError = true
        end
        return {}  -- Return an empty table if neither returnToCamp nor chaseOn is enabled
    end

    -- Reset error flag if a valid location is found
    hasLoggedError = false

    local mobsInRange = mq.getFilteredSpawns(function(spawn)
        local mobX, mobY, mobZ = spawn.X(), spawn.Y(), spawn.Z()
        if not mobX or not mobY or not mobZ then
            return false  -- Skip this spawn if any coordinate is nil
        end

        local distanceToReference = math.sqrt((referenceLocation.x - mobX)^2 +
                                              (referenceLocation.y - mobY)^2 +
                                              (referenceLocation.z - mobZ)^2)
                                              
        -- Check for NPC type, distance within range, and LOS to the reference point
        return spawn.Type() == 'NPC' and distanceToReference <= range and spawn.LineOfSight()
    end)

    return mobsInRange  -- Return the list of mobs in range and within LOS
end

-- Load the mez ignore list from the config file
function utils.loadMezConfig()
    local configData, err = loadfile(mezConfigPath)
    if configData then
        local config = configData() or {}
        
        -- Load each zone-specific list
        for zone, mobs in pairs(config) do
            utils.mezConfig[zone] = mobs
        end
        
        -- Ensure the global ignore list is always loaded and initialized
        utils.mezConfig.globalIgnoreList = utils.mezConfig.globalIgnoreList or {}
        
        print("Mez ignore list loaded from " .. mezConfigPath)
    else
        print("No mez ignore list found. Starting with an empty list.")
        utils.mezConfig = {globalIgnoreList = {}}  -- Initialize with an empty global list
    end
end

-- Function to add a mob to the ignore list using its clean name
function utils.addMobToMezIgnoreList(targetName, isGlobal)
    local zoneName = isGlobal and "globalIgnoreList" or mq.TLO.Zone.ShortName() or "UnknownZone"
    
    if targetName then
        -- Ensure the zone or global list has an entry in the table
        utils.mezConfig[zoneName] = utils.mezConfig[zoneName] or {}
        
        -- Add the mob's clean name to the appropriate ignore list if not already present
        if not utils.mezConfig[zoneName][targetName] then
            utils.mezConfig[zoneName][targetName] = true
            print(string.format("Added '%s' to the ignore list for '%s'.", targetName, zoneName))
            utils.saveMezConfig() -- Save the configuration after adding
        else
            print(string.format("'%s' is already in the ignore list for '%s'.", targetName, zoneName))
        end
    else
        print("Error: No target selected. Please target a mob to add it to the ignore list.")
    end
end

-- Function to remove a mob from the ignore list using its clean name
function utils.removeMobFromMezIgnoreList(targetName, isGlobal)
    local zoneName = isGlobal and "globalIgnoreList" or mq.TLO.Zone.ShortName() or "UnknownZone"
    
    if targetName then
        -- Check if the zone or global entry exists in the ignore list
        if utils.mezConfig[zoneName] and utils.mezConfig[zoneName][targetName] then
            utils.mezConfig[zoneName][targetName] = nil  -- Remove the mob entry
            print(string.format("Removed '%s' from the ignore list for '%s'.", targetName, zoneName))
            utils.saveMezConfig()  -- Save the updated ignore list
        else
            print(string.format("'%s' is not in the ignore list for '%s'.", targetName, zoneName))
        end
    else
        print("Error: No target selected. Please target a mob to remove it from the ignore list.")
    end
end

-- Save the mez ignore list to the config file
function utils.saveMezConfig()
    local config = {}
    for zone, mobs in pairs(utils.mezConfig) do
        config[zone] = mobs
    end
    mq.pickle(mezConfigPath, config)
    print("Mez ignore list saved to " .. mezConfigPath)
end

return utils