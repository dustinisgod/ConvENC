local mq = require('mq')
local gui = require('gui')
local spells = require('spells')

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
    local assistRange = gui.assistRange
    local nearbyMobs = mq.getFilteredSpawns(function(spawn)
        return spawn.Type() == "NPC" and spawn.Distance() <= assistRange and spawn.LineOfSight()
    end)

    for _, mob in ipairs(nearbyMobs) do
        local mobID = mob.ID()
        
        -- Target the mob and check if it's already crippled
        mq.cmdf("/target id %d", mobID)
        mq.delay(100, function() return mq.TLO.Target.ID() == mobID end)

        if not mq.TLO.Target.Crippled() and not isCrippledRecently(mobID) then
            return mob
        end
    end
    return nil
end

function cripple.crippleRoutine()
    local crippleSpell = spells.findBestSpell("Cripple", charLevel)
    local mob = findNearbyUncrippledMob()
    
    if crippleSpell and mob and gui.crippleOn then
        local mobID = mob.ID()

        if mq.TLO.Me.PctMana() < 10 then
            return
        end

        if mq.TLO.Spell(crippleSpell).Mana() > mq.TLO.Me.CurrentMana() then
            return
        end
        
        if mq.TLO.Me.Gem(3)() ~= crippleSpell then
            spells.loadAndMemorizeSpell("Cripple", charLevel, 3)
            debugPrint("DEBUG: Loaded Cripple spell in slot 3")
        end

        local readyAttempt = 0
        while not mq.TLO.Me.SpellReady(crippleSpell)() and readyAttempt < 20 do
            readyAttempt = readyAttempt + 1
            debugPrint("DEBUG: Waiting for Cripple spell to be ready, attempt:", readyAttempt)
            mq.delay(500)
        end

        debugPrint("DEBUG: Casting Cripple on mob - ID:", mobID)
        mq.cmdf("/cast %d", 3)
        mq.delay(100)

        while mq.TLO.Me.Casting() do
            if mq.TLO.Target.Crippled() then
                debugPrint("DEBUG: Cripple successfully applied to mob - ID:", mobID)
                addToQueue(mobID)
                mq.delay(100)
                break
            end
            mq.delay(10)
        end

        if mq.TLO.Target.Crippled() then
            addToQueue(mobID)
            return true
        end
    end
end

return cripple