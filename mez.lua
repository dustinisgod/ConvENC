local mq = require('mq')
local spells = require('spells')
local gui = require('gui')
local utils = require('utils')
local tash = require('tash')

local mez = {}

-- Persistent queues for mezzing control
local notMezzableQueue = {}   -- Tracks unmezzable mobs due to level, repeated failure, etc.
local mezzedQueue = {}        -- Tracks mobs currently mezzed with sufficient duration and expiration

local charLevel = mq.TLO.Me.Level()

-- Constants
local NOT_MEZZABLE_EXPIRATION = 30  -- Expiration duration in seconds for `notMezzableQueue` entries
local MEZ_RECHECK_THRESHOLD = 8     -- Recheck only when mez duration is < 5 seconds

local DEBUG_MODE = true
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local function mezTashRoutine(mobID)
    local tashSpell = spells.findBestSpell("Tash", charLevel)
    if tashSpell and not mq.TLO.Target.Tashed() and gui.mezTashOn then
        debugPrint("DEBUG: Casting Tash on mob - ID:", mobID)
        if mq.TLO.Me.Gem(1)() ~= tashSpell then
            spells.loadAndMemorizeSpell("Tash", charLevel, 1)
            debugPrint("DEBUG: Loaded Tash spell in slot 1")
        end

        if mq.TLO.Spell(tashSpell).Mana() > mq.TLO.Me.CurrentMana() then
            return
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
                mq.delay(100)
                break
            end
            mq.delay(10)
        end

        if mq.TLO.Target.Tashed() then
            debugPrint("DEBUG: Tash successfully applied to mob - ID:", mobID)
            mq.delay(100)
            return true
        end
    end
end

-- Remove expired entries from `notMezzableQueue`
local function cleanupNotMezzableQueue()
    local currentTime = os.time()
    for mobID, timestamp in pairs(notMezzableQueue) do
        if currentTime - timestamp > NOT_MEZZABLE_EXPIRATION then
            notMezzableQueue[mobID] = nil
        end
    end
end

-- Update the expiration time for a mezzed mob
local function updateMezStatus(mobID, duration)
    mezzedQueue[mobID] = os.time() + duration
end

-- Check if a mob needs to be remezzed based on its remaining mez duration
local function shouldRemez(mobID)
    local expireTime = mezzedQueue[mobID]
    return expireTime and (expireTime - os.time() <= MEZ_RECHECK_THRESHOLD)
end

-- Main mezzing routine
function mez.mezRoutine()
        -- Check bot status and settings
    if not gui.botOn or not gui.mezOn or charLevel < 15 then
        return
    end

    -- Get mobs within the defined mez radius
    local mobsInRange = utils.referenceLocation(gui.mezRadius) or {}
    debugPrint("Mobs in range:", #mobsInRange)
    
    -- Check if enough mobs are present to initiate mezzing
    if #mobsInRange < (gui.mezAmount or 1) then
        return
    end

    -- Find the best mez spell for the character's level
    local bestMezSpell = spells.findBestSpell("Mez", charLevel)
    if not bestMezSpell then
        print("Error: No suitable mez spell found for level", charLevel)
        return
    end
    debugPrint("Best Mez Spell:", bestMezSpell)

    if mq.TLO.Spell(bestMezSpell).Mana() > mq.TLO.Me.CurrentMana() then
        return
    end

    ---@diagnostic disable-next-line: undefined-field
    local maxMezLevel = mq.TLO.Spell(bestMezSpell) and mq.TLO.Spell(bestMezSpell).MaxLevel() or 0
    debugPrint("Max Mez Level:", maxMezLevel)
    -- Clear expired entries from `notMezzableQueue`
    cleanupNotMezzableQueue()

    -- Populate mobQueue based on conditions and store mobs with their levels for sorting
    local mobQueue = {}

    for _, mob in ipairs(mobsInRange) do
        local mobID = mob.ID()
        local mobName = mob.CleanName()
        local mobLevel = mob.Level()

        debugPrint("Mob ID:", mobID, " Mob Name:", mobName, " Mob Level:", mobLevel)

        if mobID and mobName and mobLevel then
            if mobLevel > maxMezLevel then
                debugPrint("Mob is unmezzable due to level:", mobLevel)
                notMezzableQueue[mobID] = os.time()
            elseif utils.mezConfig[mq.TLO.Zone.ShortName()] and utils.mezConfig[mq.TLO.Zone.ShortName()][mobName] then
                debugPrint("Mob is unmezzable due to configuration.")
                notMezzableQueue[mobID] = os.time()
            elseif shouldRemez(mobID) or not mezzedQueue[mobID] then
                debugPrint("Mob is eligible for mezzing.")
                table.insert(mobQueue, {id = mobID, level = mobLevel})
            end
        end
    end

    -- Sort the mobQueue by level (lowest to highest)
    table.sort(mobQueue, function(a, b) return a.level < b.level end)

    -- Attempt to mez each mob in the sorted mobQueue
    for _, mobEntry in ipairs(mobQueue) do
        local mobID = mobEntry.id
        debugPrint("Mezzing mob ID:", mobID, " Level:", mobEntry.level)

        -- Reset attempt counters for each mob
        local attempts, mezSuccessful = 0, false

        while attempts < 2 and not mezSuccessful do
            attempts = attempts + 1
            debugPrint("Mezzing attempt:", attempts)

            if mq.TLO.Spell(bestMezSpell).Mana() > mq.TLO.Me.CurrentMana() then
                return
            end

            if mq.TLO.Target.ID() ~= mobID then
                debugPrint("Targeting mob ID:", mobID)
                mq.cmdf("/squelch /target id %d", mobID)
                mq.delay(500)
            end

            -- Validate target distance and health before mezzing
            if mq.TLO.Target() and mq.TLO.Target.Distance() > gui.mezRadius then
                debugPrint("Target out of range! Distance:", mq.TLO.Target.Distance(), " Radius: ", gui.mezRadius)
                break
            end

            -- Validate target distance and health before mezzing
            if mq.TLO.Target() and mq.TLO.Target.PctHPs() < gui.mezStopPercent then
                debugPrint("Target Hp to low!")
                break
            end

            if mq.TLO.Target() and not mq.TLO.Target.Tashed() and gui.mezTashOn then
                mezTashRoutine(mobID)
            end

            -- Attempt to cast mez
            if not mq.TLO.Target.Mezzed() or (mq.TLO.Target.Mezzed() and mq.TLO.Target.Mezzed.Duration() < MEZ_RECHECK_THRESHOLD) then

                mq.cmdf("/squelch /cast 2")
                debugPrint("Casting mez spell gem 2")
                mq.delay(100)

                -- Monitor casting completion and apply mez with a 4-second timeout
                local castStartTime = os.time()
                while mq.TLO.Me.Casting() do
                    if (os.time() - castStartTime) > 5 then
                        mq.cmd("/squelch /stopcast")
                        debugPrint("Casting timed out after 5 seconds.")
                        break
                    end

                    if mq.TLO.Target.ID() ~= mobID or mq.TLO.Target.Distance() > gui.mezRadius or mq.TLO.Target.PctHPs() < gui.mezStopPercent then
                        mq.cmd("/squelch /stopcast")
                        debugPrint("Casting interrupted: Range: " .. mq.TLO.Target.Distance() .. " HP%: " .. mq.TLO.Target.PctHPs())
                        break
                    elseif mq.TLO.Target.Mezzed() and mq.TLO.Target.Mezzed.Duration() > MEZ_RECHECK_THRESHOLD then
                        mq.cmd("/squelch /stopcast")
                        updateMezStatus(mobID, mq.TLO.Target.Mezzed.Duration() / 1000)
                        mezSuccessful = true
                        debugPrint("Mez successful.")
                        break
                    end

                    mq.delay(10)
                end

                mq.delay(100)

                if mq.TLO.Target.Mezzed() and mq.TLO.Target.Mezzed.Duration() > MEZ_RECHECK_THRESHOLD then
                updateMezStatus(mobID, mq.TLO.Target.Mezzed.Duration() / 1000)
                debugPrint("Mez successful on second check.")
                mezSuccessful = true
                break
                end

            elseif mq.TLO.Target.Mezzed() and mq.TLO.Target.Mezzed.Duration() > MEZ_RECHECK_THRESHOLD then
                updateMezStatus(mobID, mq.TLO.Target.Mezzed.Duration() / 1000)
                debugPrint("Mez successful on second check.")
                mezSuccessful = true
                break
            end
        end

        -- Add to `notMezzableQueue` if mezzing attempts failed
        if not mezSuccessful then
            print(string.format("Warning: Failed to mez mob ID %d after 2 attempts.", mobID))
            notMezzableQueue[mobID] = os.time()
            debugPrint("Adding mob ID to notMezzableQueue:", mobID)
        else
            mobQueue[mobID] = nil
            debugPrint("Removing mob ID from mobQueue:", mobID)
        end
        mq.delay(50)
    end
    debugPrint("Mezzing routine completed.")
end

return mez