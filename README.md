# Aurora UI Library — v7.0 Developer Reference

Aurora is a Roblox Lua UI library for building in-game script interfaces. It provides a tabbed window system, 17 built-in element types, a notification system, and a full configuration persistence layer — all loaded via a single `loadstring` call.

---

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Aurora Root API](#2-aurora-root-api)
3. [Window](#3-window)
4. [Tab](#4-tab)
5. [Elements — Common API](#5-elements--common-api)
6. [Elements — Reference](#6-elements--reference)
   - [Button](#button)
   - [Toggle](#toggle)
   - [Slider](#slider)
   - [Dropdown](#dropdown)
   - [SearchDropdown](#searchdropdown)
   - [MultiSelect](#multiselect)
   - [Input](#input)
   - [NumberInput](#numberinput)
   - [Keybind](#keybind)
   - [ColorPicker](#colorpicker)
   - [Label](#label)
   - [Section](#section)
   - [ProgressBar](#progressbar)
   - [StatusLabel](#statuslabel)
   - [Table](#table)
   - [Row](#row)
   - [AccordionSection](#accordionsection)
7. [Notifications](#7-notifications)
8. [Themes & Config](#8-themes--config)
9. [Config System](#9-config-system)
10. [Signals](#10-signals)
11. [ConnSet](#11-connset)
12. [Architecture & Internals](#12-architecture--internals)
13. [Advanced: Custom Elements](#13-advanced-custom-elements)
14. [Building from Source](#14-building-from-source)
15. [Suggested Improvements](#15-suggested-improvements)

---

## 1. Getting Started

### Loading

```lua
local Aurora = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Gladamy/Aurora/main/Aurora.lua"
))()
```

### Minimal example

```lua
local Aurora = loadstring(...)()

local win = Aurora:CreateWindow({ Title = "My Script" })
local tab = win:CreateTab({ Name = "Main", Icon = "" })

local toggle = tab:CreateToggle({
    Text     = "God Mode",
    Default  = false,
    Callback = function(val)
        -- val is true or false
    end,
})

-- Read value at any time
print(toggle.GetValue())   -- false

-- Set silently (no callback fires)
toggle.SetValue(true)
```

---

## 2. Aurora Root API

`Aurora` is the table returned by `loadstring(...)()`. It is the only global surface — everything else hangs off it.

```lua
Aurora:CreateWindow(cfg)    -- → Window
Aurora:CreateConfig(cfg)    -- → ConfigObject
Aurora:Notify(cfg)          -- show a shared toast notification
Aurora:SetTheme(tbl)        -- patch theme colours at runtime
Aurora.Config               -- read-only access to the Config table
```

### `Aurora:CreateWindow(cfg)`

| Key | Type | Default | Description |
|---|---|---|---|
| `Title` | string | `"Aurora"` | Window title bar text |
| `Size` | UDim2 | `620×420` | Initial window size |
| `Position` | UDim2 | centred | Initial screen position |

Returns a [Window](#3-window).

### `Aurora:CreateConfig(cfg)`

See [Config System](#9-config-system) for full reference.

### `Aurora:Notify(cfg)`

See [Notifications](#7-notifications).

### `Aurora:SetTheme(tbl)`

Patches `Aurora.Config.Theme` at runtime. Only elements created **after** this call use the new colours. Elements already on screen are not retroactively updated.

```lua
Aurora:SetTheme({
    Primary = Color3.fromRGB(255, 80, 80),
    Success = Color3.fromRGB(0, 220, 100),
})
```

Valid keys: `Primary`, `Secondary`, `Background`, `Surface`, `Text`, `TextMuted`, `Success`, `Warning`, `Error`, `Border`, `Glow`.

### `Aurora.Config`

Direct access to the internal config table. Useful for reading animation settings.

```lua
print(Aurora.Config.Theme.Primary)
print(Aurora.Config.Animation.Duration)   -- 0.3
print(Aurora.Config.Font)                 -- Enum.Font.Gotham
print(Aurora.Config.CornerRadius)         -- UDim.new(0, 6)
print(Aurora.Config.ShadowTransparency)   -- 0.7
```

See [Themes & Config](#8-themes--config) for the full table.

---

## 3. Window

### Properties

| Property | Type | Description |
|---|---|---|
| `Tabs` | `Tab[]` | Array of all tabs in creation order |
| `ActiveTab` | `Tab` | Currently visible tab |
| `ScreenGui` | `Instance` | The `ScreenGui` created in `PlayerGui` |
| `MainFrame` | `Instance` | The root `Frame` of the window |
| `OnTabChanged` | `Signal` | Fires `(newTab, oldTab)` when the active tab switches |

### Methods

```lua
win:CreateTab(cfg)      -- → Tab
win:SelectTab(index)    -- switch to tab by 1-based index (fires OnTabChanged)
win:Notify(cfg)         -- show a toast scoped to this window's notification layer
win:Destroy()           -- teardown: disconnects all connections, destroys ScreenGui
```

### `win:CreateTab(cfg)`

| Key | Type | Description |
|---|---|---|
| `Name` | string | Tab label text |
| `Icon` | string | Roblox asset ID string for the tab icon image. Optional — omit for text-only tabs |

```lua
local tab = win:CreateTab({ Name = "Settings", Icon = "rbxassetid://123456" })
```

> **First tab** is auto-activated when created, without firing `OnTabChanged`.

### `win:Destroy()`

Performs a full teardown in this order:
1. Disconnects every element's `ConnSet` across all tabs
2. Disconnects window-level connections (drag, sidebar reflow)
3. Destroys the per-window notification layer if one was created
4. Destroys `ScreenGui` (cascades to all child instances)

### Window behaviour

- **Draggable** — drag by the title bar
- **Minimize** — the `—` button collapses the window to 40px (title bar only). Click again to restore
- **Close** — the `✕` button plays a shrink animation then calls `Destroy()`
- **Intro animation** — the window opens with a `Back` easing expand from the centre point (0.5s)
- **Sidebar auto-resize** — the tab sidebar grows with the longest tab name (min 110px, max 200px). The content area reflows automatically

---

## 4. Tab

All 17 `Create*` methods are defined once on the `Tab` prototype — creating many tabs allocates zero additional closures compared to one.

### Properties

| Property | Type | Description |
|---|---|---|
| `Name` | string | Tab name as passed to `CreateTab` |
| `Button` | `Instance` | The sidebar `TextButton` |
| `Label` | `Instance` | The `TextLabel` inside the button |
| `Content` | `Instance` | The `ScrollingFrame` holding all elements |
| `Elements` | `table` | Array of all registered elements in insertion order |
| `OnElementAdded` | `Signal` | Fires with the element when any `Create*` method completes |

### Methods

```lua
tab:Activate()    -- programmatically switch to this tab (fires window.OnTabChanged)
tab:CreateButton(cfg)
tab:CreateToggle(cfg)
tab:CreateSlider(cfg)
tab:CreateDropdown(cfg)
tab:CreateSearchDropdown(cfg)
tab:CreateMultiSelect(cfg)
tab:CreateInput(cfg)
tab:CreateNumberInput(cfg)
tab:CreateKeybind(cfg)
tab:CreateColorPicker(cfg)
tab:CreateLabel(cfg)
tab:CreateSection(cfg)
tab:CreateProgressBar(cfg)
tab:CreateStatusLabel(cfg)
tab:CreateTable(cfg)
tab:CreateRow(cfg)
tab:CreateAccordionSection(cfg)
```

> `tab:Activate()` is equivalent to clicking the tab button. It fires `window.OnTabChanged` with `(self, previousTab)`. Calling it on the already-active tab is a no-op.

### Empty state

Every new tab shows a `"No elements yet."` placeholder text. It disappears automatically as soon as the first element is registered. It reappears if all elements are destroyed.

### Tab content scrolling

The content area is a `ScrollingFrame` with `AutomaticCanvasSize = Y`. Elements stack vertically with 8px gaps and 10px top/bottom padding. The scroll bar is 3px wide and uses `Config.Theme.Border` colour.

---

## 5. Elements — Common API

Every element returned by a `Create*` call exposes these fields and functions regardless of element type.

### Standard fields

| Field | Type | Description |
|---|---|---|
| `OnChanged` | `Signal` | Fires on user interaction. **Never** fires when `SetValue` is called (except `Label`, `StatusLabel`, `ProgressBar` — see their entries). **Not present on `Button` or `Section`** — those have no interactive value |
| `Frame` | `Instance` | The root `Frame` instance of the element in the UI |
| `_conns` | `ConnSet` | The element's connection set. Advanced use only |

### Standard functions

```lua
element.GetValue()           -- returns current value
element.SetValue(v)          -- updates silently — never fires Callback or OnChanged*
element.SetEnabled(bool)     -- enable/disable. Disabled = semi-transparent overlay, no interaction
element.SetVisible(bool)     -- show/hide the element's frame
element.Destroy()            -- disconnect all connections, remove from Tab.Elements, destroy frame
```

> **\* SetValue silent contract** — `SetValue` never fires `Callback` or `OnChanged` on any interactive element. This is a hard guarantee that makes the ConfigSystem safe: it can call `SetValue` to restore saved values without triggering re-saves or callback side effects.
>
> The three display-only elements (`Label`, `StatusLabel`, `ProgressBar`) are the only exceptions — they have no user interaction, so `SetValue` is the only meaningful change mechanism and fires `OnChanged` to keep observers in sync.

### `SetEnabled(false)` behaviour

- Any open expandable (Dropdown, SearchDropdown, MultiSelect, ColorPicker) is force-collapsed first
- All descendant text labels and buttons are dimmed to `Config.Theme.Border`
- A semi-transparent overlay `TextButton` is placed over the frame at `ZIndex 99` to block all input
- `SetEnabled(true)` reverses all of the above

---

## 6. Elements — Reference

### Button

```lua
local btn = tab:CreateButton({
    Text     = "Click Me",    -- button label
    Callback = function()
        -- fires on click
    end,
})
```

**Extra API:**
```lua
btn.SetText("New Label")    -- update button text at runtime
```

**Behaviour:** hover tints the background slightly; `MouseButton1Down` flashes the primary colour; `MouseButton1Up` reverts to hover state.

---

### Toggle

```lua
local toggle = tab:CreateToggle({
    Text     = "Auto Farm",
    Default  = false,          -- initial state
    Callback = function(val)   -- val: boolean
    end,
})
```

**`GetValue()`** → `boolean`

**`SetValue(bool)`** — coerces to boolean. Animates the track and circle. Silent.

---

### Slider

```lua
local slider = tab:CreateSlider({
    Text      = "Speed",
    Min       = 0,
    Max       = 100,
    Default   = 16,
    Increment = 1,        -- snap step
    Callback  = function(val)   -- val: number
    end,
})
```

| Option | Type | Default | Description |
|---|---|---|---|
| `Min` | number | `0` | Minimum value |
| `Max` | number | `100` | Maximum value |
| `Default` | number | `Min` | Initial value, clamped to Min..Max |
| `Increment` | number | `1` | Snap step. Value is always a multiple of this |

**`GetValue()`** → `number`

**`SetValue(n)`** — clamps to Min..Max, snaps to `Increment`. Silent.

**Behaviour:** drag the knob or click anywhere on the bar. The fill and value label update live during drag.

---

### Dropdown

```lua
local dd = tab:CreateDropdown({
    Text     = "Fruit",
    Options  = { "Apple", "Banana", "Cherry" },
    Default  = "Apple",
    Callback = function(chosen)   -- chosen: string
    end,
})
```

**`GetValue()`** → `string` (selected option)

**`SetValue(str)`** — updates the label. Silent. No-op if `str` is not in the current options list.

**`SetOptions(tbl)`** — replaces the option list entirely at runtime. Clears and rebuilds all option buttons. Preserves `selected` if it still exists in the new list; otherwise falls back to `options[1]` or `"Select..."`. Collapses the dropdown. Silent (does not fire `Callback` or `OnChanged`).

```lua
-- Example: update options then select the first new one
dd.SetOptions({ "Sword", "Shield", "Bow" })
dd.SetValue("Shield")
```

---

### SearchDropdown

Identical to `Dropdown` but adds a live-filter text box above the option list.

```lua
local sdd = tab:CreateSearchDropdown({
    Text       = "Quest Type",
    Options    = { ... },
    Default    = "Any",
    MaxVisible = 6,       -- max rows to show before scrolling (default 6)
    Callback   = function(chosen) end,
})
```

| Extra option | Type | Default | Description |
|---|---|---|---|
| `MaxVisible` | number | `6` | Maximum visible rows; list becomes scrollable beyond this |

**`GetValue()`** → `string`

**`SetValue(str)`** — Silent. Must be in the options list.

> `SearchDropdown` does **not** have `SetOptions`. Use a standard `Dropdown` if you need runtime option replacement.

> The search box uses `ClearTextOnFocus = true` — it clears when the user clicks into it. This differs from `Input`, which preserves existing text on focus.

---

### MultiSelect

```lua
local ms = tab:CreateMultiSelect({
    Text     = "Rarities",
    Options  = { "Common", "Rare", "Epic", "Legendary" },
    Default  = { "Rare", "Epic" },    -- pre-selected array
    Callback = function(selected)      -- selected: string[]
    end,
})
```

**`GetValue()`** → `string[]` — array of selected options in original `Options` order.

**`SetValue(tbl)`** — replaces the entire selection. Syncs all checkboxes. Silent.

**`IsSelected(str)`** → `boolean` — returns `true` if the given option is currently selected.

```lua
if ms.IsSelected("Legendary") then
    -- ...
end
```

**Header text behaviour:**
- 0 selected → `"Rarities: None"`
- 1 selected → `"Rarities: Rare"`
- 2+ selected → `"Rarities: 3 selected"`

---

### Input

```lua
local input = tab:CreateInput({
    Text        = "Webhook URL",          -- label above the box
    Placeholder = "https://discord.com/...",
    Callback    = function(text)           -- fires on Enter
    end,
})
```

**`GetValue()`** → `string` (current text box content)

**`SetValue(str)`** — sets the text box content. Silent.

**Behaviour:** `Callback` (and `OnChanged`) fire only when the user presses **Enter** (`FocusLost` with `enterPressed = true`). Clicking away without pressing Enter does not fire anything. The box highlights on focus.

---

### NumberInput

```lua
local numInput = tab:CreateNumberInput({
    Text    = "Delay (ms)",
    Min     = 0,
    Max     = 5000,
    Step    = 50,       -- increment/decrement amount for + / − buttons
    Default = 200,
    Callback = function(val)   -- val: number
    end,
})
```

> **Note:** `NumberInput` uses `Step`, not `Increment` (that's `Slider`).

| Option | Type | Default | Description |
|---|---|---|---|
| `Min` | number | `-math.huge` | Minimum value |
| `Max` | number | `math.huge` | Maximum value |
| `Step` | number | `1` | Amount the `+` / `−` buttons change the value by |
| `Default` | number | `0` | Initial value, clamped to Min..Max |

**`GetValue()`** → `number`

**`SetValue(n)`** — snaps and clamps. Silent.

**Behaviour:** click `−` / `+` or type directly. On `FocusLost`, typed input is parsed; invalid text reverts to the last valid value. Values are always snapped to `Step` and clamped to `[Min, Max]`.

---

### Keybind

```lua
local keybind = tab:CreateKeybind({
    Text     = "Toggle GUI",
    Default  = Enum.KeyCode.RightShift,
    Callback = function(key)   -- key: Enum.KeyCode
    end,
})
```

**`GetValue()`** → `Enum.KeyCode`

**`SetValue(keyCode)`** — updates the button label. Silent.

**Behaviour:**
- Click the key button to enter listening mode — it shows `"..."` and turns primary colour
- Press any key while listening to bind it
- Click the button again while listening to **cancel** (reverts to the previous key)
- Clicking anywhere else on screen while listening also cancels
- `Enum.KeyCode.Unknown` displays as `"None"`
- Only keyboard keys are captured (`UserInputType.Keyboard`). Game-processed input (`processed = true`) is filtered out.

---

### ColorPicker

```lua
local picker = tab:CreateColorPicker({
    Text     = "Trail Color",
    Default  = Color3.fromRGB(88, 101, 242),
    Callback = function(color)   -- color: Color3
    end,
})
```

**`GetValue()`** → `Color3`

**`SetValue(color3)`** — updates the HSV state, preview swatch, cursors, and hex input. Silent.

**Behaviour:**
- Click the header to expand/collapse the picker panel
- The SV (saturation/value) pad is the square area; drag to set saturation and brightness
- The hue bar is the thin vertical strip on the right; drag to set hue
- The hex input at the bottom accepts 6-character hex codes (with or without `#`). Press Enter to apply

---

### Label

```lua
local lbl = tab:CreateLabel({ Text = "Status: idle" })
-- Legacy string form also works:
local lbl = tab:CreateLabel("Status: idle")
```

**`GetValue()`** → `string`

**`SetValue(str)`** — updates the label text AND **fires `OnChanged`**. This is intentional: `Label` has no user interaction, so `SetValue` is the only change mechanism.

**Extra API:**
```lua
lbl.SetText("New text")    -- identical to SetValue but does NOT fire OnChanged
```

---

### Section

```lua
tab:CreateSection({ Text = "Automation" })
-- Legacy string form also works:
tab:CreateSection("Automation")
```

Renders as a small uppercase label in `Primary` colour with a 1px border line beneath it. Used as a visual divider between groups of elements.

**Extra API:**
```lua
section.SetValue("NEW TITLE")    -- updates label (auto-uppercases)
section.SetText("NEW TITLE")     -- identical
section.GetValue()               -- returns current label text
```

---

### ProgressBar

```lua
local bar = tab:CreateProgressBar({
    Text    = "Loading",
    Default = 0,                           -- initial fill (0..1)
    Color   = Config.Theme.Success,        -- optional bar colour
})

-- Update from a game loop:
bar.SetValue(0.65)   -- 65% fill
```

**`GetValue()`** → `number` (0..1)

**`SetValue(n)`** — clamps to 0..1, animates the fill with `Utility.Tween`, updates the `%` label, and **fires `OnChanged`**. Unlike interactive elements, this fires intentionally since `SetValue` is the only change mechanism.

**Extra API:**
```lua
bar.SetLabel("Harvesting...")    -- update the text label above the bar
bar.SetColor(Color3.fromRGB(255, 200, 0))   -- change bar fill colour at runtime
```

---

### StatusLabel

```lua
local status = tab:CreateStatusLabel({
    Text = "Connected",
    Type = "Success",    -- "Info" | "Success" | "Warning" | "Error"
})
```

Renders as a small coloured dot followed by text. The dot and text colour both match the `Type`.

| Type | Colour |
|---|---|
| `Info` | `Primary` |
| `Success` | `Success` |
| `Warning` | `Warning` |
| `Error` | `Error` |

**`GetValue()`** → `string` (current text)

**`SetValue(text, type?)`** — updates text and optionally changes the type. **Fires `OnChanged`**.

```lua
status.SetValue("Disconnected", "Error")
status.SetValue("Reconnecting...")     -- keeps current type
```

**Extra API:**
```lua
status.SetText("New text")    -- updates text only, does NOT fire OnChanged
status.SetType("Warning")     -- change type colour without touching text
```

---

### Table

```lua
local tbl = tab:CreateTable({
    Columns    = { "Name", "Value", "Status" },
    Rows       = {
        { "Speed",    "50",  "Active"   },
        { "Gravity",  "196", "Inactive" },
    },
    MaxVisible = 6,    -- rows before the body scrolls (default 6)
})
```

The table has a fixed `Primary`-coloured header row and a scrollable body.

**Signals:**
```lua
tbl.OnRowClicked:Connect(function(rowIndex, rowData)
    print("Clicked row", rowIndex, rowData[1])
end)
```

**Methods:**

```lua
tbl.SetRows(newRows)              -- replace all rows at once. Clears colour overrides
tbl.AddRow(rowData)               -- append a row
tbl.RemoveRow(index)              -- remove by 1-based index. Only re-renders rows after the removed index
tbl.SetCell(rowIndex, colIndex, value)   -- update a single cell
tbl.SetRowColor(index, color)     -- tint a row's background colour
tbl.ClearRowColor(index)          -- restore a row to its default alternating colour
tbl.Clear()                       -- remove all rows
tbl.GetRows()                     -- returns a shallow copy of the rows array
```

**Alternating rows:** odd rows use `Background`, even rows use `Surface`.

**`SetRowColor` / `ClearRowColor`** correctly handle hover: each row stores its own base colour as an upvalue, so hovering a tinted row uses the tint as the restore colour rather than the default alternating colour.

---

### Row

New in v7. A horizontal layout container that places elements side by side in equal columns.

```lua
local row = tab:CreateRow({
    Columns = 2,    -- number of columns (default 2)
    Gap     = 6,    -- pixel gap between columns (default 6)
    Height  = 36,   -- row height in pixels (default 36)
})

row.Add(tab:CreateButton({ Text = "Enable" }))
row.Add(tab:CreateButton({ Text = "Disable" }))
```

**`row.Add(element)`** — reparents the element's frame into the row container and resizes it to fill one column slot. The element remains in `tab.Elements` and retains its full standard API.

**`row.Destroy()`** — calls `Destroy()` on all child elements, then destroys the row frame.

> ⚠ **Expandable elements inside rows clip** at the row height. Dropdown, SearchDropdown, MultiSelect, and ColorPicker expanded panels will be hidden. Use these in regular (non-row) positions.

---

### AccordionSection

New in v7. A collapsible group container. Child elements are added via the section's own `Create*` methods and live inside an animated expand/collapse panel.

```lua
local section = tab:CreateAccordionSection({
    Text        = "Movement Settings",   -- header label (auto-uppercased)
    DefaultOpen = true,                  -- initial state (default: true)
})

-- Add elements exactly like a normal tab
local speed = section:CreateSlider({ Text = "Walk Speed", Min = 0, Max = 100, Default = 16 })
local jump  = section:CreateToggle({ Text = "Infinite Jump", Default = false })
```

| Option | Type | Default | Description |
|---|---|---|---|
| `Text` | string | `"Section"` | Header label text. Rendered in uppercase |
| `DefaultOpen` | boolean | `true` | Whether the section starts expanded |

`section:Create*` supports all standard element factories:
`CreateButton`, `CreateToggle`, `CreateSlider`, `CreateDropdown`,
`CreateSearchDropdown`, `CreateMultiSelect`, `CreateInput`,
`CreateNumberInput`, `CreateKeybind`, `CreateColorPicker`,
`CreateLabel`, `CreateSection`, `CreateProgressBar`, `CreateStatusLabel`,
`CreateTable`, `CreateRow`.

**`GetValue()`** → `boolean` — `true` if currently expanded, `false` if collapsed.

**`SetValue(bool)`** — expands or collapses with animation. **Silent** — does not fire `OnChanged`.

**Extra API:**
```lua
section.Expand()     -- expand with animation. No-op if already open
section.Collapse()   -- collapse with animation. No-op if already closed
```

**Signals:**
```lua
section.OnChanged:Connect(function(isOpen)
    -- fires on every user-triggered toggle (header click)
    -- does NOT fire when SetValue, Expand, or Collapse are called
end)
```

**Height tracking:** the outer frame height is kept in sync with its children automatically via `InnerFrame:GetPropertyChangedSignal("AbsoluteSize")`. Elements added after creation will correctly expand the section while it is open — no manual resize is needed.

**Destroy cascade:** `section.Destroy()` calls `Destroy()` on all child elements before destroying its own frame. Child `ConnSet`s are shared with the parent tab's `_elementConnSets` array, so `Window:Destroy()` also cleans them up correctly.

> ⚠ **Known limitation:** `SetEnabled(false)` on an open `AccordionSection` will apply the disabled overlay but will **not** collapse the content panel. This is because `AccordionSection` manages its own expand/collapse logic rather than going through `Expandable.makeExpandable`, so its frame is not registered in the `Expandable` auto-collapse registry. The content remains visually expanded behind the overlay. A fix is tracked.

> ℹ **Nesting:** `CreateAccordionSection` is intentionally not exposed on the section proxy — accordion-inside-accordion nesting is not supported.

---

## 7. Notifications

### Shared (Aurora-level)

```lua
Aurora:Notify({
    Title    = "Done",
    Message  = "Operation complete.",
    Type     = "Success",    -- "Info" | "Success" | "Warning" | "Error"
    Duration = 4,            -- seconds until auto-dismiss (default 3)
})
```

### Per-window

```lua
win:Notify({
    Title   = "Shop",
    Message = "Purchased 3 seeds.",
    Type    = "Info",
})
```

Each window has its own notification layer. Two windows can never corrupt each other's toast stacks. `Aurora:Notify()` uses a shared singleton layer.

### Appearance

- 280×80px frame anchored to the bottom-right of the screen
- Coloured accent bar on the left edge matching the `Type`
- Progress bar along the bottom shrinks over `Duration` seconds
- Slides in from the right (Quart easing, 0.4s), slides out to the right (Quart, 0.35s)
- Multiple notifications stack upward with 8px gaps and reposition when one is dismissed
- The shared layer is lazily created and re-created automatically if its `ScreenGui` is ever destroyed

---

## 8. Themes & Config

### Default theme

```lua
Aurora.Config.Theme = {
    Primary    = Color3.fromRGB(88,  101, 242),   -- accent, active states, buttons
    Secondary  = Color3.fromRGB(30,  30,  35),    -- secondary surface
    Background = Color3.fromRGB(18,  18,  22),    -- main window background
    Surface    = Color3.fromRGB(25,  25,  30),    -- cards, tab bar, panels
    Text       = Color3.fromRGB(245, 245, 250),   -- primary text
    TextMuted  = Color3.fromRGB(150, 150, 160),   -- secondary/hint text
    Success    = Color3.fromRGB(46,  204, 113),   -- green status
    Warning    = Color3.fromRGB(241, 196,  15),   -- yellow status
    Error      = Color3.fromRGB(231,  76,  60),   -- red status
    Border     = Color3.fromRGB(55,   55,  68),   -- dividers, scroll bars
    Glow       = Color3.fromRGB(88,  101, 242),   -- shadow/glow tint
}
```

### Animation settings

```lua
Aurora.Config.Animation = {
    Duration  = 0.3,                      -- default tween duration (seconds)
    Easing    = Enum.EasingStyle.Quart,
    Direction = Enum.EasingDirection.Out,
}
```

### Font & geometry

```lua
Aurora.Config.Font             = Enum.Font.Gotham
Aurora.Config.FontBold         = Enum.Font.GothamBold
Aurora.Config.FontMedium       = Enum.Font.GothamMedium
Aurora.Config.CornerRadius     = UDim.new(0, 6)
Aurora.Config.ShadowTransparency = 0.7
```

### Changing the theme

```lua
Aurora:SetTheme({
    Primary = Color3.fromRGB(255, 80, 80),
})
```

> Only elements created **after** this call use the new values. Use `Aurora:SetTheme` before calling `CreateWindow` if you want the whole UI to use a custom palette.

---

## 9. Config System

The config system persists element values to JSON files using the executor's file API. It supports named profiles, last-profile memory across sessions, import/export, and an optional built-in UI panel.

### Creating a config

```lua
local cfg = Aurora:CreateConfig({
    Name     = "GardenShovel",   -- filename stem
    Folder   = "Aurora",         -- subfolder in executor workspace
    AutoSave = true,             -- save on every user interaction
    AutoLoad = true,             -- restore saved values on creation
})
```

| Option | Type | Default | Description |
|---|---|---|---|
| `Name` | string | `"Config"` | Filename stem. Profiles are stored as `Name.json`, `Name_pvp.json`, etc. |
| `Folder` | string | `"Aurora"` | Subfolder in executor workspace. Created automatically if missing |
| `Profile` | string | `"default"` | Starting profile name. Overridden by the last-profile sidecar if `AutoLoad` is true |
| `AutoSave` | boolean | `true` | Automatically save to disk on every `OnChanged` event from any linked element |
| `AutoLoad` | boolean | `true` | On creation, load the last-used profile's data and silently apply it to all linked elements |

### Linking elements

```lua
cfg:Link("GodMode",  godModeToggle)
   :Link("Speed",    speedSlider)
   :Link("Color",    colorPicker)
   :Link("Webhook",  webhookInput)
```

`Link` is chainable. Each call:
1. Snapshots the element's current value as its **reset default**
2. Silently applies the cached saved value (if `AutoLoad` loaded one) via `SetValue`
3. Wires the element's `OnChanged` signal to auto-save if `AutoSave` is on

**What to link:** any value the user would want to persist between sessions.

**What not to link:** running state toggles (e.g. "Auto Farm is currently ON"), or values that depend on live game data that should be freshly computed each session.

### File layout on disk

```
Aurora/
  GardenShovel.json                -- "default" profile
  GardenShovel_pvp.json            -- "pvp" profile
  GardenShovel_harvest.json        -- "harvest" profile
  GardenShovel_lastProfile.txt     -- contains "pvp" (persists across sessions)
```

### Config object API

```lua
-- Persistence
cfg:Save()              -- → self  write current values to disk
cfg:Load()              -- → bool  read from disk, apply silently. Returns true if file found
cfg:Reset()             -- → self  restore all elements to their Link-time defaults, clear save file

-- Serialisation
cfg:Export()            -- → string  serialise current values to a JSON string
cfg:Import(str)         -- → bool    apply values from a JSON string. Saves if AutoSave on

-- Profiles
cfg:SetProfile(name)    -- → self    switch to a named profile, load its data, persist choice
cfg:GetProfile()        -- → string  returns the active profile name
cfg:ListProfiles()      -- → string[] all discovered profile names (requires listfiles API)
cfg:RenameProfile(new)  -- → bool    rename active profile. Fails if name is taken or profile is "default"
cfg:DeleteProfile(name) -- → bool    delete profile file. Switches to "default" if active. Cannot delete "default"
cfg:NextProfileName()   -- → string  returns next available auto-name: "Profile 1", "Profile 2", …
cfg:HasStorage()        -- → bool    true if executor file API is available

-- Signals
cfg.OnSave             -- fires after each successful save
cfg.OnLoad             -- fires after each successful load
cfg.OnReset            -- fires after reset
cfg.OnProfileChanged   -- fires(profileName) whenever SetProfile is called
```

### `RenameProfile` rules

- Cannot rename the `"default"` profile
- Will fail (return `false`) if the target name is already used by another profile
- Copies the save file to the new name, deletes the old file, updates the active profile and sidecar atomically

### `DeleteProfile` rules

- Cannot delete `"default"`
- If the active profile is deleted, automatically switches to `"default"`
- Uses `deletefile` with a fallback to `delfile` (executor variation), then verifies the file is gone via `isfile`. Returns `true` only if the file was actually removed

### Built-in UI (`CreateControls`)

```lua
cfg:CreateControls(configTab)
```

Injects these elements into the given tab — no additional code needed:

- **Selected Profile** dropdown — click to switch. Auto-refreshes when profiles are added/deleted/renamed
- **Create New Profile** button — auto-names `"Profile 1"`, `"Profile 2"`, etc., seeds with current values, switches immediately
- **Rename Current Profile** input — type new name, press Enter. Protected: cannot rename `"default"`, cannot rename to a name that already exists
- **Delete Current Profile** button — protected: cannot delete `"default"`, notifies on success or failure
- **Export to Clipboard** / **Export (console)** button — copies JSON to clipboard if available, otherwise prints to console
- **Import Config** input — paste JSON and press Enter
- **Reset to Defaults** button — restores Link-time defaults

> The entire profile section is omitted if `HAS_FILE_API` is false (executor has no file API). Only the import/export/reset section is shown in that case, since those work without a filesystem.

### Executor API detection

The config system detects available executor APIs at load time:

| Flag | Checks for |
|---|---|
| `HAS_FILE_API` | `writefile` |
| `HAS_FOLDER_API` | `makefolder` |
| `HAS_LIST_FILES` | `listfiles` |
| `HAS_DELETE` | `deletefile` or `delfile` |
| `HAS_CLIPBOARD` | `setclipboard` |

All features gracefully degrade. If `HAS_LIST_FILES` is false, the profile dropdown will only show the active profile rather than all discovered ones.

### Full integration example

```lua
local Window    = Aurora:CreateWindow({ Title = "Garden Shovel" })
local ShovelTab = Window:CreateTab({ Name = "Shovel" })
local ConfigTab = Window:CreateTab({ Name = "Config" })

local cfg = Aurora:CreateConfig({
    Name     = "GardenShovel",
    Folder   = "Aurora",
    AutoSave = true,
    AutoLoad = true,
})

-- ...create your elements...

-- Link everything (call after elements are created)
cfg:Link("Shovel_FruitTypes",   fruitMultiSelect)
   :Link("Shovel_MaxWeight",    maxWeightInput)
   :Link("Settings_Webhook",    webhookInput)

-- Add built-in config UI
cfg:CreateControls(ConfigTab)

-- React to profile switches in your own code if needed
cfg.OnProfileChanged:Connect(function(profileName)
    print("Switched to profile:", profileName)
end)
```

---

## 10. Signals

Aurora uses a lightweight built-in `Signal` class. All `OnChanged`, `OnRowClicked`, window/tab signals, and config signals use this system.

### API

```lua
local s = Signal.new()

-- Connect a persistent handler
local conn = s:Connect(function(...)
    print(...)
end)
conn.Disconnect()   -- unsubscribe

-- Connect a one-shot handler (auto-disconnects after first fire)
local conn = s:Once(function(...)
    print("fired once")
end)
conn.Disconnect()   -- can also cancel before it fires

-- Fire the signal
s:Fire(value1, value2, ...)
```

### Error handling

Signal callbacks are called via `pcall`. A runtime error inside a callback prints a warning (`[Aurora Signal] Callback error: ...`) but does **not** break other handlers or the calling code.

### Signal ordering

Handlers fire in **insertion order** (by connection ID). There is no priority system.

---

## 11. ConnSet

`ConnSet` is the connection ownership system used throughout Aurora for clean teardown. Each element gets its own `ConnSet`; each window has one for window-level connections.

```lua
local cs = ConnSet.new()

-- Track a connection (returns the connection for inline use)
cs:Add(UserInputService.InputChanged:Connect(fn))

-- Disconnect and stop tracking one connection
cs:Remove(someConn)

-- Disconnect every tracked connection at once
cs:DisconnectAll()
```

`ConnSet` uses a hash-keyed set internally — `Add`, `Remove`, and `DisconnectAll` are all O(1) regardless of set size.

> You generally don't need to use `ConnSet` directly. It's used internally by `Tab:RegisterElement` for each element, and by the Window for its drag and reflow connections. The element's `_conns` field exposes it if you need to add your own cleanup logic.

---

## 12. Architecture & Internals

### Module dependency order

```
Signal → Config → ConnSet → Utility → Expandable
→ Button, Toggle, Slider, Dropdown, SearchDropdown,
  MultiSelect, Input, NumberInput, Keybind, ColorPicker,
  Label, Section, ProgressBar, StatusLabel, Table, Row,
  AccordionSection
→ Tab → Notification → Window → ConfigSystem → Aurora (init)
```

Each module is wrapped in an IIFE: `local Name = (function() ... end)()`. Modules earlier in this chain are available as upvalues to modules that come after — no explicit dependency injection.

### Tab prototype

All 17 `Create*` methods are assigned to `Tab.__index` once. Creating 100 tabs allocates the same number of closures as creating 1 tab.

### Expandable base (`Expandable.lua`)

`Dropdown`, `SearchDropdown`, `MultiSelect`, and `ColorPicker` all use `Expandable.makeExpandable(frame, collapsedH, getExpandedH, arrowLabel?)` rather than each implementing their own expand/collapse logic. This provides:

- A single `_registry` (weak-keyed) mapping frames to their `collapse()` function
- `tryCollapse(frame)` — called by `SetEnabled(false)` to auto-collapse any expandable element
- Tween cancellation: `Utility.Tween` is used for all expand/collapse animations, and competing tweens on the same instance are cancelled automatically

> `AccordionSection` manages its own expand/collapse logic independently and is **not** registered in `_registry`. See the known limitation note in its [element entry](#accordionsection).

### Tween cancellation

`Utility.Tween(inst, props, duration, ...)` maintains an `_activeTweens[inst]` registry. Before starting a new tween, any in-flight tween on the same instance is cancelled. This prevents competing-tween pile-up on elements driven rapidly (e.g. a `ProgressBar` updated every frame).

### Forward reference pattern

Expandable elements have a local `exp` declared before their option buttons are created, then assigned after. This is required because Lua closures capture upvalue **slots** at closure creation time. If `exp` were declared after the closures that reference `exp.toggle()` / `exp.collapse()`, those closures would capture `nil`.

```lua
local exp    -- declared here: slot is valid
-- ... create buttons that reference exp.toggle(), exp.collapse() ...
exp = Expandable.makeExpandable(...)   -- assigned after: closures now resolve correctly
```

### SetValue silent contract (detailed)

Every interactive element has two internal paths:

- **User path** (`applyFromInput`, `applyUI(false)`, etc.): fires `Callback` and `OnChanged`
- **Silent path** (`SetValue` → `applyUI(true)` etc.): updates only the UI, never fires callbacks

This design means `ConfigSystem:Load()` can call `element.SetValue(savedValue)` on every linked element without triggering a cascade of `OnChanged` → `AutoSave` → `Save()` calls.

### AccordionSection proxy pattern

`AccordionSection` uses a proxy table to redirect child `Create*` calls to `InnerFrame` rather than the parent tab's `ScrollingFrame`. The proxy shares `_elementConnSets` with the parent tab so that `Window:Destroy()` cleans up child element connections without any additional wiring. The proxy's `_emptyLabel` is a dummy table so `RegisterElement` does not accidentally show or hide the parent tab's empty-state label.

---

## 13. Advanced: Custom Elements

`Tab:BaseFrame` and `Tab:RegisterElement` are the two internal methods that all 17 built-in elements use. You can use them directly to integrate a completely custom element into Aurora.

### `Tab:BaseFrame(height)`

Creates a standard-sized `Frame` parented to the tab's `ScrollingFrame` with the correct background colour and rounded corners. Returns the frame.

```lua
local frame = tab:BaseFrame(36)   -- 36px tall, parented to tab content
```

### `Tab:RegisterElement(element, frame, elementConns?)`

Registers any table as an Aurora element. Injects the standard API (`Destroy`, `SetVisible`, `SetEnabled`) and adds the element to `tab.Elements`. Fires `tab.OnElementAdded`.

| Argument | Type | Description |
|---|---|---|
| `element` | table | Your element table. Can have any fields; `GetValue`, `SetValue`, `OnChanged` are conventional |
| `frame` | Instance | The root frame. `SetVisible`, `SetEnabled`, and `Destroy` all operate on this |
| `elementConns` | ConnSet? | Optional `ConnSet` for UserInputService connections. Gets disconnected on `Destroy()` and on `Window:Destroy()`. If omitted, a new empty `ConnSet` is created |

Returns the `element` table with the injected standard API fields added to it.

```lua
-- Minimal custom element example
return function(self, cfg)
    cfg = cfg or {}
    local value = cfg.Default or ""
    local OnChanged = Signal.new()

    local frame = self:BaseFrame(36)

    -- ... build your Roblox instances inside frame ...

    local elementConns = ConnSet.new()
    elementConns:Add(UserInputService.InputBegan:Connect(function(inp)
        -- your UIS logic
    end))

    return self:RegisterElement({
        OnChanged = OnChanged,
        GetValue  = function() return value end,
        SetValue  = function(v)
            value = v
            -- update UI silently
        end,
    }, frame, elementConns)
end
```

Then assign it to the Tab prototype in `src/Tab.lua`:
```lua
Tab.CreateMyElement = _MyElement
```

And add it to `build_manifest.json` in the modules array before running `python3 build.py`.

---

## 14. Building from Source

The source lives in `src/` as 27 separate `.lua` files. `build.py` wraps each in an IIFE and concatenates them in topological dependency order.

```bash
# Standard build → Aurora.lua
python3 build.py

# Custom output path
python3 build.py --out dist/Aurora.lua

# Strip comments and blank lines
python3 build.py --minify
```

### Source file tree

```
src/
  Signal.lua
  Config.lua
  ConnSet.lua
  Utility.lua
  Expandable.lua
  Tab.lua
  Notification.lua
  Window.lua
  ConfigSystem.lua
  init.lua
  elements/
    Button.lua
    Toggle.lua
    Slider.lua
    Dropdown.lua
    SearchDropdown.lua
    MultiSelect.lua
    Input.lua
    NumberInput.lua
    Keybind.lua
    ColorPicker.lua
    Label.lua
    Section.lua
    ProgressBar.lua
    StatusLabel.lua
    Table.lua
    Row.lua
    AccordionSection.lua
```

---

## 15. Suggested Improvements

### Library

| Idea | Notes |
|---|---|
| **Theme hot-reload** | `SetTheme` currently only affects future elements. A `RefreshTheme()` that patches all live instances would make runtime theme switching fully work |
| **Tab icons rendered** | The `Icon` field in `CreateTab` is stored but the `ImageLabel` uses it as an asset ID — confirm correct asset IDs are being passed |
| **Searchable MultiSelect** | Same live-filter as `SearchDropdown` but with checkboxes |
| **Toast queue cap** | Cap visible notifications at N (e.g. 4); queue the rest and show them as earlier ones dismiss |
| **Element groups** | `Group:SetEnabled(false)` / `Group:SetVisible(false)` collapses a set of elements together — useful for hiding advanced options behind a toggle |
| **Slider + text input hybrid** | Drag OR type a value; both sides stay in sync |
| **Window resize handle** | Drag the bottom-right corner to resize freely |
| **`onDestroy` callback** | `window.OnDestroy` signal for consuming scripts to clean up their own state |
| **AccordionSection `SetEnabled` collapse** | `SetEnabled(false)` on an open section should collapse it. Fix: register the `OuterFrame` in `Expandable._registry` or call `makeExpandable` and wire it to the existing `applySize` logic |
| **Nested accordions** | Currently blocked intentionally. Could be supported by exposing `CreateAccordionSection` on the proxy if demand arises |

### Config System

| Idea | Notes |
|---|---|
| **Profile duplication** | "Duplicate Current Profile" — clones the active profile's file to a new name |
| **Profile descriptions** | Store a short note string alongside each profile; show it as a subtitle in the dropdown |
| **Config versioning** | Embed a `_version` key in the JSON so `Import` can warn when loading from an incompatible schema after a script update |
| **`listfiles` fallback** | If `listfiles` is unavailable, probe for known filenames using `isfile` so the dropdown still discovers all profiles on rejoin |
| **Per-key defaults** | Allow `Link("key", el, customDefault)` to override the snapshot default independently of the element's current value at link time |
