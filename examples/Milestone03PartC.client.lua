-- Roblox-ImGui Milestone 03 Part C: legacy columns layout test.
-- Run as a client LocalScript after placing ImGui.lua in ReplicatedStorage.
-- In an executor, replace the require line with the project's raw-GitHub loader.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ImGui = require(ReplicatedStorage:WaitForChild("ImGui"))

local ui = ImGui.new({ Name = "RobloxImGuiM03PartC", DisplayOrder = 115 })
local state = { Left = 0, Middle = 0, Right = 0, Borderless = 0 }
local connection
local firstFrame = true

local function draw()
    ui:NewFrame()
    local flags = { Size = UDim2.fromOffset(620, 620) }
    if firstFrame then
        flags.Position = UDim2.fromOffset(210, 80)
        firstFrame = false
    end

    if ui:Begin("M03 Part C - Columns", flags) then
        ui:Text("M03 / Part C — Legacy columns")
        ui:Text("Each column should keep an independent vertical item flow.")

        ui:Separator("Two equal columns")
        ui:Columns(2, "m03c-equal")
        ui:Text("Column 0")
        ui:Text("Index: " .. tostring(ui:GetColumnIndex()))
        ui:Text("Width: " .. tostring(math.floor(ui:GetColumnWidth() + 0.5)) .. " px")
        ui:Button("Left action", { Callback = function() state.Left += 1 end, ID = "m03c-left" })
        ui:Text("Left clicks: " .. tostring(state.Left))
        ui:NextColumn()
        ui:Text("Column 1")
        ui:Text("Index: " .. tostring(ui:GetColumnIndex()))
        ui:Text("Width: " .. tostring(math.floor(ui:GetColumnWidth() + 0.5)) .. " px")
        ui:Button("Right action", { Callback = function() state.Right += 1 end, ID = "m03c-right" })
        ui:Text("Right clicks: " .. tostring(state.Right))
        ui:NextColumn()
        ui:Text("Wrapped to column: " .. tostring(ui:GetColumnIndex()))
        ui:Text("The index should now be 0.")
        ui:EndColumns()

        ui:Separator("Three columns with custom widths")
        ui:Columns(3, "m03c-custom")
        ui:SetColumnWidth(0, 140)
        ui:SetColumnWidth(2, 110)
        ui:Text("Column 0 (140 px)")
        ui:Text("Width: " .. tostring(math.floor(ui:GetColumnWidth(0) + 0.5)) .. " px")
        ui:Button("Column 0 button", { Callback = function() state.Left += 1 end, ID = "m03c-custom-left" })
        ui:NextColumn()
        ui:Text("Column 1 (flexible)")
        ui:Text("Width: " .. tostring(math.floor(ui:GetColumnWidth() + 0.5)) .. " px")
        ui:Button("Column 1 button", { Callback = function() state.Middle += 1 end, ID = "m03c-custom-middle" })
        ui:NextColumn()
        ui:Text("Column 2 (110 px)")
        ui:Text("Width: " .. tostring(math.floor(ui:GetColumnWidth() + 0.5)) .. " px")
        ui:Button("Column 2 button", { Callback = function() state.Right += 1 end, ID = "m03c-custom-right" })
        ui:EndColumns()

        ui:Separator("Borderless columns")
        ui:Columns(2, "m03c-borderless", false)
        ui:Text("No vertical divider")
        ui:Button("Borderless left", { Callback = function() state.Borderless += 1 end, ID = "m03c-borderless-left" })
        ui:NextColumn()
        ui:Text("Second column")
        ui:Button("Borderless right", { Callback = function() state.Borderless += 1 end, ID = "m03c-borderless-right" })
        ui:EndColumns()
        ui:Text("Borderless clicks: " .. tostring(state.Borderless))

        ui:Separator("Scope / layout regression")
        ui:Text("This text should appear below the column region at full width.")
        ui:Button("Full-width flow restored", { Callback = function() print("[M03 Part C] Parent layout restored") end })
        ui:Text("If this window renders without errors, all column scopes were balanced.")
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
        warn("[M03 Part C] Test failed:", err)
    end
end)

_G.RobloxImGuiM03PartC = {
    UI = ui,
    State = state,
    Destroy = function()
        if connection then connection:Disconnect(); connection = nil end
        ui:Destroy()
        _G.RobloxImGuiM03PartC = nil
    end,
}
print("[M03 Part C] Started. Stop with _G.RobloxImGuiM03PartC.Destroy().")
