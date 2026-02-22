-- This function simply sets the entity statebag deformation value
-- It will then be recognized on other clients and all apply deformation if possible
-- This seems to be the best and more accurate way to sync deformation with minimal performance impact
-- Being out of render or relogging does seem to sync the deformation, so it is of no concern that the entity state may not always be up to date
---@param veh integer
---@param deformation table
function SetDeformation(veh, deformation)
    Entity(veh).state:set("deformation", deformation, true)
end

-- The actual function applying the deformation
---@param veh integer
---@param deformation table
function ApplyDeformation(veh, deformation)
    CreateThread(function()
        if (not DoesEntityExist(veh)) then return end
        if (not deformation or #deformation == 0) then
            FixDeformation(veh)
            return
        end

        -- List of all deformations, their current iteration and if they are replicated
        -- This is because applying damage is very inconsistent
        -- Looping around the entire vehicle and applying it in small chunks seems to work better
        local defProg = {}

        local maxIterations = 25
        local acceptableDmgThreshold = 0.01

        repeat
            local vehDoesExist = DoesEntityExist(veh)
            if (not vehDoesExist) then break end

            for i = #deformation, 1, -1 do
                Wait(50) -- Minimum wait to apply the damage so that we can check the next difference

                if (not defProg[i]) then defProg[i] = {totalIterations = 0, lastDiff = 0} end

                local isUsingNative = type(deformation[i][1]) == "number"
                local x, y, z
                local totalDmg

                if (isUsingNative) then
                    x, y, z = deformation[i][1], deformation[i][2], deformation[i][3]
                    totalDmg = deformation[i][4]
                else
                    x, y, z = deformation[i][1].x, deformation[i][1].y, deformation[i][1].z
                    totalDmg = deformation[i][2]
                end

                local currDef = GetVehicleDeformationAtPos(veh, x, y, z)
                local currDmg = #(currDef)
                local diff = totalDmg - currDmg
                local isDamageReplicted = diff < acceptableDmgThreshold

                if (not isDamageReplicted) then
                    -- Does not seem to apply damage if it's lower than ~0.03 * 250.0
                    -- However, it is insanely slow so we'll do at least 0.05
                    local dmgToApply = diff / 3
                    local minimumDmg = 0.05
                    if (dmgToApply < minimumDmg) then dmgToApply = minimumDmg end

                    SetVehicleDamage(veh, x, y, z, dmgToApply * 250.0, 1250.0, true)
                end

                defProg[i].totalIterations = defProg[i].totalIterations + 1
                if (isDamageReplicted or defProg[i].totalIterations >= maxIterations or defProg[i].lastDiff == diff) then
                    table.remove(deformation, i)
                    defProg[i] = nil
                else
                    -- Track the last damage, so if there are no changes we'll remove it
                    -- Sometimes the damage just simply doesn't apply and it uses the max iteration with no change
                    defProg[i].lastDiff = diff
                end
            end
        until #deformation == 0
    end)
end

exports("SetDeformation", SetDeformation)

---@param veh integer @Vehicle handle
function GetDeformation(veh)
    if (not DoesEntityExist(veh)) then return end

    local vehModel = GetEntityModel(veh)
    local offsets = GetModelOffsets(vehModel)
    local deformation = {}
    local threshold = 0.01 -- Threshold to be recognized, otherwise it will return 0

    for i = 1, #offsets do
        local pos = offsets[i]
        local deformationAtPos = GetVehicleDeformationAtPos(veh, pos.x, pos.y, pos.z)
        local damage = #(deformationAtPos)

        if (damage < threshold) then goto continue end

        local offsetDeformation = {
            pos.x, pos.y, pos.z, -- Offsets
            Round(damage, 2) -- Damage
        }

        deformation[#deformation+1] = offsetDeformation

        ::continue::
    end

    return deformation
end

exports("GetDeformation", GetDeformation)

---@param model integer @Model hash
function GetModelOffsets(model)
    local min, max = GetModelDimensions(model)
    local x = (max.x - min.x) / 2
    local y = (max.y - min.y) / 2

    local offsets = {
        vector3(x, -y, 0), -- Front left
        vector3(x / 2, -y, 0), -- Front left middle
        vector3(0, -y, 0), -- Front middle
        vector3(-x / 2, -y, 0), -- Front right middle
        vector3(-x, -y, 0), -- Front right

        vector3(x, y, 0), -- Back left
        vector3(x / 2, y, 0), -- Back left middle
        vector3(0, y, 0), -- Back middle
        vector3(-x / 2, y, 0), -- Back right middle
        vector3(-x, y, 0), -- Back right

        vector3(x, -y / 2, 0), -- Middle left upper
        vector3(x, -y / 4, 0), -- Middle left upper middle
        vector3(x, 0, 0), -- Middle left
        vector3(x, y / 4, 0), -- Middle left lower middle
        vector3(x, y / 2, 0), -- Middle left lower

        vector3(-x, -y / 2, 0), -- Middle right upper
        vector3(-x, -y / 4, 0), -- Middle right upper middle
        vector3(-x, 0, 0), -- Middle right
        vector3(-x, y / 4, 0), -- Middle right lower middle
        vector3(-x, y / 2, 0) -- Middle right lower
    }

    return offsets
end

---@param veh integer @Vehicle handle
function FixDeformation(veh)
    SetVehicleDeformationFixed(veh)
end

exports("FixDeformation", FixDeformation)