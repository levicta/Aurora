-- src/elements/StatusLabel.lua
-- Tab:CreateStatusLabel(cfg) factory.
-- cfg: { Text?, Type? }   Type: "Info" | "Success" | "Warning" | "Error"
--
-- SetValue(text, type?) updates display. For this display-only element,
-- OnChanged fires on SetValue (it IS the change mechanism).

return function(self, cfg)
    cfg = cfg or {}
    local typeColors = {
        Info    = Config.Theme.Primary,
        Success = Config.Theme.Success,
        Warning = Config.Theme.Warning,
        Error   = Config.Theme.Error,
    }
    local currentType = cfg.Type or "Info"
    local OnChanged   = Signal.new()

    local frame = Utility.Create("Frame", {
        Parent             = self.Content,
        Size               = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
    })

    local Dot = Utility.Create("Frame", {
        Parent           = frame,
        Position         = UDim2.new(0, 2, 0.5, -4),
        Size             = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = typeColors[currentType],
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Dot, UDim.new(1, 0))

    local Lbl = Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(0, 16, 0, 0),
        Size               = UDim2.new(1, -16, 1, 0),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "",
        TextColor3         = typeColors[currentType],
        Font               = Config.FontMedium,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
        TextTruncate       = Enum.TextTruncate.AtEnd,
    })

    local function applyType(t)
        currentType = t
        local c = typeColors[t] or typeColors.Info
        Dot.BackgroundColor3 = c
        Lbl.TextColor3       = c
    end

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return Lbl.Text end,
        -- SetValue(text, type?) — updates display and fires OnChanged.
        SetValue  = function(t, typ)
            Lbl.Text = tostring(t)
            if typ then applyType(typ) end
            OnChanged:Fire(Lbl.Text)
        end,
        SetText = function(t) Lbl.Text = tostring(t) end,
        SetType = applyType,
    }, frame)
end
