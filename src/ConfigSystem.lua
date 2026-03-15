-- src/ConfigSystem.lua
-- Aurora configuration persistence system.
-- Aurora:CreateConfig(cfg) → ConfigObject
--
-- Saves and loads all linked element values to a JSON file using executor
-- file APIs (writefile / readfile). Falls back to in-memory-only mode
-- silently if those APIs are unavailable (e.g. some stripped executors).
--
-- Key design properties:
--   - SetValue is silent in v7, so loading values never triggers auto-save.
--     There are no circular load→change→save→load cycles.
--   - Link() captures each element's current value as its "default" so
--     Reset() can restore factory state without re-running user code.
--   - Link() is chainable: cfg:Link("A", a):Link("B", b)
--   - CreateControls(tab) injects a full profile selector + import/export/reset UI.
--   - The last active profile is persisted to disk so rejoining restores it.

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