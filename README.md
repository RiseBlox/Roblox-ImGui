# Roblox-ImGui

A modern, Roblox-native immediate-mode GUI library inspired by Dear ImGui.

**Status:** early foundation, version 0.1.0. This is an independent Luau implementation. It is not a C++ port, does not embed Dear ImGui source, and is not an official Dear ImGui project.

## Goals

- Bring Dear ImGui's immediate-mode workflow and visual language to Roblox.
- Use native Roblox GUI instances and client-side Luau.
- Support both Roblox Studio LocalScripts and client executor environments through the same shared core; avoid hard dependencies on executor-only APIs.
- Track the current Dear ImGui feature set while respecting Roblox platform constraints.
- Provide stable IDs, style customization, reusable widgets, examples, and documentation.
- Keep the legacy [Depthso-Roblox-ImGui](https://github.com/RiseBlox/Depthso-Roblox-ImGui) repository untouched.

## Current foundation

- Context creation and teardown: ImGui.new and Destroy
- Frame lifecycle: NewFrame, Begin, End, Render
- Draggable windows, vertically scrollable window content, independently scrollable child regions, and a Dear ImGui-inspired dark theme with blue accents
- Compact widget rows with right-side labels, square frames, minimal rounding, active-window title styling, and visible slider grabs
- ID stack: PushID, PopID, GetID
- Text, buttons, checkboxes, radio buttons, progress bars, float/integer sliders, text inputs
- Separators, spacing, a configurable ImGui-style palette/layout, built-in demo
- Retained Roblox instances keyed by widget ID

This is an initial foundation, not feature parity. The core lifecycle is being hardened before the larger widget set is added.

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
| Checkbox(label, value, callback, id?) | Render a checkbox |\n| RadioButton(label, active, callback?, id?) | Render a radio button; callback runs when clicked |\n| ProgressBar(fraction, size?, overlay?, id?) | Render a normalized progress bar |
| SliderFloat / SliderInt | Render numeric sliders |
| InputText(label, value, callback, config?) | Render a text input |
| Separator(text?) / Spacing() | Layout helpers |
| PushID(id) / PopID() | Scope widget IDs |
| ShowDemoWindow() | Render the built-in demo |
| Destroy() | Disconnect and destroy the context |

## Development roadmap

1. Core correctness: frame lifecycle guards, stable widget identity across windows/children, lifecycle cleanup, input connection ownership, nested scopes, and Studio/executor smoke tests.
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
