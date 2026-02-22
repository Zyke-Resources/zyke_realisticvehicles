Config = Config or {}

Config.Settings = {
    debug = false -- Only enable in development environments, exposes dangerous commands
}

Config.DamageSystem = {
    -- Master toggle, set to false to disable the damage system entirely
    -- Visual deformation syncing continues to work independently
    enabled = true,

    -- Preset level (1-5):
    -- 1 = Arcade
    -- 2 = Casual
    -- 3 = Balanced (recommended)
    -- 4 = Realistic
    -- 5 = Hardcore
    preset = 3,

    -- Override any individual value from the preset (see shared/presets.lua for all keys)
    -- Example: overrides = { limpMode = true, damageFactorEngine = 5.0 }
    overrides = {},
}