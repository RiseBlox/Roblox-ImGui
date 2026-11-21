# Roblox-ImGui

A modern, Roblox-native immediate-mode GUI library inspired by Dear ImGui.

**Status:** early foundation, version 0.1.0. This is an independent Luau implementation. It is not a C++ port, does not embed Dear ImGui source, and is not an official Dear ImGui project.

## Goals

- Bring Dear ImGui's immediate-mode workflow and visual language to Roblox.
- Use native Roblox GUI instances and client-side Luau.
- Track the current Dear ImGui feature set while respecting Roblox platform constraints.
- Provide stable IDs, style customization, reusable widgets, examples, and documentation.
- Keep the legacy [Depthso-Roblox-ImGui](https://github.com/RiseBlox/Depthso-Roblox-ImGui) repository untouched.

## Current foundation

- Context creation and teardown: ImGui.new and Destroy
- Frame lifecycle: NewFrame, Begin, End, Render
- Draggable windows and child regions
- ID stack: PushID, PopID, GetID
- Text, buttons, checkboxes, float/integer sliders, text inputs
- Separators, spacing, basic style palette, built-in demo
- Retained Roblox instances keyed by widget ID

This is an initial foundation, not feature parity. Docking, tables, menus, popups, navigation, draw lists, font atlas management, and a complete style editor remain planned work.

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
| ImGui.new(config) | Create a GUI context |
| NewFrame() / Render() | Start and finish a frame |
| Begin(name, flags) / End() | Begin/end a window |
| BeginChild(id, size) / EndChild() | Begin/end a child region |
| Text(text, config?) | Render text |
| Button(label, config?) | Render a button |
| Checkbox(label, value, callback, id?) | Render a checkbox |
| SliderFloat / SliderInt | Render numeric sliders |
| InputText(label, value, callback, config?) | Render a text input |
| Separator(text?) / Spacing() | Layout helpers |
| PushID(id) / PopID() | Scope widget IDs |
| ShowDemoWindow() | Render the built-in demo |
| Destroy() | Disconnect and destroy the context |

## Development roadmap

1. Core correctness: stable widget state, lifecycle cleanup, input connection ownership, nested scopes.
2. Widget coverage: radio buttons, combos, selectables, progress bars, color editing, trees, tabs, tables, menus, popups, modal dialogs.
3. Layout: groups, columns, table sizing, clipping, scrolling and layout rules.
4. Interaction: keyboard navigation, focus, shortcuts, gamepad navigation, drag-and-drop.
5. Drawing: draw lists, primitives, clipping, gradients, images and custom callbacks.
6. Window systems: resizing, collapsing, docking and multi-window management where Roblox permits.
7. Tooling: demo browser, style editor, tests, API docs and examples.

## Upstream reference

The visual and API direction is informed by [Dear ImGui](https://github.com/ocornut/imgui). Dear ImGui is MIT-licensed. This repository is an independent Roblox implementation and does not include its C++ source code.

## License

MIT. See [LICENSE](LICENSE).
