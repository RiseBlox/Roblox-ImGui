-- Roblox-ImGui Milestone 01 interaction regression test.
-- Run as a client LocalScript in Studio, or in a supported client executor.
-- Tests click focus, click-to-front, dragging, child scopes, and Destroy cleanup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ImGui: any
local moduleScript = ReplicatedStorage:FindFirstChild("ImGui")
if moduleScript and moduleScript:IsA("ModuleScript") then
    ImGui = require(moduleScript)
else
    local source = game:HttpGet("https://raw.githubusercontent.com/RiseBlox/Roblox-ImGui/main/src/ImGui.lua")
    ImGui = loadstring(source)()
end

local ui = ImGui.new({ Name = "RobloxImGuiMilestone01Test", DisplayOrder = 110 })
local state = {
    AClicks = 0,
    BClicks = 0,
    ChildClicks = 0,
    Status = "Click a window title, body, or widget to activate it.",
}
local connection
local firstFrame = true

local function report(message)
    state.Status = message
    print("[Roblox-ImGui M1] " .. message)
end

local function draw()
    ui:NewFrame()

    local aFlags = { Size = UDim2.fromOffset(360, 300) }
    local bFlags = { Size = UDim2.fromOffset(360, 300) }
    if firstFrame then
        aFlags.Position = UDim2.fromOffset(70, 90)
        bFlags.Position = UDim2.fromOffset(270, 190)
        firstFrame = false
    end

    if ui:Begin("Window A - behind", aFlags) then
        ui:Text("Window A is partially covered by Window B.")
        ui:Text("Click this button to activate and bring A forward.")
        ui:Button("Activate Window A", {
            ID = "m1-a-button",
            Callback = function()
                state.AClicks += 1
                report("Window A activated by widget click. A clicks: " .. state.AClicks)
            end,
        })
        ui:Text("A button clicks: " .. state.AClicks)
        ui:Separator("Child focus")
        ui:BeginChild("m1-child", UDim2.new(1, 0, 0, 90))
        ui:Text("Click the child button; Window A should activate.")
        ui:Button("Child button", {
            ID = "m1-child-button",
            Callback = function()
                state.ChildClicks += 1
                report("Child widget activated Window A. Child clicks: " .. state.ChildClicks)
            end,
        })
        ui:EndChild()
        ui:Text("Click empty content space to test body focus.")
        ui:Text("Status: " .. state.Status)
    end
    ui:End()

    if ui:Begin("Window B - front", bFlags) then
        ui:Text("Window B starts in front of A.")
        ui:Button("Activate Window B", {
            ID = "m1-b-button",
            Callback = function()
                state.BClicks += 1
                report("Window B activated by widget click. B clicks: " .. state.BClicks)
            end,
        })
        ui:Text("B button clicks: " .. state.BClicks)
        ui:Text("Click blank space in this body to activate B.")
        ui:Text("Status: " .. state.Status)
    end
    ui:End()

    ui:Render()
end

connection = RunService.RenderStepped:Connect(function()
    local ok, err = pcall(draw)
    if not ok then
        if connection then connection:Disconnect(); connection = nil end
        ui:Destroy()
        warn("[Roblox-ImGui M1] Test crashed:", err)
    end
end)

_G.RobloxImGuiMilestone01Test = {
    UI = ui,
    State = state,
    Destroy = function()
        if connection then connection:Disconnect(); connection = nil end
        ui:Destroy()
        _G.RobloxImGuiMilestone01Test = nil
        print("[Roblox-ImGui M1] Test UI destroyed.")
    end,
}

print("[Roblox-ImGui M1] Started. Test body/widget focus, click-to-front, dragging, and child focus.")
print("[Roblox-ImGui M1] Cleanup: _G.RobloxImGuiMilestone01Test.Destroy()")
