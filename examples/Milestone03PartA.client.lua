-- Roblox-ImGui Milestone 03 Part A layout primitives smoke test.
-- Run as a client LocalScript after placing ImGui.lua in ReplicatedStorage.
-- In an executor, replace the require line with the project's raw-GitHub loadstring loader.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ImGui = require(ReplicatedStorage:WaitForChild("ImGui"))

local ui = ImGui.new({ Name = "RobloxImGuiM03PartA", DisplayOrder = 113 })
local state = { Clicks = 0, Checked = false, VerticalClicks = 0, LayoutButtonClicks = 0 }
local connection
local firstFrame = true

local function draw()
    ui:NewFrame()
    local flags = { Size = UDim2.fromOffset(550, 560) }
    if firstFrame then
        flags.Position = UDim2.fromOffset(180, 100)
        firstFrame = false
    end

    if ui:Begin("M03 Part A - Layout Primitives", flags) then
        ui:Text("Milestone 03 / Part A")
        ui:Text("SameLine places the next item beside the preceding item.")
        ui:SameLine()
        ui:Button("Inline button", { Callback = function() state.Clicks += 1 end })
        ui:Text("Inline button clicks: " .. state.Clicks)

        ui:Separator("New line and spacing")
        ui:Button("First vertical item", { Callback = function() state.VerticalClicks += 1 end })
        ui:NewLine()
        ui:Button("NewLine resumes vertical flow", { Callback = function() state.VerticalClicks += 1 end })
        ui:Text("Vertical button clicks: " .. state.VerticalClicks)

        ui:Separator("Button layout combinations")
        local function countLayoutClick()
            state.LayoutButtonClicks += 1
        end

        ui:Text("Three buttons on one row:")
        ui:Button("Row 1 - A", { Size = UDim2.fromOffset(112, 26), Callback = countLayoutClick })
        ui:SameLine()
        ui:Button("Row 1 - B", { Size = UDim2.fromOffset(112, 26), Callback = countLayoutClick })
        ui:SameLine()
        ui:Button("Row 1 - C", { Size = UDim2.fromOffset(112, 26), Callback = countLayoutClick })

        ui:Text("Two buttons on one row:")
        ui:Button("Left action", { Size = UDim2.fromOffset(130, 26), Callback = countLayoutClick })
        ui:SameLine()
        ui:Button("Right action", { Size = UDim2.fromOffset(130, 26), Callback = countLayoutClick })

        ui:Text("NewLine after a same-line row:")
        ui:Button("Inline A", { Size = UDim2.fromOffset(105, 26), Callback = countLayoutClick })
        ui:SameLine()
        ui:Button("Inline B", { Size = UDim2.fromOffset(105, 26), Callback = countLayoutClick })
        ui:NewLine()
        ui:Button("Back to vertical flow", { Size = UDim2.fromOffset(220, 26), Callback = countLayoutClick })

        ui:Text("Layout button clicks: " .. state.LayoutButtonClicks)
        ui:Spacing(14)
        ui:Text("The previous item is followed by 14 pixels of extra spacing.")
        ui:Dummy(UDim2.fromOffset(80, 18))
        ui:Text("Dummy above reserves an invisible 80 x 18 pixel area.")

        ui:Separator("Indent / Unindent")
        ui:Text("Before indentation")
        ui:Indent()
        ui:Text("Indented content (default 14 px)")
        ui:Checkbox("Indented checkbox", state.Checked, function(value)
            state.Checked = value
        end, "m03a-indented-check")
        ui:Indent(22)
        ui:Text("Nested indentation (additional 22 px)")
        ui:Unindent()
        ui:Text("Back to the first indentation level")
        ui:Unindent()
        ui:Text("Back to the original content alignment")

        ui:Separator("BeginGroup / EndGroup")
        ui:BeginGroup()
        ui:Text("Grouped item one")
        ui:Button("Grouped button", { Callback = function() state.Clicks += 1 end })
        ui:EndGroup()
        ui:Text("Outside the group")
        ui:Text("Total button clicks: " .. state.Clicks)
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
        warn("[M03 Part A] Test failed:", err)
    end
end)

_G.RobloxImGuiM03PartA = {
    UI = ui,
    State = state,
    Destroy = function()
        if connection then connection:Disconnect(); connection = nil end
        ui:Destroy()
        _G.RobloxImGuiM03PartA = nil
    end,
}
print("[M03 Part A] Started. Stop with _G.RobloxImGuiM03PartA.Destroy().")
