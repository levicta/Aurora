-- src/elements/AccordionSection.lua
-- Tab:CreateAccordionSection(cfg) factory.
-- cfg: { Text?, DefaultOpen? }
--
-- A collapsible section group. Child elements are added via section:Create*()
-- and live inside an inner content frame that expands/collapses with animation.
--
-- Design:
--   - A proxy table (Content = InnerFrame) is passed as `self` to all child
--     element factories. This redirects frame parenting without touching the
--     Tab's own element list.
--   - Child ConnSets are inserted into the parent tab's _elementConnSets array
--     so Window:Destroy() cleans them up correctly.
--   - section:Destroy() cascades to all children before destroying the frame.
--   - OuterFrame height is tracked via InnerFrame:GetPropertyChangedSignal
--     so children added after creation expand the accordion automatically.

return function(self, cfg)
    cfg = cfg or {}
    local labelText  = cfg.Text        or "Section"
    local defaultOpen = cfg.DefaultOpen ~= false   -- default: open
    local expanded   = defaultOpen
    local OnChanged  = Signal.new()

    -- ── Outer container (clips inner content when collapsed) ─────────────────
    local OuterFrame = Utility.Create("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Config.Theme.Background,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.AddCorner(OuterFrame, UDim.new(0, 4))

    -- ── Header bar ───────────────────────────────────────────────────────────
    local Header = Utility.Create("Frame", {
        Parent           = OuterFrame,
        Size             = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Header, UDim.new(0, 4))
    -- Flush bottom corners so header blends into content when open
    Utility.Create("Frame", {
        Parent           = Header,
        Position         = UDim2.new(0, 0, 1, -6),
        Size             = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
    })

    Utility.Create("TextLabel", {
        Parent             = Header,
        Position           = UDim2.new(0, 12, 0, 0),
        Size               = UDim2.new(1, -38, 1, 0),
        BackgroundTransparency = 1,
        Text               = labelText:upper(),
        TextColor3         = Config.Theme.Primary,
        Font               = Config.FontBold,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local Arrow = Utility.Create("TextLabel", {
        Parent             = Header,
        Position           = UDim2.new(1, -28, 0, 0),
        Size               = UDim2.new(0, 20, 0, 36),
        BackgroundTransparency = 1,
        Text               = "▼",
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.FontBold,
        TextSize           = 11,
        Rotation           = defaultOpen and 180 or 0,
    })

    -- ── Inner content frame ──────────────────────────────────────────────────
    local InnerFrame = Utility.Create("Frame", {
        Parent             = OuterFrame,
        Position           = UDim2.new(0, 0, 0, 36),
        Size               = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel    = 0,
        AutomaticSize      = Enum.AutomaticSize.Y,
    })
    Utility.Create("UIListLayout", {
        Parent    = InnerFrame,
        Padding   = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    Utility.Create("UIPadding", {
        Parent        = InnerFrame,
        PaddingTop    = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft   = UDim.new(0, 0),
        PaddingRight  = UDim.new(0, 0),
    })

    -- ── Proxy ────────────────────────────────────────────────────────────────
    -- Create* methods are called on this object. It redirects Content to
    -- InnerFrame; everything else falls through to the parent Tab.
    local proxy = {
        Content          = InnerFrame,
        Elements         = {},            -- own list; does not pollute tab.Elements
        _window          = self._window,
        _elementConnSets = self._elementConnSets,   -- shared: Window:Destroy() cleans up
        _emptyLabel      = { Visible = true },      -- dummy: prevents touching tab's label
        OnElementAdded   = Signal.new(),
    }
    setmetatable(proxy, { __index = self })

    -- ── Size management ──────────────────────────────────────────────────────
    local function getExpandedH()
        return 36 + InnerFrame.AbsoluteSize.Y
    end

    local function applySize(animate)
        local targetH = expanded and getExpandedH() or 36
        if animate then
            Utility.Tween(OuterFrame, { Size = UDim2.new(1, 0, 0, targetH) }, 0.2)
        else
            OuterFrame.Size = UDim2.new(1, 0, 0, targetH)
        end
    end

    -- Keep outer height in sync as children are added/removed while open.
    InnerFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if expanded then
            OuterFrame.Size = UDim2.new(1, 0, 0, getExpandedH())
        end
    end)

    -- Set correct initial height after children are added (one frame later).
    task.defer(function()
        applySize(false)
    end)

    -- ── Header toggle ────────────────────────────────────────────────────────
    Utility.Create("TextButton", {
        Parent             = Header,
        Size               = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 2,
    }).MouseButton1Click:Connect(function()
        expanded = not expanded
        Utility.Tween(Arrow, { Rotation = expanded and 180 or 0 }, 0.2)
        applySize(true)
        OnChanged:Fire(expanded)
    end)

    -- ── Register on parent tab ───────────────────────────────────────────────
    local element = self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return expanded end,
        -- SetValue(bool): programmatically expand or collapse.
        SetValue  = function(v)
            v = not not v
            if v == expanded then return end
            expanded = v
            Utility.Tween(Arrow, { Rotation = expanded and 180 or 0 }, 0.2)
            applySize(true)
        end,
        -- Convenience aliases
        Expand   = function()
            if expanded then return end
            expanded = true
            Utility.Tween(Arrow, { Rotation = 180 }, 0.2)
            applySize(true)
        end,
        Collapse = function()
            if not expanded then return end
            expanded = false
            Utility.Tween(Arrow, { Rotation = 0 }, 0.2)
            applySize(true)
        end,
    }, OuterFrame)

    -- ── Expose Create* via proxy ─────────────────────────────────────────────
    -- Each method calls the Tab factory with `proxy` as self so elements are
    -- parented to InnerFrame rather than tab.Content.
    element.CreateButton         = function(_, c) return Tab.CreateButton(proxy, c) end
    element.CreateToggle         = function(_, c) return Tab.CreateToggle(proxy, c) end
    element.CreateSlider         = function(_, c) return Tab.CreateSlider(proxy, c) end
    element.CreateDropdown       = function(_, c) return Tab.CreateDropdown(proxy, c) end
    element.CreateSearchDropdown = function(_, c) return Tab.CreateSearchDropdown(proxy, c) end
    element.CreateMultiSelect    = function(_, c) return Tab.CreateMultiSelect(proxy, c) end
    element.CreateInput          = function(_, c) return Tab.CreateInput(proxy, c) end
    element.CreateNumberInput    = function(_, c) return Tab.CreateNumberInput(proxy, c) end
    element.CreateKeybind        = function(_, c) return Tab.CreateKeybind(proxy, c) end
    element.CreateColorPicker    = function(_, c) return Tab.CreateColorPicker(proxy, c) end
    element.CreateLabel          = function(_, c) return Tab.CreateLabel(proxy, c) end
    element.CreateSection        = function(_, c) return Tab.CreateSection(proxy, c) end
    element.CreateProgressBar    = function(_, c) return Tab.CreateProgressBar(proxy, c) end
    element.CreateStatusLabel    = function(_, c) return Tab.CreateStatusLabel(proxy, c) end
    element.CreateTable          = function(_, c) return Tab.CreateTable(proxy, c) end
    element.CreateRow            = function(_, c) return Tab.CreateRow(proxy, c) end

    -- ── Override Destroy to cascade to children ──────────────────────────────
    local parentDestroy = element.Destroy
    element.Destroy = function()
        for _, child in ipairs(proxy.Elements) do
            if child.Destroy then pcall(child.Destroy) end
        end
        parentDestroy()
    end

    return element
end