-- src/elements/NumberInput.lua
-- Tab:CreateNumberInput(cfg) factory.
-- cfg: { Text?, Min?, Max?, Step?, Default?, Callback? }
--
-- Splits Commit (user-triggered, fires Callback+OnChanged) from SetValue (silent).
-- Invalid typed input reverts to last valid value.

return function(self, cfg)
    cfg = cfg or {}
    local min     = cfg.Min     or -math.huge
    local max     = cfg.Max     or  math.huge
    local step    = cfg.Step    or 1
    local current = math.clamp(cfg.Default or 0, min, max)
    local OnChanged = Signal.new()
    local frame     = self:BaseFrame(54)

    Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(0, 12, 0, 6),
        Size               = UDim2.new(1, -24, 0, 16),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Number",
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.FontMedium,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local Row = Utility.Create("Frame", {
        Parent             = frame,
        Position           = UDim2.new(0, 10, 0, 26),
        Size               = UDim2.new(1, -20, 0, 22),
        BackgroundTransparency = 1,
        BorderSizePixel    = 0,
    })

    local function makeStepBtn(anchorX, symbol)
        local btn = Utility.Create("TextButton", {
            Parent           = Row,
            AnchorPoint      = Vector2.new(anchorX, 0),
            Position         = UDim2.new(anchorX, 0, 0, 0),
            Size             = UDim2.new(0, 26, 1, 0),
            BackgroundColor3 = Config.Theme.Surface,
            Text             = symbol,
            TextColor3       = Config.Theme.Primary,
            Font             = Config.FontBold,
            TextSize         = 16,
            AutoButtonColor  = false,
            BorderSizePixel  = 0,
        })
        Utility.AddCorner(btn, UDim.new(0, 4))
        btn.MouseEnter:Connect(function()
            Utility.Tween(btn, { BackgroundColor3 = Config.Theme.Primary, TextColor3 = Config.Theme.Text }, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            Utility.Tween(btn, { BackgroundColor3 = Config.Theme.Surface, TextColor3 = Config.Theme.Primary }, 0.15)
        end)
        return btn
    end

    local MinusBtn = makeStepBtn(0, "−")
    local PlusBtn  = makeStepBtn(1, "+")

    local NumBox = Utility.Create("TextBox", {
        Parent             = Row,
        Position           = UDim2.new(0, 30, 0, 0),
        Size               = UDim2.new(1, -60, 1, 0),
        BackgroundColor3   = Config.Theme.Surface,
        BorderSizePixel    = 0,
        Text               = tostring(current),
        TextColor3         = Config.Theme.Text,
        Font               = Config.FontBold,
        TextSize           = 13,
        ClearTextOnFocus   = false,
        TextXAlignment     = Enum.TextXAlignment.Center,
    })
    Utility.AddCorner(NumBox, UDim.new(0, 4))

    -- User-triggered: snap + clamp, then fire callbacks.
    local function commit(val)
        val = math.clamp(math.floor(val / step + 0.5) * step, min, max)
        if val == current then
            NumBox.Text = tostring(current)  -- reset display if clamped to same value
            return
        end
        current     = val
        NumBox.Text = tostring(val)
        if cfg.Callback then cfg.Callback(val) end
        OnChanged:Fire(val)
    end

    -- Silent: same snap + clamp but NO callbacks.
    local function applyUI(val)
        current     = math.clamp(math.floor(val / step + 0.5) * step, min, max)
        NumBox.Text = tostring(current)
    end

    MinusBtn.MouseButton1Click:Connect(function() commit(current - step) end)
    PlusBtn.MouseButton1Click:Connect(function()  commit(current + step) end)
    NumBox.FocusLost:Connect(function()
        local n = tonumber(NumBox.Text)
        if n then commit(n)
        else NumBox.Text = tostring(current) end
    end)

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return current end,
        SetValue  = function(val) applyUI(val) end,
    }, frame)
end
