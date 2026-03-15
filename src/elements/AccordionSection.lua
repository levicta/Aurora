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
--
-- v7.1 visual changes:
--   - Left accent bar in Primary colour anchors the header as a clickable card.
--   - OuterFrame uses Surface background (not Background) so it reads as a
--     raised card rather than blending into the content area behind it.
--   - A 1px Border-coloured stroke is simulated via a slightly larger backing
--     frame so the closed state has visible edges.
--   - Header gains MouseEnter/MouseLeave hover feedback.
--   - Arrow uses Primary colour (matching the title) instead of TextMuted.
--   - When collapsed the bottom-flush patch is hidden; when expanded it is shown,
--     keeping the header seamlessly connected to the content.

return function(self, cfg)
    cfg = cfg or {}
    local labelText   = cfg.Text        or "Section"
    local defaultOpen = cfg.DefaultOpen ~= false   -- default: open
    local expanded    = defaultOpen
    local OnChanged   = Signal.new()

    -- ── Outer container (clips inner content when collapsed) ─────────────────
    -- Surface background gives the card visible depth against the tab's
    -- Background-coloured scroll area.
    local OuterFrame = Utility.Create("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.AddCorner(OuterFrame, UDim.new(0, 6))

    -- 1px border effect: a slightly larger frame behind OuterFrame in Border colour.
    -- Placed at ZIndex - 1 so it sits behind all content.
    local BorderBacking = Utility.Create("Frame", {
        Parent           = OuterFrame,
        Position         = UDim2.new(0, -1, 0, -1),
        Size             = UDim2.new(1, 2, 1, 2),
        BackgroundColor3 = Config.Theme.Border,
        BorderSizePixel  = 0,
        ZIndex           = OuterFrame.ZIndex - 1,
    })
    Utility.AddCorner(BorderBacking, UDim.new(0, 7))

    -- ── Header bar ───────────────────────────────────────────────────────────
    local Header = Utility.Create("Frame", {
        Parent           = OuterFrame,
        Size             = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Header, UDim.new(0, 6))

    -- Flush-bottom patch: shown when expanded so the header blends seamlessly
    -- into the content area below it; hidden when collapsed so the rounded
    -- bottom corners of the header are visible.
    local FlushPatch = Utility.Create("Frame", {
        Parent           = Header,
        Position         = UDim2.new(0, 0, 1, -8),
        Size             = UDim2.new(1, 0, 0, 8),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
        Visible          = defaultOpen,
    })

    -- Left accent bar — primary colour, communicates interactivity.
    local AccentBar = Utility.Create("Frame", {
        Parent           = Header,
        Position         = UDim2.new(0, 0, 0, 6),
        Size             = UDim2.new(0, 3, 1, -12),
        BackgroundColor3 = Config.Theme.Primary,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(AccentBar, UDim.new(1, 0))

    Utility.Create("TextLabel", {
        Parent             = Header,
        Position           = UDim2.new(0, 14, 0, 0),
        Size               = UDim2.new(1, -42, 1, 0),
        BackgroundTransparency = 1,
        Text               = labelText:upper(),
        TextColor3         = Config.Theme.Primary,
        Font               = Config.FontBold,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    -- Arrow: Primary colour so it reads as part of the same interactive unit
    -- as the title rather than a separate, dimmed hint.
    local Arrow = Utility.Create("TextLabel", {
        Parent             = Header,
        Position           = UDim2.new(1, -28, 0, 0),
        Size               = UDim2.new(0, 20, 0, 36),
        BackgroundTransparency = 1,
        Text               = "▼",
        TextColor3         = Config.Theme.Primary,
        Font               = Config.FontBold,
        TextSize           = 12,
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
        PaddingLeft   = UDim.new(0, 6),
        PaddingRight  = UDim.new(0, 6),
    })

    -- ── Proxy ────────────────────────────────────────────────────────────────
    -- Create* methods are called on this object. It redirects Content to
    -- InnerFrame; everything else falls through to the parent Tab.
    local proxy = {
        Content          = InnerFrame,
        Elements         = {},
        _window          = self._window,
        _elementConnSets = self._elementConnSets,
        _emptyLabel      = { Visible = true },
        OnElementAdded   = Signal.new(),
    }
    setmetatable(proxy, { __index = self })

    -- ── Size management ──────────────────────────────────────────────────────
    local function getExpandedH()
        return 36 + InnerFrame.AbsoluteSize.Y
    end

    local function applySize(animate)
        local targetH = expanded and getExpandedH() or 36
        -- Show/hide the flush patch so corners look correct in both states.
        FlushPatch.Visible = expanded
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

    -- ── Header toggle + hover feedback ───────────────────────────────────────
    local ToggleBtn = Utility.Create("TextButton", {
        Parent             = Header,
        Size               = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 2,
    })

    -- Hover: brighten the header slightly so it feels clickable.
    ToggleBtn.MouseEnter:Connect(function()
        Utility.Tween(Header, { BackgroundColor3 = Color3.fromRGB(32, 32, 40) }, 0.15)
        FlushPatch.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    end)
    ToggleBtn.MouseLeave:Connect(function()
        Utility.Tween(Header, { BackgroundColor3 = Config.Theme.Surface }, 0.15)
        FlushPatch.BackgroundColor3 = Config.Theme.Surface
    end)

    ToggleBtn.MouseButton1Click:Connect(function()
        expanded = not expanded
        Utility.Tween(Arrow, { Rotation = expanded and 180 or 0 }, 0.2)
        applySize(true)
        OnChanged:Fire(expanded)
    end)

    -- ── Register on parent tab ───────────────────────────────────────────────
    local element = self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return expanded end,
        SetValue  = function(v)
            v = not not v
            if v == expanded then return end
            expanded = v
            Utility.Tween(Arrow, { Rotation = expanded and 180 or 0 }, 0.2)
            applySize(true)
        end,
        Expand = function()
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
