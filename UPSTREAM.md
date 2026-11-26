# Upstream provenance

The current `main` implementation imports the Roblox-targeting source port from:

- Repository: https://github.com/4DBug/imgui-luau
- Source commit: `6e9790bf2a00a8b829d36a499bf83d8358221bec`
- Upstream Wally package version: `0.4.4`
- Ported Dear ImGui revision stated by that source: docking branch, `v1.93.0 WIP`

This is an imported and adapted starting point, not a claim that RiseBlox independently authored the complete translation. Source files retain their existing attribution and comments. The repository contains the corresponding comparison inputs under `tools/test/upstream/`, the upstream-generated coverage report under `docs/PORT_STATUS.txt`, and porting rules under `docs/PORTING.md`.

## Integration decisions

- Keep the core Dear ImGui translation and the Roblox backend separate.
- Preserve upstream function names and immediate-mode state/return conventions.
- Keep the upstream test harness and comparison fixtures so subsequent changes can be checked.
- Treat the upstream report as a useful baseline, not a substitute for local verification or a guarantee of full parity.
- Record local patches and deviations explicitly; do not silently turn the core into a Roblox-specific widget recreation.

When updating the imported port, record the new upstream commit here and regenerate `docs/PORT_STATUS.txt` with `tools/compare_upstream.py`.
