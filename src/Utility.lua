-- src/Utility.lua
-- Shared helper functions used throughout the library.
-- References Config, TweenService, UserInputService as outer-scope upvalues (resolved at build time).
--
-- Key improvement over v6: Tween() cancels any in-flight tween on the same
-- instance before starting a new one, preventing competing-tween pile-up on
-- rapidly-updated elements (ProgressBar driven by a game loop, programmatic
-- SetValue on sliders, etc.).

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
