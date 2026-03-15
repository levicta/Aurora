-- src/elements/ProgressBar.lua
-- Tab:CreateProgressBar(cfg) factory.
-- cfg: { Text?, Default?, Color? }
--
-- Value range is always 0..1.
-- For this element there is no user interaction — SetValue IS the only trigger,
-- so OnChanged fires on SetValue (the only meaningful change source).
-- Callback is NOT fired on SetValue for consistency with the rest of the API.

return function(self, cfg)
    cfg = cfg or {}
    local value     = math.clamp(cfg.Default or 0, 0, 1)
    local OnChanged = Signal.new()
    local frame     = self:BaseFrame(46)

    local LabelText = Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(0, 12, 0, 6),
        Size               = UDim2.new(1, -60, 0, 16),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Progress",
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.FontMedium,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local PctLabel = Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(1, -50, 0, 6),
        Size               = UDim2.new(0, 42, 0, 16),
        BackgroundTransparency = 1,
        Text               = "0%",
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.Font,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Right,
    })

    local Track = Utility.Create("Frame", {
        Parent           = frame,
        Position         = UDim2.new(0, 10, 0, 30),
        Size             = UDim2.new(1, -20, 0, 8),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Track, UDim.new(1, 0))

    local barColor = cfg.Color or Config.Theme.Primary
    local Fill = Utility.Create("Frame", {
        Parent           = Track,
        Size             = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = barColor,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Fill, UDim.new(1, 0))

    local function apply(pct)
        pct        = math.clamp(pct, 0, 1)
        value      = pct
        Utility.Tween(Fill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.2)
        PctLabel.Text = math.floor(pct * 100) .. "%"
        OnChanged:Fire(pct)
    end

    apply(value)  -- seed initial display

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return value end,
        SetValue  = function(pct) apply(pct) end,
        SetLabel  = function(t) LabelText.Text = tostring(t) end,
        SetColor  = function(c)
            barColor              = c
            Fill.BackgroundColor3 = c
        end,
    }, frame)
end
