local cfg = Config.DamageSystem

if (not cfg.enabled) then return end
if (not cfg.torqueMultiplierEnabled and not cfg.preventVehicleFlip and not cfg.limpMode) then return end

local lastCheckedRoll = GetGameTimer()
local isFlipped = false

-- Runs every frame while in vehicle (torque and flip control are per-frame)
---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler("currentVehicle", nil, function(bagName, key, value)
    if (value == nil) then return end

    while true do
        local sleep = 100
        local ped = PlayerPedId()

        local veh = GetVehiclePedIsIn(ped, false)

        if (veh == 0) then break end

        -- Seat switching won't re-trigger currentVehicle, so we just skip the rest of the logic until we are the driver
        if (GetPedInVehicleSeat(veh, -1) ~= ped) then
            sleep = 1000
            goto continue
        end

        -- Torque reduction and limp mode
        if (cfg.torqueMultiplierEnabled or cfg.limpMode) then
            local engineHealth = GetVehicleEngineHealth(veh)
            local torqueFactor = 1.0

            if (cfg.torqueMultiplierEnabled and engineHealth < 900) then
                torqueFactor = (engineHealth + 200.0) / 1100
            end

            if (cfg.limpMode and engineHealth < cfg.engineSafeGuard + 5) then
                torqueFactor = cfg.limpModeMultiplier
            end

            -- If we're reducing our torque, we need to run it every frame
            if (torqueFactor < 1.0) then
                sleep = 1
            end

            SetVehicleEngineTorqueMultiplier(veh, torqueFactor)
        end

        -- Flip prevention: disable steering when rolled over and nearly stopped
        if (cfg.preventVehicleFlip) then
            if (GetGameTimer() - lastCheckedRoll > 500) then
                local roll = GetEntityRoll(veh)
                isFlipped = (roll > 75.0 or roll < -75.0)

                lastCheckedRoll = GetGameTimer()
            end

            if (isFlipped and (GetEntitySpeed(veh) < 5)) then
                sleep = 1

                DisableControlAction(2, 59, true)
                DisableControlAction(2, 60, true)
            end
        end

        ::continue::

        Wait(sleep)
    end

    isFlipped = false
end)
