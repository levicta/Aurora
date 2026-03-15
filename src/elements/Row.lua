-- src/elements/Row.lua
-- Tab:CreateRow(cfg) factory.
-- NEW in v7: horizontal layout container. Removes the hard ceiling of single-column tabs.
--
-- cfg: { Columns?, Gap?, Height? }
--
-- Usage:
--   local row = Tab:CreateRow({ Columns = 2, Height = 36 })
--   row.Add(Tab:CreateToggle({ Text = "Option A" }))
--   row.Add(Tab:CreateToggle({ Text = "Option B" }))
--
-- Notes:
--   - Expandable elements (dropdowns, pickers) inside a Row will clip at the row's
--     fixed height. Use them in regular (non-row) positions instead.
--   - Row.Destroy() propagates to all child elements.
--   - Child elements remain in Tab.Elements and retain their full API.

return function(self, cfg)
    cfg = cfg or {}
    local columns = cfg.Columns or 2
    local gap     = cfg.Gap     or 6
    local height  = cfg.Height  or 36

    local RowFrame = Utility.Create("Frame", {
        Parent             = self.Content,
        Size               = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel    = 0,
    })
    Utility.Create("UIListLayout", {
        Parent        = RowFrame,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Padding       = UDim.new(0, gap),
    })

    local rowChildren = {}
    -- Width each column should occupy: equal share minus the proportional gap.
    local colW      = 1 / columns
    local colOffset = -math.floor(gap * (columns - 1) / columns)

    local rowData = {
        -- Reparent an element's frame into this row and resize it to fill one column.
        -- The element remains in Tab.Elements and retains its full API.
        Add = function(element)
            if not element or not element.Frame then return end
            table.insert(rowChildren, element)
            element.Frame.Parent     = RowFrame
            element.Frame.Size       = UDim2.new(colW, colOffset, 1, 0)
            element.Frame.LayoutOrder = #rowChildren
        end,
    }

    local rowElem = self:RegisterElement(rowData, RowFrame)

    -- Wrap Destroy so child elements are also cleaned up cleanly.
    local parentDestroy = rowElem.Destroy
    rowElem.Destroy = function()
        for _, child in ipairs(rowChildren) do
            if child.Destroy then pcall(child.Destroy) end
        end
        parentDestroy()
    end

    return rowElem
end
