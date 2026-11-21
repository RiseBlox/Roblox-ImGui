-- Roblox-ImGui Milestone 02 Part B smoke test.
-- Run as a client LocalScript after placing ImGui.lua in ReplicatedStorage.
-- In an executor, replace the require line with the project's raw-GitHub loadstring loader.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ImGui = require(ReplicatedStorage:WaitForChild("ImGui"))

local ui = ImGui.new({ Name = "RobloxImGuiM02PartB", DisplayOrder = 111 })
local state = {
    DragFloat = 0.5,
    DragInt = 25,
    InputFloat = 1.25,
    InputInt = 10,
    Changes = 0,
}
local connection
local firstFrame = true

local function draw()
    ui:NewFrame()
    local flags = { Size = UDim2.fromOffset(480, 440) }
    if firstFrame then flags.Position = UDim2.fromOffset(140, 100); firstFrame = false end
    if ui:Begin("M02 Part B - Numeric Controls", flags) then
        ui:Text("Milestone 02 / Part B")
        ui:Text("This long explanatory line should wrap automatically when the window is narrowed, then expand again when the window is widened. It should not run past the right edge.")
        ui:Separator("Drag controls")
        ui:DragFloat("Float drag", state.DragFloat, 0.01, 0, 1, function(value)
            state.DragFloat = value
            state.Changes += 1
        end, "m02b-drag-float")
        ui:DragInt("Integer drag", state.DragInt, 1, 0, 100, function(value)
            state.DragInt = value
            state.Changes += 1
        end, "m02b-drag-int")
        ui:Text(string.format("Drag values: %.3f | %d", state.DragFloat, state.DragInt))
        ui:Separator("Slider fill visibility")
        ui:SliderFloat("Float slider", state.SliderFloat or 0.35, 0, 1, function(value)
            state.SliderFloat = value
        end, "m02b-slider-float")

        ui:Separator("Numeric text inputs")
        ui:InputFloat("Float input", state.InputFloat, function(value)
            state.InputFloat = value
            state.Changes += 1
        end, { ID = "m02b-input-float", Min = 0, Max = 10, Decimals = 3 })
        ui:InputInt("Integer input", state.InputInt, function(value)
            state.InputInt = value
            state.Changes += 1
        end, { ID = "m02b-input-int", Min = 0, Max = 100 })
        ui:Text(string.format("Input values: %.3f | %d", state.InputFloat, state.InputInt))
        ui:Text("Committed changes: " .. state.Changes)
        ui:Text("Try invalid text, decimals in InputInt, and values outside the configured limits.")
    end
    ui:End()
    ui:Render()
end

connection = RunService.RenderStepped:Connect(function()
    local ok, err = pcall(draw)
    if not ok then
        connection:Disconnect()
        connection = nil
        ui:Destroy()
        warn("[M02 Part B] Test failed:", err)
    end
end)

_G.RobloxImGuiM02PartB = {
    UI = ui,
    State = state,
    Destroy = function()
        if connection then connection:Disconnect(); connection = nil end
        ui:Destroy()
        _G.RobloxImGuiM02PartB = nil
    end,
}
print("[M02 Part B] Started. Stop with _G.RobloxImGuiM02PartB.Destroy().")
