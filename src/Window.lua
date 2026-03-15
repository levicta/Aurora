-- src/Window.lua
-- Window factory: creates a draggable, tabbed UI window.
-- Returns a createWindow(config) function used by Aurora:CreateWindow().

local function createWindow(config)
    config = config or {}
    local title    = config.Title    or "Aurora"
    local size     = config.Size     or UDim2.new(0, 620, 0, 420)
    local position = config.Position or UDim2.new(0.5, -310, 0.5, -210)

    local windowConns = ConnSet.new()   -- window-lifetime connections

    local ScreenGui = Utility.Create("ScreenGui", {
        Name           = "AuroraUI",
        Parent         = LocalPlayer:WaitForChild("PlayerGui"),
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    local MainFrame = Utility.Create("Frame", {
        Name             = "MainFrame",
        Parent           = ScreenGui,
        Position         = position,
        Size             = size,
        BackgroundColor3 = Config.Theme.Background,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.AddCorner(MainFrame)
    Utility.AddShadow(MainFrame, 1.2)

    -- Title bar
    local TitleBar = Utility.Create("Frame", {
        Name             = "TitleBar",
        Parent           = MainFrame,
        Size             = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(TitleBar)
    Utility.Create("Frame", {
        Parent           = TitleBar,
        Position         = UDim2.new(0, 0, 1, -8),
        Size             = UDim2.new(1, 0, 0, 8),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
    })
    Utility.Create("TextLabel", {
        Name               = "Title",
        Parent             = TitleBar,
        Position           = UDim2.new(0, 15, 0, 0),
        Size               = UDim2.new(1, -120, 1, 0),
        BackgroundTransparency = 1,
        Text               = title,
        TextColor3         = Config.Theme.Text,
        Font               = Config.FontBold,
        TextSize           = 16,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local function makeControlBtn(xOffset, icon, iconColor)
        local btn = Utility.Create("TextButton", {
            Parent           = TitleBar,
            Position         = UDim2.new(1, xOffset, 0.5, -10),
            Size             = UDim2.new(0, 20, 0, 20),
            BackgroundColor3 = Config.Theme.Surface,
            Text             = icon,
            TextColor3       = iconColor,
            Font             = Config.FontBold,
            TextSize         = 13,
            AutoButtonColor  = false,
            BorderSizePixel  = 0,
        })
        Utility.AddCorner(btn, UDim.new(0, 4))
        btn.MouseEnter:Connect(function()
            Utility.Tween(btn, { BackgroundColor3 = iconColor, TextColor3 = Config.Theme.Text }, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            Utility.Tween(btn, { BackgroundColor3 = Config.Theme.Surface, TextColor3 = iconColor }, 0.15)
        end)
        return btn
    end

    local CloseBtn    = makeControlBtn(-28, "✕", Config.Theme.Error)
    local MinimizeBtn = makeControlBtn(-54, "—", Config.Theme.TextMuted)

    -- Tab sidebar
    local SIDEBAR_MIN = 110
    local SIDEBAR_MAX = 200
    local SIDEBAR_GAP = 8

    local TabContainer = Utility.Create("Frame", {
        Name             = "TabContainer",
        Parent           = MainFrame,
        Position         = UDim2.new(0, 8, 0, 48),
        Size             = UDim2.new(0, SIDEBAR_MIN, 1, -56),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
        AutomaticSize    = Enum.AutomaticSize.X,
    })
    Utility.AddCorner(TabContainer)
    Utility.Create("UIListLayout", {
        Parent    = TabContainer,
        Padding   = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    Utility.Create("UIPadding", {
        Parent        = TabContainer,
        PaddingTop    = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
        PaddingLeft   = UDim.new(0, 6), PaddingRight  = UDim.new(0, 6),
    })
    Utility.Create("UISizeConstraint", {
        Parent  = TabContainer,
        MinSize = Vector2.new(SIDEBAR_MIN, 0),
        MaxSize = Vector2.new(SIDEBAR_MAX, math.huge),
    })

    local ContentContainer = Utility.Create("Frame", {
        Name             = "ContentContainer",
        Parent           = MainFrame,
        Position         = UDim2.new(0, 8 + SIDEBAR_MIN + SIDEBAR_GAP, 0, 48),
        Size             = UDim2.new(1, -(8 + SIDEBAR_MIN + SIDEBAR_GAP + 8), 1, -56),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.AddCorner(ContentContainer)

    -- Reflow ContentContainer when sidebar auto-resizes.
    windowConns:Add(TabContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local w = math.clamp(TabContainer.AbsoluteSize.X, SIDEBAR_MIN, SIDEBAR_MAX)
        ContentContainer.Position = UDim2.new(0, 8 + w + SIDEBAR_GAP, 0, 48)
        ContentContainer.Size     = UDim2.new(1, -(8 + w + SIDEBAR_GAP + 8), 1, -56)
    end))

    -- Bottom fade
    local FadeGradient = Utility.Create("Frame", {
        Parent           = ContentContainer,
        Position         = UDim2.new(0, 0, 1, -28),
        Size             = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
        ZIndex           = 10,
    })
    Utility.Create("UIGradient", {
        Parent       = FadeGradient,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation = 90,
    })

    -- Window object (built before Tab.new calls so Tabs array exists)
    local Window = {
        ScreenGui        = ScreenGui,
        MainFrame        = MainFrame,
        TabContainer     = TabContainer,
        ContentContainer = ContentContainer,
        Tabs             = {},
        ActiveTab        = nil,
        OnTabChanged     = Signal.new(),
        _conns           = windowConns,
        _notifLayer      = nil,
    }

    -- ── Minimize ─────────────────────────────────────────────────────────────

    local minimized = false
    MinimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        Utility.Tween(MainFrame,
            { Size = minimized and UDim2.new(0, size.X.Offset, 0, 40) or size }, 0.3)
    end)

    -- ── Close ────────────────────────────────────────────────────────────────

    CloseBtn.MouseButton1Click:Connect(function()
        local absPos  = MainFrame.AbsolutePosition
        local absSize = MainFrame.AbsoluteSize
        Utility.Tween(MainFrame, {
            Size     = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0, absPos.X + absSize.X/2, 0, absPos.Y + absSize.Y/2),
        }, 0.3)
        task.wait(0.3)
        Window:Destroy()
    end)

    -- ── Tab API ──────────────────────────────────────────────────────────────

    function Window:CreateTab(tabConfig)
        tabConfig = tabConfig or {}
        local tab = Tab.new({
            window           = self,
            tabContainer     = TabContainer,
            contentContainer = ContentContainer,
            name             = tabConfig.Name or "Tab",
            icon             = tabConfig.Icon or "",
        })

        -- First tab auto-activates without firing OnTabChanged.
        if #self.Tabs == 0 then
            tab.Button.BackgroundColor3 = Config.Theme.Primary
            tab.Label.TextColor3        = Config.Theme.Text
            tab.Content.Visible         = true
            self.ActiveTab              = tab
        end

        table.insert(self.Tabs, tab)
        return tab
    end

    function Window:SelectTab(index)
        local tab = self.Tabs[index]
        if tab then tab:Activate() end
    end

    -- ── Notification (per-window scope) ──────────────────────────────────────
    -- Each window has its own notification layer so stacks never collide between
    -- two independent windows or two scripts sharing the same PlayerGui.

    function Window:Notify(cfg)
        if not self._notifLayer or not self._notifLayer.Gui.Parent then
            self._notifLayer = Notification.createLayer(LocalPlayer:WaitForChild("PlayerGui"))
        end
        self._notifLayer.Notify(cfg)
    end

    -- ── Destroy ──────────────────────────────────────────────────────────────

    function Window:Destroy()
        -- 1. Disconnect every element's UIS connections across all tabs.
        for _, tab in ipairs(self.Tabs) do
            for _, cs in ipairs(tab._elementConnSets) do
                cs:DisconnectAll()
            end
        end
        -- 2. Disconnect window-level connections (drag, reflow).
        self._conns:DisconnectAll()
        -- 3. Tear down the per-window notification layer if it was created.
        if self._notifLayer then
            self._notifLayer.Destroy()
        end
        -- 4. Destroy the ScreenGui (cascades to all child instances).
        ScreenGui:Destroy()
    end

    -- ── Draggable ────────────────────────────────────────────────────────────

    local dragConns = Utility.MakeDraggable(MainFrame, TitleBar)
    for _, c in ipairs(dragConns) do windowConns:Add(c) end

    -- ── Intro animation ──────────────────────────────────────────────────────

    MainFrame.Size     = UDim2.new(0, 0, 0, 0)
    MainFrame.Position = UDim2.new(
        position.X.Scale, position.X.Offset + size.X.Offset / 2,
        position.Y.Scale, position.Y.Offset + size.Y.Offset / 2
    )
    Utility.Tween(MainFrame, { Size = size, Position = position }, 0.5,
        Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    return Window
end

return createWindow
