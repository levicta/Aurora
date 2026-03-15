-- src/elements/Label.lua
-- Tab:CreateLabel(cfg) factory.
-- Now accepts config table (like all other elements) instead of positional string.
-- cfg: { Text? }   — legacy positional string still accepted for backwards compat.
-- Full element API: GetValue, SetValue, SetText, OnChanged, Destroy, SetVisible, SetEnabled.

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
