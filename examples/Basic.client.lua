--!strict
-- Place ImGui.lua in ReplicatedStorage and run this from a LocalScript.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ImGui = require(ReplicatedStorage:WaitForChild("ImGui"))

local ui = ImGui.new({ Name = "RobloxImGuiDemo", DisplayOrder = 50 })
local enabled = true
local speed = 16

RunService.RenderStepped:Connect(function()
    ui:NewFrame()
    if ui:Begin("Roblox-ImGui demo", { Size = UDim2.fromOffset(440, 350) }) then
        ui:Text("Roblox-ImGui " .. ImGui.Version, { Color = ui.Style.Accent })
        ui:Separator("Controls")
        ui:Button("Print", { Callback = function() print("Clicked") end })
        ui:Checkbox("Enabled", enabled, function(value) enabled = value end, "enabled")
        ui:SliderInt("WalkSpeed", speed, 0, 100, function(value) speed = value end, "walk-speed")
    end
    ui:End()
    ui:Render()
end)

-- Call ui:Destroy() when your script shuts down.
