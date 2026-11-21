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
- Interactive widgets participate in Tab-based keyboard/gamepad selection; selecting a widget activates its owning window
- Compact widget rows with right-side labels, square frames, minimal rounding, active-window title styling, and visible slider grabs
- ID stack: PushID, PopID, GetID
- Text, buttons, checkboxes, radio buttons, progress bars, float/integer sliders, text inputs
- Separators, spacing, a configurable ImGui-style palette/layout, built-in demo
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
| RadioButton(label, active, callback?, id?) | Render a radio button; callback runs when clicked |
| ProgressBar(fraction, size?, overlay?, id?) | Render a normalized progress bar |
| SliderFloat / SliderInt | Render numeric sliders |
| InputText(label, value, callback, config?) | Render a text input |
| Separator(text?) / Spacing() | Layout helpers |
| PushID(id) / PopID() | Scope widget IDs |
| ShowDemoWindow() | Render the built-in demo |
| Destroy() | Disconnect and destroy the context |

## Development roadmap

1. Core interaction and lifecycle: frame lifecycle guards, stable widget identity across windows/children, click-to-focus and click-to-front, title hover states, Tab selection, nested scopes, and context cleanup. Initial interaction smoke test: \`examples/Milestone01InteractionTest.client.lua\`.
2. Widget coverage: radio buttons, combos, selectables, progress bars, color editing, trees, tabs, tables, menus, popups, modal dialogs.
3. Layout: groups, columns, table sizing, advanced clipping, item widths, and layout rules.
4. Interaction: keyboard navigation, focus, shortcuts, gamepad navigation, drag-and-drop.
5. Drawing: draw lists, primitives, clipping, gradients, images and custom callbacks.
6. Window systems: resizing, collapsing, docking and multi-window management where Roblox permits.
7. Tooling: demo browser, style editor, tests, API docs and examples.

## Upstream reference

The visual and API direction is informed by [Dear ImGui](https://github.com/ocornut/imgui). Dear ImGui is MIT-licensed. This repository is an independent Roblox implementation and does not include its C++ source code.

## License

MIT. See [LICENSE](LICENSE).
