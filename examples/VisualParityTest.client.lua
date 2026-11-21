--!strict
-- Roblox-ImGui visual parity smoke test.
-- Run from a client LocalScript in Studio, or in a client executor.
-- This is a visual/interaction smoke test, not a substitute for TestEZ.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ImGui
local moduleScript = ReplicatedStorage:FindFirstChild("ImGui")
if moduleScript and moduleScript:IsA("ModuleScript") then
    ImGui = require(moduleScript)
else
    -- Executor fallback for quick testing without installing a ModuleScript.
    local source = game:HttpGet("https://raw.githubusercontent.com/RiseBlox/Roblox-ImGui/main/src/ImGui.lua")
    ImGui = loadstring(source)()
end

local ui = ImGui.new({
    Name = "RobloxImGuiVisualParityTest",
    DisplayOrder = 100,
})

local state = {
    Enabled = true,
    Choice = 1,
    Float = 0.35,
    Integer = 6,
    Input = "Hello Dear ImGui",
    Progress = 0.65,
    ChildClicks = 0,
    ButtonClicks = 0,
}

local firstMainFrame = true
local firstSecondaryFrame = true
local connection

local function draw()
    ui:NewFrame()

    -- Only set Position on the first frame. Reapplying it every frame would
    -- override the user's drag movement.
    local mainFlags = {
        Size = UDim2.fromOffset(520, 560),
    }
    if firstMainFrame then
        mainFlags.Position = UDim2.fromOffset(80, 70)
        firstMainFrame = false
    end

    if ui:Begin("Dear ImGui - Visual Parity Test", mainFlags) then
        ui:Text("Roblox-ImGui " .. ImGui.Version .. " | Dear ImGui-inspired layout", {
            Color = ui.Style.Accent,
        })
        ui:Separator("Basic widgets")

        ui:Button("Button", {
            ID = "test-button",
            Callback = function()
                state.ButtonClicks += 1
                print("[Roblox-ImGui] Button clicked:", state.ButtonClicks)
            end,
        })
        ui:Text("Button clicks: " .. state.ButtonClicks)

        ui:Checkbox("Checkbox", state.Enabled, function(value)
            state.Enabled = value
        end, "test-checkbox")

        ui:RadioButton("Radio A", state.Choice == 1, function()
            state.Choice = 1
        end, "radio-a")
        ui:RadioButton("Radio B", state.Choice == 2, function()
            state.Choice = 2
        end, "radio-b")
        ui:RadioButton("Radio C", state.Choice == 3, function()
            state.Choice = 3
        end, "radio-c")
        ui:Text("Selected radio: " .. state.Choice)

        ui:SliderFloat("Float", state.Float, 0, 1, function(value)
            state.Float = value
        end, "test-float")
        ui:SliderInt("Integer", state.Integer, 0, 20, function(value)
            state.Integer = value
        end, "test-integer")

        ui:InputText("Text input", state.Input, function(value)
            state.Input = value
        end, {
            ID = "test-input",
            Placeholder = "Type here",
        })
        ui:ProgressBar(state.Progress, UDim2.new(1, 0, 0, 18), "65%", "test-progress")

        ui:Separator("Child region - independent scrolling")
        ui:BeginChild("scroll-child", UDim2.new(1, 0, 0, 150))
        for index = 1, 12 do
            ui:Text("Child row " .. index)
        end
        ui:Button("Child button", {
            ID = "child-button",
            Callback = function()
                state.ChildClicks += 1
                print("[Roblox-ImGui] Child button clicked:", state.ChildClicks)
            end,
        })
        ui:EndChild()
        ui:Text("Child button clicks: " .. state.ChildClicks)

        ui:Separator("Window overflow - scroll this window")
        for index = 1, 18 do
            ui:Text("Overflow row " .. index)
        end
    end
    ui:End()

    local secondaryFlags = {
        Size = UDim2.fromOffset(260, 150),
    }
    if firstSecondaryFrame then
        secondaryFlags.Position = UDim2.fromOffset(620, 90)
        firstSecondaryFrame = false
    end

    if ui:Begin("Secondary window", secondaryFlags) then
        ui:Text("Independent window")
        ui:Text("Drag both title bars.")
        ui:Button("Secondary button", {
            ID = "secondary-button",
            Callback = function()
                print("[Roblox-ImGui] Secondary window works")
            end,
        })
    end
    ui:End()

    ui:Render()
end

connection = RunService.RenderStepped:Connect(function()
    local success, err = pcall(draw)
    if not success then
        if connection then
            connection:Disconnect()
            connection = nil
        end
        ui:Destroy()
        warn("[Roblox-ImGui] Visual parity test failed:", err)
    end
end)

_G.RobloxImGuiVisualParityTest = {
    UI = ui,
    State = state,
    Destroy = function()
        if connection then
            connection:Disconnect()
            connection = nil
        end
        ui:Destroy()
        _G.RobloxImGuiVisualParityTest = nil
    end,
}

print("[Roblox-ImGui] Visual parity test started. Run _G.RobloxImGuiVisualParityTest.Destroy() to stop it.")
