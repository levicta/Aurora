-- src/elements/SearchDropdown.lua
-- Tab:CreateSearchDropdown(cfg) factory.
-- cfg: { Text?, Options?, Default?, MaxVisible?, Callback? }
--
-- Uses the shared Expandable module.
-- SetValue is SILENT. User selection fires Callback + OnChanged.

return function(self, cfg)
    cfg = cfg or {}
    local options    = cfg.Options    or {}
    local selected   = cfg.Default    or "Select..."
    local OnChanged  = Signal.new()
    local labelText  = cfg.Text       or "Search"
    local MAX_VIS    = cfg.MaxVisible or 6
    local ROW_H      = 30

    local DropFrame = Utility.Create("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Config.Theme.Background,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.AddCorner(DropFrame, UDim.new(0, 4))

    local HeaderLabel = Utility.Create("TextLabel", {
        Parent             = DropFrame,
        Position           = UDim2.new(0, 12, 0, 0),
        Size               = UDim2.new(1, -38, 0, 36),
        BackgroundTransparency = 1,
        Text               = labelText .. ": " .. selected,
        TextColor3         = Config.Theme.Text,
        Font               = Config.FontMedium,
        TextSize           = 14,
        TextXAlignment     = Enum.TextXAlignment.Left,
        TextTruncate       = Enum.TextTruncate.AtEnd,
    })

    local Arrow = Utility.Create("TextLabel", {
        Parent             = DropFrame,
        Position           = UDim2.new(1, -28, 0, 0),
        Size               = UDim2.new(0, 20, 0, 36),
        BackgroundTransparency = 1,
        Text               = "▼",
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.FontBold,
        TextSize           = 11,
    })

    local SearchBox = Utility.Create("TextBox", {
        Parent            = DropFrame,
        Position          = UDim2.new(0, 6, 0, 38),
        Size              = UDim2.new(1, -12, 0, 24),
        BackgroundColor3  = Config.Theme.Surface,
        BorderSizePixel   = 0,
        Text              = "",
        PlaceholderText   = "Search...",
        PlaceholderColor3 = Config.Theme.TextMuted,
        TextColor3        = Config.Theme.Text,
        Font              = Config.Font,
        TextSize          = 12,
        ClearTextOnFocus  = true,
    })
    Utility.AddCorner(SearchBox, UDim.new(0, 4))
    Utility.Create("UIPadding", { Parent = SearchBox, PaddingLeft = UDim.new(0, 8) })

    local ListFrame = Utility.Create("ScrollingFrame", {
        Parent               = DropFrame,
        Position             = UDim2.new(0, 0, 0, 66),
        Size                 = UDim2.new(1, 0, 0, math.min(#options, MAX_VIS) * ROW_H),
        BackgroundColor3     = Config.Theme.Surface,
        BorderSizePixel      = 0,
        ScrollBarThickness   = 2,
        ScrollBarImageColor3 = Config.Theme.Border,
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        ClipsDescendants     = true,
    })
    Utility.Create("UIListLayout", { Parent = ListFrame, SortOrder = Enum.SortOrder.LayoutOrder })

    local exp  -- pre-declared so closures below capture the upvalue slot

    local optionBtns = {}
    for i, option in ipairs(options) do
        local ob = Utility.Create("TextButton", {
            Parent           = ListFrame,
            Size             = UDim2.new(1, 0, 0, ROW_H),
            BackgroundColor3 = Config.Theme.Surface,
            Text             = option,
            TextColor3       = Config.Theme.TextMuted,
            Font             = Config.FontMedium,
            TextSize         = 13,
            LayoutOrder      = i,
            AutoButtonColor  = false,
        })
        ob.MouseEnter:Connect(function()
            Utility.Tween(ob, { BackgroundColor3 = Config.Theme.Background, TextColor3 = Config.Theme.Text }, 0.15)
        end)
        ob.MouseLeave:Connect(function()
            Utility.Tween(ob, { BackgroundColor3 = Config.Theme.Surface, TextColor3 = Config.Theme.TextMuted }, 0.15)
        end)
        ob.MouseButton1Click:Connect(function()
            selected          = option
            HeaderLabel.Text  = labelText .. ": " .. option
            SearchBox.Text    = ""
            for _, btn in ipairs(optionBtns) do btn.Visible = true end
            exp.collapse()
            if cfg.Callback then cfg.Callback(option) end
            OnChanged:Fire(option)
        end)
        optionBtns[i] = ob
    end

    -- Live filter
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query  = SearchBox.Text:lower()
        local visible = 0
        for i, opt in ipairs(options) do
            local show = query == "" or opt:lower():find(query, 1, true) ~= nil
            optionBtns[i].Visible = show
            if show then visible = visible + 1 end
        end
        local newH = math.min(visible, MAX_VIS) * ROW_H
        ListFrame.Size = UDim2.new(1, 0, 0, newH)
        DropFrame.Size = UDim2.new(1, 0, 0, 66 + newH)
    end)

    local function expandedH()
        return 66 + math.min(#options, MAX_VIS) * ROW_H
    end

    -- Header toggle
    Utility.Create("TextButton", {
        Parent             = DropFrame,
        Size               = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text               = "",
    }).MouseButton1Click:Connect(function()
        if exp.isExpanded() then
            exp.collapse()
        else
            SearchBox.Text = ""
            for _, btn in ipairs(optionBtns) do btn.Visible = true end
            ListFrame.Size = UDim2.new(1, 0, 0, math.min(#options, MAX_VIS) * ROW_H)
            exp.expand()
        end
    end)

    exp = Expandable.makeExpandable(DropFrame, 36, expandedH, Arrow)

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return selected end,
        SetValue  = function(val)
            if table.find(options, val) then
                selected         = val
                HeaderLabel.Text = labelText .. ": " .. val
            end
        end,
    }, DropFrame)
end