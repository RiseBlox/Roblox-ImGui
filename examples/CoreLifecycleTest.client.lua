--!strict
-- Standalone Roblox-ImGui lifecycle regression test.
-- This is a normal client LocalScript: no TestEZ, describe(), it(), or expect().
--
-- Setup:
--   1. Put src/ImGui.lua in ReplicatedStorage as a ModuleScript named "ImGui".
--   2. Put this file in StarterPlayerScripts as a LocalScript.
--   3. Run in Roblox Studio or a supported client environment.
--
-- Results are printed to the Output window. Each test gets its own ImGui context.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ImGui = require(ReplicatedStorage:WaitForChild("ImGui"))

local passed = 0
local failed = 0
local results = {}

local function check(condition, message)
    if not condition then
        error(message or "Assertion failed", 2)
    end
end

local function expectError(callback, message)
    local ok = pcall(callback)
    check(not ok, message or "Expected the operation to throw an error")
end

local function runTest(name, callback)
    local ui = nil
    local ok, err = pcall(function()
        ui = ImGui.new({
            Name = "ImGuiLifecycle_" .. tostring(#results + 1),
            DisplayOrder = 200,
        })
        callback(function() return ui end)
    end)

    if ui then
        pcall(function() ui:Destroy() end)
    end

    if ok then
        passed += 1
        table.insert(results, { Name = name, Passed = true })
        print("[ImGui Lifecycle] PASS - " .. name)
    else
        failed += 1
        table.insert(results, { Name = name, Passed = false, Error = tostring(err) })
        warn("[ImGui Lifecycle] FAIL - " .. name .. ": " .. tostring(err))
    end
end

print("==================================================")
print("[ImGui Lifecycle] Starting standalone regression tests")
print("[ImGui Lifecycle] No external test framework required")
print("==================================================")

runTest("Begin and Render require an active frame", function(getUI)
    local ui = getUI()
    expectError(function() ui:Begin("Outside frame") end, "Begin() should reject calls outside a frame")
    expectError(function() ui:Render() end, "Render() should reject calls outside a frame")
end)

runTest("Rejects starting a second frame before Render", function(getUI)
    local ui = getUI()
    ui:NewFrame()
    expectError(function() ui:NewFrame() end, "NewFrame() should reject a second active frame")
end)

runTest("Rejects Render with an unclosed window", function(getUI)
    local ui = getUI()
    ui:NewFrame()
    ui:Begin("Unclosed")
    expectError(function() ui:Render() end, "Render() should reject an unclosed window")
end)

runTest("Renders consecutive frames", function(getUI)
    local ui = getUI()
    ui:NewFrame()
    ui:Begin("Main")
    ui:Text("Frame one")
    ui:End()
    ui:Render()

    ui:NewFrame()
    ui:Begin("Main")
    ui:Text("Frame two")
    ui:End()
    ui:Render()

    check(ui.FrameNumber == 2, "Expected FrameNumber to equal 2")
end)

runTest("End cannot close a child scope", function(getUI)
    local ui = getUI()
    ui:NewFrame()
    ui:Begin("Main")
    ui:BeginChild("Nested")
    expectError(function() ui:End() end, "End() should reject a child scope")
    ui:EndChild()
    ui:End()
    ui:Render()
end)

runTest("EndChild rejects calls without BeginChild", function(getUI)
    local ui = getUI()
    ui:NewFrame()
    ui:Begin("Main")
    expectError(function() ui:EndChild() end, "EndChild() should reject a missing child scope")
    ui:End()
    ui:Render()
end)

runTest("Render rejects an unclosed PushID scope", function(getUI)
    local ui = getUI()
    ui:NewFrame()
    ui:Begin("IDs")
    ui:PushID("parent")
    ui:Text("Scoped")
    ui:End()
    expectError(function() ui:Render() end, "Render() should reject an unclosed PushID scope")
    ui:PopID()
    ui:Render()
end)

runTest("PopID rejects stack underflow", function(getUI)
    local ui = getUI()
    ui:NewFrame()
    expectError(function() ui:PopID() end, "PopID() should reject an empty ID stack")
end)

runTest("Destroy disconnects registered event connections", function(getUI)
    local ui = getUI()
    ui:NewFrame()
    ui:Begin("Connections")
    ui:Button("Tracked", { Callback = function() end })
    ui:End()
    ui:Render()

    check(#ui._connections > 0, "Expected at least one tracked connection")
    local connections = table.clone(ui._connections)
    ui:Destroy()

    for _, connection in ipairs(connections) do
        check(not connection.Connected, "A connection remained active after Destroy()")
    end
end)

runTest("Widget IDs are isolated between windows and child scopes", function(getUI)
    local ui = getUI()
    ui:NewFrame()

    ui:Begin("First")
    ui:Text("Shared", { ID = "same" })
    ui:BeginChild("Nested")
    ui:Text("Shared", { ID = "same" })
    ui:EndChild()
    ui:End()

    ui:Begin("Second")
    ui:Text("Shared", { ID = "same" })
    ui:End()
    ui:Render()

    local expectedKeys = {
        "Window:First/same",
        "Window:First/Child:Nested/same",
        "Window:Second/same",
    }
    local seen = {}
    for _, key in ipairs(expectedKeys) do
        local widget = ui.Widgets[key]
        check(widget ~= nil, "Missing retained widget for scoped ID: " .. key)
        check(widget:IsA("TextLabel"), "Expected a TextLabel for scoped ID: " .. key)
        for previousKey, previousWidget in pairs(seen) do
            check(widget ~= previousWidget,
                "Scoped IDs unexpectedly share one instance: " .. previousKey .. " and " .. key)
        end
        seen[key] = widget
    end
    check(#expectedKeys == 3, "Expected three distinct text widgets across the two windows and child scope")
end)

runTest("Callbacks are isolated between windows", function(getUI)
    local ui = getUI()
    local firstCallback = function() end
    local secondCallback = function() end

    ui:NewFrame()
    ui:Begin("First")
    ui:Button("Shared", { ID = "shared-button", Callback = firstCallback })
    ui:End()

    ui:Begin("Second")
    ui:Button("Shared", { ID = "shared-button", Callback = secondCallback })
    ui:End()
    ui:Render()

    check(ui._callbacks["Window:First/shared-button"] == firstCallback,
        "First window callback was overwritten")
    check(ui._callbacks["Window:Second/shared-button"] == secondCallback,
        "Second window callback was not retained")
end)

runTest("Progress controllers are isolated between windows", function(getUI)
    local ui = getUI()
    ui:NewFrame()

    ui:Begin("First")
    local first = ui:ProgressBar(0.25, nil, "first", "shared-progress")
    ui:End()

    ui:Begin("Second")
    local second = ui:ProgressBar(0.75, nil, "second", "shared-progress")
    ui:End()
    ui:Render()

    check(first ~= second, "Progress controllers should be distinct")
    check(first.Frame ~= second.Frame, "Progress bar frames should be distinct")
end)

runTest("RadioButton and ProgressBar still render", function(getUI)
    local ui = getUI()
    ui:NewFrame()
    ui:Begin("Widgets")
    local selected = ui:RadioButton("Option A", true, function() end, "option-a")
    local bar = ui:ProgressBar(0.65, nil, "65%", "loading")
    ui:End()
    ui:Render()

    check(selected == true, "RadioButton should return its selected state")
    check(ui.Widgets["Window:Widgets/option-a"] ~= nil, "RadioButton widget was not created")
    check(type(bar) == "table" and bar.Frame ~= nil, "ProgressBar should return a controller with a Frame")
    local fill = bar.Frame:FindFirstChild("Fill")
    local overlay = bar.Frame:FindFirstChild("Overlay")
    check(fill ~= nil and math.abs(fill.Size.X.Scale - 0.65) < 0.001, "ProgressBar fill fraction is incorrect")
    check(overlay ~= nil and overlay.Text == "65%", "ProgressBar overlay text is incorrect")
end)

runTest("Dear ImGui-inspired default style remains intact", function(getUI)
    local ui = getUI()
    check(ui.Style.Font == Enum.Font.Code, "Unexpected default font")
    check(ui.Style.FontSize == 13, "Unexpected default font size")
    check(ui.Style.WindowRounding == 0, "Unexpected window rounding")
    check(ui.Style.FrameRounding == 0, "Unexpected frame rounding")
    check(ui.Style.WindowPadding == Vector2.new(8, 8), "Unexpected window padding")
    check(ui.Style.ItemSpacing == Vector2.new(8, 4), "Unexpected item spacing")
    check(ui.Style.Accent == Color3.fromRGB(66, 150, 250), "Unexpected accent color")
end)

runTest("Slider retains its track, grab, value and label", function(getUI)
    local ui = getUI()
    ui:NewFrame()
    ui:Begin("Slider")
    ui:SliderFloat("Amount", 0.5, 0, 1, function() end, "amount")
    ui:End()
    ui:Render()

    local slider = ui.Widgets["Window:Slider/amount"]
    check(slider ~= nil, "Slider widget was not created")
    local track = slider:FindFirstChild("Track")
    check(track ~= nil, "Slider track was not created")
    check(track:FindFirstChild("Grab") ~= nil, "Slider grab was not created")
    check(track:FindFirstChild("Value") ~= nil, "Slider value label was not created")
    check(slider:FindFirstChild("Label") ~= nil, "Slider label was not created")
end)

runTest("Destroy removes GUI and rejects future frames", function(getUI)
    local ui = getUI()
    local screen = ui.ScreenGui
    ui:Destroy()
    check(screen.Parent == nil, "ScreenGui still has a parent after Destroy()")
    expectError(function() ui:NewFrame() end, "NewFrame() should reject a destroyed context")
end)

print("==================================================")
print(string.format("[ImGui Lifecycle] Finished: %d passed, %d failed, %d total", passed, failed, passed + failed))
print("==================================================")

if failed > 0 then
    warn("[ImGui Lifecycle] Some tests failed. Review the errors above.")
else
    print("[ImGui Lifecycle] ALL TESTS PASSED")
end

_G.RobloxImGuiLifecycleTest = {
    Passed = passed,
    Failed = failed,
    Results = results,
}
