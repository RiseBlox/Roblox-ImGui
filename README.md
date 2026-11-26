# Roblox-ImGui

**A source-level port of Dear ImGui to Luau, with a Roblox backend.**

This repository is transitioning away from the original independent UI recreation (preserved on [prototype/legacy-recreation](https://github.com/RiseBlox/Roblox-ImGui/tree/prototype/legacy-recreation)) toward a genuine port of Dear ImGui's core implementation.

## Project status

<details>
<summary><strong>Previous implementation — discontinued</strong></summary>

The previous main-branch implementation was an independent Roblox-native recreation of Dear ImGui's API and visual style. It was incomplete and did not include or translate Dear ImGui source code.

It has been preserved in the [prototype/legacy-recreation branch](https://github.com/RiseBlox/Roblox-ImGui/tree/prototype/legacy-recreation) for reference. It is no longer the active project.

</details>

The new project direction is a genuine source-level Luau port: translating Dear ImGui's core algorithms and implementation, then integrating Roblox as a platform/rendering backend—not rebuilding its widgets independently.

## Target

- **Upstream:** Dear ImGui 1.93.x (stable release targeted where possible)
- **Language:** Luau
- **Architecture:** Dear ImGui immediate-mode core, ported from upstream
- **Platform:** Roblox backend
- **Goal:** API, behavior, algorithms, and semantics faithful to upstream, with documented platform limitations

## Porting principles

1. Dear ImGui upstream source and documentation define core behavior and semantics.
2. Port implementation—not merely the appearance or API surface.
3. Keep Roblox-specific platform and renderer adaptations separated from the core where possible.
4. Track upstream behavior, APIs, and tests systematically.
5. Document unavoidable Roblox limitations and deviations.
6. Keep this repository an unofficial port; it is not affiliated with the Dear ImGui project.

## Reference

- [Dear ImGui upstream](https://github.com/ocornut/imgui)
- [Dear ImGui releases](https://github.com/ocornut/imgui/releases)
- [4DBug/imgui-luau](https://github.com/4DBug/imgui-luau) — existing Luau source port and Roblox backend, to be evaluated as a potential porting base rather than treated as upstream.

## Work in progress

The main branch is being reset for this port. No new port implementation is included yet.

## License

MIT. See [LICENSE](LICENSE).
