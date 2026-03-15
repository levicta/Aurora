-- src/elements/Dropdown.lua
-- Tab:CreateDropdown(cfg) factory.
-- cfg: { Text?, Options?, Default?, Callback? }
--
-- Uses the shared Expandable module — no duplicated tween/registry code.
-- SetValue is SILENT. User selection fires Callback + OnChanged.
-- SetOptions replaces the option list at runtime (used by ConfigSystem profile picker).

return function(self, cfg)
    cfg = cfg or {}
    local options   = cfg.Options or {}
    local selected  = cfg.Default or "Select..."
    local OnChanged = Signal.new()
    local labelText = cfg.Text or "Dropdown"

    local DropFrame = Utility.Create("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Config.Theme.Background,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.AddCorner(DropFrame, UDim.new(0, 4))

    local Label = Utility.Create("TextLabel", {
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

    local OptionsFrame = Utility.Create("Frame", {
        Parent           = DropFrame,
        Position         = UDim2.new(0, 0, 0, 36),
        Size             = UDim2.new(1, 0, 0, #options * 30),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.Create("UIListLayout", { Parent = OptionsFrame, SortOrder = Enum.SortOrder.LayoutOrder })

    -- Pre-declare exp so all closures below capture the upvalue slot.
    local exp

    -- Builds one option button. Used by initial build and SetOptions.
    local function makeOptionButton(i, option)
        local ob = Utility.Create("TextButton", {
            Parent           = OptionsFrame,
            Size             = UDim2.new(1, 0, 0, 30),
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
            selected   = option
            Label.Text = labelText .. ": " .. option
            exp.collapse()
            if cfg.Callback then cfg.Callback(option) end
            OnChanged:Fire(option)
        end)
        return ob
    end

    for i, option in ipairs(options) do
        makeOptionButton(i, option)
    end

    -- Toggle button (header click)
    Utility.Create("TextButton", {
        Parent             = DropFrame,
        Size               = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text               = "",
    }).MouseButton1Click:Connect(function() exp.toggle() end)

    exp = Expandable.makeExpandable(
        DropFrame,
        36,
        function() return 36 + #options * 30 end,
        Arrow
    )

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return selected end,
        -- Silent: updates label only, does NOT fire Callback or OnChanged.
        SetValue  = function(val)
            if table.find(options, val) then
                selected   = val
                Label.Text = labelText .. ": " .. val
            end
        end,
        -- Replace the full options list at runtime. Preserves selected if still valid.
        -- Does NOT fire Callback or OnChanged.
        SetOptions = function(newOptions)
            options = newOptions or {}
            for _, child in ipairs(OptionsFrame:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            for i, option in ipairs(options) do
                makeOptionButton(i, option)
            end
            OptionsFrame.Size = UDim2.new(1, 0, 0, #options * 30)
            if not table.find(options, selected) then
                selected   = options[1] or "Select..."
                Label.Text = labelText .. ": " .. selected
            end
            exp.collapse()
        end,
    }, DropFrame)
end