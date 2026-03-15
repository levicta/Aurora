-- src/Notification.lua
-- Notification layer factory.
--
-- v7 change: notifications are now scoped per-layer instance rather than using
-- a single module-level queue. Each Window gets its own layer via Window:Notify().
-- Aurora:Notify() still works via a shared singleton layer.
--
-- createLayer(guiParent) → { Notify(cfg), Destroy() }
-- The layer creates its own ScreenGui in `guiParent` (always PlayerGui).

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
