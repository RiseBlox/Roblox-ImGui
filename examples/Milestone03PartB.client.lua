-- Roblox-ImGui Milestone 03 Part B: item width and alignment test.
-- Run as a client LocalScript after placing ImGui.lua in ReplicatedStorage.
-- In an executor, replace the require line with the project's raw-GitHub loader.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ImGui = require(ReplicatedStorage:WaitForChild("ImGui"))

local ui = ImGui.new({ Name = "RobloxImGuiM03PartB", DisplayOrder = 114 })
local state = {
    FloatA = 0.35,
    FloatB = 0.65,
    DragA = 25,
    DragB = 60,
    InputFloat = 12.5,
    InputInt = 42,
    Text = "Width test",
}
local connection
local firstFrame = true

local function draw()
    ui:NewFrame()
    local flags = { Size = UDim2.fromOffset(620, 700) }
    if firstFrame then
        flags.Position = UDim2.fromOffset(190, 90)
        firstFrame = false
    end

    if ui:Begin("M03 Part B - Item Widths", flags) then
        ui:Text("M03 / Part B — Item width and alignment")
        ui:Text("Default widths remain unchanged unless an item width is set.")

        ui:Separator("SetNextItemWidth")
        ui:SetNextItemWidth(120)
        ui:SliderFloat("120 px slider", state.FloatA, 0, 1, function(v) state.FloatA = v end, "m03b-next-120")
        ui:SetNextItemWidth(220)
        ui:InputFloat("220 px numeric input", state.InputFloat, function(v) state.InputFloat = v end, {
            ID = "m03b-next-input-float", Min = 0, Max = 100,
        })
        ui:SetNextItemWidth(-100)
        ui:SliderFloat("Leave 100 px right margin", state.FloatB, 0, 1, function(v) state.FloatB = v end, "m03b-next-negative")

        ui:Separator("PushItemWidth / PopItemWidth")
        ui:PushItemWidth(180)
        ui:DragFloat("180 px drag", state.DragA, 0.1, 0, 100, function(v) state.DragA = v end, "m03b-push-drag-a")
        ui:InputInt("180 px integer input", state.InputInt, function(v) state.InputInt = v end, {
            ID = "m03b-push-input-int", Min = 0, Max = 100,
        })
        ui:DragFloat("Same pushed width", state.DragB, 0.1, 0, 100, function(v) state.DragB = v end, "m03b-push-drag-b")
        ui:PopItemWidth()

        ui:Separator("CalcItemWidth")
        ui:Text("Default effective width: " .. tostring(ui:CalcItemWidth()) .. " px")
        ui:PushItemWidth(240)
        ui:Text("Pushed effective width: " .. tostring(ui:CalcItemWidth()) .. " px")
        ui:InputText("240 px text input", state.Text, function(v) state.Text = v end, { ID = "m03b-push-text" })
        ui:PopItemWidth()

        ui:Separator("Negative width inside indentation")
        ui:PushItemWidth(-80)
        ui:Text("The control should end 80 px before the indented content edge.")
        ui:Indent(28)
        ui:SliderFloat("Indented right aligned", state.FloatA, 0, 1, function(v) state.FloatA = v end, "m03b-indented-negative")
        ui:Unindent()
        ui:PopItemWidth()

        ui:Separator("Default sizing regression check")
        ui:SliderFloat("Default slider", state.FloatB, 0, 1, function(v) state.FloatB = v end, "m03b-default-slider")
        ui:InputText("Default text input", state.Text, function(v) state.Text = v end, { ID = "m03b-default-text" })
        ui:Text("If this window renders without errors, all width stacks were balanced.")
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
        warn("[M03 Part B] Test failed:", err)
    end
end)

_G.RobloxImGuiM03PartB = {
    UI = ui,
    State = state,
    Destroy = function()
        if connection then connection:Disconnect(); connection = nil end
        ui:Destroy()
        _G.RobloxImGuiM03PartB = nil
    end,
}
print("[M03 Part B] Started. Stop with _G.RobloxImGuiM03PartB.Destroy().")
