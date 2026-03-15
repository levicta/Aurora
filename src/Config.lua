-- src/Config.lua
-- Mutable theme + animation configuration.
-- Aurora:SetTheme() patches this table at runtime.
-- Note: only elements created AFTER a SetTheme call will use the new colours.

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
