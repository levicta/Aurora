-- src/init.lua
-- Aurora public API surface.
-- This is the table returned to the consumer: local Aurora = loadstring(...)()

local Aurora = {}

-- Create and open a new UI window.
function Aurora:CreateWindow(config)
    return Window(config)
end

-- Display a toast notification using the shared singleton layer.
-- For per-window notifications, call window:Notify(cfg) instead.
function Aurora:Notify(cfg)
    Notification.sharedNotify(cfg)
end

-- Override theme colours. Only affects elements created AFTER the call.
-- Valid keys: Primary, Secondary, Background, Surface, Text, TextMuted,
--             Success, Warning, Error, Border, Glow.
function Aurora:SetTheme(newTheme)
    for k, v in pairs(newTheme) do
        if Config.Theme[k] ~= nil then
            Config.Theme[k] = v
        end
    end
end

-- Create a configuration object that persists element values to disk.
--
-- Usage:
--   local cfg = Aurora:CreateConfig({ Name = "MyScript", Folder = "MyGame" })
--   cfg:Link("ToggleA", toggleA)
--       :Link("Speed",   speedSlider)
--       :Link("Color",   colorPicker)
--   cfg:CreateControls(settingsTab)   -- optional: adds import/export/reset UI
--
-- Options (all optional):
--   Name      string   File name stem.                         Default: "Config"
--   Folder    string   Subfolder in executor workspace.        Default: "Aurora"
--   Profile   string   Named save slot — switch at runtime.    Default: "default"
--   AutoSave  bool     Save on every user change.              Default: true
--   AutoLoad  bool     Load saved values at creation time.     Default: true
function Aurora:CreateConfig(options)
    return ConfigSystem(options)
end

-- Expose Config for advanced consumers who want to read animation settings etc.
Aurora.Config = Config

return Aurora