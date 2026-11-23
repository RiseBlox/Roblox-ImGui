# Roblox-ImGui

A Roblox-native GUI library inspired by Dear ImGui, with an immediate-mode-style submission API and retained Roblox GUI instances.

**Status:** early foundation, version 0.1.0. This is an independent Luau implementation. It is not a C++ port, does not embed Dear ImGui source, and is not an official Dear ImGui project.

## Goals

- Bring Dear ImGui's API conventions, interaction model, layout rules, and visual language to Roblox.
- Use native Roblox GUI instances and client-side Luau.
- Support both Roblox Studio LocalScripts and client executor environments through the same shared core; avoid hard dependencies on executor-only APIs.
- Track the current Dear ImGui feature set while respecting Roblox platform constraints.
- Provide stable IDs, style customization, reusable widgets, examples, and documentation.
- Keep the legacy [Depthso-Roblox-ImGui](https://github.com/RiseBlox/Depthso-Roblox-ImGui) repository untouched.

## Current foundation

- Context creation and teardown: ImGui.new and Destroy
- Frame lifecycle: NewFrame, Begin, End, Render
- Draggable windows with click-to-focus and click-to-front behavior, vertically scrollable window content, independently scrollable child regions, and a Dear ImGui-inspired dark theme with blue accents
- Compact widget rows with right-side labels, square frames, minimal rounding, active-window title styling, and visible slider grabs
- ID stack: PushID, PopID, GetID
- Text, buttons, checkboxes, radio buttons, selectables, combo boxes, collapsing headers, tree nodes, bullet text, images, progress bars, float/integer sliders, drag controls, numeric inputs, text inputs, and HSV color edit/picker controls
- Separators, spacing, same-line rows, explicit new lines, dummy spacers, indentation scopes, groups, legacy multi-column layouts, a configurable ImGui-style palette/layout, built-in demo
- Retained Roblox instances keyed by widget ID; widgets are resubmitted each frame and their GUI instances are reused

This is an initial foundation, not feature parity. The API follows an immediate-mode-style frame submission pattern, while rendering currently uses retained Roblox GUI instances.

## Runtime compatibility

The library targets client-side execution in both environments:

- **Roblox Studio:** require the module from a `LocalScript`; by default, the context attaches to `LocalPlayer.PlayerGui`.
- **Client executors:** the shared core uses standard Roblox client services and GUI APIs. Pass a valid client-side GUI parent with `ImGui.new({ Parent = ... })` when the default `PlayerGui` lookup is not appropriate.
- **Shared-core rule:** executor-specific globals and APIs must remain optional and isolated in a future compatibility adapter. The core must not require a particular executor.

This is an architectural target, not a claim of verified compatibility across every executor. Studio and executor behavior must be tested independently; differences in sandbox permissions, GUI parenting, input routing, and available APIs may affect support. The project does not provide anti-cheat bypasses, stealth, or executor-specific exploit functionality.

## Quick start

Place src/ImGui.lua in ReplicatedStorage and require it from a LocalScript:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ImGui = require(ReplicatedStorage:WaitForChild("ImGui"))

local ui = ImGui.new({ DisplayOrder = 50 })

RunService.RenderStepped:Connect(function()
    ui:NewFrame()
    if ui:Begin("Example", { Size = UDim2.fromOffset(420, 300) }) then
        ui:Text("Hello from Roblox-ImGui")
        ui:Button("Click me", { Callback = function() print("Clicked") end })
        ui:Checkbox("Enabled", false, function(value) print(value) end, "enabled")
    end
    ui:End()
    ui:Render()
end)

-- Call ui:Destroy() when the UI is no longer needed.
```

## Visual parity smoke test

Run [`examples/VisualParityTest.client.lua`](examples/VisualParityTest.client.lua) as a client LocalScript after placing the module in `ReplicatedStorage`. It exercises two draggable windows, buttons, checkboxes, radio buttons, sliders, text input, progress bars, child scrolling, and window scrolling. Set initial window positions only once; reapplying a fixed position every frame prevents dragging.

## API snapshot

| Method | Purpose |
| --- | --- |
| ImGui.new(config) | Create a GUI context; `config.Style` overrides style values |
| NewFrame() / Render() | Start and finish a frame |
| Begin(name, flags) / End() | Begin/end a window |
| BeginChild(id, size) / EndChild() | Begin/end a child region |
| Text(text, config?) | Render text |
| Style fields | WindowPadding, FramePadding, ItemSpacing, ItemInnerSpacing, WindowRounding, ChildRounding, FrameRounding, BorderSize, FrameBorderSize, ScrollbarSize, GrabMinSize, TitleBarHeight, colors, and font settings |
| Button(label, config?) | Render a button |
| Checkbox(label, value, callback, id?) | Render a checkbox |
| Selectable(label, selected, callback?, id?) | Render a selectable row; callback receives the next selected state |
| Combo(label, selected, items, callback?, id?) | Render a dropdown; selected is a 1-based index or item string; callback receives index and item |
| CollapsingHeader(label, id?) | Toggle a section; conditionally submit its contents when true |
| TreeNode(label, id?) / TreePop() | Toggle a tree node; conditionally submit its contents when true |
| BulletText(text, level?) | Render a nested bullet row; level 1 = filled circle, 2 = hollow circle, 3 = square (deeper levels repeat the marker pattern) |
| Image(image, size?, config?) | Render a Roblox image asset/content ID |
| RadioButton(label, active, callback?, id?) | Render a radio button; callback runs when clicked |
| ProgressBar(fraction, size?, overlay?, id?) | Render a normalized progress bar |
| SliderFloat / SliderInt | Render numeric sliders |
| SetNextItemWidth(width) | Set the width of the next width-aware control; negative values leave space at the right edge |
| PushItemWidth(width) / PopItemWidth() | Apply and restore a width for subsequent controls; negative values are right-edge-relative |
| CalcItemWidth() | Calculate the effective width from the next-item setting, width stack, or default |\n| DragFloat / DragInt | Adjust values by horizontal dragging; accepts speed, optional minimum/maximum, callback, and ID |\n| InputFloat / InputInt | Edit numeric values in a text field; commits on focus loss; config supports ID, Min, Max, Decimals, and Placeholder |\n| ColorEdit(label, color, callback?, id?) | Show a clickable color swatch that expands into HSV controls; callback receives a Color3 |\n| ColorPicker(label, color, callback?, id?) | Show a live color swatch and always-visible HSV controls; callback receives a Color3 |
| InputText(label, value, callback, config?) | Render a text input |
| Separator(text?) / Spacing(amount?) | Separator and vertical spacing helpers; amount is pixel height |
| SameLine() / NewLine() | Place the next item beside the previous item, or resume vertical flow |\n| Columns(count, id?, border?) / NextColumn() / EndColumns() | Begin a legacy multi-column layout, advance/wrap between columns, and close it |\n| GetColumnIndex() / GetColumnWidth(index?) / SetColumnWidth(index, width) | Query the zero-based active column and read/set column widths in pixels |
| Dummy(size) | Add an invisible layout item with a UDim2 size |
| Indent(width?) / Unindent() | Open/close an indented vertical layout scope; default width is 14 pixels |
| BeginGroup() / EndGroup() | Open/close a grouped vertical layout scope |
| PushID(id) / PopID() | Scope widget IDs |
| ShowDemoWindow() | Render the built-in demo |
| Destroy() | Disconnect and destroy the context |

## Development roadmap

1. Core interaction and lifecycle: frame lifecycle guards, stable widget identity across windows/children, click-to-focus and click-to-front, title hover states, nested scopes, and context cleanup. Initial interaction smoke test: \`examples/Milestone01InteractionTest.client.lua\`.
2. Widget coverage: core controls, Part A selection/tree/display widgets, Part B numeric controls, and Part C color controls; tabs, tables, menus, popups, and modal dialogs remain future widget work.
3. Layout: Part A basic primitives (SameLine, NewLine, Spacing, Dummy, Indent/Unindent, BeginGroup/EndGroup); Part B item widths and alignment (`examples/Milestone03PartB.client.lua`); Part C legacy columns (`examples/Milestone03PartC.client.lua`); Part D tables and advanced layout.
4. Interaction: keyboard navigation, focus, shortcuts, gamepad navigation, drag-and-drop.
5. Drawing: draw lists, primitives, clipping, gradients, images and custom callbacks.
6. Window systems: resizing, collapsing, docking and multi-window management where Roblox permits.
7. Tooling: demo browser, style editor, tests, API docs and examples.

## Upstream reference

The visual and API direction is informed by [Dear ImGui](https://github.com/ocornut/imgui). Dear ImGui is MIT-licensed. This repository is an independent Roblox implementation and does not include its C++ source code.

## License

MIT. See [LICENSE](LICENSE).


### Text, slider, and separator layout

- `Text()` wraps to the available content width by default; pass `{ Wrap = false }` to opt out.
- `SliderFloat()` / `SliderInt()` use a visible accent fill and grab to communicate the current value.
- Bounded `DragFloat()` / `DragInt()` controls show an accent fill proportional to their current value; integer drags display whole numbers.
- `Separator(text)` uses a transparent label over the window content, with separator lines ending around the measured text width.


### Slider interaction and text alignment

- Slider tracks resolve focus against their owning window before accepting pointer input; this enables both float and integer slider callbacks.
- Slider fill and grab positions update directly from the pointer's horizontal position while dragging.
- `Text()` uses custom dynamic justified wrapping by measuring words and distributing spacing across wrapped lines; Roblox does not provide a `Justify` enum value. Set `Align = Enum.TextXAlignment.Left`, `Center`, or `Right` to use native alignment instead. Rich-text labels retain Roblox native wrapping.


### Button and slider interaction feedback

- Buttons use a dark idle color, the brightest blue on hover, and a lighter mid-tone while pressed. The pressed color remains active while the pointer is held down; moving off the button cancels the pressed visual state.
- Float and integer sliders highlight the track on hover and use a brighter, slightly larger grab while hovered or actively dragged. Their active track state is distinct from the idle and hover states.
- These visual states use the configurable `Button`, `ButtonHovered`, `ButtonActive`, `FrameBg`, `FrameBgHovered`, `FrameBgActive`, and `SliderGrab` style colors.


### Item widths and alignment (M03 Part B)

- `SetNextItemWidth(width)` applies to the next width-aware control only.
- `PushItemWidth(width)` / `PopItemWidth()` scope a width across multiple controls. The width stack must be balanced before `Render()`.
- `CalcItemWidth()` reports the effective width without consuming a pending next-item width.
- Positive widths are pixel widths. Negative widths are relative to the available content width: for example, `-100` leaves a 100-pixel right margin.
- Width-aware controls include sliders, drag controls, numeric inputs, and text inputs. Buttons and ordinary text retain their natural/default layout.
- Sliders use an unfilled track with one movable grab block; they do not render a progress-fill segment.
- Widths are clamped to the current available content width, accounting for the active window/child/indent content padding.


### Columns (M03 Part C)

- `Columns(count, id?, border?)` begins a legacy Dear ImGui-style multi-column region. The count must be between 1 and 64; nested column regions are not supported.
- `NextColumn()` advances to the next zero-based column and wraps to column 0 after the last column. Each column has its own vertical item flow.
- `GetColumnIndex()` returns the current zero-based column index. `GetColumnWidth(index?)` returns a column width in pixels; omit the index or pass `-1` for the current column.
- `SetColumnWidth(index, width)` sets a persistent pixel width for a column; pass `-1` for the current column. Remaining flexible columns share the available width.
- `EndColumns()` closes the region and resumes the parent layout. Column scopes must be closed before `Render()`.
- Column widths adapt to the available parent width. Set widths consistently each frame when a fixed layout is desired.
- This is the legacy Columns API; the more capable table API is planned for M03 Part D.
