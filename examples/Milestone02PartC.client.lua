-- Roblox-ImGui Milestone 02 Part C smoke test.
-- Run as a client LocalScript after placing ImGui.lua in ReplicatedStorage.
-- In an executor, replace the require line with the project's raw-GitHub loadstring loader.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ImGui = require(ReplicatedStorage:WaitForChild("ImGui"))

local ui = ImGui.new({ Name = "RobloxImGuiM02PartC", DisplayOrder = 112 })
local state = {
    EditColor = Color3.fromRGB(66, 150, 250),
    PickerColor = Color3.fromRGB(230, 90, 75),
    Changes = 0,
}
local connection
local firstFrame = true

local function draw()
    ui:NewFrame()
    local flags = { Size = UDim2.fromOffset(480, 430) }
    if firstFrame then
        flags.Position = UDim2.fromOffset(160, 110)
        firstFrame = false
    end

    if ui:Begin("M02 Part C - Color Controls", flags) then
        ui:Text("Milestone 02 / Part C")
        ui:Text("Test the compact color editor and the always-visible HSV color picker.")
        ui:Separator("Color edit")
        ui:ColorEdit("Accent color", state.EditColor, function(color)
            state.EditColor = color
            state.Changes += 1
        end, "m02c-color-edit")
        ui:Text(string.format("Edit RGB: %d, %d, %d",
            math.floor(state.EditColor.R * 255 + 0.5),
            math.floor(state.EditColor.G * 255 + 0.5),
            math.floor(state.EditColor.B * 255 + 0.5)))
        ui:Separator("Color picker")
        ui:ColorPicker("Preview color", state.PickerColor, function(color)
            state.PickerColor = color
            state.Changes += 1
        end, "m02c-color-picker")
        ui:Text(string.format("Picker RGB: %d, %d, %d",
            math.floor(state.PickerColor.R * 255 + 0.5),
            math.floor(state.PickerColor.G * 255 + 0.5),
            math.floor(state.PickerColor.B * 255 + 0.5)))
        ui:Text("Callbacks received: " .. state.Changes)
        ui:Text("Click the Accent color swatch to expand or collapse its HSV controls. Adjust Hue, Saturation, and Value to change either color.")
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
        warn("[M02 Part C] Test failed:", err)
    end
end)

_G.RobloxImGuiM02PartC = {
    UI = ui,
    State = state,
    Destroy = function()
        if connection then connection:Disconnect(); connection = nil end
        ui:Destroy()
        _G.RobloxImGuiM02PartC = nil
    end,
}
print("[M02 Part C] Started. Stop with _G.RobloxImGuiM02PartC.Destroy().")
