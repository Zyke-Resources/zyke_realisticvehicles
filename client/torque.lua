local cfg = Config.DamageSystem

if (not cfg.enabled) then return end
if (not cfg.torqueMultiplierEnabled and not cfg.preventVehicleFlip and not cfg.limpMode) then return end

-- State
local lastCheckedRoll = GetGameTimer()
local lastHandlingUpdate = 0
local isFlipped = false

-- Handling originals (saved on vehicle entry, restored on exit)
local origDriveForce = 0.0
local origDriveInertia = 0.0
local origClutchUp = 0.0
local origClutchDown = 0.0
local lastHandlingFactor = 1.0

--- Store original handling values and apply initial damage-based modifications
---@param veh integer
local function onInit(veh)
    origDriveForce = GetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDriveForce")
    origDriveInertia = GetVehicleHandlingFloat(veh, "CHandlingData", "fDriveInertia")
    origClutchUp = GetVehicleHandlingFloat(veh, "CHandlingData", "fClutchChangeRateScaleUpShift")
    origClutchDown = GetVehicleHandlingFloat(veh, "CHandlingData", "fClutchChangeRateScaleDownShift")
    lastHandlingFactor = 1.0

    if (cfg.torqueMultiplierEnabled or cfg.limpMode) then
        local engineHealth = GetVehicleEngineHealth(veh)
        local factor = 1.0

        if (cfg.torqueMultiplierEnabled and engineHealth < cfg.torqueDegradationThreshold) then
            factor = (engineHealth + (cfg.torqueDegradationThreshold * 0.2)) / (cfg.torqueDegradationThreshold * 1.2)
        end

        if (cfg.limpMode and engineHealth < cfg.engineSafeGuard + 5) then
            factor = cfg.limpModeMultiplier
        end

        if (factor < 1.0) then
            SetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDriveForce", origDriveForce * factor)
            SetVehicleHandlingFloat(veh, "CHandlingData", "fDriveInertia", origDriveInertia * math.sqrt(factor))
            SetVehicleHandlingFloat(veh, "CHandlingData", "fClutchChangeRateScaleUpShift", origClutchUp * factor)
            SetVehicleHandlingFloat(veh, "CHandlingData", "fClutchChangeRateScaleDownShift", origClutchDown * factor)
            ModifyVehicleTopSpeed(veh, factor)
            lastHandlingFactor = factor
        end
    end

    if (Config.Settings.debug) then
        print(('[TORQUE] init | driveForce=%.4f | inertia=%.4f | clutchUp=%.2f | clutchDown=%.2f | factor=%.4f'):format(
            origDriveForce, origDriveInertia, origClutchUp, origClutchDown, lastHandlingFactor
        ))
    end
end

--- Restore all original handling values on vehicle exit
---@param veh integer
local function onCleanup(veh)
    SetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDriveForce", origDriveForce)
    SetVehicleHandlingFloat(veh, "CHandlingData", "fDriveInertia", origDriveInertia)
    SetVehicleHandlingFloat(veh, "CHandlingData", "fClutchChangeRateScaleUpShift", origClutchUp)
    SetVehicleHandlingFloat(veh, "CHandlingData", "fClutchChangeRateScaleDownShift", origClutchDown)
    ModifyVehicleTopSpeed(veh, 1.0)
    lastHandlingFactor = 1.0
    isFlipped = false

    if (Config.Settings.debug) then
        print('[TORQUE] cleanup | all handling values restored')
    end
end

--- Update handling modifications when the damage factor changes meaningfully
---@param veh integer
---@param factor number
local function updateHandling(veh, factor)
    -- Fully repaired, restore originals
    if (factor == 1.0 and lastHandlingFactor ~= 1.0) then
        SetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDriveForce", origDriveForce)
        SetVehicleHandlingFloat(veh, "CHandlingData", "fDriveInertia", origDriveInertia)
        SetVehicleHandlingFloat(veh, "CHandlingData", "fClutchChangeRateScaleUpShift", origClutchUp)
        SetVehicleHandlingFloat(veh, "CHandlingData", "fClutchChangeRateScaleDownShift", origClutchDown)
        ModifyVehicleTopSpeed(veh, 1.0)
        lastHandlingFactor = 1.0

        if (Config.Settings.debug) then
            print('[TORQUE] repaired | all handling values restored')
        end

        return
    end

    -- Only write when factor changes meaningfully (avoid float noise)
    if (math.abs(factor - lastHandlingFactor) > 0.01) then
        local inertiaFactor = math.sqrt(factor)

        SetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDriveForce", origDriveForce * factor)
        SetVehicleHandlingFloat(veh, "CHandlingData", "fDriveInertia", origDriveInertia * inertiaFactor)
        SetVehicleHandlingFloat(veh, "CHandlingData", "fClutchChangeRateScaleUpShift", origClutchUp * factor)
        SetVehicleHandlingFloat(veh, "CHandlingData", "fClutchChangeRateScaleDownShift", origClutchDown * factor)
        ModifyVehicleTopSpeed(veh, factor)

        if (Config.Settings.debug) then
            print(('[TORQUE] update | factor=%.4f -> %.4f | driveForce=%.4f | inertia=%.4f | clutchUp=%.2f | topSpeed=%.2f%%'):format(
                lastHandlingFactor, factor, origDriveForce * factor, origDriveInertia * inertiaFactor,
                origClutchUp * factor, factor * 100
            ))
        end

        lastHandlingFactor = factor
    end
end

---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler("currentVehicle", nil, function(bagName, key, value)
    if (value == nil) then return end

    local initialized = false

    while (1) do
        local sleep = 500
        local ped = PlayerPedId()

        local veh = GetVehiclePedIsIn(ped, false)

        if (veh == 0) then
            if (initialized) then
                local lastVeh = GetVehiclePedIsIn(ped, true)
                if (lastVeh and lastVeh ~= 0) then onCleanup(lastVeh) end
            end

            break
        end

        -- Seat switching won't re-trigger currentVehicle, so we just skip the rest of the logic until we are the driver
        if (GetPedInVehicleSeat(veh, -1) ~= ped) then
            sleep = 1000
            goto continue
        end

        if (not initialized) then
            onInit(veh)
            initialized = true
        end

        -- Torque reduction and limp mode (via handling modifications)
        if ((cfg.torqueMultiplierEnabled or cfg.limpMode) and GetGameTimer() - lastHandlingUpdate > 500) then
            lastHandlingUpdate = GetGameTimer()

            local engineHealth = GetVehicleEngineHealth(veh)
            local torqueFactor = 1.0

            if (cfg.torqueMultiplierEnabled and engineHealth < cfg.torqueDegradationThreshold) then
                torqueFactor = (engineHealth + (cfg.torqueDegradationThreshold * 0.2)) / (cfg.torqueDegradationThreshold * 1.2)
            end

            if (cfg.limpMode and engineHealth < cfg.engineSafeGuard + 5) then
                torqueFactor = cfg.limpModeMultiplier
            end

            updateHandling(veh, torqueFactor)
        end

        -- Flip prevention, disable steering when rolled over and nearly stopped
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
