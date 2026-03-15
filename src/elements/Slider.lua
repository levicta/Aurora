-- src/elements/Slider.lua
-- Tab:CreateSlider(cfg) factory.
-- cfg: { Text?, Min?, Max?, Default?, Increment?, Callback? }
--
-- UIS connections (InputChanged, InputEnded) go into the element's own ConnSet
-- so they are disconnected on element.Destroy() without touching the window set.
--
-- SetValue is SILENT (does not fire Callback or OnChanged).
-- Dragging fires both.

return function(self, cfg)
    cfg = cfg or {}
    local min       = cfg.Min       or 0
    local max       = cfg.Max       or 100
    local increment = cfg.Increment or 1
    local current   = math.clamp(cfg.Default or min, min, max)
    local OnChanged = Signal.new()
    local frame     = self:BaseFrame(50)

    Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(0, 12, 0, 8),
        Size               = UDim2.new(1, -60, 0, 16),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Slider",
        TextColor3         = Config.Theme.Text,
        Font               = Config.FontMedium,
        TextSize           = 14,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local ValueLabel = Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(1, -52, 0, 8),
        Size               = UDim2.new(0, 42, 0, 16),
        BackgroundTransparency = 1,
        Text               = tostring(current),
        TextColor3         = Config.Theme.Primary,
        Font               = Config.FontBold,
        TextSize           = 14,
        TextXAlignment     = Enum.TextXAlignment.Right,
    })

    local Bar = Utility.Create("Frame", {
        Parent           = frame,
        Position         = UDim2.new(0, 12, 0, 32),
        Size             = UDim2.new(1, -24, 0, 4),
        BackgroundColor3 = Config.Theme.Border,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Bar, UDim.new(1, 0))

    local function pct() return (current - min) / (max - min) end

    local Fill = Utility.Create("Frame", {
        Parent           = Bar,
        Size             = UDim2.new(pct(), 0, 1, 0),
        BackgroundColor3 = Config.Theme.Primary,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Fill, UDim.new(1, 0))

    local Knob = Utility.Create("Frame", {
        Parent           = Bar,
        Position         = UDim2.new(pct(), -6, 0.5, -6),
        Size             = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Knob, UDim.new(1, 0))

    -- Apply a raw X screen position to the slider (user drag).
    -- Always fires Callback + OnChanged.
    local function applyFromInput(inputX)
        local p = math.clamp((inputX - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
        local snapped = math.clamp(math.floor((min + (max - min) * p) / increment + 0.5) * increment, min, max)
        if snapped == current then return end
        current = snapped
        local f = pct()
        Fill.Size       = UDim2.new(f, 0, 1, 0)
        Knob.Position   = UDim2.new(f, -6, 0.5, -6)
        ValueLabel.Text = tostring(snapped)
        if cfg.Callback then cfg.Callback(snapped) end
        OnChanged:Fire(snapped)
    end

    -- Silent UI update (for SetValue).
    local function applyUI(val)
        current         = math.clamp(val, min, max)
        local f         = pct()
        Fill.Size       = UDim2.new(f, 0, 1, 0)
        Knob.Position   = UDim2.new(f, -6, 0.5, -6)
        ValueLabel.Text = tostring(current)
    end

    local dragging = false
    -- Frame-local connections: destroyed with the frame, no ConnSet needed.
    Knob.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    Bar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            applyFromInput(inp.Position.X)
        end
    end)

    -- UIS global connections: must be tracked in ConnSet for proper cleanup.
    local elementConns = ConnSet.new()
    elementConns:Add(UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            applyFromInput(inp.Position.X)
        end
    end))
    elementConns:Add(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return current end,
        -- Silent: updates UI only.
        SetValue  = function(val) applyUI(val) end,
    }, frame, elementConns)
end
