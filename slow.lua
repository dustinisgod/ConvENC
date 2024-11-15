local mq = require('mq')
local gui = require('gui')
local spells = require('spells')

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
    local assistRange = gui.assistRange
    local nearbyMobs = mq.getFilteredSpawns(function(spawn)
        return spawn.Type() == "NPC" and spawn.Distance() <= assistRange
    end)

    for _, mob in ipairs(nearbyMobs) do
        local mobID = mob.ID()
        
        -- Target the mob and check if it's already slowed
        mq.cmdf("/target id %d", mobID)
        mq.delay(100, function() return mq.TLO.Target.ID() == mobID end)

        if not mq.TLO.Target.Slowed() and not isSlowedRecently(mobID) then
            return mob
        end
    end
    return nil
end

function slow.slowRoutine()
    local slowSpell = spells.findBestSpell("Slow", charLevel)
    local mob = findNearbyUnslowedMob()
    
    if slowSpell and mob and gui.slowOn then
        local mobID = mob.ID()

        if mq.TLO.Me.PctMana() < 10 then
            return
        end

        if mq.TLO.Spell(slowSpell).Mana() > mq.TLO.Me.CurrentMana() then
            return
        end
        
        if mq.TLO.Me.Gem(3)() ~= slowSpell then
            spells.loadAndMemorizeSpell("Slow", charLevel, 3)
            debugPrint("DEBUG: Loaded Slow spell in slot 3")
        end

        local readyAttempt = 0
        while not mq.TLO.Me.SpellReady(slowSpell)() and readyAttempt < 20 do
            readyAttempt = readyAttempt + 1
            debugPrint("DEBUG: Waiting for Slow spell to be ready, attempt:", readyAttempt)
            mq.delay(500)
        end

        debugPrint("DEBUG: Casting Slow on mob - ID:", mobID)
        mq.cmdf("/cast %d", 3)
        mq.delay(100)

        while mq.TLO.Me.Casting() do
            if mq.TLO.Target.Slowed() then
                debugPrint("DEBUG: Slow successfully applied to mob - ID:", mobID)
                addToQueue(mobID)
                mq.delay(100)
                break
            end
            mq.delay(10)
        end

        if mq.TLO.Target.Slowed() then
            addToQueue(mobID)
            return true
        end
    end
end

return slow