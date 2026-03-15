-- src/Tab.lua
-- Tab prototype.
--
-- v7 architectural changes vs v6:
--   1. Defined as a proper metatable prototype — element factory methods exist once,
--      not re-allocated as closures on every CreateTab call.
--   2. RegisterElement uses per-element ConnSet instead of a flat window array,
--      eliminating linear scans and the double-insertion bug.
--   3. SetEnabled uses Expandable.tryCollapse (single implementation, not 4 copies).
--   4. All element factories are assigned from separate src/elements/*.lua modules.

local Tab = {}
Tab.__index = Tab

-- ── Constructor ──────────────────────────────────────────────────────────────

function Tab.new(cfg)
    -- cfg: { window, tabContainer, contentContainer, name, icon }
    local tabName = cfg.name or "Tab"
    local tabIcon = cfg.icon or ""
    local window  = cfg.window

    -- Sidebar button
    local TabButton = Utility.Create("TextButton", {
        Name             = tabName .. "Tab",
        Parent           = cfg.tabContainer,
        Size             = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Config.Theme.Background,
        Text             = "",
        AutoButtonColor  = false,
        LayoutOrder      = #window.Tabs + 1,
        AutomaticSize    = Enum.AutomaticSize.X,
    })
    Utility.AddCorner(TabButton, UDim.new(0, 4))

    if tabIcon ~= "" then
        Utility.Create("ImageLabel", {
            Name               = "Icon",
            Parent             = TabButton,
            Position           = UDim2.new(0, 8, 0.5, -8),
            Size               = UDim2.new(0, 16, 0, 16),
            BackgroundTransparency = 1,
            Image              = tabIcon,
            ImageColor3        = Config.Theme.TextMuted,
        })
    end

    local iconOffset = tabIcon ~= "" and 30 or 10
    local TabLabel = Utility.Create("TextLabel", {
        Name               = "Label",
        Parent             = TabButton,
        Position           = UDim2.new(0, iconOffset, 0, 0),
        Size               = UDim2.new(0, 0, 1, 0),
        AutomaticSize      = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text               = tabName,
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.FontMedium,
        TextSize           = 13,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })
    Utility.Create("UIPadding", { Parent = TabLabel, PaddingRight = UDim.new(0, 10) })

    -- Tab content (scrollable)
    local TabContent = Utility.Create("ScrollingFrame", {
        Name                 = tabName .. "Content",
        Parent               = cfg.contentContainer,
        Size                 = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        ScrollBarThickness   = 3,
        ScrollBarImageColor3 = Config.Theme.Border,
        Visible              = false,
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
    })
    Utility.Create("UIListLayout", {
        Parent = TabContent, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
    })
    Utility.Create("UIPadding", {
        Parent = TabContent,
        PaddingTop    = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft   = UDim.new(0, 10), PaddingRight  = UDim.new(0, 12),
    })

    -- Empty-state placeholder (hidden once first element is added)
    local EmptyLabel = Utility.Create("TextLabel", {
        Parent             = TabContent,
        Size               = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        Text               = "No elements yet.",
        TextColor3         = Config.Theme.Border,
        Font               = Config.Font,
        TextSize           = 13,
        TextXAlignment     = Enum.TextXAlignment.Center,
        LayoutOrder        = 9999,
    })

    local self = setmetatable({
        Name             = tabName,
        Button           = TabButton,
        Label            = TabLabel,
        Content          = TabContent,
        Elements         = {},
        OnElementAdded   = Signal.new(),
        _window          = window,
        _elementConnSets = {},   -- [ConnSet, ...] — one per element, cleaned on window destroy
        _emptyLabel      = EmptyLabel,
    }, Tab)

    TabButton.MouseButton1Click:Connect(function() self:Activate() end)

    return self
end

-- ── Core methods ─────────────────────────────────────────────────────────────

function Tab:Activate()
    if self._window.ActiveTab == self then return end
    local oldTab = self._window.ActiveTab

    if oldTab then
        Utility.Tween(oldTab.Button, { BackgroundColor3 = Config.Theme.Background }, 0.2)
        Utility.Tween(oldTab.Label,  { TextColor3 = Config.Theme.TextMuted }, 0.2)
        if oldTab.Button:FindFirstChild("Icon") then
            Utility.Tween(oldTab.Button.Icon, { ImageColor3 = Config.Theme.TextMuted }, 0.2)
        end
        oldTab.Content.Visible = false
    end

    self._window.ActiveTab = self
    Utility.Tween(self.Button, { BackgroundColor3 = Config.Theme.Primary }, 0.2)
    Utility.Tween(self.Label,  { TextColor3 = Config.Theme.Text }, 0.2)
    if self.Button:FindFirstChild("Icon") then
        Utility.Tween(self.Button.Icon, { ImageColor3 = Config.Theme.Text }, 0.2)
    end
    self.Content.Visible = true
    self.Content.CanvasPosition = Vector2.new(0, 0)

    self._window.OnTabChanged:Fire(self, oldTab)
end

-- Shared base frame used by element factories.
function Tab:BaseFrame(height)
    local f = Utility.Create("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Config.Theme.Background,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(f, UDim.new(0, 4))
    return f
end

-- Register an element and inject the standard API (Destroy, SetVisible, SetEnabled).
-- elementConns: optional ConnSet for this element's UIS connections.
--   Lives in self._elementConnSets so Window:Destroy() cleans it up.
--   element.Destroy() also calls ConnSet:DisconnectAll() immediately.
function Tab:RegisterElement(element, frame, elementConns)
    elementConns = elementConns or ConnSet.new()
    table.insert(self._elementConnSets, elementConns)

    if #self.Elements == 0 then
        self._emptyLabel.Visible = false
    end
    table.insert(self.Elements, element)
    self.OnElementAdded:Fire(element)

    element.Frame  = frame
    element._conns = elementConns

    element.Destroy = function()
        elementConns:DisconnectAll()
        -- Remove from the window-level tracking list.
        for i, cs in ipairs(self._elementConnSets) do
            if cs == elementConns then
                table.remove(self._elementConnSets, i)
                break
            end
        end
        frame:Destroy()
        for i, e in ipairs(self.Elements) do
            if e == element then table.remove(self.Elements, i) break end
        end
        if #self.Elements == 0 then self._emptyLabel.Visible = true end
    end

    element.SetVisible = function(visible)
        frame.Visible = visible
    end

    element.SetEnabled = function(enabled)
        local overlay = frame:FindFirstChild("_DisabledOverlay")
        if enabled then
            if overlay then overlay:Destroy() end
            Utility.Tween(frame, { BackgroundTransparency = 0 }, 0.15)
            for _, lbl in ipairs(frame:GetDescendants()) do
                if lbl:IsA("TextLabel") or lbl:IsA("TextButton") or lbl:IsA("TextBox") then
                    local orig = lbl:GetAttribute("_origColor")
                    if orig then
                        lbl.TextColor3 = Color3.fromHex(orig)
                        lbl:SetAttribute("_origColor", nil)
                    end
                end
            end
        else
            -- Collapse any open expandable (dropdown/picker) before locking.
            Expandable.tryCollapse(frame)
            for _, lbl in ipairs(frame:GetDescendants()) do
                if lbl:IsA("TextLabel") or lbl:IsA("TextButton") or lbl:IsA("TextBox") then
                    if not lbl:GetAttribute("_origColor") then
                        lbl:SetAttribute("_origColor", lbl.TextColor3:ToHex())
                    end
                    Utility.Tween(lbl, { TextColor3 = Config.Theme.Border }, 0.15)
                end
            end
            if not overlay then
                overlay = Utility.Create("TextButton", {
                    Name                   = "_DisabledOverlay",
                    Parent                 = frame,
                    Size                   = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3       = Config.Theme.Background,
                    BackgroundTransparency = 0.5,
                    BorderSizePixel        = 0,
                    ZIndex                 = 99,
                    Text                   = "",
                    AutoButtonColor        = false,
                })
                Utility.AddCorner(overlay, UDim.new(0, 4))
            end
        end
    end

    return element
end

-- ── Element factories (assigned from src/elements/*.lua) ─────────────────────

Tab.CreateButton           = _Button
Tab.CreateToggle           = _Toggle
Tab.CreateSlider           = _Slider
Tab.CreateDropdown         = _Dropdown
Tab.CreateSearchDropdown   = _SearchDropdown
Tab.CreateMultiSelect      = _MultiSelect
Tab.CreateInput            = _Input
Tab.CreateNumberInput      = _NumberInput
Tab.CreateKeybind          = _Keybind
Tab.CreateColorPicker      = _ColorPicker
Tab.CreateLabel            = _Label
Tab.CreateSection          = _Section
Tab.CreateProgressBar      = _ProgressBar
Tab.CreateStatusLabel      = _StatusLabel
Tab.CreateTable            = _Table
Tab.CreateRow              = _Row
Tab.CreateAccordionSection = _AccordionSection

return Tab
