local mq = require('mq')
local ImGui = require('ImGui')

local charName = mq.TLO.Me.Name()
local configPath = mq.configDir .. '/' .. 'ConvENC_'.. charName .. '_config.lua'
local config = {}

local gui = {}

gui.isOpen = true

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local function setDefaultConfig()
    gui.botOn = false
    gui.mainAssist = ""
    gui.assistRange = 40
    gui.assistPercent = 95
    gui.switchWithMA = true
    gui.returnToCamp = false
    gui.campDistance = 10
    gui.chaseOn = false
    gui.chaseTarget = ""
    gui.chaseDistance = 20
    gui.mezOn = false
    gui.mezTashOn = false
    gui.mezAmount = 2
    gui.mezRadius = 50
    gui.mezStopPercent = 95
    gui.slowOn = false
    gui.tashOn = false
    gui.crippleOn = false
    gui.buffsOn = false
    gui.buffGroup = false
    gui.buffRaid = false
    gui.hastebuff = false
    gui.manaregenbuff = false
    gui.intwisbuff = false
    gui.magicresistbuff = false
    gui.selfshield = false
    gui.sitMed = false
end

function gui.saveConfig()
    for key, value in pairs(gui) do
        config[key] = value
    end
    mq.pickle(configPath, config)
    print("Configuration saved to " .. configPath)
end

local function loadConfig()
    local configData, err = loadfile(configPath)
    if configData then
        config = configData() or {}
        for key, value in pairs(config) do
            gui[key] = value
        end
    else
        print("Config file not found. Initializing with defaults.")
        setDefaultConfig()
        gui.saveConfig()
    end
end

loadConfig()

function ColoredText(text, color)
    ImGui.TextColored(color[1], color[2], color[3], color[4], text)
end

local function controlGUI()

    gui.isOpen, _ = ImGui.Begin("Convergence Enchanter", gui.isOpen, 2)

        if not gui.isOpen then
            mq.exit()
        end

        ImGui.SetWindowSize(440, 600)

        gui.botOn = ImGui.Checkbox("Bot On", gui.botOn or false)

        ImGui.SameLine()

        if ImGui.Button("Save Config") then
            gui.saveConfig()

            ImGui.Spacing()

        end

        if ImGui.CollapsingHeader("Assist Settings") then

            ImGui.Spacing()
            ImGui.SetNextItemWidth(100)
            gui.mainAssist = ImGui.InputText("Assist", gui.mainAssist)


            if ImGui.IsItemDeactivatedAfterEdit() then

                if gui.mainAssist ~= "" then
                    gui.mainAssist = gui.mainAssist:sub(1, 1):upper() .. gui.mainAssist:sub(2):lower()
                end
            end

            -- Validate the spawn if the input is non-empty
            if gui.mainAssist ~= "" then
                local spawn = mq.TLO.Spawn(gui.mainAssist)
                if not (spawn and spawn.Type() == "PC") or gui.mainAssist == charName then
                    ImGui.TextColored(1, 0, 0, 1, "Invalid Target")
                end
            end

            ImGui.Spacing()
            if gui.mainAssist ~= "" then
                ImGui.Spacing()
                ImGui.SetNextItemWidth(100)
                gui.assistRange = ImGui.SliderInt("Assist Range", gui.assistRange, 5, 200)
                ImGui.Spacing()
                ImGui.SetNextItemWidth(100)
                gui.assistPercent= ImGui.SliderInt("Assist %", gui.assistPercent, 5, 100)
                ImGui.Spacing()
            end
        end

        if ImGui.CollapsingHeader("Nav Settings") then

            ImGui.Spacing()

            local previousReturnToCamp = gui.returnToCamp or false
            local previousChaseOn = gui.chaseOn or false

            local currentReturnToCamp = ImGui.Checkbox("Return To Camp", gui.returnToCamp or false)
            if currentReturnToCamp ~= previousReturnToCamp then
                gui.returnToCamp = currentReturnToCamp
                    if gui.returnToCamp then
                        gui.chaseOn = false
                    else
                        local nav = require('nav')
                        nav.campLocation = nil
                    end
                previousReturnToCamp = currentReturnToCamp
            end

            if gui.returnToCamp then
                ImGui.SameLine()
                ImGui.SetNextItemWidth(100)
                gui.campDistance = ImGui.SliderInt("Camp Distance", gui.campDistance, 5, 200)
                ImGui.SameLine()
                ImGui.SetNextItemWidth(100)
                if ImGui.Button("Camp Here") then
                    local nav = require('nav')
                    nav.setCamp()
                end
            end

            local currentChaseOn = ImGui.Checkbox("Chase", gui.chaseOn or false)
            if currentChaseOn ~= previousChaseOn then
                gui.chaseOn = currentChaseOn
                    if gui.chaseOn then
                        local nav = require('nav')
                        gui.returnToCamp = false
                        nav.campLocation = nil
                        gui.pullOn = false
                    end
                previousChaseOn = currentChaseOn
            end

            if gui.chaseOn then
                ImGui.SameLine()
                ImGui.SetNextItemWidth(100)
                gui.chaseTarget = ImGui.InputText("Name", gui.chaseTarget)
                ImGui.SameLine()
                ImGui.SetNextItemWidth(100)
                gui.chaseDistance = ImGui.SliderInt("Chase Distance", gui.chaseDistance, 5, 200)
            end
        end

        ImGui.Spacing()

        if ImGui.CollapsingHeader("Mez Settings:") then

            ImGui.Spacing()

            gui.mezOn = ImGui.Checkbox("Mez", gui.mezOn or false)

            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()

            if gui.mezOn then
                -- Add Mob to Zone Ignore List Button
                if ImGui.Button("+ Mez Zone Ignore") then
                    local utils = require("utils")
                    local targetName = mq.TLO.Target.CleanName()
                    if targetName then
                        utils.addMobToMezIgnoreList(targetName)  -- Add to the zone-specific ignore list
                        print(string.format("'%s' has been added to the mez ignore list for the current zone.", targetName))
                    else
                        print("Error: No target selected. Please target a mob to add it to the mez ignore list.")
                    end
                end

                -- Remove Mob from Zone Ignore List Button
                if ImGui.Button("- Mez Zone Ignore") then
                    local utils = require("utils")
                    local targetName = mq.TLO.Target.CleanName()
                    if targetName then
                        utils.removeMobFromMezIgnoreList(targetName)  -- Remove from the zone-specific ignore list
                        print(string.format("'%s' has been removed from the mez ignore list for the current zone.", targetName))
                    else
                        print("Error: No target selected. Please target a mob to remove it from the mez ignore list.")
                    end
                end

                -- Add Mob to Global QuestNPC Ignore List Button
                if ImGui.Button("+ Mez Global Ignore") then
                    local utils = require("utils")
                    local targetName = mq.TLO.Target.CleanName()
                    if targetName then
                        utils.addMobToMezIgnoreList(targetName, true)  -- Add to the global ignore list
                        print(string.format("'%s' has been added to the global quest NPC ignore list.", targetName))
                    else
                        print("Error: No target selected. Please target a mob to add it to the global quest NPC ignore list.")
                    end
                end

                -- Remove Mob from Global QuestNPC Ignore List Button
                if ImGui.Button("- Mez Global Ignore") then
                    local utils = require("utils")
                    local targetName = mq.TLO.Target.CleanName()
                    if targetName then
                        utils.removeMobFromMezIgnoreList(targetName, true)  -- Remove from the global ignore list
                        print(string.format("'%s' has been removed from the global quest NPC ignore list.", targetName))
                    else
                        print("Error: No target selected. Please target a mob to remove it from the global quest NPC ignore list.")
                    end
                end

                ImGui.Spacing()

                gui.mezTashOn = ImGui.Checkbox("Tash Before Mez", gui.mezTashOn or false)
                if gui.mezTashOn then
                    gui.tashOn = false
                end
                ImGui.Spacing()
                ImGui.SetNextItemWidth(100)
                gui.mezAmount = ImGui.SliderInt("Amount In Camp", gui.mezAmount, 1, 20)
                ImGui.Spacing()
                ImGui.SetNextItemWidth(100)
                gui.mezRadius = ImGui.SliderInt("Radius", gui.mezRadius, 5, 100)
                ImGui.Spacing()
                ImGui.SetNextItemWidth(100)
                gui.mezStopPercent = ImGui.SliderInt("Stop %", gui.mezStopPercent, 1, 100)

                ImGui.Spacing()

            end
        end

        if ImGui.CollapsingHeader("DeBuff Settings") then

                ImGui.Spacing()

                gui.tashOn = ImGui.Checkbox("Tash", gui.tashOn or false)
                if gui.tashOn then
                    gui.mezTashOn = false
                end

                ImGui.Spacing()

                gui.slowOn = ImGui.Checkbox("Slow", gui.slowOn or false)

                ImGui.Spacing()

                gui.crippleOn = ImGui.Checkbox("Cripple", gui.crippleOn or false)

                ImGui.Spacing()

        end

        if ImGui.CollapsingHeader("Buff Settings") then
            gui.buffsOn = ImGui.Checkbox("Buffs", gui.buffsOn or false)
            if gui.buffsOn then

                if gui.botOn then
                    local utils = require("utils")
                    local currentTime = os.time()
                    local timeLeft = math.max(0, utils.nextBuffTime - currentTime)
        
                    if timeLeft > 0 then
                        ImGui.Text(string.format("Buff Check In: %d seconds", timeLeft))
                    else
                        ImGui.Text("Buff Check Running.")
                    end
                else
                    ImGui.Text("Bot is not active.")
                end

                ImGui.Spacing()

                gui.buffGroup = ImGui.Checkbox("Buff Group", gui.buffGroup or false)
                if gui.buffGroup then
                    gui.buffRaid = false
                end

                ImGui.SameLine()

                gui.buffRaid = ImGui.Checkbox("Buff Raid", gui.buffRaid or false)
                if gui.buffRaid then
                    gui.buffGroup = false
                end

                ImGui.Spacing()
                ImGui.Separator()
                ImGui.Spacing()

                gui.hastebuff = ImGui.Checkbox("Haste", gui.hastebuff or false)

                ImGui.Spacing()

                gui.manaregenbuff = ImGui.Checkbox("Mana Regen", gui.manaregenbuff or false)

                ImGui.Spacing()

                gui.intwisbuff = ImGui.Checkbox("Int/Wis", gui.intwisbuff or false)

                ImGui.Spacing()

                gui.magicresistbuff = ImGui.Checkbox("Magic Resist", gui.magicresistbuff or false)

                ImGui.Spacing()

                gui.selfshield = ImGui.Checkbox("Shield", gui.selfshield or false)

                ImGui.Spacing()

            end
        end

        if ImGui.CollapsingHeader("Misc Settings") then

            ImGui.Spacing()

            gui.sitMed = ImGui.Checkbox("Sit to Med", gui.sitMed or false)

            ImGui.Spacing()
        end
    ImGui.End()
end

gui.controlGUI = controlGUI

return gui