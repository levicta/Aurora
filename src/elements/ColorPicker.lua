-- src/elements/ColorPicker.lua
-- Tab:CreateColorPicker(cfg) factory.
-- cfg: { Text?, Default?, Callback? }
--
-- Fixes the v6 double-insertion bug: svMove/svEnd/hueMove/hueEnd were inserted
-- into windowConnections directly AND passed as ownedConns, causing them to live
-- in the array twice and never fully disconnect on element.Destroy().
-- All four UIS connections now live exclusively in the element's ConnSet.
--
-- Splits CommitUser (user drag — fires Callback+OnChanged) from applyUI
-- (SetValue — silent).

return function(self, cfg)
    cfg = cfg or {}
    local color = cfg.Default or Color3.fromRGB(255, 255, 255)
    local OnChanged = Signal.new()
    local h, s, v = Color3.toHSV(color)

    local EXPANDED_H = 148   -- 36 header + 6 gap + 68 pads + 6 gap + 22 hex + 10 pad

    local PickerFrame = Utility.Create("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Config.Theme.Background,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.AddCorner(PickerFrame, UDim.new(0, 4))

    Utility.Create("TextLabel", {
        Parent             = PickerFrame,
        Position           = UDim2.new(0, 12, 0, 0),
        Size               = UDim2.new(1, -56, 0, 36),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Color",
        TextColor3         = Config.Theme.Text,
        Font               = Config.FontMedium,
        TextSize           = 14,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local Preview = Utility.Create("Frame", {
        Parent           = PickerFrame,
        Position         = UDim2.new(1, -42, 0.5, -10),
        Size             = UDim2.new(0, 28, 0, 20),
        BackgroundColor3 = color,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Preview, UDim.new(0, 4))

    local exp  -- pre-declared so toggle closure below captures the upvalue slot

    Utility.Create("TextButton", {
        Parent             = PickerFrame,
        Size               = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 10,
    }).MouseButton1Click:Connect(function() exp.toggle() end)

    local Panel = Utility.Create("Frame", {
        Parent             = PickerFrame,
        Position           = UDim2.new(0, 8, 0, 44),
        Size               = UDim2.new(1, -16, 0, 96),
        BackgroundTransparency = 1,
        BorderSizePixel    = 0,
    })

    -- SV Pad
    local SVPad = Utility.Create("Frame", {
        Parent           = Panel,
        Position         = UDim2.new(0, 0, 0, 0),
        Size             = UDim2.new(1, -26, 0, 68),
        BackgroundColor3 = Color3.fromHSV(h, 1, 1),
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        ZIndex           = 2,
    })
    Utility.AddCorner(SVPad, UDim.new(0, 4))
    local WLayer = Utility.Create("Frame", { Parent = SVPad, Size = UDim2.new(1,0,1,0),
        BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 3 })
    Utility.Create("UIGradient", { Parent = WLayer,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1) }), Rotation = 0 })
    local BLayer = Utility.Create("Frame", { Parent = SVPad, Size = UDim2.new(1,0,1,0),
        BackgroundColor3 = Color3.new(0,0,0), BorderSizePixel = 0, ZIndex = 4 })
    Utility.Create("UIGradient", { Parent = BLayer,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0) }), Rotation = 90 })

    local SVDrag = Utility.Create("TextButton", {
        Parent = SVPad, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", ZIndex = 6
    })
    local SVCursor = Utility.Create("Frame", {
        Parent = SVPad, Size = UDim2.new(0,10,0,10), AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(s,0,1-v,0), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 7
    })
    Utility.AddCorner(SVCursor, UDim.new(1,0))

    -- Hue Bar
    local HueBar = Utility.Create("Frame", {
        Parent = Panel, Position = UDim2.new(1,-20,0,0), Size = UDim2.new(0,14,0,68),
        BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2
    })
    Utility.AddCorner(HueBar, UDim.new(0,4))
    Utility.Create("UIGradient", { Parent = HueBar, Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0/6, Color3.fromHSV(0/6,1,1)),
            ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6,1,1)),
            ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6,1,1)),
            ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6,1,1)),
            ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6,1,1)),
            ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6,1,1)),
            ColorSequenceKeypoint.new(1,   Color3.fromHSV(0,  1,1)),
        })
    })
    local HueDrag = Utility.Create("TextButton", {
        Parent = HueBar, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", ZIndex = 3
    })
    local HueCursor = Utility.Create("Frame", {
        Parent = HueBar, Size = UDim2.new(1,0,0,4), AnchorPoint = Vector2.new(0,0.5),
        Position = UDim2.new(0,0,h,0), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 4
    })
    Utility.AddCorner(HueCursor, UDim.new(1,0))

    -- Hex Input
    local HexInput = Utility.Create("TextBox", {
        Parent = Panel, Position = UDim2.new(0,0,0,74), Size = UDim2.new(1,0,0,22),
        BackgroundColor3 = Config.Theme.Surface, BorderSizePixel = 0,
        Text = string.format("#%02X%02X%02X", math.round(color.R*255), math.round(color.G*255), math.round(color.B*255)),
        TextColor3 = Config.Theme.Text, Font = Config.Font, TextSize = 12, ClearTextOnFocus = false, ZIndex = 2,
    })
    Utility.AddCorner(HexInput, UDim.new(0,4))
    Utility.Create("UIPadding", { Parent = HexInput, PaddingLeft = UDim.new(0,8) })

    -- Sync all visuals to current h/s/v.  silent = skip Callback/OnChanged.
    local function applyUI(silent)
        color                    = Color3.fromHSV(h, s, v)
        Preview.BackgroundColor3 = color
        SVPad.BackgroundColor3   = Color3.fromHSV(h, 1, 1)
        SVCursor.Position        = UDim2.new(s, 0, 1-v, 0)
        HueCursor.Position       = UDim2.new(0, 0, h, 0)
        HexInput.Text = string.format("#%02X%02X%02X",
            math.round(color.R*255), math.round(color.G*255), math.round(color.B*255))
        if not silent then
            if cfg.Callback then cfg.Callback(color) end
            OnChanged:Fire(color)
        end
    end

    -- User drag helpers
    local svDragging, hueDragging = false, false

    SVDrag.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            svDragging = true
            s = math.clamp((inp.Position.X - SVPad.AbsolutePosition.X) / SVPad.AbsoluteSize.X, 0, 1)
            v = 1 - math.clamp((inp.Position.Y - SVPad.AbsolutePosition.Y) / SVPad.AbsoluteSize.Y, 0, 1)
            applyUI(false)
        end
    end)
    HueDrag.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            hueDragging = true
            h = math.clamp((inp.Position.Y - HueBar.AbsolutePosition.Y) / HueBar.AbsoluteSize.Y, 0, 1)
            applyUI(false)
        end
    end)

    -- UIS globals: tracked in ConnSet — no double-insertion, clean teardown.
    local elementConns = ConnSet.new()
    elementConns:Add(UserInputService.InputChanged:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if svDragging then
            s = math.clamp((inp.Position.X - SVPad.AbsolutePosition.X) / SVPad.AbsoluteSize.X, 0, 1)
            v = 1 - math.clamp((inp.Position.Y - SVPad.AbsolutePosition.Y) / SVPad.AbsoluteSize.Y, 0, 1)
            applyUI(false)
        elseif hueDragging then
            h = math.clamp((inp.Position.Y - HueBar.AbsolutePosition.Y) / HueBar.AbsoluteSize.Y, 0, 1)
            applyUI(false)
        end
    end))
    elementConns:Add(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            svDragging  = false
            hueDragging = false
        end
    end))

    HexInput.FocusLost:Connect(function(enter)
        if not enter then return end
        local hex = HexInput.Text:gsub("#", "")
        if #hex == 6 then
            local r = tonumber(hex:sub(1,2), 16)
            local g = tonumber(hex:sub(3,4), 16)
            local b = tonumber(hex:sub(5,6), 16)
            if r and g and b then
                color     = Color3.fromRGB(r, g, b)
                h, s, v   = Color3.toHSV(color)
                applyUI(false)
            end
        end
    end)

    exp = Expandable.makeExpandable(PickerFrame, 36, EXPANDED_H)

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return color end,
        -- Silent: syncs all visuals, does NOT fire Callback or OnChanged.
        SetValue  = function(c)
            color   = c
            h, s, v = Color3.toHSV(c)
            applyUI(true)
        end,
    }, PickerFrame, elementConns)
end