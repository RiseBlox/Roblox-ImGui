-- Roblox-ImGui Milestone 03 Part C: legacy columns test.
-- Run as a client LocalScript after placing ImGui.lua in ReplicatedStorage.
-- No TestEZ or external test framework is required.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ImGui = require(ReplicatedStorage:WaitForChild("ImGui"))

local ui = ImGui.new({ Name = "RobloxImGuiM03PartC", DisplayOrder = 115 })
local state = {
    Clicks = { 0, 0, 0 },
    Values = { 0.2, 0.5, 0.8 },
    FirstWidth = 180,
    SecondWidth = 130,
}
local connection
local firstFrame = true
local secondWindowFirstFrame = true
local checkCount = 0

local function check(condition, message)
    if not condition then error(message or "Column assertion failed", 2) end
    checkCount += 1
end

local function draw()
    ui:NewFrame()
    local flags = { Size = UDim2.fromOffset(700, 690) }
    if firstFrame then
        flags.Position = UDim2.fromOffset(130, 70)
        firstFrame = false
    end

    if ui:Begin("M03 Part C - Columns", flags) then
        ui:Text("Legacy Columns API")
        ui:Text("Three independent vertical flows; NextColumn wraps after the last column.")

        ui:Separator("Three columns / index / width")
        ui:Columns(3, "main-columns", true)
        check(ui:GetColumnIndex() == 0, "First column index should be zero")
        ui:SetColumnWidth(0, state.FirstWidth)
        check(ui:GetColumnWidth() > 0, "Current column width should be positive")
        ui:Text("Column 0")
        ui:Text("Index: " .. ui:GetColumnIndex())
        ui:Button("Increment 0", { Callback = function() state.Clicks[1] += 1 end, ID = "column-button-0" })
        ui:Text("Clicks: " .. state.Clicks[1])
        ui:SliderFloat("Value 0", state.Values[1], 0, 1, function(v) state.Values[1] = v end, "column-slider-0")

        ui:NextColumn()
        check(ui:GetColumnIndex() == 1, "NextColumn should advance to index one")
        ui:Text("Column 1")
        ui:Text("Index: " .. ui:GetColumnIndex())
        ui:Button("Increment 1", { Callback = function() state.Clicks[2] += 1 end, ID = "column-button-1" })
        ui:Text("Clicks: " .. state.Clicks[2])
        ui:SliderFloat("Value 1", state.Values[2], 0, 1, function(v) state.Values[2] = v end, "column-slider-1")

        ui:NextColumn()
        check(ui:GetColumnIndex() == 2, "NextColumn should advance to index two")
        ui:SetColumnWidth(-1, 150)
        check(ui:GetColumnWidth(-1) > 0, "Explicit current-column width should be positive")
        ui:Text("Column 2")
        ui:Text("Index: " .. ui:GetColumnIndex())
        ui:Button("Increment 2", { Callback = function() state.Clicks[3] += 1 end, ID = "column-button-2" })
        ui:Text("Clicks: " .. state.Clicks[3])
        ui:SliderFloat("Value 2", state.Values[3], 0, 1, function(v) state.Values[3] = v end, "column-slider-2")

        ui:NextColumn()
        check(ui:GetColumnIndex() == 0, "NextColumn should wrap back to index zero")
        ui:EndColumns()
        ui:Text("The parent layout resumes here after EndColumns().")

        ui:Separator("Repeated IDs across columns")
        ui:Columns(2, "duplicate-id-columns", false)
        ui:Text("Left column", { ID = "same-cell-id" })
        local leftKey = ui:_callbackKey("same-cell-id")
        ui:NextColumn()
        ui:Text("Right column", { ID = "same-cell-id" })
        local rightKey = ui:_callbackKey("same-cell-id")
        check(leftKey ~= rightKey, "Repeated IDs in different columns must be isolated")
        ui:EndColumns()
        ui:Text("Separate column IDs must retain separate widget instances.")

        ui:Separator("Parent layout restoration")
        ui:Text("This item should use the full parent width after EndColumns().")
        ui:Button("Full-width parent button", { Callback = function() print("[M03 Part C] Parent flow restored") end })

        ui:Separator("Width identity across windows")
        ui:Columns(2, "shared-columns", false)
        ui:SetColumnWidth(0, state.FirstWidth)
        ui:Text("Window A / left")
        ui:NextColumn()
        ui:Text("Window A / right")
        ui:EndColumns()
    end
    ui:End()

    local secondWindowFlags = { Size = UDim2.fromOffset(320, 230) }
    if secondWindowFirstFrame then
        secondWindowFlags.Position = UDim2.fromOffset(850, 90)
        secondWindowFirstFrame = false
    end
    if ui:Begin("M03 Part C - Width Isolation", secondWindowFlags) then
        ui:Columns(2, "shared-columns", false)
        ui:SetColumnWidth(0, state.SecondWidth)
        ui:Text("Window B / left")
        ui:NextColumn()
        ui:Text("Window B / right")
        ui:EndColumns()
    end
    ui:End()
    ui:Render()

    local firstWidths = ui._columnWidths["Window:M03 Part C - Columns/shared-columns"]
    local secondWidths = ui._columnWidths["Window:M03 Part C - Width Isolation/shared-columns"]
    check(firstWidths ~= nil and secondWidths ~= nil, "Both windows should retain column width state")
    check(firstWidths ~= secondWidths, "Column width state must be isolated between windows")
    check(firstWidths[1] ~= secondWidths[1], "Different windows should retain their own configured widths")
end

connection = RunService.RenderStepped:Connect(function()
    local ok, err = pcall(draw)
    if not ok then
        if connection then connection:Disconnect(); connection = nil end
        ui:Destroy()
        warn("[M03 Part C] Test failed:", err)
    end
end)

_G.RobloxImGuiM03PartC = {
    UI = ui,
    State = state,
    GetCheckCount = function() return checkCount end,
    Destroy = function()
        if connection then connection:Disconnect(); connection = nil end
        ui:Destroy()
        _G.RobloxImGuiM03PartC = nil
    end,
}
print("[M03 Part C] Started. Test column switching, spacing, width persistence, borders, repeated IDs, parent-flow restoration, and dragging both windows.")
print("[M03 Part C] Stop with _G.RobloxImGuiM03PartC.Destroy().")
