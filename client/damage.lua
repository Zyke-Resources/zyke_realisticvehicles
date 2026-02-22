if (not Config.DamageSystem.enabled) then return end

local cfg = Config.DamageSystem

-- State
local wasInVehicleLastTick = false
local currentVehicle = nil
local previousVehicle = nil
local vehicleClass = nil

-- Health tracking: last (previous tick), current (native read), new (calculated target)
local healthEngineLast     = 1000.0
local healthEngineCurrent  = 1000.0
local healthEngineNew      = 1000.0

local healthBodyLast       = 1000.0
local healthBodyCurrent    = 1000.0
local healthBodyNew        = 1000.0

local healthPetrolTankLast    = 1000.0
local healthPetrolTankCurrent = 1000.0
local healthPetrolTankNew     = 1000.0

-- Original handling values (restored on exit)
local origDeformationDamageMult = 0.0
local origCollisionDamageMult   = 0.0
local origEngineDamageMult      = 0.0
local origBrakeForce            = 1.0

local EXCLUDED_CLASSES = {
    [13] = true, -- Bicycles
    [15] = true, -- Helicopters
    [16] = true, -- Planes
    [21] = true, -- Trains
}

--- Check if the player is driving a supported vehicle, updates currentVehicle
---@return boolean
local function isPedDrivingSupported()
    local ped = PlayerPedId()

    local veh = GetVehiclePedIsIn(ped, false)
    if (veh == 0) then return false end

    if (GetPedInVehicleSeat(veh, -1) ~= ped) then return false end
    if (EXCLUDED_CLASSES[GetVehicleClass(veh)]) then return false end

    currentVehicle = veh

    return true
end

--- Normalize handling values on vehicle entry
---@param veh integer
local function onVehicleEnter(veh)
    origDeformationDamageMult = GetVehicleHandlingFloat(veh, "CHandlingData", "fDeformationDamageMult")
    origBrakeForce            = GetVehicleHandlingFloat(veh, "CHandlingData", "fBrakeForce")
    origCollisionDamageMult   = GetVehicleHandlingFloat(veh, "CHandlingData", "fCollisionDamageMult")
    origEngineDamageMult      = GetVehicleHandlingFloat(veh, "CHandlingData", "fEngineDamageMult")

    if (cfg.deformationMultiplier ~= -1) then
        local compressed = origDeformationDamageMult ^ cfg.deformationExponent
        SetVehicleHandlingFloat(veh, "CHandlingData", "fDeformationDamageMult", compressed * cfg.deformationMultiplier)
    end

    if (cfg.weaponsDamageMultiplier ~= -1) then
        SetVehicleHandlingFloat(veh, "CHandlingData", "fWeaponDamageMult", cfg.weaponsDamageMultiplier / cfg.damageFactorBody)
    end

    local compressedCollision = origCollisionDamageMult ^ cfg.collisionDamageExponent
    SetVehicleHandlingFloat(veh, "CHandlingData", "fCollisionDamageMult", compressedCollision)

    local compressedEngine = origEngineDamageMult ^ cfg.engineDamageExponent
    SetVehicleHandlingFloat(veh, "CHandlingData", "fEngineDamageMult", compressedEngine)

    -- Pull up catastrophic body health so we can detect new deltas
    if (healthBodyCurrent < cfg.cascadingFailureThreshold) then
        healthBodyNew = cfg.cascadingFailureThreshold
    end

    wasInVehicleLastTick = true
end

--- Restore original handling values on vehicle exit
---@param veh integer
local function onVehicleExit(veh)
    if (cfg.deformationMultiplier ~= -1) then
        SetVehicleHandlingFloat(veh, "CHandlingData", "fDeformationDamageMult", origDeformationDamageMult)
    end

    SetVehicleHandlingFloat(veh, "CHandlingData", "fBrakeForce", origBrakeForce)

    if (cfg.weaponsDamageMultiplier ~= -1) then
        SetVehicleHandlingFloat(veh, "CHandlingData", "fWeaponDamageMult", cfg.weaponsDamageMultiplier)
    end

    SetVehicleHandlingFloat(veh, "CHandlingData", "fCollisionDamageMult", origCollisionDamageMult)
    SetVehicleHandlingFloat(veh, "CHandlingData", "fEngineDamageMult", origEngineDamageMult)
end

--- Core damage calculation
---@param veh integer
local function processDamage(veh)
    healthEngineCurrent     = GetVehicleEngineHealth(veh)
    healthBodyCurrent       = GetVehicleBodyHealth(veh)
    healthPetrolTankCurrent = GetVehiclePetrolTankHealth(veh)

    -- Reset tracking when fully repaired
    if (healthEngineCurrent == 1000) then healthEngineLast = 1000.0 end
    if (healthBodyCurrent == 1000) then healthBodyLast = 1000.0 end
    if (healthPetrolTankCurrent == 1000) then healthPetrolTankLast = 1000.0 end

    healthEngineNew     = healthEngineCurrent
    healthBodyNew       = healthBodyCurrent
    healthPetrolTankNew = healthPetrolTankCurrent

    local engineDelta     = healthEngineLast - healthEngineCurrent
    local bodyDelta       = healthBodyLast - healthBodyCurrent
    local petrolTankDelta = healthPetrolTankLast - healthPetrolTankCurrent

    local classMultiplier       = cfg.classDamageMultiplier[vehicleClass] or 1.0
    local engineDeltaScaled     = engineDelta * cfg.damageFactorEngine * classMultiplier
    local bodyDeltaScaled       = bodyDelta * cfg.damageFactorBody * classMultiplier
    local petrolTankDeltaScaled = petrolTankDelta * cfg.damageFactorPetrolTank * classMultiplier

    if (healthEngineCurrent > cfg.engineSafeGuard + 1) then
        SetVehicleUndriveable(veh, false)
    elseif (not cfg.limpMode) then
        SetVehicleUndriveable(veh, true)
    end

    -- Skip first tick after entering to prevent amplification
    if (not wasInVehicleLastTick) then return end

    -- No damage on the vehicle
    if (healthEngineCurrent == 1000.0 and healthBodyCurrent == 1000.0 and healthPetrolTankCurrent == 1000.0) then return end

    -- Use the largest scaled delta as the primary engine damage source
    local combinedDelta = math.max(engineDeltaScaled, bodyDeltaScaled, petrolTankDeltaScaled)

    -- Scale back near-fatal hits to give a brief window before failure
    if (combinedDelta > (healthEngineCurrent - cfg.engineSafeGuard)) then
        combinedDelta = combinedDelta * 0.7
    end

    -- Cap to leave room for cascading failure
    if (combinedDelta > healthEngineCurrent) then
        combinedDelta = healthEngineCurrent - (cfg.cascadingFailureThreshold / 5)
    end

    healthEngineNew = healthEngineLast - combinedDelta

    if (bodyDelta > 0) then healthBodyNew = healthBodyLast - bodyDeltaScaled end
    if (petrolTankDelta > 0) then healthPetrolTankNew = healthPetrolTankLast - petrolTankDeltaScaled end

    -- Progressive degradation: slow passive drain between thresholds
    if (healthEngineNew >= cfg.cascadingFailureThreshold and healthEngineNew < cfg.degradingFailureThreshold) then
        healthEngineNew = healthEngineNew - (0.038 * cfg.degradingHealthSpeedFactor)
    end

    -- Cascading failure: rapid drain below threshold
    if (healthEngineNew < cfg.cascadingFailureThreshold) then
        healthEngineNew = healthEngineNew - (0.1 * cfg.cascadingFailureSpeedFactor)
    end

    if (healthEngineNew < cfg.engineSafeGuard) then healthEngineNew = cfg.engineSafeGuard end
    if (healthPetrolTankCurrent < 750) then healthPetrolTankNew = 750.0 end
    if (healthBodyNew < 0) then healthBodyNew = 0.0 end
end

-- Runs every 50ms while in vehicle
---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler("currentVehicle", nil, function(bagName, key, value)
    if (value == nil) then return end

    while (true) do
        local sleep = 50

        if (isPedDrivingSupported()) then
            vehicleClass = GetVehicleClass(currentVehicle)

            if (currentVehicle ~= previousVehicle) then
                wasInVehicleLastTick = false
            end

            processDamage(currentVehicle)

            if (not wasInVehicleLastTick) then
                onVehicleEnter(currentVehicle)
            end

            if (healthEngineNew ~= healthEngineCurrent) then
                SetVehicleEngineHealth(currentVehicle, healthEngineNew)
            end
            if (healthBodyNew ~= healthBodyCurrent) then
                SetVehicleBodyHealth(currentVehicle, healthBodyNew)
            end
            if (healthPetrolTankNew ~= healthPetrolTankCurrent) then
                SetVehiclePetrolTankHealth(currentVehicle, healthPetrolTankNew)
            end

            healthEngineLast     = healthEngineNew
            healthBodyLast       = healthBodyNew
            healthPetrolTankLast = healthPetrolTankNew
            previousVehicle      = currentVehicle
        else
            if (wasInVehicleLastTick) then
                local lastVeh = GetVehiclePedIsIn(PlayerPedId(), true)
                if (lastVeh and lastVeh ~= 0) then
                    onVehicleExit(lastVeh)
                end
            end

            wasInVehicleLastTick = false

            break
        end

        Wait(sleep)
    end
end)
