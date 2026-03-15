-- src/Signal.lua
-- Lightweight publish/subscribe event system.
-- No external dependencies.

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
