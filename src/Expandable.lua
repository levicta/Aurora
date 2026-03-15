-- src/Expandable.lua
-- Shared expand/collapse behaviour for all "accordion" elements
-- (Dropdown, SearchDropdown, MultiSelect, ColorPicker).
--
-- Replaces four verbatim copies of the same tween + registry code from v6.
-- Single source of truth: change the animation once here, all elements update.
--
-- References Config, Utility as outer-scope upvalues (resolved at build time).

-- Weak-keyed registry: frame → collapse()
-- Weak keys mean frames that are GC'd stop holding entries automatically.
-- SetEnabled(false) calls tryCollapse() before overlaying the element.
local _registry = setmetatable({}, { __mode = "k" })

-- Create an expandable controller for `frame`.
--   collapsedH   : number  — pixel height when closed
--   getExpandedH : number | () → number  — pixel height (or thunk) when open
--   arrowLabel   : TextLabel? — optional arrow glyph to rotate 0↔180
--
-- Returns a controller table with collapse(), expand(), toggle(), isExpanded().
local function makeExpandable(frame, collapsedH, getExpandedH, arrowLabel)
    local expanded = false

    local function resolveH()
        return type(getExpandedH) == "function" and getExpandedH() or getExpandedH
    end

    local function collapse()
        if not expanded then return end
        expanded = false
        Utility.Tween(frame, { Size = UDim2.new(1, 0, 0, collapsedH) }, 0.2)
        if arrowLabel then
            Utility.Tween(arrowLabel, { Rotation = 0 }, 0.2)
        end
    end

    local function expand()
        if expanded then return end
        expanded = true
        Utility.Tween(frame, { Size = UDim2.new(1, 0, 0, resolveH()) }, 0.2)
        if arrowLabel then
            Utility.Tween(arrowLabel, { Rotation = 180 }, 0.2)
        end
    end

    local function toggle()
        if expanded then collapse() else expand() end
    end

    -- Register so SetEnabled(false) can auto-collapse this element.
    _registry[frame] = collapse

    return {
        collapse   = collapse,
        expand     = expand,
        toggle     = toggle,
        isExpanded = function() return expanded end,
    }
end

-- Called by RegisterElement's SetEnabled(false) path.
-- Safe to call on non-expandable frames (noop if not registered).
local function tryCollapse(frame)
    local fn = _registry[frame]
    if fn then fn() end
end

return {
    makeExpandable = makeExpandable,
    tryCollapse    = tryCollapse,
}
