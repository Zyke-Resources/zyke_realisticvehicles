--[[
    ONLY MODIFY THIS FILE IF YOU KNOW WHAT YOU ARE DOING

    We recommend using the config file & selecting a preset from there
    You can adjust the presets further in here if you want to
    Just remember to re-enter your vehicle after a restart to apply the changes
]]

-- Available override keys:
--
-- Damage factors (multipliers for each health pool):
--   damageFactorEngine, damageFactorBody, damageFactorPetrolTank
--   weaponsDamageMultiplier (0.0-10.0, -1 = don't touch)
--
-- Handling normalization (compress per-vehicle handling toward 1.0):
--   deformationExponent, collisionDamageExponent, engineDamageExponent
--
-- Visual deformation:
--   deformationMultiplier (0.0-10.0, -1 = don't touch)
--
-- Failure thresholds:
--   degradingFailureThreshold, cascadingFailureThreshold, engineSafeGuard
--
-- Failure speeds:
--   degradingHealthSpeedFactor, cascadingFailureSpeedFactor
--
-- Torque:
--   torqueMultiplierEnabled
--   torqueDegradationThreshold (engine health below which torque starts degrading)
--
-- Limp mode:
--   limpMode, limpModeMultiplier (0.05-0.25)
--
-- Vehicle flip:
--   preventVehicleFlip
--
-- Per-class multiplier:
--   classDamageMultiplier (table of multipliers per vehicle class 0-21)

-- Default damage multipliers for each vehicle class
-- Manage how much damage each vehicle class takes, for example, make motorcycles weaker than cars
-- Higher number = more damage taken
local DEFAULT_CLASS_MULTIPLIER = {
    [0]  = 1.0,     --  0: Compacts
           1.0,     --  1: Sedans
           1.0,     --  2: SUVs
           1.0,     --  3: Coupes
           1.0,     --  4: Muscle
           1.0,     --  5: Sports Classics
           1.0,     --  6: Sports
           1.0,     --  7: Super
           1.25,    --  8: Motorcycles
           0.7,     --  9: Off-road
           0.25,    -- 10: Industrial
           1.0,     -- 11: Utility
           1.0,     -- 12: Vans
           1.0,     -- 13: Cycles (excluded)
           0.5,     -- 14: Boats
           1.0,     -- 15: Helicopters (excluded)
           1.0,     -- 16: Planes (excluded)
           0.75,    -- 17: Service
           0.75,    -- 18: Emergency
           0.75,    -- 19: Military
           1.0,     -- 20: Commercial
           1.0,     -- 21: Trains (excluded)
}

local Presets = {
    -- Level 1: Arcade - very tanky, minimal consequences
    [1] = {
        damageFactorEngine          = 0.4,
        damageFactorBody            = 0.5,
        damageFactorPetrolTank      = 10.0,
        deformationExponent         = 0.6,
        collisionDamageExponent     = 0.8,
        engineDamageExponent        = 0.8,
        deformationMultiplier       = 4.2,
        weaponsDamageMultiplier     = 0.5,
        degradingFailureThreshold   = 240.0,
        cascadingFailureThreshold   = 150.0,
        engineSafeGuard             = 200.0,
        degradingHealthSpeedFactor  = 0.4,
        cascadingFailureSpeedFactor = 0.4,
        torqueMultiplierEnabled     = false,
        torqueDegradationThreshold  = 200,
        limpMode                    = true,
        limpModeMultiplier          = 0.4,
        preventVehicleFlip          = false,
        classDamageMultiplier       = DEFAULT_CLASS_MULTIPLIER,
    },

    -- Casual, noticeable but forgiving
    [2] = {
        damageFactorEngine          = 0.8,
        damageFactorBody            = 1.5,
        damageFactorPetrolTank      = 30.0,
        deformationExponent         = 0.5,
        collisionDamageExponent     = 0.7,
        engineDamageExponent        = 0.7,
        deformationMultiplier       = 5.6,
        weaponsDamageMultiplier     = 1.0,
        degradingFailureThreshold   = 360.0,
        cascadingFailureThreshold   = 250.0,
        engineSafeGuard             = 150.0,
        degradingHealthSpeedFactor  = 1.0,
        cascadingFailureSpeedFactor = 0.8,
        torqueMultiplierEnabled     = true,
        torqueDegradationThreshold  = 400,
        limpMode                    = true,
        limpModeMultiplier          = 0.25,
        preventVehicleFlip          = false,
        classDamageMultiplier       = DEFAULT_CLASS_MULTIPLIER,
    },

    -- Balanced, sweet spot for most RP servers (recommended)
    [3] = {
        damageFactorEngine          = 1.2,
        damageFactorBody            = 2.0,
        damageFactorPetrolTank      = 48.0,
        deformationExponent         = 0.45,
        collisionDamageExponent     = 0.65,
        engineDamageExponent        = 0.65,
        deformationMultiplier       = 7.0,
        weaponsDamageMultiplier     = 1.5,
        degradingFailureThreshold   = 420.0,
        cascadingFailureThreshold   = 300.0,
        engineSafeGuard             = 120.0,
        degradingHealthSpeedFactor  = 1.6,
        cascadingFailureSpeedFactor = 1.2,
        torqueMultiplierEnabled     = true,
        torqueDegradationThreshold  = 500,
        limpMode                    = false,
        limpModeMultiplier          = 0.19,
        preventVehicleFlip          = true,
        classDamageMultiplier       = DEFAULT_CLASS_MULTIPLIER,
    },

    -- Realistic, vehicles fail faster, serious RP
    [4] = {
        damageFactorEngine          = 1.6,
        damageFactorBody            = 3.0,
        damageFactorPetrolTank      = 64.0,
        deformationExponent         = 0.4,
        collisionDamageExponent     = 0.6,
        engineDamageExponent        = 0.6,
        deformationMultiplier       = 8.4,
        weaponsDamageMultiplier     = 2.0,
        degradingFailureThreshold   = 480.0,
        cascadingFailureThreshold   = 360.0,
        engineSafeGuard             = 100.0,
        degradingHealthSpeedFactor  = 2.0,
        cascadingFailureSpeedFactor = 1.6,
        torqueMultiplierEnabled     = true,
        torqueDegradationThreshold  = 600,
        limpMode                    = false,
        limpModeMultiplier          = 0.19,
        preventVehicleFlip          = true,
        classDamageMultiplier       = DEFAULT_CLASS_MULTIPLIER,
    },

    -- Hardcore, very fragile, maximum realism
    [5] = {
        damageFactorEngine          = 3.2,
        damageFactorBody            = 5.0,
        damageFactorPetrolTank      = 100.0,
        deformationExponent         = 0.3,
        collisionDamageExponent     = 0.5,
        engineDamageExponent        = 0.5,
        deformationMultiplier       = 11.2,
        weaponsDamageMultiplier     = 3.0,
        degradingFailureThreshold   = 540.0,
        cascadingFailureThreshold   = 450.0,
        engineSafeGuard             = 80.0,
        degradingHealthSpeedFactor  = 3.0,
        cascadingFailureSpeedFactor = 2.4,
        torqueMultiplierEnabled     = true,
        torqueDegradationThreshold  = 700,
        limpMode                    = false,
        limpModeMultiplier          = 0.15,
        preventVehicleFlip          = true,
        classDamageMultiplier       = DEFAULT_CLASS_MULTIPLIER,
    },
}

-- Resolve preset + overrides into Config.DamageSystem
local chosenLevel = Config.DamageSystem.preset or 3
local preset = Presets[chosenLevel]

if (not preset) then
    print(("[zyke_realisticvehicles] WARNING: Invalid preset level '%s'. Falling back to level 3 (Balanced)."):format(tostring(chosenLevel)))
    preset = Presets[3]
end

for key, value in pairs(preset) do
    Config.DamageSystem[key] = value
end

local overrides = Config.DamageSystem.overrides
if overrides then
    for key, value in pairs(overrides) do
        Config.DamageSystem[key] = value
    end
end

local presetNames = {
    [1] = "Arcade",
    [2] = "Casual",
    [3] = "Balanced",
    [4] = "Realistic",
    [5] = "Hardcore",
}

local overrideCount = 0
if overrides then
    for _ in pairs(overrides) do overrideCount = overrideCount + 1 end
end

print(("[zyke_realisticvehicles] Damage system loaded! Preset: %d (%s)%s"):format(
    chosenLevel,
    presetNames[chosenLevel] or "Unknown",
    overrideCount > 0 and (" with %d override(s)"):format(overrideCount) or ""
))
