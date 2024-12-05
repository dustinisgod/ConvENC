local mq = require('mq')
local gui = require('gui')
local spells = require('spells')
local utils = require('utils')

local cripple = {}

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local crippleQueue = {} -- Table to keep track of crippled mobs with timestamps
local crippleDuration = 30 -- Duration in seconds to keep a mob in the queue

local charLevel = mq.TLO.Me.Level()
debugPrint("DEBUG: Character level:", charLevel)

local function isCrippledRecently(mobID)
    local entry = crippleQueue[mobID]
    if entry then
        local elapsed = os.time() - entry
        if elapsed < crippleDuration then
            return true
        else
            crippleQueue[mobID] = nil -- Remove expired entry
        end
    end
    return false
end

local function addToQueue(mobID)
    crippleQueue[mobID] = os.time()
end

local function findNearbyUncrippledMob()
    local crippleradius = gui.crippleRadius
    local currentZone = mq.TLO.Zone.ShortName()
    local nearbyMobs = mq.getFilteredSpawns(function(spawn)
        return spawn.Type() == "NPC" and spawn.Distance() <= crippleradius and spawn.LineOfSight() and (not gui.crippleNamedOnly or spawn.Named())
    end)

    if not nearbyMobs or #nearbyMobs == 0 then
        debugPrint("DEBUG: No nearby mobs found.")
        return nil
    end

    for _, mob in ipairs(nearbyMobs) do
        local mobID = mob.ID()
        local mobName = mob.CleanName()

        -- Check crippleConfig for the current zone and mob name or global ignore list
        if (utils.crippleConfig.globalIgnoreList and utils.crippleConfig.globalIgnoreList[mobName]) or
        (utils.crippleConfig[currentZone] and utils.crippleConfig[currentZone][mobName]) then
            debugPrint("DEBUG: Skipping mob:", mobName, "as it is in the crippleConfig global or zone-specific list.")
            goto continue
        end

        debugPrint("DEBUG: Checking mob ID:", mobID)

        -- Target the mob and check if it's uncrippled
        mq.cmdf("/target id %d", mobID)
        mq.delay(100, function() return mq.TLO.Target.ID() == mobID end)

        if mq.TLO.Target() and mobID and mq.TLO.Target.ID() == mobID and not mq.TLO.Target.Crippled() and not isCrippledRecently(mobID) then
            debugPrint("DEBUG: Found uncrippled mob:", mobName)
            return mob
        end

        ::continue::
    end

    debugPrint("DEBUG: No uncrippled mobs found.")
    return nil
end

function cripple.crippleRoutine()

    if gui.botOn and gui.crippleOn and charLevel >= 18 then

        local crippleSpell = spells.findBestSpell("Cripple", charLevel)
        local mob = findNearbyUncrippledMob()

        if crippleSpell and mob and gui.crippleOn then
            local mobID = mob.ID()

            if mq.TLO.Me.PctMana() < 10 then
                return
            end

            if mq.TLO.Me.Gem(1)() ~= crippleSpell then
                spells.loadAndMemorizeSpell("Cripple", charLevel, 1)
                debugPrint("DEBUG: Loaded Cripple spell in slot 1")
            end

            local readyAttempt = 0
            while not mq.TLO.Me.SpellReady(crippleSpell)() and readyAttempt < 20 do
                readyAttempt = readyAttempt + 1
                debugPrint("DEBUG: Waiting for Cripple spell to be ready, attempt:", readyAttempt)
                mq.delay(500)
            end

            debugPrint("DEBUG: Casting Cripple on mob - ID:", mobID)
            mq.cmdf("/cast %s", crippleSpell)
            mq.delay(100)

            while mq.TLO.Target() and mq.TLO.Me.Casting() do
                if mq.TLO.Target() and mq.TLO.Target.Crippled() then
                    debugPrint("DEBUG: Cripple successfully applied to mob - ID:", mobID)
                    addToQueue(mobID)
                    mq.delay(100)
                    break
                end
                if mq.TLO.Target() and mq.TLO.Target.PctHPs() and mq.TLO.Target.PctHPs() <= (gui.crippleStopPercent or 20) and not mq.TLO.Target.Named() then
                    debugPrint("DEBUG: Stopping cast: target HP above: ", gui.crippleStopPercent)
                    mq.cmd('/stopcast')
                    break
                end
                mq.delay(10)
            end

            if mq.TLO.Target() and mq.TLO.Target.Crippled() then
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

return cripple