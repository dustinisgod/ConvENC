mq = require('mq')
local gui = require('gui')
local DEBUG_MODE = true
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end
local spells = {
    Tash = {
	    {level = 57, name = "Tashanian"},
        {level = 41, name = "Tashania"},
        {level = 18, name = "Tashani"},
        {level = 2, name = "Tashina"}
    },
    Mez = {
	    {level = 54, name = "Glamour of Kintaz"},
        {level = 52, name = "Fascination"},
        {level = 47, name = "Dazzle"},
		{level = 13, name = "Enthrall"},
        {level = 2, name = "Mesmerize"}
    },
	Slow = {
        {level = 57, name = "Forlorn Deeds"},
        {level = 53, name = "Cripple"},
        {level = 41, name = "Shiftless Deeds"},
        {level = 36, name = "Insipid Weakness"},
        {level = 23, name = "Tepid Deeds"},
        {level = 9, name = "Languid Pace"}
    },
    Cripple = {
        {level = 53, name = "Cripple"},
		{level = 42, name = "Weakness"},
		{level = 40, name = "Incapacitate"},
        {level = 36, name = "Insipid Weakness"},
        {level = 23, name = "Listless Power"},
		{level = 16, name = "Disempower"},
        {level = 9, name = "Ebbing Strength"},
        {level = 4, name = "Enfeeblement"},
        {level = 1, name = "Weaken"}
    },
    Charm = {
	    {level = 53, name = "Boltran's Agacerie"},
        {level = 46, name = "Allure"},
        {level = 37, name = "Cajoling Whispers"},
        {level = 30, name = "Entrance"},
        {level = 23, name = "Beguile"},
        {level = 11, name = "Charm"}
    },
    ManaRegenBuff = {
        {level = 60, name = "Koadic's Endless Intellect"},
        {level = 56, name = "Gift of Pure Thought"},
		{level = 42, name = "Boon of the Clear Mind"},
        {level = 26, name = "Clarity"},
        {level = 14, name = "Breeze"}
    },
	HasteBuff = {
        {level = 60, name = "Visions of Grandeur"},
        {level = 58, name = "Wondrous Rapidity"},
        {level = 47, name = "Swift Like the Wind"},
		{level = 39, name = "Celerity"},
        {level = 28, name = "Augmentation"},
		{level = 21, name = "Alacrity"},
		{level = 15, name = "Quickness"}
    },
    MagicResistBuff = {
        {level = 48, name = "Group Resist Magic"},
        {level = 37, name = "Resist Magic"},
		{level = 17, name = "Endure Magic"}
    },
    IntWisBuff = {
        {level = 57, name = "Enlightenment"},
        {level = 41, name = "Brilliance"},
        {level = 35, name = "Insight"}
    },
	ACBuff = {
	    {level = 54, name = "Shield of the Magi"},
	    {level = 40, name = "Arch Shielding"},
        {level = 31, name = "Greater Shielding"},
	    {level = 23, name = "Major Shielding"},
        {level = 16, name = "Shielding"},
	    {level = 10, name = "Minor Shielding"},
        {level = 9, name = "Lesser Shielding"},
        {level = 1, name = "Minor Shielding"}
	}
}
-- Function to find the best spell for a given type and level
function spells.findBestSpell(spellType, charLevel)
    local spells = spells[spellType]
    if not spells then
        return nil -- Return nil if the spell type doesn't exist
    end
    -- Skip BuffHPOnly and BuffACOnly if cleric level is 58 or higher, as Aegolism line covers all three buffs
    if charLevel == 60 and mq.TLO.Me.Book("Koadic's Endless Intellect")() and spellType == "IntWisBuff" then
        return nil
    end
    if spellType == "ManaRegenBuff" and charLevel == 60 then
        if mq.TLO.Me.Book("Koadic's Endless Intellect")() then
            return "Koadic's Endless Intellect"
        else
            return "Gift of Pure Thought"
        end
    end
    if spellType == "HasteBuff" and charLevel == 60 then
        if mq.TLO.Me.Book("Visions of Grandeur")() then
            return "Visions of Grandeur"
        else
            return "Wondrous Rapidity"
        end
    end
    -- General spell search for other types and levels
    for _, spell in ipairs(spells) do
        if charLevel >= spell.level then
            return spell.name
        end
    end
    return nil
end
function spells.loadDefaultSpells(charLevel)
    local defaultSpells = {}
    if gui.tashOn and charLevel >= 2 then
        defaultSpells[1] = spells.findBestSpell("Tash", charLevel)
    end
    if gui.mezOn and charLevel >= 2 then
        defaultSpells[2] = spells.findBestSpell("Mez", charLevel)
    end
    if gui.slowOn and charLevel >= 9 then
        defaultSpells[3] = spells.findBestSpell("Slow", charLevel)
    end
    if gui.crippleOn and charLevel >= 2 then
        defaultSpells[4] = spells.findBestSpell("Cripple", charLevel)
    end
    if gui.charmOn and charLevel >= 11 then
        defaultSpells[5] = spells.findBestSpell("Charm", charLevel)
    end
    if gui.intWisBuff and charLevel >= 35 then
        defaultSpells[6] = spells.findBestSpell("IntWisBuff", charLevel)
    end
    if gui.manaRegen and charLevel >= 14 then
        defaultSpells[7] = spells.findBestSpell("ManaRegenBuff", charLevel)
    end
    if gui.hasteBuff and charLevel >= 15 then
        defaultSpells[8] = spells.findBestSpell("HasteBuff", charLevel)
    end
    if gui.magicResistBuff and charLevel >= 17 then
        defaultSpells[9] = spells.findBestSpell("MagicResistBuff", charLevel)
    end
    if charLevel > 0 then
        defaultSpells[10] = spells.findBestSpell("ACBuff", charLevel)
    end
    return defaultSpells
end

-- Function to memorize spells in the correct slots with delay
function spells.memorizeSpells(spells)
    for slot, spellName in pairs(spells) do
        if spellName then
            -- Check if the spell is already in the correct slot
            if mq.TLO.Me.Gem(slot)() == spellName then
                printf(string.format("Spell %s is already memorized in slot %d", spellName, slot))
            else
                -- Clear the slot first to avoid conflicts
                mq.cmdf('/mem "" %d', slot)
                mq.delay(500)  -- Short delay to allow the slot to clear

                -- Issue the /mem command to memorize the spell in the slot
                mq.cmdf('/mem "%s" %d', spellName, slot)
                mq.delay(1000)  -- Initial delay to allow the memorization command to take effect

                -- Loop to check if the spell is correctly memorized
                local maxAttempts = 10
                local attempt = 0
                while mq.TLO.Me.Gem(slot)() ~= spellName and attempt < maxAttempts do
                    mq.delay(500)  -- Check every 0.5 seconds
                    attempt = attempt + 1
                end

                -- Check if memorization was successful
                if mq.TLO.Me.Gem(slot)() ~= spellName then
                    printf(string.format("Failed to memorize spell: %s in slot %d", spellName, slot))
                else
                    printf(string.format("Successfully memorized %s in slot %d", spellName, slot))
                end
            end
        end
    end
end


function spells.loadAndMemorizeSpell(spellType, level, spellSlot)

    local bestSpell = spells.findBestSpell(spellType, level)

    if not bestSpell then
        printf("No spell found for type: " .. spellType .. " at level: " .. level)
        return
    end

    -- Check if the spell is already in the correct spell gem slot
    if mq.TLO.Me.Gem(spellSlot).Name() == bestSpell then
        printf("Spell " .. bestSpell .. " is already memorized in slot " .. spellSlot)
        return true
    end

    -- Memorize the spell in the correct slot
    mq.cmdf('/mem "%s" %d', bestSpell, spellSlot)

    -- Add a delay to wait for the spell to be memorized
    local maxAttempts = 10
    local attempt = 0
    while mq.TLO.Me.Gem(spellSlot).Name() ~= bestSpell and attempt < maxAttempts do
        mq.delay(2000) -- Wait 2 seconds before checking again
        attempt = attempt + 1
    end

    -- Check if the spell is now memorized correctly
    if mq.TLO.Me.Gem(spellSlot).Name() == bestSpell then
        printf("Successfully memorized spell " .. bestSpell .. " in slot " .. spellSlot)
        return true
    else
        printf("Failed to memorize spell " .. bestSpell .. " in slot " .. spellSlot)
        return false
    end
end

function spells.startup(charLevel)

    local defaultSpells = spells.loadDefaultSpells(charLevel)

    spells.memorizeSpells(defaultSpells)
end

return spells