-- src/ConnSet.lua
-- Connection set: hash-keyed for O(1) add, remove, and disconnect-all.
-- Replaces the flat windowConnections array from v6, eliminating linear scans
-- and the double-insertion bug in CreateColorPicker.
--
-- Usage:
--   local cs = ConnSet.new()
--   cs:Add(UserInputService.InputChanged:Connect(...))
--   cs:Remove(someConn)     -- disconnects and forgets it
--   cs:DisconnectAll()      -- disconnects every tracked connection

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
