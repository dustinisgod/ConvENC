local mq = require('mq')
local spells = require('spells')
local utils = require('utils')
local gui = require('gui')
local mez = require('mez')

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local selfbuffer = {}
selfbuffer.buffQueue = {}

local charLevel = mq.TLO.Me.Level()

-- Helper function: Pre-cast checks for combat, movement, and casting status
local function preCastChecks()
    debugPrint("Checking pre-cast conditions")
    return not (mq.TLO.Me.Moving() or mq.TLO.Me.Combat() or mq.TLO.Me.Casting())
end

-- Helper function: Check if we have enough mana to cast the spell
local function hasEnoughMana(spellName)
    debugPrint("Checking mana for spell:", spellName)
    return spellName and mq.TLO.Me.CurrentMana() >= mq.TLO.Spell(spellName).Mana()
end

local function handleMezRoutineAndReturn()
    debugPrint("DEBUG: Running mez routine")
    mez.mezRoutine()
    utils.monitorNav()
    return true
end

function selfbuffer.selfbuffRoutine()
    if not gui.botOn and gui.buffsOn then return end

    if not preCastChecks() then
        debugPrint("Pre-cast checks failed")
        return
    end

    if mq.TLO.Me.PctMana() < 20 then
        debugPrint("Not enough mana to cast buffs")
        return
    end

    local spellTypes = {}

    -- Determine which buffs to apply based on the player's level and GUI settings
    if gui.buffsOn and charLevel >= 39 then
        debugPrint("Adding selfshield to queue")
        table.insert(spellTypes, "selfshield")
    end

    -- Process each spell type for self-buffing only
    for _, spellType in ipairs(spellTypes) do
        if not gui.botOn then return end

        local bestSpell = spells.findBestSpell(spellType, charLevel)
        if bestSpell then
            selfbuffer.buffQueue = {}
                debugPrint("Best spell for", spellType, "is", bestSpell)

            -- Define specific slots for each spell type
            local spellSlot
            if spellType == "selfshield" then
                spellSlot = 10
            else
                spellSlot = 10 -- Default slot for unspecified cases
            end

            -- Check if the spell is already memorized in the slot, load if necessary
            if mq.TLO.Me.Gem(spellSlot).Name() ~= bestSpell then
                spells.loadAndMemorizeSpell(spellType, charLevel, spellSlot)
            end

            -- Check if the buff is missing and if it stacks on the player
            if not mq.TLO.Me.Buff(bestSpell)() and mq.TLO.Spell(bestSpell).Stacks() then
                table.insert(selfbuffer.buffQueue, {spell = bestSpell, spellType = spellType, slot = spellSlot})
            end

            -- Process the buff queue
            selfbuffer.processBuffQueue()
        end
    end
end

function selfbuffer.processBuffQueue()
    while #selfbuffer.buffQueue > 0 do
        if not gui.botOn and gui.buffsOn then
            debugPrint("Bot is off, stopping buff routine")
            return
        end

        if not preCastChecks() then
            debugPrint("Pre-cast checks failed")
            return
        end

        if mq.TLO.Me.PctMana() < 20 then
            debugPrint("Not enough mana to cast buffs")
            return
        end

        local buffTask = table.remove(selfbuffer.buffQueue, 1)
        local maxReadyAttempts = 20
        local readyAttempt = 0

        -- Target self if casting AggroMultiplier
        if buffTask.spellType == "AggroMultiplier" then
            debugPrint("Casting AggroMultiplier, targeting self")
            mq.cmd("/target myself")
            mq.delay(100)
        end

        -- Ensure spell is ready before proceeding
        while not mq.TLO.Me.SpellReady(buffTask.spell)() and readyAttempt < maxReadyAttempts do
            if not handleMezRoutineAndReturn() then
                debugPrint("Tank routine failed")
                return
            end
                debugPrint("Spell not ready, waiting...")
            if not gui.botOn then
                debugPrint("Bot is off, stopping buff routine")
                return
            end
            readyAttempt = readyAttempt + 1
            mq.delay(1000)
        end

        if not mq.TLO.Me.SpellReady(buffTask.spell)() then
            debugPrint("Spell not ready after waiting")
            break
        end

        if not hasEnoughMana(buffTask.spell) then
            debugPrint("Not enough mana to cast", buffTask.spell)
            return
        end

        mq.cmdf('/cast %d', buffTask.slot)
        debugPrint("Casting", buffTask.spell)
        mq.delay(500)  -- Allow time for casting to start

        -- Wait for casting to complete, or stop if conditions are met
        while mq.TLO.Me.Casting() do
            debugPrint("Casting", buffTask.spell)
            mq.delay(50)
        end

        -- Reinsert into the queue if the buff was not applied successfully
        if not mq.TLO.Me.Buff(buffTask.spell)() then
            debugPrint("Failed to apply", buffTask.spell)
            table.insert(selfbuffer.buffQueue, buffTask)
        end

        mq.delay(100)
    end
end

return selfbuffer