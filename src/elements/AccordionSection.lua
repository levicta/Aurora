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
-- Visual changes (v7.1):
--   - OuterFrame now uses Surface colour + UIStroke for a defined card boundary.
--     Removed the Background fill that made the card invisible against the tab.
--   - Replaced the fragile "flush-bottom-corners" Frame hack with a clean 1px
--     separator line that fades in/out alongside the expand animation.
--   - Added a 3px Primary-coloured left accent bar on the header.  The outer
--     frame's ClipsDescendants rounds its exposed corners automatically so no
--     extra cover-frame trickery is needed.
--   - Arrow tint changed from TextMuted → Primary to match the header label.
--   - Header gains a subtle hover tween (Surface → slightly brighter) so the
--     click target gives visual feedback.
--   - Label TextSize bumped from 11 → 12 (consistent with other elements).
--   - InnerFrame gains 8px left/right padding so child elements no longer
--     press flush against the card edges.

return function(self, cfg)
    cfg = cfg or {}
    local labelText   = cfg.Text        or "Section"
    local defaultOpen = cfg.DefaultOpen ~= false   -- default: open
    local expanded    = defaultOpen
    local OnChanged   = Signal.new()

    -- Layout constants kept as locals so all size calculations stay in sync.
    local HEADER_H = 36
    local SEP_H    = 1

    -- Hover colours derived from the theme so custom SetTheme calls still look
    -- reasonable without needing a per-instance patch.
    local COLOR_HOVER = Color3.fromRGB(32, 32, 40)   -- slightly brighter than Surface

    -- ── Outer container ───────────────────────────────────────────────────────
    -- Surface fill + border stroke gives this a proper "card" boundary against
    -- the Background-coloured tab content area.  ClipsDescendants handles the
    -- expand/collapse mask and also rounds the exposed corners of the AccentBar.
    local OuterFrame = Utility.Create("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, HEADER_H),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.AddCorner(OuterFrame, UDim.new(0, 6))
    Utility.Create("UIStroke", {
        Parent       = OuterFrame,
        Color        = Config.Theme.Border,
        Thickness    = 1,
        Transparency = 0.45,
    })

    -- ── Header bar ────────────────────────────────────────────────────────────
    -- Same colour as OuterFrame — renders invisible but acts as the hover target
    -- (so a tween on Header alone changes the header region without affecting
    -- the content area or the outer card border).
    local Header = Utility.Create("Frame", {
        Parent           = OuterFrame,
        Size             = UDim2.new(1, 0, 0, HEADER_H),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
    })

    -- 3px left accent bar.  OuterFrame's ClipsDescendants + 6px corner radius
    -- naturally rounds the bar's top-left and bottom-left corners — no extra
    -- cover-frame required.
    Utility.Create("Frame", {
        Parent           = Header,
        Position         = UDim2.new(0, 0, 0, 0),
        Size             = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = Config.Theme.Primary,
        BorderSizePixel  = 0,
    })

    -- Section label — offset 16px from the left to clear the accent bar.
    Utility.Create("TextLabel", {
        Parent             = Header,
        Position           = UDim2.new(0, 16, 0, 0),
        Size               = UDim2.new(1, -44, 1, 0),
        BackgroundTransparency = 1,
        Text               = labelText:upper(),
        TextColor3         = Config.Theme.Primary,
        Font               = Config.FontBold,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    -- Arrow indicator.  Uses Primary to match the label — was TextMuted before.
    -- TextSize 10 gives a subtle hierarchy against the 12px label.
    local Arrow = Utility.Create("TextLabel", {
        Parent             = Header,
        Position           = UDim2.new(1, -30, 0, 0),
        Size               = UDim2.new(0, 20, 0, HEADER_H),
        BackgroundTransparency = 1,
        Text               = "▼",
        TextColor3         = Config.Theme.Primary,
        Font               = Config.FontBold,
        TextSize           = 10,
        Rotation           = defaultOpen and 180 or 0,
    })

    -- ── Separator ─────────────────────────────────────────────────────────────
    -- 1px line between header and content.  Positioned at Y = HEADER_H so it
    -- is naturally clipped when OuterFrame is collapsed.  Fades in/out with the
    -- expand animation rather than popping abruptly.
    -- A small horizontal inset (8px each side) keeps it visually lightweight.
    local Separator = Utility.Create("Frame", {
        Parent                 = OuterFrame,
        Position               = UDim2.new(0, 8, 0, HEADER_H),
        Size                   = UDim2.new(1, -16, 0, SEP_H),
        BackgroundColor3       = Config.Theme.Border,
        BorderSizePixel        = 0,
        BackgroundTransparency = defaultOpen and 0.4 or 1,
    })

    -- ── Inner content frame ───────────────────────────────────────────────────
    -- Starts at HEADER_H + SEP_H to sit below the separator line.
    -- Horizontal padding added so child elements don't press against card edges.
    local InnerFrame = Utility.Create("Frame", {
        Parent             = OuterFrame,
        Position           = UDim2.new(0, 0, 0, HEADER_H + SEP_H),
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
        PaddingTop    = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft   = UDim.new(0, 8),
        PaddingRight  = UDim.new(0, 8),
    })

    -- ── Proxy ─────────────────────────────────────────────────────────────────
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

    -- ── Size management ───────────────────────────────────────────────────────
    local function getExpandedH()
        return HEADER_H + SEP_H + InnerFrame.AbsoluteSize.Y
    end

    local function applySize(animate)
        local targetH = expanded and getExpandedH() or HEADER_H
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

    -- ── Header toggle ─────────────────────────────────────────────────────────
    local ClickButton = Utility.Create("TextButton", {
        Parent             = Header,
        Size               = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 2,
    })

    -- Subtle hover feedback: tween Header background between Surface and a
    -- slightly brighter shade.  Does not affect the accent bar or arrow — only
    -- the neutral header area changes, keeping the accent visually stable.
    ClickButton.MouseEnter:Connect(function()
        Utility.Tween(Header, { BackgroundColor3 = COLOR_HOVER }, 0.15)
    end)
    ClickButton.MouseLeave:Connect(function()
        Utility.Tween(Header, { BackgroundColor3 = Config.Theme.Surface }, 0.15)
    end)

    ClickButton.MouseButton1Click:Connect(function()
        expanded = not expanded
        Utility.Tween(Arrow, { Rotation = expanded and 180 or 0 }, 0.2)
        -- Fade separator in quickly when opening, out nearly instantly when closing
        -- so it doesn't linger behind the collapsing content.
        Utility.Tween(
            Separator,
            { BackgroundTransparency = expanded and 0.4 or 1 },
            expanded and 0.15 or 0.05
        )
        applySize(true)
        OnChanged:Fire(expanded)
    end)

    -- ── Register on parent tab ────────────────────────────────────────────────
    local element = self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return expanded end,
        -- SetValue(bool): programmatically expand or collapse. Silent — does not
        -- fire OnChanged (matches the convention used by every other element).
        SetValue  = function(v)
            v = not not v
            if v == expanded then return end
            expanded = v
            Utility.Tween(Arrow, { Rotation = expanded and 180 or 0 }, 0.2)
            Utility.Tween(
                Separator,
                { BackgroundTransparency = expanded and 0.4 or 1 },
                expanded and 0.15 or 0.05
            )
            applySize(true)
        end,
        -- Convenience aliases
        Expand = function()
            if expanded then return end
            expanded = true
            Utility.Tween(Arrow, { Rotation = 180 }, 0.2)
            Utility.Tween(Separator, { BackgroundTransparency = 0.4 }, 0.15)
            applySize(true)
        end,
        Collapse = function()
            if not expanded then return end
            expanded = false
            Utility.Tween(Arrow, { Rotation = 0 }, 0.2)
            Utility.Tween(Separator, { BackgroundTransparency = 1 }, 0.05)
            applySize(true)
        end,
    }, OuterFrame)

    -- ── Expose Create* via proxy ──────────────────────────────────────────────
    -- Each method calls the Tab factory with `proxy` as self so elements are
    -- parented to InnerFrame rather than tab.Content.
    -- Use `self` (the tab instance) rather than the `Tab` upvalue — Tab is defined
    -- after _AccordionSection in the build chain so the upvalue would be nil.
    -- self.CreateX resolves through Tab.__index at call time, which is fine.
    element.CreateButton         = function(_, c) return self.CreateButton(proxy, c) end
    element.CreateToggle         = function(_, c) return self.CreateToggle(proxy, c) end
    element.CreateSlider         = function(_, c) return self.CreateSlider(proxy, c) end
    element.CreateDropdown       = function(_, c) return self.CreateDropdown(proxy, c) end
    element.CreateSearchDropdown = function(_, c) return self.CreateSearchDropdown(proxy, c) end
    element.CreateMultiSelect    = function(_, c) return self.CreateMultiSelect(proxy, c) end
    element.CreateInput          = function(_, c) return self.CreateInput(proxy, c) end
    element.CreateNumberInput    = function(_, c) return self.CreateNumberInput(proxy, c) end
    element.CreateKeybind        = function(_, c) return self.CreateKeybind(proxy, c) end
    element.CreateColorPicker    = function(_, c) return self.CreateColorPicker(proxy, c) end
    element.CreateLabel          = function(_, c) return self.CreateLabel(proxy, c) end
    element.CreateSection        = function(_, c) return self.CreateSection(proxy, c) end
    element.CreateProgressBar    = function(_, c) return self.CreateProgressBar(proxy, c) end
    element.CreateStatusLabel    = function(_, c) return self.CreateStatusLabel(proxy, c) end
    element.CreateTable          = function(_, c) return self.CreateTable(proxy, c) end
    element.CreateRow            = function(_, c) return self.CreateRow(proxy, c) end

    -- ── Override Destroy to cascade to children ───────────────────────────────
    local parentDestroy = element.Destroy
    element.Destroy = function()
        for _, child in ipairs(proxy.Elements) do
            if child.Destroy then pcall(child.Destroy) end
        end
        parentDestroy()
    end

    return element
end
