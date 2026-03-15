-- src/elements/Keybind.lua
-- Tab:CreateKeybind(cfg) factory.
-- cfg: { Text?, Default?, Callback? }
--
-- The UIS cancel connection goes into the element's ConnSet for clean teardown.
-- SetValue is SILENT. Binding a new key fires Callback + OnChanged.

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
