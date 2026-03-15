-- src/elements/Button.lua
-- Tab:CreateButton(cfg) factory.
-- cfg: { Text?, Callback? }

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
