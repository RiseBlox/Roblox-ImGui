# Roblox-ImGui

**A Luau port of Dear ImGui with a Roblox platform and renderer backend.**

The active implementation on `main` is based on the source-level port in [4DBug/imgui-luau](https://github.com/4DBug/imgui-luau), not the discontinued Roblox-native recreation preserved on [`prototype/legacy-recreation`](https://github.com/RiseBlox/Roblox-ImGui/tree/prototype/legacy-recreation).

## Port baseline

| Item | Baseline |
| --- | --- |
| Dear ImGui source | Docking branch, **1.93.0 WIP** |
| Luau port source | [4DBug/imgui-luau](https://github.com/4DBug/imgui-luau), snapshot `6e9790bf2a00a8b829d36a499bf83d8358221bec` |
| Upstream package version | `0.4.4` |
| Platform backend | Roblox |
| Rendering | Dear ImGui draw data rasterized into tiled `EditableImage` textures |

See [UPSTREAM.md](UPSTREAM.md) for provenance and [docs/PORTING.md](docs/PORTING.md) for the source-port conventions. The exact upstream C++ comparison inputs are kept under `tools/test/upstream/`.

## Status and scope

This is a substantial source-level port, but it should **not** be described as a perfectly complete or byte-for-byte translation. The imported port's generated comparison report records:

- 99.7% of upstream function definitions matched by name (1,811 functions compared).
- 100% of the listed public API function names and enum values in that report.
- 70.7% estimated upstream code reproduced by the report's weighted similarity metric.
- A small set of unported or partially ported functions and platform omissions.

These are the upstream port author's static comparison estimates, not an independent certification. Read [docs/PORT_STATUS.txt](docs/PORT_STATUS.txt) and [docs/TODO.txt](docs/TODO.txt) before assuming a feature is fully compatible.

The Roblox backend requires **Allow Mesh / Image APIs** (EditableImage) to be enabled in the experience's security settings. It uses software rasterization and uploads changed image tiles; large, frequently changing UIs can be CPU-intensive. This project currently targets the Roblox client. Compatibility with third-party script executors is not guaranteed and must be tested separately.

Known platform limitations include no multi-viewport windows, no native gamepad navigation, and limited text input/IME support. See the TODO and backend documentation for details.

## Build

Requirements:

- Python 3
- [Luau CLI](https://github.com/luau-lang/luau) for the headless tests
- [Rojo](https://rojo.space) for syncing the example into Studio (optional)

From the repository root:

```sh
python3 tools/bundle.py
```

This generates:

- `build/ImGui.luau` — the bundled implementation ModuleScript
- `build/ImGuiTyped.luau` — typed public entry module
- `build/ImGuiWorker.client.luau` — parallel raster worker LocalScript
- `build/ImGui.linemap.json` — source line mapping for bundle errors

The generated build files are not required to edit the source modules. Rebuild after changing library or Roblox backend sources.

## Roblox Studio setup

1. Enable **Allow Mesh / Image APIs** for the experience.
2. Run `python3 tools/bundle.py`.
3. Sync the project with `rojo serve` or `rojo build default.project.json`.
4. Run the example LocalScript under `StarterPlayerScripts`.

The project tree places the typed module at `ReplicatedStorage.ImGui`, with the implementation and worker as child ModuleScripts/LocalScripts.

## Minimal example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui = G.ImGui
local Backend = G.ImGui_ImplRoblox

ImGui.CreateContext()
Backend.Init() -- defaults to LocalPlayer.PlayerGui

RunService.Stepped:Connect(function()
    Backend.NewFrame()
    ImGui.NewFrame()

    if ImGui.Begin("Hello, Roblox") then
        ImGui.Text("Dear ImGui is running through the Roblox backend.")

        if ImGui.Button("Click me") then
            print("Button pressed")
        end
    end
    ImGui.End()

    ImGui.EndFrame()
    ImGui.Render()
    Backend.RenderDrawData(ImGui.GetDrawData())
end)
```

## Tests

The bundled test harness runs the library against a mocked Roblox environment using Luau CLI:

```sh
python3 tools/test/run.py
python3 tools/test/run.py --open
python3 tools/test/run.py --main tools/test/scripts/t_tables.luau --frames 150
python3 tools/test/missing.py
```

The test scripts cover draw-data stability, input, windows, docking, tables, widgets, fonts, rendering, and backend behavior. A local test run is still required on changes; repository import alone is not evidence that the code runs in your particular Studio/client environment.

## Source layout

- Root `imgui*.lua` and `imstb_*.lua`: Dear ImGui core port and support code.
- `backends/roblox/`: Roblox input/platform integration, EditableImage rendering, rasterizer, tiles, and optional parallel worker.
- `fonts/`: embedded font data for Roblox's virtual file layer.
- `examples/example_roblox/`: Roblox LocalScript demo.
- `tools/bundle.py`: builds the ModuleScript layout.
- `tools/test/`: headless tests and upstream comparison fixtures.
- `docs/`: porting rules, generated comparison report, and known gaps.

## References

- [Dear ImGui](https://github.com/ocornut/imgui) — authoritative upstream project and behavior.
- [4DBug/imgui-luau](https://github.com/4DBug/imgui-luau) — imported Luau port and Roblox backend.
- [Iris](https://github.com/SirMallard/Iris) — supplementary immediate-mode architecture reference; not this implementation's core.
- [WebGui Dear ImGui demo](https://jnmaloney.github.io/WebGui/imgui.html) — supplementary visual behavior comparison.

## License

The repository's original project files remain MIT-licensed. The imported Dear ImGui-derived code is also distributed under the MIT terms stated by its upstream port; see [LICENSES/DEAR_IMGUI.txt](LICENSES/DEAR_IMGUI.txt) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
