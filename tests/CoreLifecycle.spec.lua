--!strict
-- TestEZ spec. Run in a client test environment with Roblox-ImGui available.
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ImGui = require(ReplicatedStorage:WaitForChild("ImGui"))

    describe("Roblox-ImGui core lifecycle", function()
        local ui
        beforeEach(function() ui = ImGui.new({ Name = "RobloxImGuiLifecycleTest" }) end)
        afterEach(function() if ui then ui:Destroy(); ui = nil end end)

        it("requires NewFrame before Begin and Render", function()
            expect(function() ui:Begin("Outside frame") end).to.throw()
            expect(function() ui:Render() end).to.throw()
        end)

        it("rejects starting a second frame before rendering the first", function()
            ui:NewFrame()
            expect(function() ui:NewFrame() end).to.throw()
        end)

        it("rejects rendering with an unclosed window", function()
            ui:NewFrame()
            ui:Begin("Unclosed")
            expect(function() ui:Render() end).to.throw()
        end)

        it("renders consecutive frames", function()
            ui:NewFrame(); ui:Begin("Main"); ui:Text("Frame one"); ui:End(); ui:Render()
            ui:NewFrame(); ui:Begin("Main"); ui:Text("Frame two"); ui:End(); ui:Render()
            expect(ui.FrameNumber).to.equal(2)
        end)

        it("isolates widget IDs between windows and child scopes", function()
            ui:NewFrame()
            ui:Begin("First")
            ui:Text("Shared", { ID = "same" })
            ui:BeginChild("Nested")
            ui:Text("Shared", { ID = "same" })
            ui:EndChild()
            ui:End()
            ui:Begin("Second")
            ui:Text("Shared", { ID = "same" })
            ui:End()
            ui:Render()
            local count = 0
            for _ in pairs(ui.Widgets) do count += 1 end
            expect(count).to.equal(3)
        end)


        it("creates radio buttons and progress bars", function()
            ui:NewFrame()
            ui:Begin("Widgets")
            local selected = ui:RadioButton("Option A", true, function() end, "option-a")
            local bar = ui:ProgressBar(0.65, nil, "65%", "loading")
            ui:End()
            ui:Render()
            expect(selected).to.equal(true)
            expect(ui.Widgets["Window:Widgets/option-a"]).never.to.equal(nil)
            expect(math.abs(bar:FindFirstChild("Fill").Size.X.Scale - 0.65) < 0.001).to.equal(true)
            expect(bar:FindFirstChild("Overlay").Text).to.equal("65%")
        end)

        it("destroys its GUI and rejects further frames", function()
            local screen = ui.ScreenGui
            ui:Destroy()
            expect(screen.Parent).to.equal(nil)
            expect(function() ui:NewFrame() end).to.throw()
        end)
    end)
end