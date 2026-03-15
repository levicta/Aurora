-- src/elements/Toggle.lua
-- Tab:CreateToggle(cfg) factory.
-- cfg: { Text?, Default?, Callback? }
--
-- SetValue is SILENT (does not fire Callback or OnChanged).
-- User interaction fires both.

return function(self, cfg)
    cfg = cfg or {}
    local toggled   = cfg.Default or false
    local OnChanged = Signal.new()
    local frame     = self:BaseFrame(36)

    Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(0, 12, 0, 0),
        Size               = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Toggle",
        TextColor3         = Config.Theme.Text,
        Font               = Config.FontMedium,
        TextSize           = 14,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local Track = Utility.Create("Frame", {
        Parent           = frame,
        Position         = UDim2.new(1, -46, 0.5, -10),
        Size             = UDim2.new(0, 36, 0, 20),
        BackgroundColor3 = toggled and Config.Theme.Primary or Config.Theme.Border,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Track, UDim.new(1, 0))

    local Circle = Utility.Create("Frame", {
        Parent           = Track,
        Position         = toggled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        Size             = UDim2.new(0, 16, 0, 16),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Circle, UDim.new(1, 0))

    -- Sync track + circle to current state.
    -- silent=true → skip Callback/OnChanged (used by SetValue).
    local function applyUI(silent)
        Utility.Tween(Track,  { BackgroundColor3 = toggled and Config.Theme.Primary or Config.Theme.Border }, 0.2)
        Utility.Tween(Circle, { Position = toggled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }, 0.2)
        if not silent then
            if cfg.Callback then cfg.Callback(toggled) end
            OnChanged:Fire(toggled)
        end
    end

    Utility.Create("TextButton", {
        Parent             = frame,
        Size               = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text               = "",
    }).MouseButton1Click:Connect(function()
        toggled = not toggled
        applyUI(false)
    end)

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return toggled end,
        -- Silent: updates UI only, does NOT fire Callback or OnChanged.
        SetValue  = function(val)
            val = not not val   -- coerce to boolean
            if toggled ~= val then
                toggled = val
                applyUI(true)
            end
        end,
    }, frame)
end
