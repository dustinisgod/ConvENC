local mq = require('mq')
local gui = require('gui')
local spells = require('spells')
local utils = require('utils')

local slow = {}

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local slowQueue = {} -- Table to keep track of slowed mobs with timestamps
local slowDuration = 30 -- Duration in seconds to keep a mob in the queue

local charLevel = mq.TLO.Me.Level()
debugPrint("DEBUG: Character level:", charLevel)

local function isSlowedRecently(mobID)
    local entry = slowQueue[mobID]
    if entry then
        local elapsed = os.time() - entry
        if elapsed < slowDuration then
            return true
        else
            slowQueue[mobID] = nil -- Remove expired entry
        end
    end
    return false
end

local function addToQueue(mobID)
    slowQueue[mobID] = os.time()
end

local function findNearbyUnslowedMob()
    local slowradius = gui.slowRadius
    local currentZone = mq.TLO.Zone.ShortName()
    local nearbyMobs = mq.getFilteredSpawns(function(spawn)
        return spawn.Type() == "NPC" and spawn.Distance() <= slowradius and spawn.LineOfSight() and (not gui.slowNamedOnly or spawn.Named())
    end)

    if not nearbyMobs or #nearbyMobs == 0 then
        debugPrint("DEBUG: No nearby mobs found.")
        return nil
    end

    for _, mob in ipairs(nearbyMobs) do
        local mobID = mob.ID()
        local mobName = mob.CleanName()

        -- Check slowConfig for the current zone and mob name or global ignore list
        if (utils.slowConfig.globalIgnoreList and utils.slowConfig.globalIgnoreList[mobName]) or
        (utils.slowConfig[currentZone] and utils.slowConfig[currentZone][mobName]) then
            debugPrint("DEBUG: Skipping mob:", mobName, "as it is in the slowConfig global or zone-specific list.")
            goto continue
        end

        debugPrint("DEBUG: Checking mob ID:", mobID)

        -- Target the mob and check if it's unslowed
        mq.cmdf("/target id %d", mobID)
        mq.delay(100, function() return mq.TLO.Target.ID() == mobID end)

        if mq.TLO.Target() and mobID and mq.TLO.Target.ID() == mobID and not mq.TLO.Target.Slowed() and not isSlowedRecently(mobID) then
            debugPrint("DEBUG: Found unslowed mob:", mobName)
            return mob
        end

        ::continue::
    end

    debugPrint("DEBUG: No unslowed mobs found.")
    return nil
end

function slow.slowRoutine()

    if gui.botOn and gui.slowOn and charLevel >= 18 then

        local slowSpell = spells.findBestSpell("Slow", charLevel)
        local mob = findNearbyUnslowedMob()

        if slowSpell and mob and gui.slowOn then
            local mobID = mob.ID()

            if mq.TLO.Me.PctMana() < 10 then
                return
            end

            if mq.TLO.Me.Gem(1)() ~= slowSpell then
                spells.loadAndMemorizeSpell("Slow", charLevel, 1)
                debugPrint("DEBUG: Loaded Slow spell in slot 1")
            end

            local readyAttempt = 0
            while not mq.TLO.Me.SpellReady(slowSpell)() and readyAttempt < 20 do
                readyAttempt = readyAttempt + 1
                debugPrint("DEBUG: Waiting for Slow spell to be ready, attempt:", readyAttempt)
                mq.delay(500)
            end

            if mq.TLO.Target() and mq.TLO.Target.LineOfSight() and not mq.TLO.Target.Slowed() then
                debugPrint("DEBUG: Casting Slow on mob - ID:", mobID)
                mq.cmdf("/cast %s", slowSpell)
                mq.delay(100)
            end

            while mq.TLO.Target() and mq.TLO.Me.Casting() do
                if mq.TLO.Target() and mq.TLO.Target.Slowed() then
                    debugPrint("DEBUG: Slow successfully applied to mob - ID:", mobID)
                    addToQueue(mobID)
                    mq.delay(100)
                    break
                end
                if mq.TLO.Target() and mq.TLO.Target.PctHPs() and mq.TLO.Target.PctHPs() <= (gui.slowStopPercent or 20) and not mq.TLO.Target.Named() then
                    debugPrint("DEBUG: Stopping cast: target HP above: ", gui.slowStopPercent)
                    mq.cmd('/stopcast')
                    break
                end
                mq.delay(10)
            end

            if mq.TLO.Target() and mq.TLO.Target.Slowed() then
                addToQueue(mobID)
                return true
            end
        else
            return
        end
    else
        return
    end
end

return slow