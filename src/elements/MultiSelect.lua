-- src/elements/MultiSelect.lua
-- Tab:CreateMultiSelect(cfg) factory.
-- cfg: { Text?, Options?, Default?, Callback? }
--
-- Uses the shared Expandable module.
-- SetValue(array) is SILENT. User interaction fires Callback + OnChanged.
-- Extra method: IsSelected(optionString) → bool

return function(self, cfg)
    cfg = cfg or {}
    local options   = cfg.Options or {}
    local selected  = {}
    local OnChanged = Signal.new()
    local labelText = cfg.Text or "Select"

    for _, opt in ipairs(cfg.Default or {}) do selected[opt] = true end

    local function selectedList()
        local t = {}
        for _, opt in ipairs(options) do
            if selected[opt] then t[#t+1] = opt end
        end
        return t
    end

    local function headerText()
        local list = selectedList()
        if #list == 0     then return labelText .. ": None"
        elseif #list == 1 then return labelText .. ": " .. list[1]
        else                   return labelText .. ": " .. #list .. " selected" end
    end

    local MultiFrame = Utility.Create("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Config.Theme.Background,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.AddCorner(MultiFrame, UDim.new(0, 4))

    local Label = Utility.Create("TextLabel", {
        Parent             = MultiFrame,
        Position           = UDim2.new(0, 12, 0, 0),
        Size               = UDim2.new(1, -38, 0, 36),
        BackgroundTransparency = 1,
        Text               = headerText(),
        TextColor3         = Config.Theme.Text,
        Font               = Config.FontMedium,
        TextSize           = 14,
        TextXAlignment     = Enum.TextXAlignment.Left,
        TextTruncate       = Enum.TextTruncate.AtEnd,
    })

    local Arrow = Utility.Create("TextLabel", {
        Parent             = MultiFrame,
        Position           = UDim2.new(1, -28, 0, 0),
        Size               = UDim2.new(0, 20, 0, 36),
        BackgroundTransparency = 1,
        Text               = "▼",
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.FontBold,
        TextSize           = 11,
    })

    local OptionsFrame = Utility.Create("Frame", {
        Parent           = MultiFrame,
        Position         = UDim2.new(0, 0, 0, 36),
        Size             = UDim2.new(1, 0, 0, #options * 30),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.Create("UIListLayout", { Parent = OptionsFrame, SortOrder = Enum.SortOrder.LayoutOrder })

    -- Per-row visual sync helpers: box + tick + label for each option.
    local rowVisuals = {}   -- [option] = { box, tick, label }
    local exp  -- pre-declared so toggle closure below captures the upvalue slot

    for i, option in ipairs(options) do
        local on  = selected[option] or false
        local row = Utility.Create("Frame", {
            Parent           = OptionsFrame,
            Size             = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Config.Theme.Surface,
            BorderSizePixel  = 0,
            LayoutOrder      = i,
        })
        local Box = Utility.Create("Frame", {
            Parent           = row,
            Position         = UDim2.new(0, 8, 0.5, -8),
            Size             = UDim2.new(0, 16, 0, 16),
            BackgroundColor3 = on and Config.Theme.Primary or Config.Theme.Border,
            BorderSizePixel  = 0,
        })
        Utility.AddCorner(Box, UDim.new(0, 3))
        local Tick = Utility.Create("TextLabel", {
            Parent             = Box,
            Size               = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text               = on and "✓" or "",
            TextColor3         = Config.Theme.Text,
            Font               = Config.FontBold,
            TextSize           = 11,
        })
        local OptionLbl = Utility.Create("TextLabel", {
            Parent             = row,
            Position           = UDim2.new(0, 32, 0, 0),
            Size               = UDim2.new(1, -40, 1, 0),
            BackgroundTransparency = 1,
            Text               = option,
            TextColor3         = on and Config.Theme.Text or Config.Theme.TextMuted,
            Font               = Config.FontMedium,
            TextSize           = 13,
            TextXAlignment     = Enum.TextXAlignment.Left,
            Name               = "OptionLabel",
        })
        rowVisuals[option] = { box = Box, tick = Tick, label = OptionLbl }

        local RowBtn = Utility.Create("TextButton", {
            Parent             = row,
            Size               = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text               = "",
        })
        RowBtn.MouseEnter:Connect(function()
            Utility.Tween(row, { BackgroundColor3 = Config.Theme.Background }, 0.15)
        end)
        RowBtn.MouseLeave:Connect(function()
            Utility.Tween(row, { BackgroundColor3 = Config.Theme.Surface }, 0.15)
        end)
        RowBtn.MouseButton1Click:Connect(function()
            selected[option] = not selected[option]
            local state = selected[option]
            Utility.Tween(Box, { BackgroundColor3 = state and Config.Theme.Primary or Config.Theme.Border }, 0.15)
            Tick.Text = state and "✓" or ""
            Utility.Tween(OptionLbl, { TextColor3 = state and Config.Theme.Text or Config.Theme.TextMuted }, 0.15)
            Label.Text = headerText()
            local vals = selectedList()
            if cfg.Callback then cfg.Callback(vals) end
            OnChanged:Fire(vals)
        end)
    end

    Utility.Create("TextButton", {
        Parent             = MultiFrame,
        Size               = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text               = "",
    }).MouseButton1Click:Connect(function() exp.toggle() end)

    exp = Expandable.makeExpandable(
        MultiFrame,
        36,
        function() return 36 + #options * 30 end,
        Arrow
    )

    return self:RegisterElement({
        OnChanged  = OnChanged,
        GetValue   = function() return selectedList() end,
        -- Silent: syncs checkboxes, does NOT fire Callback or OnChanged.
        SetValue   = function(vals)
            selected = {}
            for _, v in ipairs(vals) do selected[v] = true end
            Label.Text = headerText()
            for _, opt in ipairs(options) do
                local vis = rowVisuals[opt]
                local on  = selected[opt] or false
                if vis then
                    vis.box.BackgroundColor3 = on and Config.Theme.Primary or Config.Theme.Border
                    vis.tick.Text  = on and "✓" or ""
                    vis.label.TextColor3 = on and Config.Theme.Text or Config.Theme.TextMuted
                end
            end
        end,
        IsSelected = function(opt) return selected[opt] == true end,
    }, MultiFrame)
end