local mq = require('mq')
local gui = require('gui')
local spells = require('spells')

local tash = {}

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local tashQueue = {} -- Table to keep track of tashed mobs with timestamps
local tashDuration = 30 -- Duration in seconds to keep a mob in the queue

local charLevel = mq.TLO.Me.Level()
debugPrint("DEBUG: Character level:", charLevel)

local function isTashedRecently(mobID)
    local entry = tashQueue[mobID]
    if entry then
        local elapsed = os.time() - entry
        if elapsed < tashDuration then
            return true
        else
            tashQueue[mobID] = nil -- Remove expired entry
        end
    end
    return false
end

local function addToQueue(mobID)
    tashQueue[mobID] = os.time()
end

local function findNearbyUntashedMob()
    local assistRange = gui.assistRange
    local nearbyMobs = mq.getFilteredSpawns(function(spawn)
        return spawn.Type() == "NPC" and spawn.Distance() <= assistRange
    end)

    for _, mob in ipairs(nearbyMobs) do
        local mobID = mob.ID()
        
        -- Target the mob and check if it's already tashed
        mq.cmdf("/target id %d", mobID)
        mq.delay(100, function() return mq.TLO.Target.ID() == mobID end)

        if not mq.TLO.Target.Tashed() and not isTashedRecently(mobID) then
            return mob
        end
    end
    return nil
end

function tash.tashRoutine()
    local tashSpell = spells.findBestSpell("Tash", charLevel)
    local mob = findNearbyUntashedMob()

    if tashSpell and mob and gui.tashOn then
        local mobID = mob.ID()

        if mq.TLO.Me.PctMana() < 10 then
            return
        end

        if mq.TLO.Me.Gem(1)() ~= tashSpell then
            spells.loadAndMemorizeSpell("Tash", charLevel, 1)
            debugPrint("DEBUG: Loaded Tash spell in slot 1")
        end

        local readyAttempt = 0
        while not mq.TLO.Me.SpellReady(tashSpell)() and readyAttempt < 20 do
            readyAttempt = readyAttempt + 1
            debugPrint("DEBUG: Waiting for Tash spell to be ready, attempt:", readyAttempt)
            mq.delay(500)
        end

        debugPrint("DEBUG: Casting Tash on mob - ID:", mobID)
        mq.cmdf("/cast %d", 1)
        mq.delay(100)

        while mq.TLO.Me.Casting() do
            if mq.TLO.Target.Tashed() then
                debugPrint("DEBUG: Tash successfully applied to mob - ID:", mobID)
                addToQueue(mobID)
                mq.delay(100)
                break
            end
            mq.delay(10)
        end

        if mq.TLO.Target.Tashed() then
            addToQueue(mobID)
            return true
        end
    end
end

return tash