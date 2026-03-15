--// Aurora UI Library
--// Version: 7.0.0
--// Built output — do not edit directly.
--// Source: src/  |  Rebuild: python3 build.py

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer

-- Built: 2026-03-12 09:03 UTC

-- ────────────────────────────────────────────────────────────────────────
--  Lightweight pub/sub event system
-- ────────────────────────────────────────────────────────────────────────
local Signal = (function()
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({ _handlers = {}, _counter = 0 }, Signal)
end

function Signal:Connect(fn)
    self._counter = self._counter + 1
    local id = self._counter
    self._handlers[id] = fn
    return {
        Disconnect = function()
            self._handlers[id] = nil
        end,
    }
end

-- Fires fn exactly once then auto-disconnects.
-- Returns a handle with .Disconnect() to cancel before it fires.
function Signal:Once(fn)
    local handle
    handle = self:Connect(function(...)
        handle.Disconnect()
        fn(...)
    end)
    return handle
end

function Signal:Fire(...)
    for _, fn in pairs(self._handlers) do
        local ok, err = pcall(fn, ...)
        if not ok then
            warn("[Aurora Signal] Callback error: " .. tostring(err))
        end
    end
end

return Signal
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Mutable theme + animation configuration
-- ────────────────────────────────────────────────────────────────────────
local Config = (function()
return {
    Theme = {
        Primary    = Color3.fromRGB(88,  101, 242),
        Secondary  = Color3.fromRGB(30,  30,  35),
        Background = Color3.fromRGB(18,  18,  22),
        Surface    = Color3.fromRGB(25,  25,  30),
        Text       = Color3.fromRGB(245, 245, 250),
        TextMuted  = Color3.fromRGB(150, 150, 160),
        Success    = Color3.fromRGB(46,  204, 113),
        Warning    = Color3.fromRGB(241, 196,  15),
        Error      = Color3.fromRGB(231,  76,  60),
        Border     = Color3.fromRGB(55,   55,  68),
        Glow       = Color3.fromRGB(88,  101, 242),
    },
    Animation = {
        Duration  = 0.3,
        Easing    = Enum.EasingStyle.Quart,
        Direction = Enum.EasingDirection.Out,
    },
    Font             = Enum.Font.Gotham,
    FontBold         = Enum.Font.GothamBold,
    FontMedium       = Enum.Font.GothamMedium,
    CornerRadius     = UDim.new(0, 6),
    ShadowTransparency = 0.7,
}
end)()

-- ────────────────────────────────────────────────────────────────────────
--  O(1) connection ownership set
-- ────────────────────────────────────────────────────────────────────────
local ConnSet = (function()
local ConnSet = {}
ConnSet.__index = ConnSet

function ConnSet.new()
    return setmetatable({ _set = {} }, ConnSet)
end

-- Track a connection. Returns the connection for inline use:
--   cs:Add(UIS.InputChanged:Connect(fn))
function ConnSet:Add(conn)
    if conn then self._set[conn] = true end
    return conn
end

-- Disconnect and stop tracking a specific connection.
function ConnSet:Remove(conn)
    if conn then
        self._set[conn] = nil
        if conn.Disconnect then conn:Disconnect() end
    end
end

-- Disconnect every tracked connection and empty the set.
function ConnSet:DisconnectAll()
    for conn in pairs(self._set) do
        if conn.Disconnect then conn:Disconnect() end
    end
    self._set = {}
end

return ConnSet
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Shared helpers: Create, Tween (with cancellation), AddCorner, AddShadow, MakeDraggable
-- ────────────────────────────────────────────────────────────────────────
local Utility = (function()
local _activeTweens = {}   -- [Instance] → Tween  (cancellation registry)

local function Create(className, props)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do inst[k] = v end
    return inst
end

local function Tween(inst, props, duration, easingStyle, easingDir)
    -- Cancel any competing tween on this instance first.
    if _activeTweens[inst] then
        _activeTweens[inst]:Cancel()
        _activeTweens[inst] = nil
    end
    local info = TweenInfo.new(
        duration    or Config.Animation.Duration,
        easingStyle or Config.Animation.Easing,
        easingDir   or Config.Animation.Direction
    )
    local t = TweenService:Create(inst, info, props)
    _activeTweens[inst] = t
    t.Completed:Connect(function()
        -- Clear only if this is still the active tween (a newer one may have replaced it).
        if _activeTweens[inst] == t then
            _activeTweens[inst] = nil
        end
    end)
    t:Play()
    return t
end

local function AddCorner(parent, radius)
    return Create("UICorner", {
        CornerRadius = radius or Config.CornerRadius,
        Parent       = parent,
    })
end

local function AddShadow(parent, intensity)
    return Create("ImageLabel", {
        Name                   = "Shadow",
        Parent                 = parent,
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.5, 4),
        Size                   = UDim2.new(1, 24, 1, 24),
        BackgroundTransparency = 1,
        Image                  = "rbxassetid://6014261993",
        ImageColor3            = Color3.new(0, 0, 0),
        ImageTransparency      = Config.ShadowTransparency * (intensity or 1),
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(49, 49, 450, 450),
        ZIndex                 = parent.ZIndex - 1,
    })
end

-- Returns an array of three RBXScriptConnections.
-- The caller is responsible for tracking / disconnecting them.
local function MakeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos = false, nil, nil
    local conns = {}

    conns[1] = handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = inp.Position
            startPos  = frame.Position
        end
    end)

    conns[2] = UserInputService.InputChanged:Connect(function(inp)
        if dragging and (
            inp.UserInputType == Enum.UserInputType.MouseMovement or
            inp.UserInputType == Enum.UserInputType.Touch
        ) then
            local d = inp.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)

    conns[3] = UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return conns
end

return {
    Create        = Create,
    Tween         = Tween,
    AddCorner     = AddCorner,
    AddShadow     = AddShadow,
    MakeDraggable = MakeDraggable,
}
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Shared expand/collapse base for accordion elements
-- ────────────────────────────────────────────────────────────────────────
local Expandable = (function()
local _registry = setmetatable({}, { __mode = "k" })

-- Create an expandable controller for `frame`.
--   collapsedH   : number  — pixel height when closed
--   getExpandedH : number | () → number  — pixel height (or thunk) when open
--   arrowLabel   : TextLabel? — optional arrow glyph to rotate 0↔180
--
-- Returns a controller table with collapse(), expand(), toggle(), isExpanded().
local function makeExpandable(frame, collapsedH, getExpandedH, arrowLabel)
    local expanded = false

    local function resolveH()
        return type(getExpandedH) == "function" and getExpandedH() or getExpandedH
    end

    local function collapse()
        if not expanded then return end
        expanded = false
        Utility.Tween(frame, { Size = UDim2.new(1, 0, 0, collapsedH) }, 0.2)
        if arrowLabel then
            Utility.Tween(arrowLabel, { Rotation = 0 }, 0.2)
        end
    end

    local function expand()
        if expanded then return end
        expanded = true
        Utility.Tween(frame, { Size = UDim2.new(1, 0, 0, resolveH()) }, 0.2)
        if arrowLabel then
            Utility.Tween(arrowLabel, { Rotation = 180 }, 0.2)
        end
    end

    local function toggle()
        if expanded then collapse() else expand() end
    end

    -- Register so SetEnabled(false) can auto-collapse this element.
    _registry[frame] = collapse

    return {
        collapse   = collapse,
        expand     = expand,
        toggle     = toggle,
        isExpanded = function() return expanded end,
    }
end

-- Called by RegisterElement's SetEnabled(false) path.
-- Safe to call on non-expandable frames (noop if not registered).
local function tryCollapse(frame)
    local fn = _registry[frame]
    if fn then fn() end
end

return {
    makeExpandable = makeExpandable,
    tryCollapse    = tryCollapse,
}
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateButton factory
-- ────────────────────────────────────────────────────────────────────────
local _Button = (function()
return function(self, cfg)
    cfg = cfg or {}
    local frame = self:BaseFrame(36)

    local btn = Utility.Create("TextButton", {
        Parent             = frame,
        Size               = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Button",
        TextColor3         = Config.Theme.Text,
        Font               = Config.FontMedium,
        TextSize           = 14,
        AutoButtonColor    = false,
    })

    btn.MouseEnter:Connect(function()
        Utility.Tween(frame, { BackgroundColor3 = Color3.fromRGB(35, 35, 45) }, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        Utility.Tween(frame, { BackgroundColor3 = Config.Theme.Background }, 0.15)
    end)
    btn.MouseButton1Down:Connect(function()
        Utility.Tween(frame, { BackgroundColor3 = Config.Theme.Primary }, 0.1)
    end)
    btn.MouseButton1Up:Connect(function()
        Utility.Tween(frame, { BackgroundColor3 = Color3.fromRGB(35, 35, 45) }, 0.1)
    end)
    btn.MouseButton1Click:Connect(cfg.Callback or function() end)

    return self:RegisterElement({
        SetText = function(t) btn.Text = t end,
    }, frame)
end
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateToggle factory
-- ────────────────────────────────────────────────────────────────────────
local _Toggle = (function()
return function(self, cfg)
    cfg = cfg or {}
    local toggled   = cfg.Default or false
    local OnChanged = Signal.new()
    local frame     = self:BaseFrame(36)

    Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(0, 12, 0, 0),
        Size               = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Toggle",
        TextColor3         = Config.Theme.Text,
        Font               = Config.FontMedium,
        TextSize           = 14,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local Track = Utility.Create("Frame", {
        Parent           = frame,
        Position         = UDim2.new(1, -46, 0.5, -10),
        Size             = UDim2.new(0, 36, 0, 20),
        BackgroundColor3 = toggled and Config.Theme.Primary or Config.Theme.Border,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Track, UDim.new(1, 0))

    local Circle = Utility.Create("Frame", {
        Parent           = Track,
        Position         = toggled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        Size             = UDim2.new(0, 16, 0, 16),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Circle, UDim.new(1, 0))

    -- Sync track + circle to current state.
    -- silent=true → skip Callback/OnChanged (used by SetValue).
    local function applyUI(silent)
        Utility.Tween(Track,  { BackgroundColor3 = toggled and Config.Theme.Primary or Config.Theme.Border }, 0.2)
        Utility.Tween(Circle, { Position = toggled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }, 0.2)
        if not silent then
            if cfg.Callback then cfg.Callback(toggled) end
            OnChanged:Fire(toggled)
        end
    end

    Utility.Create("TextButton", {
        Parent             = frame,
        Size               = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text               = "",
    }).MouseButton1Click:Connect(function()
        toggled = not toggled
        applyUI(false)
    end)

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return toggled end,
        -- Silent: updates UI only, does NOT fire Callback or OnChanged.
        SetValue  = function(val)
            val = not not val   -- coerce to boolean
            if toggled ~= val then
                toggled = val
                applyUI(true)
            end
        end,
    }, frame)
end
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateSlider factory
-- ────────────────────────────────────────────────────────────────────────
local _Slider = (function()
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
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateDropdown factory
-- ────────────────────────────────────────────────────────────────────────
local _Dropdown = (function()
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
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateSearchDropdown factory
-- ────────────────────────────────────────────────────────────────────────
local _SearchDropdown = (function()
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
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateMultiSelect factory
-- ────────────────────────────────────────────────────────────────────────
local _MultiSelect = (function()
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
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateInput factory
-- ────────────────────────────────────────────────────────────────────────
local _Input = (function()
return function(self, cfg)
    cfg = cfg or {}
    local OnChanged = Signal.new()
    local frame     = self:BaseFrame(54)

    Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(0, 12, 0, 6),
        Size               = UDim2.new(1, -24, 0, 16),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Input",
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.FontMedium,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local InputBox = Utility.Create("TextBox", {
        Parent            = frame,
        Position          = UDim2.new(0, 10, 0, 26),
        Size              = UDim2.new(1, -20, 0, 22),
        BackgroundColor3  = Config.Theme.Surface,
        BorderSizePixel   = 0,
        Text              = "",
        PlaceholderText   = cfg.Placeholder or "Type here...",
        PlaceholderColor3 = Config.Theme.TextMuted,
        TextColor3        = Config.Theme.Text,
        Font              = Config.Font,
        TextSize          = 13,
        ClearTextOnFocus  = false,
        TextXAlignment    = Enum.TextXAlignment.Left,
    })
    Utility.AddCorner(InputBox, UDim.new(0, 4))
    Utility.Create("UIPadding", { Parent = InputBox, PaddingLeft = UDim.new(0, 8) })

    InputBox.Focused:Connect(function()
        Utility.Tween(InputBox, { BackgroundColor3 = Color3.fromRGB(32, 32, 42) }, 0.15)
    end)
    InputBox.FocusLost:Connect(function(enter)
        Utility.Tween(InputBox, { BackgroundColor3 = Config.Theme.Surface }, 0.15)
        if enter then
            if cfg.Callback then cfg.Callback(InputBox.Text) end
            OnChanged:Fire(InputBox.Text)
        end
    end)

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return InputBox.Text end,
        SetValue  = function(val) InputBox.Text = val end,
    }, frame)
end
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateNumberInput factory
-- ────────────────────────────────────────────────────────────────────────
local _NumberInput = (function()
return function(self, cfg)
    cfg = cfg or {}
    local min     = cfg.Min     or -math.huge
    local max     = cfg.Max     or  math.huge
    local step    = cfg.Step    or 1
    local current = math.clamp(cfg.Default or 0, min, max)
    local OnChanged = Signal.new()
    local frame     = self:BaseFrame(54)

    Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(0, 12, 0, 6),
        Size               = UDim2.new(1, -24, 0, 16),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Number",
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.FontMedium,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local Row = Utility.Create("Frame", {
        Parent             = frame,
        Position           = UDim2.new(0, 10, 0, 26),
        Size               = UDim2.new(1, -20, 0, 22),
        BackgroundTransparency = 1,
        BorderSizePixel    = 0,
    })

    local function makeStepBtn(anchorX, symbol)
        local btn = Utility.Create("TextButton", {
            Parent           = Row,
            AnchorPoint      = Vector2.new(anchorX, 0),
            Position         = UDim2.new(anchorX, 0, 0, 0),
            Size             = UDim2.new(0, 26, 1, 0),
            BackgroundColor3 = Config.Theme.Surface,
            Text             = symbol,
            TextColor3       = Config.Theme.Primary,
            Font             = Config.FontBold,
            TextSize         = 16,
            AutoButtonColor  = false,
            BorderSizePixel  = 0,
        })
        Utility.AddCorner(btn, UDim.new(0, 4))
        btn.MouseEnter:Connect(function()
            Utility.Tween(btn, { BackgroundColor3 = Config.Theme.Primary, TextColor3 = Config.Theme.Text }, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            Utility.Tween(btn, { BackgroundColor3 = Config.Theme.Surface, TextColor3 = Config.Theme.Primary }, 0.15)
        end)
        return btn
    end

    local MinusBtn = makeStepBtn(0, "−")
    local PlusBtn  = makeStepBtn(1, "+")

    local NumBox = Utility.Create("TextBox", {
        Parent             = Row,
        Position           = UDim2.new(0, 30, 0, 0),
        Size               = UDim2.new(1, -60, 1, 0),
        BackgroundColor3   = Config.Theme.Surface,
        BorderSizePixel    = 0,
        Text               = tostring(current),
        TextColor3         = Config.Theme.Text,
        Font               = Config.FontBold,
        TextSize           = 13,
        ClearTextOnFocus   = false,
        TextXAlignment     = Enum.TextXAlignment.Center,
    })
    Utility.AddCorner(NumBox, UDim.new(0, 4))

    -- User-triggered: snap + clamp, then fire callbacks.
    local function commit(val)
        val = math.clamp(math.floor(val / step + 0.5) * step, min, max)
        if val == current then
            NumBox.Text = tostring(current)  -- reset display if clamped to same value
            return
        end
        current     = val
        NumBox.Text = tostring(val)
        if cfg.Callback then cfg.Callback(val) end
        OnChanged:Fire(val)
    end

    -- Silent: same snap + clamp but NO callbacks.
    local function applyUI(val)
        current     = math.clamp(math.floor(val / step + 0.5) * step, min, max)
        NumBox.Text = tostring(current)
    end

    MinusBtn.MouseButton1Click:Connect(function() commit(current - step) end)
    PlusBtn.MouseButton1Click:Connect(function()  commit(current + step) end)
    NumBox.FocusLost:Connect(function()
        local n = tonumber(NumBox.Text)
        if n then commit(n)
        else NumBox.Text = tostring(current) end
    end)

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return current end,
        SetValue  = function(val) applyUI(val) end,
    }, frame)
end
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateKeybind factory
-- ────────────────────────────────────────────────────────────────────────
local _Keybind = (function()
return function(self, cfg)
    cfg = cfg or {}
    local current   = cfg.Default or Enum.KeyCode.Unknown
    local listening = false
    local OnChanged = Signal.new()
    local frame     = self:BaseFrame(36)

    Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(0, 12, 0, 0),
        Size               = UDim2.new(1, -110, 1, 0),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Keybind",
        TextColor3         = Config.Theme.Text,
        Font               = Config.FontMedium,
        TextSize           = 14,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local KeyBtn = Utility.Create("TextButton", {
        Parent           = frame,
        Position         = UDim2.new(1, -98, 0.5, -12),
        Size             = UDim2.new(0, 88, 0, 24),
        BackgroundColor3 = Config.Theme.Surface,
        Text             = current == Enum.KeyCode.Unknown and "None" or current.Name,
        TextColor3       = Config.Theme.Primary,
        Font             = Config.FontBold,
        TextSize         = 12,
        AutoButtonColor  = false,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(KeyBtn, UDim.new(0, 4))

    local keyCon  -- short-lived connection active only while listening

    local function stopListening()
        listening               = false
        KeyBtn.BackgroundColor3 = Config.Theme.Surface
        KeyBtn.TextColor3       = Config.Theme.Primary
        if keyCon then keyCon:Disconnect() keyCon = nil end
    end

    local function startListening()
        listening               = true
        KeyBtn.Text             = "..."
        KeyBtn.BackgroundColor3 = Config.Theme.Primary
        KeyBtn.TextColor3       = Config.Theme.Text
        keyCon = UserInputService.InputBegan:Connect(function(inp, processed)
            if processed then return end
            if inp.UserInputType == Enum.UserInputType.Keyboard then
                current     = inp.KeyCode
                KeyBtn.Text = inp.KeyCode.Name
                stopListening()
                if cfg.Callback then cfg.Callback(current) end
                OnChanged:Fire(current)
            end
        end)
    end

    KeyBtn.MouseButton1Click:Connect(function()
        if listening then stopListening() else startListening() end
    end)

    -- Cancel if user clicks elsewhere while listening.
    local elementConns = ConnSet.new()
    elementConns:Add(UserInputService.InputBegan:Connect(function(inp)
        if listening and inp.UserInputType == Enum.UserInputType.MouseButton1 then
            stopListening()
            KeyBtn.Text = current == Enum.KeyCode.Unknown and "None" or current.Name
        end
    end))

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return current end,
        SetValue  = function(key)
            current     = key
            KeyBtn.Text = key == Enum.KeyCode.Unknown and "None" or key.Name
        end,
    }, frame, elementConns)
end
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateColorPicker factory
-- ────────────────────────────────────────────────────────────────────────
local _ColorPicker = (function()
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
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateLabel factory
-- ────────────────────────────────────────────────────────────────────────
local _Label = (function()
return function(self, cfg)
    if type(cfg) == "string" then cfg = { Text = cfg } end
    cfg = cfg or {}

    local OnChanged = Signal.new()

    local frame = Utility.Create("Frame", {
        Parent             = self.Content,
        Size               = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
    })

    local lbl = Utility.Create("TextLabel", {
        Parent             = frame,
        Size               = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Label",
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.Font,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return lbl.Text end,
        SetValue  = function(t)
            lbl.Text = tostring(t)
            OnChanged:Fire(lbl.Text)
        end,
        SetText   = function(t) lbl.Text = tostring(t) end,
    }, frame)
end
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateSection factory
-- ────────────────────────────────────────────────────────────────────────
local _Section = (function()
return function(self, cfg)
    if type(cfg) == "string" then cfg = { Text = cfg } end
    cfg = cfg or {}

    local frame = Utility.Create("Frame", {
        Parent             = self.Content,
        Size               = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
    })

    local sectionLabel = Utility.Create("TextLabel", {
        Parent             = frame,
        Size               = UDim2.new(1, 0, 1, -1),
        BackgroundTransparency = 1,
        Text               = (cfg.Text or "Section"):upper(),
        TextColor3         = Config.Theme.Primary,
        Font               = Config.FontBold,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    Utility.Create("Frame", {
        Parent           = frame,
        Position         = UDim2.new(0, 0, 1, -1),
        Size             = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Config.Theme.Border,
        BorderSizePixel  = 0,
    })

    return self:RegisterElement({
        GetValue = function() return sectionLabel.Text end,
        SetValue = function(t) sectionLabel.Text = tostring(t):upper() end,
        SetText  = function(t) sectionLabel.Text = tostring(t):upper() end,
    }, frame)
end
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateProgressBar factory
-- ────────────────────────────────────────────────────────────────────────
local _ProgressBar = (function()
return function(self, cfg)
    cfg = cfg or {}
    local value     = math.clamp(cfg.Default or 0, 0, 1)
    local OnChanged = Signal.new()
    local frame     = self:BaseFrame(46)

    local LabelText = Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(0, 12, 0, 6),
        Size               = UDim2.new(1, -60, 0, 16),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "Progress",
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.FontMedium,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
    })

    local PctLabel = Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(1, -50, 0, 6),
        Size               = UDim2.new(0, 42, 0, 16),
        BackgroundTransparency = 1,
        Text               = "0%",
        TextColor3         = Config.Theme.TextMuted,
        Font               = Config.Font,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Right,
    })

    local Track = Utility.Create("Frame", {
        Parent           = frame,
        Position         = UDim2.new(0, 10, 0, 30),
        Size             = UDim2.new(1, -20, 0, 8),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Track, UDim.new(1, 0))

    local barColor = cfg.Color or Config.Theme.Primary
    local Fill = Utility.Create("Frame", {
        Parent           = Track,
        Size             = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = barColor,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Fill, UDim.new(1, 0))

    local function apply(pct)
        pct        = math.clamp(pct, 0, 1)
        value      = pct
        Utility.Tween(Fill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.2)
        PctLabel.Text = math.floor(pct * 100) .. "%"
        OnChanged:Fire(pct)
    end

    apply(value)  -- seed initial display

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return value end,
        SetValue  = function(pct) apply(pct) end,
        SetLabel  = function(t) LabelText.Text = tostring(t) end,
        SetColor  = function(c)
            barColor              = c
            Fill.BackgroundColor3 = c
        end,
    }, frame)
end
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateStatusLabel factory
-- ────────────────────────────────────────────────────────────────────────
local _StatusLabel = (function()
return function(self, cfg)
    cfg = cfg or {}
    local typeColors = {
        Info    = Config.Theme.Primary,
        Success = Config.Theme.Success,
        Warning = Config.Theme.Warning,
        Error   = Config.Theme.Error,
    }
    local currentType = cfg.Type or "Info"
    local OnChanged   = Signal.new()

    local frame = Utility.Create("Frame", {
        Parent             = self.Content,
        Size               = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
    })

    local Dot = Utility.Create("Frame", {
        Parent           = frame,
        Position         = UDim2.new(0, 2, 0.5, -4),
        Size             = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = typeColors[currentType],
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(Dot, UDim.new(1, 0))

    local Lbl = Utility.Create("TextLabel", {
        Parent             = frame,
        Position           = UDim2.new(0, 16, 0, 0),
        Size               = UDim2.new(1, -16, 1, 0),
        BackgroundTransparency = 1,
        Text               = cfg.Text or "",
        TextColor3         = typeColors[currentType],
        Font               = Config.FontMedium,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
        TextTruncate       = Enum.TextTruncate.AtEnd,
    })

    local function applyType(t)
        currentType = t
        local c = typeColors[t] or typeColors.Info
        Dot.BackgroundColor3 = c
        Lbl.TextColor3       = c
    end

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return Lbl.Text end,
        -- SetValue(text, type?) — updates display and fires OnChanged.
        SetValue  = function(t, typ)
            Lbl.Text = tostring(t)
            if typ then applyType(typ) end
            OnChanged:Fire(Lbl.Text)
        end,
        SetText = function(t) Lbl.Text = tostring(t) end,
        SetType = applyType,
    }, frame)
end
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateTable factory
-- ────────────────────────────────────────────────────────────────────────
local _Table = (function()
return function(self, cfg)
    cfg = cfg or {}
    local columns      = cfg.Columns    or { "Column 1", "Column 2" }
    local rows         = cfg.Rows       or {}
    local rowH         = 28
    local headerH      = 28
    local maxRows      = cfg.MaxVisible or 6
    local OnRowClicked = Signal.new()

    local numCols = #columns
    local colW    = 1 / numCols

    local TableFrame = Utility.Create("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, headerH + math.min(#rows, maxRows) * rowH),
        BackgroundColor3 = Config.Theme.Background,
        BorderSizePixel  = 0,
        ClipsDescendants = false,
    })
    Utility.AddCorner(TableFrame, UDim.new(0, 4))

    -- Header
    local Header = Utility.Create("Frame", {
        Parent           = TableFrame,
        Size             = UDim2.new(1, 0, 0, headerH),
        BackgroundColor3 = Config.Theme.Primary,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.AddCorner(Header, UDim.new(0, 4))
    Utility.Create("Frame", {   -- patch header bottom corners flush with body
        Parent = Header, Position = UDim2.new(0,0,1,-6),
        Size = UDim2.new(1,0,0,6), BackgroundColor3 = Config.Theme.Primary, BorderSizePixel = 0,
    })
    for i, col in ipairs(columns) do
        Utility.Create("TextLabel", {
            Parent = Header, Position = UDim2.new((i-1)*colW, 8, 0, 0),
            Size = UDim2.new(colW, -8, 1, 0), BackgroundTransparency = 1,
            Text = col, TextColor3 = Config.Theme.Text, Font = Config.FontBold,
            TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        })
        if i < numCols then
            Utility.Create("Frame", {
                Parent = Header, Position = UDim2.new(i*colW, 0, 0.1, 0),
                Size = UDim2.new(0, 1, 0.8, 0), BackgroundColor3 = Color3.new(1,1,1),
                BackgroundTransparency = 0.7, BorderSizePixel = 0,
            })
        end
    end

    -- Scrollable body
    local Body = Utility.Create("ScrollingFrame", {
        Parent               = TableFrame,
        Position             = UDim2.new(0, 0, 0, headerH),
        Size                 = UDim2.new(1, 0, 1, -headerH),
        BackgroundColor3     = Config.Theme.Background,
        BorderSizePixel      = 0,
        ScrollBarThickness   = 2,
        ScrollBarImageColor3 = Config.Theme.Border,
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        ClipsDescendants     = true,
    })
    Utility.AddCorner(Body, UDim.new(0, 4))
    Utility.Create("UIListLayout", { Parent = Body, SortOrder = Enum.SortOrder.LayoutOrder })

    -- rowObjects[i]       = Frame  (the rendered row)
    -- rowColors[i]        = Color3 | nil  (custom colour override)
    -- rowBaseSetters[i]   = fn(Color3)    (per-row upvalue setter — correct hover restore)
    local rowObjects     = {}
    local rowColors      = {}
    local rowBaseSetters = {}

    local function renderRow(rowData, index)
        local defaultColor = index % 2 == 0 and Config.Theme.Surface or Config.Theme.Background
        local baseColor    = rowColors[index] or defaultColor

        local rowFrame = Utility.Create("Frame", {
            Parent           = Body,
            Size             = UDim2.new(1, 0, 0, rowH),
            BackgroundColor3 = baseColor,
            BorderSizePixel  = 0,
            LayoutOrder      = index,
        })
        for c, cell in ipairs(rowData) do
            Utility.Create("TextLabel", {
                Parent = rowFrame, Position = UDim2.new((c-1)*colW, 8, 0, 0),
                Size = UDim2.new(colW, -8, 1, 0), BackgroundTransparency = 1,
                Text = tostring(cell), TextColor3 = Config.Theme.Text,
                Font = Config.Font, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            })
        end

        -- Per-row upvalue: currentBase is private to THIS row.
        -- SetRowColor / ClearRowColor call rowBaseSetters[index] to update it.
        local currentBase = baseColor
        rowBaseSetters[index] = function(c)
            currentBase           = c
            rowFrame.BackgroundColor3 = c
        end

        local rowBtn = Utility.Create("TextButton", {
            Parent = rowFrame, Size = UDim2.new(1,0,1,0),
            BackgroundTransparency = 1, Text = "",
        })
        rowBtn.MouseEnter:Connect(function()
            Utility.Tween(rowFrame, { BackgroundColor3 = Color3.fromRGB(40, 40, 55) }, 0.12)
        end)
        rowBtn.MouseLeave:Connect(function()
            -- Reads currentBase from this row's upvalue — correct even after SetRowColor.
            Utility.Tween(rowFrame, { BackgroundColor3 = currentBase }, 0.12)
        end)
        rowBtn.MouseButton1Click:Connect(function()
            OnRowClicked:Fire(index, rowData)
        end)
        return rowFrame
    end

    local function resize()
        TableFrame.Size = UDim2.new(1, 0, 0, headerH + math.min(#rows, maxRows) * rowH)
    end

    for i, rowData in ipairs(rows) do
        rowObjects[i] = renderRow(rowData, i)
    end
    resize()

    local element = {
        OnRowClicked = OnRowClicked,

        SetRows = function(newRows)
            rows = newRows
            rowColors = {}
            rowBaseSetters = {}
            for _, obj in ipairs(rowObjects) do obj:Destroy() end
            rowObjects = {}
            for i, rowData in ipairs(rows) do rowObjects[i] = renderRow(rowData, i) end
            resize()
        end,

        AddRow = function(rowData)
            table.insert(rows, rowData)
            local i = #rows
            rowObjects[i] = renderRow(rowData, i)
            resize()
        end,

        -- Incremental remove: only re-render rows after the removed index.
        RemoveRow = function(index)
            if not rows[index] then return end
            if rowObjects[index] then rowObjects[index]:Destroy() end
            table.remove(rows, index)
            table.remove(rowObjects, index)

            -- Shift colour overrides down by one.
            local newColors = {}
            for i, c in pairs(rowColors) do
                if    i > index then newColors[i-1] = c
                elseif i < index then newColors[i]   = c end
            end
            rowColors = newColors

            -- Re-render only the rows whose index changed (index onward).
            for i = index, #rows do
                if rowObjects[i] then rowObjects[i]:Destroy() end
                rowBaseSetters[i] = nil
                rowObjects[i] = renderRow(rows[i], i)
            end
            resize()
        end,

        SetCell = function(rowIndex, colIndex, value)
            if not rows[rowIndex] then return end
            rows[rowIndex][colIndex] = value
            local rowFrame = rowObjects[rowIndex]
            if not rowFrame then return end
            local labels = {}
            for _, c in ipairs(rowFrame:GetChildren()) do
                if c:IsA("TextLabel") then table.insert(labels, c) end
            end
            table.sort(labels, function(a, b) return a.Position.X.Scale < b.Position.X.Scale end)
            if labels[colIndex] then labels[colIndex].Text = tostring(value) end
        end,

        SetRowColor = function(index, color)
            rowColors[index] = color
            if rowBaseSetters[index] then rowBaseSetters[index](color) end
        end,

        ClearRowColor = function(index)
            rowColors[index] = nil
            if rowBaseSetters[index] then
                local def = index % 2 == 0 and Config.Theme.Surface or Config.Theme.Background
                rowBaseSetters[index](def)
            end
        end,

        Clear = function()
            rows = {}
            rowColors = {}
            rowBaseSetters = {}
            for _, obj in ipairs(rowObjects) do obj:Destroy() end
            rowObjects = {}
            resize()
        end,

        GetRows = function()
            local copy = {}
            for i, row in ipairs(rows) do copy[i] = row end
            return copy
        end,
    }

    return self:RegisterElement(element, TableFrame)
end
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateRow factory (NEW in v7)
-- ────────────────────────────────────────────────────────────────────────
local _Row = (function()
return function(self, cfg)
    cfg = cfg or {}
    local columns = cfg.Columns or 2
    local gap     = cfg.Gap     or 6
    local height  = cfg.Height  or 36

    local RowFrame = Utility.Create("Frame", {
        Parent             = self.Content,
        Size               = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel    = 0,
    })
    Utility.Create("UIListLayout", {
        Parent        = RowFrame,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Padding       = UDim.new(0, gap),
    })

    local rowChildren = {}
    -- Width each column should occupy: equal share minus the proportional gap.
    local colW      = 1 / columns
    local colOffset = -math.floor(gap * (columns - 1) / columns)

    local rowData = {
        -- Reparent an element's frame into this row and resize it to fill one column.
        -- The element remains in Tab.Elements and retains its full API.
        Add = function(element)
            if not element or not element.Frame then return end
            table.insert(rowChildren, element)
            element.Frame.Parent     = RowFrame
            element.Frame.Size       = UDim2.new(colW, colOffset, 1, 0)
            element.Frame.LayoutOrder = #rowChildren
        end,
    }

    local rowElem = self:RegisterElement(rowData, RowFrame)

    -- Wrap Destroy so child elements are also cleaned up cleanly.
    local parentDestroy = rowElem.Destroy
    rowElem.Destroy = function()
        for _, child in ipairs(rowChildren) do
            if child.Destroy then pcall(child.Destroy) end
        end
        parentDestroy()
    end

    return rowElem
end
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab:CreateAccordionSection factory (NEW in v7)
-- ────────────────────────────────────────────────────────────────────────
local _AccordionSection = (function()
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
    -- Two-frame approach: WrapperFrame carries the UIStroke and UICorner (visible
    -- card boundary); OuterFrame sits inside it at full size and carries
    -- ClipsDescendants (expand/collapse mask).  Keeping them separate avoids the
    -- Roblox rendering quirk where UIStroke on a ClipsDescendants frame can have
    -- its outer half clipped during size animation, producing a thinner-than-expected
    -- border at intermediate heights.
    local WrapperFrame = Utility.Create("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, HEADER_H),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel  = 0,
    })
    Utility.AddCorner(WrapperFrame, UDim.new(0, 6))
    Utility.Create("UIStroke", {
        Parent       = WrapperFrame,
        Color        = Config.Theme.Border,
        Thickness    = 1,
        Transparency = 0.45,
    })

    -- OuterFrame: full-size child that clips all inner content.
    local OuterFrame = Utility.Create("Frame", {
        Parent           = WrapperFrame,
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.AddCorner(OuterFrame, UDim.new(0, 6))

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

    -- 3px Primary accent bar spanning the full card height.
    -- Parented to OuterFrame so it covers the entire left edge when expanded,
    -- not just the 36px header.  ClipsDescendants + UICorner on OuterFrame
    -- handle rounding.  ZIndex 2 keeps it above the UIStroke.
    Utility.Create("Frame", {
        Parent           = OuterFrame,
        Position         = UDim2.new(0, 0, 0, 0),
        Size             = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = Config.Theme.Primary,
        BorderSizePixel  = 0,
        ZIndex           = 2,
    })

    -- Section label — offset 16px from the left to clear the accent bar.
    Utility.Create("TextLabel", {
        Parent             = Header,
        Position           = UDim2.new(0, 20, 0, 0),
        Size               = UDim2.new(1, -48, 1, 0),
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
        PaddingBottom = UDim.new(0, 8),
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
            Utility.Tween(WrapperFrame, { Size = UDim2.new(1, 0, 0, targetH) }, 0.2)
        else
            WrapperFrame.Size = UDim2.new(1, 0, 0, targetH)
        end
    end

    -- Keep outer height in sync as children are added/removed while open.
    InnerFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if expanded then
            WrapperFrame.Size = UDim2.new(1, 0, 0, getExpandedH())
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
        ZIndex             = 3,
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
    }, WrapperFrame)

    -- ── Override SetEnabled to reset header hover state ───────────────────────
    -- RegisterElement injects a SetEnabled that handles the overlay and text dim,
    -- but it doesn't know about the Header hover tween.  If the header is hovered
    -- when SetEnabled(false) fires, Header.BackgroundColor3 stays at COLOR_HOVER
    -- after the overlay is removed on re-enable.  We wrap the injected function to
    -- always reset the header colour alongside the standard enable/disable logic.
    local _injectedSetEnabled = element.SetEnabled
    element.SetEnabled = function(enabled)
        _injectedSetEnabled(enabled)
        if enabled then
            -- Reset any lingering hover tint — the mouse may still be over the header.
            Header.BackgroundColor3 = Config.Theme.Surface
        end
    end

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
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Tab prototype — element methods defined once on metatable
-- ────────────────────────────────────────────────────────────────────────
local Tab = (function()
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

Tab.CreateButton       = _Button
Tab.CreateToggle       = _Toggle
Tab.CreateSlider       = _Slider
Tab.CreateDropdown     = _Dropdown
Tab.CreateSearchDropdown = _SearchDropdown
Tab.CreateMultiSelect  = _MultiSelect
Tab.CreateInput        = _Input
Tab.CreateNumberInput  = _NumberInput
Tab.CreateKeybind      = _Keybind
Tab.CreateColorPicker  = _ColorPicker
Tab.CreateLabel        = _Label
Tab.CreateSection      = _Section
Tab.CreateProgressBar  = _ProgressBar
Tab.CreateStatusLabel  = _StatusLabel
Tab.CreateTable        = _Table
Tab.CreateRow            = _Row
Tab.CreateAccordionSection = _AccordionSection

return Tab
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Per-window notification layer factory + shared singleton
-- ────────────────────────────────────────────────────────────────────────
local Notification = (function()
local NOTIF_H   = 80
local NOTIF_GAP = 8
local NOTIF_X   = -300

local function createLayer(guiParent)
    local queue = {}

    local notifGui = Utility.Create("ScreenGui", {
        Name         = "AuroraNotifications",
        Parent       = guiParent,
        ResetOnSpawn = false,
    })

    local function reposition()
        for i, entry in ipairs(queue) do
            local targetY = -(i * (NOTIF_H + NOTIF_GAP))
            Utility.Tween(entry.frame, { Position = UDim2.new(1, NOTIF_X, 1, targetY) }, 0.25)
        end
    end

    local function notify(cfg)
        cfg = cfg or {}
        local colorMap = {
            Info    = Config.Theme.Primary,
            Success = Config.Theme.Success,
            Warning = Config.Theme.Warning,
            Error   = Config.Theme.Error,
        }
        local color    = colorMap[cfg.Type or "Info"] or colorMap.Info
        local duration = cfg.Duration or 3

        local slotIndex = #queue + 1
        local posY      = -(slotIndex * (NOTIF_H + NOTIF_GAP))

        local frame = Utility.Create("Frame", {
            Parent           = notifGui,
            Position         = UDim2.new(1, 20, 1, posY),
            Size             = UDim2.new(0, 280, 0, NOTIF_H),
            BackgroundColor3 = Config.Theme.Surface,
            BorderSizePixel  = 0,
        })
        Utility.AddCorner(frame)
        Utility.AddShadow(frame, 0.8)

        local AccentBar = Utility.Create("Frame", {
            Parent = frame, Size = UDim2.new(0, 4, 1, 0),
            BackgroundColor3 = color, BorderSizePixel = 0,
        })
        Utility.AddCorner(AccentBar, UDim.new(0, 4))
        Utility.Create("Frame", {
            Parent = AccentBar, Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0,
        })

        Utility.Create("TextLabel", {
            Parent = frame, Position = UDim2.new(0, 16, 0, 10),
            Size = UDim2.new(1, -32, 0, 20), BackgroundTransparency = 1,
            Text = cfg.Title or "Notification", TextColor3 = Config.Theme.Text,
            Font = Config.FontBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
        })
        Utility.Create("TextLabel", {
            Parent = frame, Position = UDim2.new(0, 16, 0, 32),
            Size = UDim2.new(1, -32, 0, 36), BackgroundTransparency = 1,
            Text = cfg.Message or "", TextColor3 = Config.Theme.TextMuted,
            Font = Config.Font, TextSize = 13, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        local Progress = Utility.Create("Frame", {
            Parent = frame, Position = UDim2.new(0, 0, 1, -2),
            Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = color, BorderSizePixel = 0,
        })

        local entry = { frame = frame }
        table.insert(queue, entry)

        Utility.Tween(frame, { Position = UDim2.new(1, NOTIF_X, 1, posY) }, 0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        Utility.Tween(Progress, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)

        task.delay(duration, function()
            Utility.Tween(frame, { Position = UDim2.new(1, 20, 1, posY) }, 0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            task.wait(0.35)
            frame:Destroy()
            for i, e in ipairs(queue) do
                if e == entry then table.remove(queue, i) break end
            end
            reposition()
        end)
    end

    return {
        Notify  = notify,
        Gui     = notifGui,
        Destroy = function() notifGui:Destroy() end,
    }
end

-- Shared singleton for Aurora:Notify().
-- Lazily created; re-created if the ScreenGui was destroyed.
local _shared = nil

local function sharedNotify(cfg)
    if not _shared or not _shared.Gui.Parent then
        _shared = createLayer(LocalPlayer:WaitForChild("PlayerGui"))
    end
    _shared.Notify(cfg)
end

return {
    createLayer   = createLayer,
    sharedNotify  = sharedNotify,
}
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Window factory function
-- ────────────────────────────────────────────────────────────────────────
local Window = (function()
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
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Config persistence: Link elements, auto-save/load, profiles, import/export
-- ────────────────────────────────────────────────────────────────────────
local ConfigSystem = (function()
local HttpService = game:GetService("HttpService")

-- Executor API detection (once at module load)
local HAS_FILE_API   = type(writefile)    == "function"
                    and type(readfile)    == "function"
                    and type(isfile)      == "function"
local HAS_FOLDER_API = type(isfolder)    == "function"
                    and type(makefolder) == "function"
local HAS_LIST_FILES = type(listfiles)   == "function"
local HAS_DELETE     = type(deletefile) == "function" or type(delfile) == "function"
local HAS_CLIPBOARD  = type(setclipboard) == "function"

-- Unified delete: tries deletefile then delfile, verifies with isfile afterwards.
local function _deleteFileRaw(path)
    if type(deletefile) == "function" then
        pcall(deletefile, path)
    elseif type(delfile) == "function" then
        pcall(delfile, path)
    end
    -- Return true only if the file is actually gone
    if type(isfile) == "function" then
        return not isfile(path)
    end
    return false
end

-- Serialisation helpers
local function serialise(value)
    local t = typeof(value)
    if t == "Color3" then
        return { _type = "Color3", r = value.R, g = value.G, b = value.B }
    elseif t == "EnumItem" then
        return { _type = "EnumItem", enum = tostring(value.EnumType), name = value.Name }
    elseif t == "boolean" or t == "number" or t == "string" then
        return value
    elseif t == "table" then
        local copy = {}
        for i, v in ipairs(value) do copy[i] = serialise(v) end
        return copy
    end
    return tostring(value)
end

local function deserialise(raw)
    if type(raw) == "table" then
        if raw._type == "Color3" then
            return Color3.new(tonumber(raw.r) or 0, tonumber(raw.g) or 0, tonumber(raw.b) or 0)
        elseif raw._type == "EnumItem" then
            local ok, val = pcall(function() return Enum[raw.enum][raw.name] end)
            return ok and val or Enum.KeyCode.Unknown
        else
            local out = {}
            for i, v in ipairs(raw) do out[i] = deserialise(v) end
            return out
        end
    end
    return raw
end

-- Factory
local function createConfig(cfg)
    cfg = cfg or {}
    local name     = cfg.Name     or "Config"
    local autoSave = cfg.AutoSave ~= false
    local autoLoad = cfg.AutoLoad ~= false
    local folder   = cfg.Folder   or "Aurora"
    local profile  = cfg.Profile  or "default"

    local OnSave           = Signal.new()
    local OnLoad           = Signal.new()
    local OnReset          = Signal.new()
    local OnProfileChanged = Signal.new()

    local _links = {}
    local _data  = {}

    -- Path helpers
    local function buildPath(p)
        p = p or profile
        local suffix = (p ~= "default") and ("_" .. p) or ""
        return folder .. "/" .. name .. suffix .. ".json"
    end

    local function lastProfilePath()
        return folder .. "/" .. name .. "_lastProfile.txt"
    end

    -- Storage layer
    local function ensureFolder()
        if HAS_FOLDER_API and not isfolder(folder) then pcall(makefolder, folder) end
    end

    local function writeFile(path, content)
        if not HAS_FILE_API then return false end
        return pcall(function() ensureFolder(); writefile(path, content) end)
    end

    local function readFile(path)
        if not HAS_FILE_API then return nil end
        local ok, content = pcall(function()
            return isfile(path) and readfile(path) or nil
        end)
        return (ok and content) or nil
    end

    local function deleteFile(path)
        if not HAS_FILE_API or not HAS_DELETE then return false end
        return _deleteFileRaw(path)
    end

    -- Last-profile persistence
    local function saveLastProfile(p)
        writeFile(lastProfilePath(), p)
    end

    local function loadLastProfile()
        local c = readFile(lastProfilePath())
        return (c and c ~= "") and c or "default"
    end

    -- Profile discovery: scans folder for matching files
    local function listProfiles()
        local profiles, seen = {}, {}
        local function add(p)
            if not seen[p] then seen[p] = true; table.insert(profiles, p) end
        end
        add("default")
        if HAS_FILE_API and HAS_LIST_FILES then
            local ok, files = pcall(listfiles, folder)
            if ok and files then
                local prefix   = name .. "_"
                local suffix   = ".json"
                local sideName = name .. "_lastProfile.txt"
                for _, path in ipairs(files) do
                    local fname = path:match("[^/\\]+$") or path
                    if fname ~= sideName
                    and fname:sub(1, #prefix) == prefix
                    and fname:sub(-#suffix)   == suffix then
                        local p = fname:sub(#prefix + 1, -#suffix - 1)
                        if p ~= "" then add(p) end
                    end
                end
            end
        end
        add(profile)  -- always include active profile
        return profiles
    end

    -- Core operations
    local function doSave()
        local out = {}
        for key, link in pairs(_links) do
            out[key] = serialise(link.element.GetValue())
        end
        local json = HttpService:JSONEncode(out)
        writeFile(buildPath(), json)
        _data = out
        OnSave:Fire()
    end

    local function doLoad()
        local content = readFile(buildPath())
        if not content or content == "" then return false end
        local ok, decoded = pcall(function() return HttpService:JSONDecode(content) end)
        if not ok or type(decoded) ~= "table" then return false end
        _data = decoded
        for key, link in pairs(_links) do
            if _data[key] ~= nil then link.element.SetValue(deserialise(_data[key])) end
        end
        OnLoad:Fire()
        return true
    end

    -- Config object
    local self = {}
    self.OnSave           = OnSave
    self.OnLoad           = OnLoad
    self.OnReset          = OnReset
    self.OnProfileChanged = OnProfileChanged

    function self:Link(key, element)
        if not element or not element.GetValue then
            warn("[Aurora Config] Link(\"" .. tostring(key) .. "\"): element missing GetValue")
            return self
        end
        _links[key] = { element = element, default = element.GetValue() }
        if _data[key] ~= nil then element.SetValue(deserialise(_data[key])) end
        if autoSave and element.OnChanged then
            element.OnChanged:Connect(function() doSave() end)
        end
        return self
    end

    function self:Save()   doSave();       return self end
    function self:Load()   return doLoad()             end

    function self:Reset()
        for _, link in pairs(_links) do link.element.SetValue(link.default) end
        _data = {}
        writeFile(buildPath(), "{}")
        OnReset:Fire()
        return self
    end

    function self:Export()
        local out = {}
        for key, link in pairs(_links) do out[key] = serialise(link.element.GetValue()) end
        return HttpService:JSONEncode(out)
    end

    function self:Import(str)
        if type(str) ~= "string" or str == "" then return false end
        local ok, decoded = pcall(function() return HttpService:JSONDecode(str) end)
        if not ok or type(decoded) ~= "table" then
            warn("[Aurora Config] Import: invalid JSON — " .. tostring(decoded))
            return false
        end
        _data = decoded
        for key, link in pairs(_links) do
            if decoded[key] ~= nil then link.element.SetValue(deserialise(decoded[key])) end
        end
        if autoSave then doSave() end
        return true
    end

    function self:SetProfile(profileName)
        profileName = tostring(profileName):match("^%s*(.-)%s*$")
        if profileName == "" then profileName = "default" end
        profile = profileName
        doLoad()
        saveLastProfile(profileName)
        OnProfileChanged:Fire(profileName)
        return self
    end

    function self:GetProfile()    return profile         end
    function self:HasStorage()    return HAS_FILE_API    end
    function self:ListProfiles()  return listProfiles()  end

    function self:DeleteProfile(profileName)
        if profileName == "default" then return false end
        local deleted = deleteFile(buildPath(profileName))
        if profile == profileName then self:SetProfile("default") end
        return deleted
    end

    -- Rename the current profile. Copies the save file to the new name,
    -- deletes the old file, updates active profile + sidecar.
    -- Returns false if newName is invalid or already exists.
    function self:RenameProfile(newName)
        newName = tostring(newName):match("^%s*(.-)%s*$")
        if newName == "" or newName == profile then return false end
        if profile == "default" then return false end
        -- Refuse if a profile with that name already exists
        for _, p in ipairs(listProfiles()) do
            if p == newName then return false end
        end
        -- Write current values under the new name
        local oldProfile = profile
        local content    = readFile(buildPath(oldProfile))
        if not content then
            -- Nothing saved yet — just switch name and save fresh
            profile = newName
            doSave()
        else
            writeFile(buildPath(newName), content)
            deleteFile(buildPath(oldProfile))
            profile = newName
        end
        saveLastProfile(newName)
        OnProfileChanged:Fire(newName)
        return true
    end

    -- Auto-generate the next available profile name: "Profile 1", "Profile 2" …
    function self:NextProfileName()
        local existing = {}
        for _, p in ipairs(listProfiles()) do existing[p] = true end
        local i = 1
        while existing["Profile " .. i] do i = i + 1 end
        return "Profile " .. i
    end

    -- CreateControls: compact dropdown + import/export/reset (no section spam)
    function self:CreateControls(tab)
        if not tab or not tab.CreateSection then
            warn("[Aurora Config] CreateControls: invalid tab")
            return self
        end

        if not HAS_FILE_API then
            tab:CreateStatusLabel({ Text = "Config: in-memory only (no file API)", Type = "Warning" })
        end

        -- Profile picker
        if HAS_FILE_API then
            tab:CreateSection({ Text = "Profile" })

            local profileDropdown
            profileDropdown = tab:CreateDropdown({
                Text     = "Selected Profile",
                Options  = listProfiles(),
                Default  = profile,
                Callback = function(chosen)
                    if chosen == profile then return end
                    self:SetProfile(chosen)
                    Notification.sharedNotify({ Title = "Config", Message = "Switched to: " .. chosen, Type = "Success" })
                end,
            })

            tab:CreateButton({
                Text     = "Create New Profile",
                Callback = function()
                    local newName = self:NextProfileName()
                    self:SetProfile(newName)
                    self:Save()
                    profileDropdown.SetOptions(listProfiles())
                    profileDropdown.SetValue(newName)
                    Notification.sharedNotify({ Title = "Config", Message = "Created: " .. newName, Type = "Success" })
                end,
            })

            tab:CreateInput({
                Text        = "Rename Current Profile",
                Placeholder = "New name — press Enter",
                Callback    = function(newName)
                    newName = newName:match("^%s*(.-)%s*$")
                    if newName == "" then return end
                    if profile == "default" then
                        Notification.sharedNotify({ Title = "Config", Message = "Can't rename default.", Type = "Warning" })
                        return
                    end
                    local prev = profile
                    if self:RenameProfile(newName) then
                        profileDropdown.SetOptions(listProfiles())
                        profileDropdown.SetValue(newName)
                        Notification.sharedNotify({ Title = "Config", Message = prev .. " renamed to " .. newName, Type = "Success" })
                    else
                        Notification.sharedNotify({ Title = "Config", Message = "Rename failed.", Type = "Error" })
                    end
                end,
            })

            tab:CreateButton({
                Text     = "Delete Current Profile",
                Callback = function()
                    if profile == "default" then
                        Notification.sharedNotify({ Title = "Config", Message = "Can't delete default.", Type = "Warning" })
                        return
                    end
                    local prev = profile
                    self:DeleteProfile(profile)
                    profileDropdown.SetOptions(listProfiles())
                    profileDropdown.SetValue("default")
                    Notification.sharedNotify({ Title = "Config", Message = prev .. " deleted.", Type = "Warning" })
                end,
            })

            OnProfileChanged:Connect(function(p)
                profileDropdown.SetValue(p)
            end)
        end

        -- Import / Export
        tab:CreateSection({ Text = "Import / Export" })

        tab:CreateButton({
            Text     = HAS_CLIPBOARD and "Export to Clipboard" or "Export (console)",
            Callback = function()
                local json = self:Export()
                if HAS_CLIPBOARD then
                    pcall(setclipboard, json)
                    Notification.sharedNotify({ Title = "Config", Message = "Copied.", Type = "Success" })
                else
                    print("[Aurora Config] Export:" .. json)
                    Notification.sharedNotify({ Title = "Config", Message = "Printed to console.", Type = "Info" })
                end
            end,
        })

        tab:CreateInput({
            Text        = "Import Config",
            Placeholder = "Paste JSON and press Enter",
            Callback    = function(str)
                if self:Import(str) then
                    Notification.sharedNotify({ Title = "Config", Message = "Imported.", Type = "Success" })
                else
                    Notification.sharedNotify({ Title = "Config", Message = "Invalid JSON.", Type = "Error" })
                end
            end,
        })

        tab:CreateButton({
            Text     = "Reset to Defaults",
            Callback = function()
                self:Reset()
                Notification.sharedNotify({ Title = "Config", Message = "Reset to defaults.", Type = "Warning" })
            end,
        })

        return self
    end

    -- Auto-load: restore last profile then load its data.
    -- Done before any Link() calls; _data is cached so Link() applies values later.
    if autoLoad then
        local last = loadLastProfile()
        if last ~= profile then
            profile = last  -- assign directly — signal not wired yet
        end
        doLoad()
    end

    return self
end

return createConfig
end)()

-- ────────────────────────────────────────────────────────────────────────
--  Public API surface — returned to consumer
-- ────────────────────────────────────────────────────────────────────────
local Aurora = (function()
local Aurora = {}

-- Create and open a new UI window.
function Aurora:CreateWindow(config)
    return Window(config)
end

-- Display a toast notification using the shared singleton layer.
-- For per-window notifications, call window:Notify(cfg) instead.
function Aurora:Notify(cfg)
    Notification.sharedNotify(cfg)
end

-- Override theme colours. Only affects elements created AFTER the call.
-- Valid keys: Primary, Secondary, Background, Surface, Text, TextMuted,
--             Success, Warning, Error, Border, Glow.
function Aurora:SetTheme(newTheme)
    for k, v in pairs(newTheme) do
        if Config.Theme[k] ~= nil then
            Config.Theme[k] = v
        end
    end
end

-- Create a configuration object that persists element values to disk.
--
-- Usage:
--   local cfg = Aurora:CreateConfig({ Name = "MyScript", Folder = "MyGame" })
--   cfg:Link("ToggleA", toggleA)
--       :Link("Speed",   speedSlider)
--       :Link("Color",   colorPicker)
--   cfg:CreateControls(settingsTab)   -- optional: adds import/export/reset UI
--
-- Options (all optional):
--   Name      string   File name stem.                         Default: "Config"
--   Folder    string   Subfolder in executor workspace.        Default: "Aurora"
--   Profile   string   Named save slot — switch at runtime.    Default: "default"
--   AutoSave  bool     Save on every user change.              Default: true
--   AutoLoad  bool     Load saved values at creation time.     Default: true
function Aurora:CreateConfig(options)
    return ConfigSystem(options)
end

-- Expose Config for advanced consumers who want to read animation settings etc.
Aurora.Config = Config

return Aurora
end)()

return Aurora
