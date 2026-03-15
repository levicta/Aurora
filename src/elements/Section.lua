-- src/elements/Section.lua
-- Tab:CreateSection(cfg) factory.
-- Now accepts config table. Legacy positional string still accepted.
-- cfg: { Text? }
-- Full element API: GetValue, SetValue, SetText.

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
