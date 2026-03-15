-- src/elements/Input.lua
-- Tab:CreateInput(cfg) factory.
-- cfg: { Text?, Placeholder?, Callback? }
-- Callback fires on Enter. SetValue is SILENT.

return function(self, cfg)
    cfg = cfg or {}
    local OnChanged = Signal.new()
    local frame     = self:BaseFrame(54)

    Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(0, 12, 0, 6),
        Size               = UDim2.new(1, -24, 0, 16),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Input",
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.FontMedium,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local InputBox = Utility.Create("TextBox", {
        Parent            = frame,
        Position          = UDim2.new(0, 10, 0, 26),
        Size              = UDim2.new(1, -20, 0, 22),
        BackgroundColor3  = Config.Theme.Surface,
        BorderSizePixel   = 0,
        Text              = "",
        PlaceholderText   = cfg.Placeholder or "Type here...",
        PlaceholderColor3 = Config.Theme.TextMuted,
        TextColor3        = Config.Theme.Text,
        Font              = Config.Font,
        TextSize          = 13,
        ClearTextOnFocus  = false,
        TextXAlignment    = Enum.TextXAlignment.Left,
    })
    Utility.AddCorner(InputBox, UDim.new(0, 4))
    Utility.Create("UIPadding", { Parent = InputBox, PaddingLeft = UDim.new(0, 8) })

    InputBox.Focused:Connect(function()
        Utility.Tween(InputBox, { BackgroundColor3 = Color3.fromRGB(32, 32, 42) }, 0.15)
    end)
    InputBox.FocusLost:Connect(function(enter)
        Utility.Tween(InputBox, { BackgroundColor3 = Config.Theme.Surface }, 0.15)
        if enter then
            if cfg.Callback then cfg.Callback(InputBox.Text) end
            OnChanged:Fire(InputBox.Text)
        end
    end)

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return InputBox.Text end,
        SetValue  = function(val) InputBox.Text = val end,
    }, frame)
end
