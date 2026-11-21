-- Roblox-ImGui Milestone 02 Part A smoke test.
-- Run as a client LocalScript after placing ImGui.lua in ReplicatedStorage.
-- For the Image() check, replace the sample asset string with an image you own/can use.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ImGui = require(ReplicatedStorage:WaitForChild("ImGui"))

local ui = ImGui.new({ Name = "RobloxImGuiM02PartA", DisplayOrder = 110 })
local state = {
    Selected = true,
    Combo = 2,
    HeaderOpen = true,
    TreeOpen = true,
    SelectableClicks = 0,
    ComboChanges = 0,
}
local connection

local function draw()
    ui:NewFrame()
    if ui:Begin("M02 Part A - Essential Widgets", {
        Size = UDim2.fromOffset(480, 560),
        Position = UDim2.fromOffset(100, 80),
    }) then
        ui:Text("Milestone 02 / Part A")
        ui:Separator("Selectable")
        ui:Text("Click the row to toggle its selected state.")
        ui:Selectable("Selectable row", state.Selected, function(value)
            state.Selected = value
            state.SelectableClicks += 1
        end, "m02-selectable")
        ui:Text("Selected: " .. tostring(state.Selected) .. " | Clicks: " .. state.SelectableClicks)

        ui:Separator("Combo")
        ui:Combo("Quality", state.Combo, { "Low", "Medium", "High", "Ultra" }, function(index, item)
            state.Combo = index
            state.ComboChanges += 1
            print("[M02 Part A] Combo:", index, item)
        end, "m02-combo")
        ui:Text("Current option: " .. state.Combo)

        ui:Separator("Collapsing header")
        state.HeaderOpen = ui:CollapsingHeader("Header contents", "m02-header")
        if state.HeaderOpen then
            ui:Text("This content is submitted only while the header is open.")
            ui:BulletText("Header child item")
        end

        ui:Separator("Tree node")
        state.TreeOpen = ui:TreeNode("Parent node", "m02-tree")
        if state.TreeOpen then
            ui:BulletText("Child node A")
            ui:BulletText("Child node B")
            ui:TreePop()
        end

        ui:Separator("Bullet text")
        ui:BulletText("First bullet item")
        ui:BulletText("Second bullet item with a longer description")

        ui:Separator("Image")
        ui:Text("Replace rbxassetid://0 with a valid image asset to see it.")
        ui:Image("rbxassetid://0", UDim2.fromOffset(96, 96), {
            ID = "m02-image",
            ScaleType = Enum.ScaleType.Fit,
            BackgroundTransparency = 0,
        })
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
        warn("[M02 Part A] Test failed:", err)
    end
end)

_G.RobloxImGuiM02PartA = {
    UI = ui,
    State = state,
    Destroy = function()
        if connection then connection:Disconnect(); connection = nil end
        ui:Destroy()
        _G.RobloxImGuiM02PartA = nil
    end,
}
print("[M02 Part A] Started. Stop with _G.RobloxImGuiM02PartA.Destroy().")
