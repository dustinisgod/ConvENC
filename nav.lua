local mq = require('mq')
local gui = require('gui')

local DEBUG_MODE = false

-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local nav = {}

nav.campLocation = nil

-- Function to set the camp location with zone information
function nav.setCamp()
    nav.campLocation = {
        x = mq.TLO.Me.X() or 0,
        y = mq.TLO.Me.Y() or 0,
        z = mq.TLO.Me.Z() or 0,
        zone = mq.TLO.Zone.ShortName()
    }
    print(string.format("Camp location set at your current position in zone %s.", nav.campLocation.zone))
end

function nav.clearCamp()
    nav.campLocation = nil
    print("Camp location cleared.")
end

-- Function to check distance from camp and return if out of range
function nav.checkCampDistance()
    if gui.botOn then
        debugPrint("checkcamp bot on.")
        if gui.returntocamp and nav.campLocation then
            debugPrint("returntocamp and camplocation.")
            -- Check if the character is in the same zone as the camp location
            if mq.TLO.Zone.ShortName() ~= nav.campLocation.zone then
                debugPrint("Character is not in the same zone as the camp location.")
                return
            end

            -- Retrieve current position
            local currentX = mq.TLO.Me.X() or 0
            local currentY = mq.TLO.Me.Y() or 0
            local currentZ = mq.TLO.Me.Z() or 0
            debugPrint(string.format("Current position: %f, %f, %f", currentX, currentY, currentZ))

            -- Calculate distance to camp using the distance formula
            local xyDistance = math.sqrt((nav.campLocation.x - currentX)^2 + (nav.campLocation.y - currentY)^2)
            local zDistance = math.abs(nav.campLocation.z - currentZ)
            debugPrint(string.format("Distance to camp: %f, %f", xyDistance, zDistance))
            
            -- Check if distance exceeds the camp radius (campDistance)
            if xyDistance > (gui.campDistance or 20) or zDistance > 20 and not mq.TLO.Me.Casting() and not mq.TLO.Stick.Active() then
                debugPrint("Returning to camp.", mq.TLO.Stick())
                mq.cmdf('/nav locyxz %f %f %f distance=5', nav.campLocation.y, nav.campLocation.x, nav.campLocation.z)
            
                local startTime = os.time()  -- Record the start time for timeout
                while mq.TLO.Me.Moving() do
                    mq.delay(100)
                    
                    -- Check if 10 seconds have passed
                    if os.time() - startTime >= 10 then
                        print("Timeout reached: Stopping navigation to camp.")
                        mq.cmd('/nav stop')
                        break
                    end
                end
            end
        end
    else
        debugPrint("checkcamp bot off.")
        return
    end
end

-- Function to follow a designated member within a specified distance
function nav.chase()
    if gui.botOn then
        if gui.chaseTarget ~= "" and gui.chaseDistance then
            local target = mq.TLO.Spawn(gui.chaseTarget)
            if target and target() then
                local distance = target.Distance3D() or 0
                if distance > gui.chaseDistance and mq.TLO.Stick() == "OFF" then
                    mq.cmdf('/nav id %d distance=5', target.ID())
                    while mq.TLO.Me.Moving() do
                        mq.delay(100)
                    end
                end
            end
        end
    else
        return
    end
end

-- Define setChaseTargetAndDistance within nav
function nav.setChaseTargetAndDistance(targetName, distance)
    if targetName and targetName ~= "" then
        -- Remove spaces, numbers, and symbols
        targetName = targetName:gsub("[^%a]", "")
        
        -- Capitalize the first letter and make the rest lowercase
        targetName = targetName:sub(1, 1):upper() .. targetName:sub(2):lower()
    end
    
    if targetName ~= "" then
        local targetSpawn = mq.TLO.Spawn(targetName)
        
        -- Validate target and path existence
        if targetSpawn and targetSpawn() and targetSpawn.Type() == 'PC' and mq.TLO.Navigation.PathExists("id " .. targetSpawn.ID())() then
            gui.chaseTarget = targetName
            gui.chaseDistance = distance
            gui.returntocamp = false  -- Disable Return to Camp
            gui.chaseon = true  -- Check Chase in the GUI
            print(string.format("Chasing %s within %d units.", gui.chaseTarget, gui.chaseDistance))
        else
            print("Error: Invalid target or no navigable path exists to the target.")
        end
    end
end

return nav