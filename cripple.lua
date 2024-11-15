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

local charLevel = mq.TLO.Me.Level()
debugPrint("DEBUG: Character level:", charLevel)

function cripple.crippleRoutine(mobID)
    local crippleSpell = spells.findBestSpell("Cripple", charLevel)
    if crippleSpell and not mq.TLO.Target.Crippled() and gui.crippleOn then

        if mq.TLO.Me.PctMana() < 10 then
            return
        end

        if mq.TLO.Spell(crippleSpell).Mana() > mq.TLO.Me.CurrentMana() then
            return
        end

        if mq.TLO.Me.Gem(4)() ~= crippleSpell then
            spells.loadAndMemorizeSpell("Cripple", charLevel, 4)
            debugPrint("DEBUG: Loaded Cripple spell in slot 4")
        end

        local readyAttempt = 0
        while not mq.TLO.Me.SpellReady(crippleSpell)() and readyAttempt < 20 do
            readyAttempt = readyAttempt + 1
            debugPrint("DEBUG: Waiting for Cripple spell to be ready, attempt:", readyAttempt)
            mq.delay(500)
        end

        debugPrint("DEBUG: Casting Cripple on mob - ID:", mobID)
        mq.cmdf("/cast %d", 4)
        mq.delay(100)

        while mq.TLO.Me.Casting() do
            if mq.TLO.Target.Crippled() then
                debugPrint("DEBUG: Cripple successfully applied to mob - ID:", mobID)
                mq.delay(100)
                break
            end
            mq.delay(10)
        end

        if mq.TLO.Target.Crippled() then
            debugPrint("DEBUG: Cripple successfully applied to mob - ID:", mobID)
            mq.delay(100)
            return true
        end
    end
end

return cripple