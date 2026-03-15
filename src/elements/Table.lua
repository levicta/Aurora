-- src/elements/Table.lua
-- Tab:CreateTable(cfg) factory.
-- cfg: { Columns?, Rows?, MaxVisible? }
--
-- v7 improvements over v6:
--   - Per-row colour stored on a rowBaseSetters upvalue (not a shared closure variable).
--   - RemoveRow only re-renders rows AFTER the removed index, not the entire table.
--   - SetRowColor / ClearRowColor restore the correct hover-base via a per-row setter.

return function(self, cfg)
    cfg = cfg or {}
    local columns      = cfg.Columns    or { "Column 1", "Column 2" }
    local rows         = cfg.Rows       or {}
    local rowH         = 28
    local headerH      = 28
    local maxRows      = cfg.MaxVisible or 6
    local OnRowClicked = Signal.new()

    local numCols = #columns
    local colW    = 1 / numCols

    local TableFrame = Utility.Create("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, headerH + math.min(#rows, maxRows) * rowH),
        BackgroundColor3 = Config.Theme.Background,
        BorderSizePixel  = 0,
        ClipsDescendants = false,
    })
    Utility.AddCorner(TableFrame, UDim.new(0, 4))

    -- Header
    local Header = Utility.Create("Frame", {
        Parent           = TableFrame,
        Size             = UDim2.new(1, 0, 0, headerH),
        BackgroundColor3 = Config.Theme.Primary,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    })
    Utility.AddCorner(Header, UDim.new(0, 4))
    Utility.Create("Frame", {   -- patch header bottom corners flush with body
        Parent = Header, Position = UDim2.new(0,0,1,-6),
        Size = UDim2.new(1,0,0,6), BackgroundColor3 = Config.Theme.Primary, BorderSizePixel = 0,
    })
    for i, col in ipairs(columns) do
        Utility.Create("TextLabel", {
            Parent = Header, Position = UDim2.new((i-1)*colW, 8, 0, 0),
            Size = UDim2.new(colW, -8, 1, 0), BackgroundTransparency = 1,
            Text = col, TextColor3 = Config.Theme.Text, Font = Config.FontBold,
            TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        })
        if i < numCols then
            Utility.Create("Frame", {
                Parent = Header, Position = UDim2.new(i*colW, 0, 0.1, 0),
                Size = UDim2.new(0, 1, 0.8, 0), BackgroundColor3 = Color3.new(1,1,1),
                BackgroundTransparency = 0.7, BorderSizePixel = 0,
            })
        end
    end

    -- Scrollable body
    local Body = Utility.Create("ScrollingFrame", {
        Parent               = TableFrame,
        Position             = UDim2.new(0, 0, 0, headerH),
        Size                 = UDim2.new(1, 0, 1, -headerH),
        BackgroundColor3     = Config.Theme.Background,
        BorderSizePixel      = 0,
        ScrollBarThickness   = 2,
        ScrollBarImageColor3 = Config.Theme.Border,
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        ClipsDescendants     = true,
    })
    Utility.AddCorner(Body, UDim.new(0, 4))
    Utility.Create("UIListLayout", { Parent = Body, SortOrder = Enum.SortOrder.LayoutOrder })

    -- rowObjects[i]       = Frame  (the rendered row)
    -- rowColors[i]        = Color3 | nil  (custom colour override)
    -- rowBaseSetters[i]   = fn(Color3)    (per-row upvalue setter — correct hover restore)
    local rowObjects     = {}
    local rowColors      = {}
    local rowBaseSetters = {}

    local function renderRow(rowData, index)
        local defaultColor = index % 2 == 0 and Config.Theme.Surface or Config.Theme.Background
        local baseColor    = rowColors[index] or defaultColor

        local rowFrame = Utility.Create("Frame", {
            Parent           = Body,
            Size             = UDim2.new(1, 0, 0, rowH),
            BackgroundColor3 = baseColor,
            BorderSizePixel  = 0,
            LayoutOrder      = index,
        })
        for c, cell in ipairs(rowData) do
            Utility.Create("TextLabel", {
                Parent = rowFrame, Position = UDim2.new((c-1)*colW, 8, 0, 0),
                Size = UDim2.new(colW, -8, 1, 0), BackgroundTransparency = 1,
                Text = tostring(cell), TextColor3 = Config.Theme.Text,
                Font = Config.Font, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            })
        end

        -- Per-row upvalue: currentBase is private to THIS row.
        -- SetRowColor / ClearRowColor call rowBaseSetters[index] to update it.
        local currentBase = baseColor
        rowBaseSetters[index] = function(c)
            currentBase           = c
            rowFrame.BackgroundColor3 = c
        end

        local rowBtn = Utility.Create("TextButton", {
            Parent = rowFrame, Size = UDim2.new(1,0,1,0),
            BackgroundTransparency = 1, Text = "",
        })
        rowBtn.MouseEnter:Connect(function()
            Utility.Tween(rowFrame, { BackgroundColor3 = Color3.fromRGB(40, 40, 55) }, 0.12)
        end)
        rowBtn.MouseLeave:Connect(function()
            -- Reads currentBase from this row's upvalue — correct even after SetRowColor.
            Utility.Tween(rowFrame, { BackgroundColor3 = currentBase }, 0.12)
        end)
        rowBtn.MouseButton1Click:Connect(function()
            OnRowClicked:Fire(index, rowData)
        end)
        return rowFrame
    end

    local function resize()
        TableFrame.Size = UDim2.new(1, 0, 0, headerH + math.min(#rows, maxRows) * rowH)
    end

    for i, rowData in ipairs(rows) do
        rowObjects[i] = renderRow(rowData, i)
    end
    resize()

    local element = {
        OnRowClicked = OnRowClicked,

        SetRows = function(newRows)
            rows = newRows
            rowColors = {}
            rowBaseSetters = {}
            for _, obj in ipairs(rowObjects) do obj:Destroy() end
            rowObjects = {}
            for i, rowData in ipairs(rows) do rowObjects[i] = renderRow(rowData, i) end
            resize()
        end,

        AddRow = function(rowData)
            table.insert(rows, rowData)
            local i = #rows
            rowObjects[i] = renderRow(rowData, i)
            resize()
        end,

        -- Incremental remove: only re-render rows after the removed index.
        RemoveRow = function(index)
            if not rows[index] then return end
            if rowObjects[index] then rowObjects[index]:Destroy() end
            table.remove(rows, index)
            table.remove(rowObjects, index)

            -- Shift colour overrides down by one.
            local newColors = {}
            for i, c in pairs(rowColors) do
                if    i > index then newColors[i-1] = c
                elseif i < index then newColors[i]   = c end
            end
            rowColors = newColors

            -- Re-render only the rows whose index changed (index onward).
            for i = index, #rows do
                if rowObjects[i] then rowObjects[i]:Destroy() end
                rowBaseSetters[i] = nil
                rowObjects[i] = renderRow(rows[i], i)
            end
            resize()
        end,

        SetCell = function(rowIndex, colIndex, value)
            if not rows[rowIndex] then return end
            rows[rowIndex][colIndex] = value
            local rowFrame = rowObjects[rowIndex]
            if not rowFrame then return end
            local labels = {}
            for _, c in ipairs(rowFrame:GetChildren()) do
                if c:IsA("TextLabel") then table.insert(labels, c) end
            end
            table.sort(labels, function(a, b) return a.Position.X.Scale < b.Position.X.Scale end)
            if labels[colIndex] then labels[colIndex].Text = tostring(value) end
        end,

        SetRowColor = function(index, color)
            rowColors[index] = color
            if rowBaseSetters[index] then rowBaseSetters[index](color) end
        end,

        ClearRowColor = function(index)
            rowColors[index] = nil
            if rowBaseSetters[index] then
                local def = index % 2 == 0 and Config.Theme.Surface or Config.Theme.Background
                rowBaseSetters[index](def)
            end
        end,

        Clear = function()
            rows = {}
            rowColors = {}
            rowBaseSetters = {}
            for _, obj in ipairs(rowObjects) do obj:Destroy() end
            rowObjects = {}
            resize()
        end,

        GetRows = function()
            local copy = {}
            for i, row in ipairs(rows) do copy[i] = row end
            return copy
        end,
    }

    return self:RegisterElement(element, TableFrame)
end
