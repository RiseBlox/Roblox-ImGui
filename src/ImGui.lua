--!strict
-- Roblox-ImGui: Roblox-native immediate-mode GUI foundation.
-- Independent Luau implementation inspired by Dear ImGui; not an official port.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local ImGui = {}
ImGui.Version = "0.1.0"
ImGui.UpstreamTarget = "Dear ImGui 1.93.x"
ImGui.__index = ImGui

local DEFAULT_STYLE = {
    -- Dear ImGui-inspired dark palette with its recognizable blue accent.
    WindowBg = Color3.fromRGB(15, 15, 15), WindowBgTransparency = 0.05,
    ChildBg = Color3.fromRGB(24, 24, 24), ChildBgTransparency = 0,
    PopupBg = Color3.fromRGB(24, 24, 24), Border = Color3.fromRGB(92, 92, 92),
    Text = Color3.fromRGB(235, 235, 235), TextDisabled = Color3.fromRGB(128, 128, 128),
    FrameBg = Color3.fromRGB(41, 74, 122), FrameBgTransparency = 0.4,
    FrameBgHovered = Color3.fromRGB(66, 112, 169), FrameBgActive = Color3.fromRGB(66, 150, 250),
    TitleBg = Color3.fromRGB(15, 15, 15), TitleBgHovered = Color3.fromRGB(30, 52, 78),
    TitleBgActive = Color3.fromRGB(41, 74, 122),
    Button = Color3.fromRGB(66, 150, 250), ButtonHovered = Color3.fromRGB(83, 164, 255),
    ButtonActive = Color3.fromRGB(45, 105, 180),
    Header = Color3.fromRGB(41, 74, 122), HeaderHovered = Color3.fromRGB(66, 112, 169),
    HeaderActive = Color3.fromRGB(45, 105, 180), Accent = Color3.fromRGB(66, 150, 250),
    CheckMark = Color3.fromRGB(66, 150, 250), SliderGrab = Color3.fromRGB(66, 150, 250),
    Separator = Color3.fromRGB(72, 72, 72), ScrollbarBg = Color3.fromRGB(20, 20, 20),
    ScrollbarGrab = Color3.fromRGB(75, 75, 75), ScrollbarGrabHovered = Color3.fromRGB(105, 105, 105),
    Font = Enum.Font.Code, FontSize = 13,
    WindowPadding = Vector2.new(8, 8), FramePadding = Vector2.new(4, 3),
    ItemSpacing = Vector2.new(8, 4), ItemInnerSpacing = Vector2.new(4, 4),
    WindowRounding = 0, ChildRounding = 0, FrameRounding = 0,
    BorderSize = 1, FrameBorderSize = 0, ScrollbarSize = 9, GrabMinSize = 10,
    TitleBarHeight = 22,
}

local function make(className, parent, properties)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do (object :: any)[key] = value end
    object.Parent = parent
    return object
end

local function round(parent, radius)
    make("UICorner", parent, { CornerRadius = UDim.new(0, radius) })
end

local function vertical(parent, gap)
    make("UIListLayout", parent, {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap),
    })
end

function ImGui.new(config)
    config = config or {}
    local player = Players.LocalPlayer
    assert(player, "Roblox-ImGui must be initialized on the client")
    local parent = config.Parent or player:WaitForChild("PlayerGui")
    local screen = make("ScreenGui", parent, {
        Name = config.Name or "RobloxImGui", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = config.IgnoreGuiInset == true,
        DisplayOrder = config.DisplayOrder or 20,
    })
    local self = setmetatable({
        ScreenGui = screen, Style = table.clone(DEFAULT_STYLE), Windows = {}, Widgets = {},
        WindowStack = {}, CurrentWindow = nil, CurrentParent = nil, _scope = "", _scopeStack = {},
        FrameNumber = 0, _idStack = {}, _order = 0, _windowOrder = 0, _connections = {}, _callbacks = {},
        _frameActive = false, _destroyed = false,
    }, ImGui)
    for key, value in pairs(config.Style or {}) do self.Style[key] = value end

    return self
end

function ImGui:PushID(id) table.insert(self._idStack, tostring(id)) end
function ImGui:PopID() if #self._idStack > 0 then table.remove(self._idStack) end end
function ImGui:GetID(id)
    local prefix = table.concat(self._idStack, "/")
    return (prefix ~= "" and prefix .. "/" or "") .. tostring(id)
end

function ImGui:_widget(id, className, parent, properties)
    local localKey = self:GetID(id)
    local key = (self._scope ~= "" and self._scope .. "/" or "") .. localKey
    local object = self.Widgets[key]
    if not object or object.ClassName ~= className or not object.Parent then
        if object then object:Destroy() end
        object = make(className, parent, properties)
        self.Widgets[key] = object
    else
        object.Parent = parent
        for property, value in pairs(properties or {}) do (object :: any)[property] = value end
    end
    object.LayoutOrder = self._order
    object:SetAttribute("ImGuiLastSeen", self.FrameNumber)

    -- Any click on a widget makes its owning window active.
    local currentWindow = self.CurrentWindow
    if currentWindow and object:GetAttribute("ImGuiFocusConnected") ~= true then
        object:SetAttribute("ImGuiFocusConnected", true)
        local function activateOwner()
            if currentWindow and currentWindow.Focus then currentWindow.Focus() end
        end
        table.insert(self._connections, object.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                local accepted = currentWindow and currentWindow.Focus and currentWindow.Focus(input.Position) == true
                object:SetAttribute("ImGuiInputAllowed", accepted == true)
            end
        end))
    end
    return object
end

function ImGui:_add(id, className, properties)
    assert(self._frameActive, "Call NewFrame() before creating widgets")
    assert(self.CurrentParent, "Call Begin() before creating widgets")
    self._order += 1
    return self:_widget(id, className, self.CurrentParent, properties)
end

function ImGui:NewFrame()
    assert(not self._destroyed, "This ImGui context has been destroyed")
    assert(not self._frameActive, "NewFrame() called before the previous frame was rendered")
    self.FrameNumber += 1
    self._order = 0
    self.WindowStack = {}
    self._scopeStack = {}
    self._scope = ""
    self.CurrentWindow, self.CurrentParent = nil, nil
    self._frameActive = true
end

function ImGui:_getWindow(name, flags)
    local window = self.Windows[name]
    if window and window.Root.Parent then return window end
    flags = flags or {}
    local style = self.Style
    local root = make("Frame", self.ScreenGui, {
        Name = "Window_" .. name, Position = flags.Position or UDim2.fromOffset(100, 100),
        Size = flags.Size or UDim2.fromOffset(430, 360), BackgroundColor3 = style.WindowBg,
        BackgroundTransparency = style.WindowBgTransparency, BorderSizePixel = 0,
        Active = true, ClipsDescendants = true,
    })
    round(root, style.WindowRounding)
    make("UIStroke", root, { Color = style.Border, Thickness = style.BorderSize })
    local title = make("TextButton", root, {
        Name = "TitleBar", Size = UDim2.new(1, 0, 0, style.TitleBarHeight), BackgroundColor3 = style.TitleBg,
        BorderSizePixel = 0, Text = name, TextColor3 = style.Text, Font = style.Font,
        TextSize = style.FontSize, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false, Active = true,
    })
    make("UIPadding", title, { PaddingLeft = UDim.new(0, style.FramePadding.X + 4) })
    local content = make("ScrollingFrame", root, {
        Name = "Content", Position = UDim2.fromOffset(0, style.TitleBarHeight),
        Size = UDim2.new(1, 0, 1, -style.TitleBarHeight),
        BackgroundTransparency = 1, BorderSizePixel = 0, Active = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollingEnabled = true,
        ScrollBarThickness = style.ScrollbarSize, ScrollBarImageColor3 = style.ScrollbarGrab,
        ScrollBarImageTransparency = 0,
    })
    make("UIPadding", content, {
        PaddingLeft = UDim.new(0, style.WindowPadding.X),
        PaddingRight = UDim.new(0, style.WindowPadding.X),
        PaddingTop = UDim.new(0, style.WindowPadding.Y),
        PaddingBottom = UDim.new(0, style.WindowPadding.Y),
    })
    vertical(content, style.ItemSpacing.Y)
    self._windowOrder += 1
    local window
    local function focusWindow(pointerPosition)
        -- Ignore pointer events delivered by obscured windows underneath the topmost one.
        if pointerPosition then
            local topmost, topmostOrder
            for _, candidate in pairs(self.Windows) do
                local candidateRoot = candidate.Root
                if candidate.Visible and candidateRoot.Parent == self.ScreenGui then
                    local position, size = candidateRoot.AbsolutePosition, candidateRoot.AbsoluteSize
                    local inside = pointerPosition.X >= position.X and pointerPosition.X <= position.X + size.X
                        and pointerPosition.Y >= position.Y and pointerPosition.Y <= position.Y + size.Y
                    if inside and (not topmostOrder or candidate.FocusOrder > topmostOrder) then
                        topmost, topmostOrder = candidate, candidate.FocusOrder
                    end
                end
            end
            if topmost and topmost.Name ~= name then return false end
        end

        local previous = self.Windows[self._focusedWindowName]
        if previous and previous.Title.Parent then previous.Title.BackgroundColor3 = style.TitleBg end
        self._windowOrder += 1
        if window then window.FocusOrder = self._windowOrder end
        self._focusedWindowName = name
        title.BackgroundColor3 = style.TitleBgActive
        if root.Parent == self.ScreenGui then
            root.Parent = nil
            root.Parent = self.ScreenGui
        end
        return true
    end
    title.MouseEnter:Connect(function()
        if self._focusedWindowName ~= name then title.BackgroundColor3 = style.TitleBgHovered end
    end)
    title.MouseLeave:Connect(function()
        if self._focusedWindowName ~= name then title.BackgroundColor3 = style.TitleBg end
    end)
    table.insert(self._connections, title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            focusWindow(input.Position)
        end
    end))

    local dragOrigin, startPosition
    table.insert(self._connections, title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if focusWindow(input.Position) ~= true then return end
            dragOrigin, startPosition = input.Position, root.Position
        end
    end))
    table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
        if not dragOrigin or not startPosition then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragOrigin
        root.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end))
    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragOrigin, startPosition = nil, nil
        end
    end))
    -- Clicking empty space in the window body also activates the window.
    local function focusOnPointer(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            focusWindow(input.Position)
        end
    end
    table.insert(self._connections, root.InputBegan:Connect(focusOnPointer))
    table.insert(self._connections, content.InputBegan:Connect(focusOnPointer))
    window = { Name = name, Root = root, Title = title, Content = content, Visible = true, Focus = focusWindow, FocusOrder = self._windowOrder }
    self.Windows[name] = window
    return window
end

function ImGui:Begin(name, flags)
    assert(self._frameActive, "Call NewFrame() before Begin()")
    flags = flags or {}
    local window = self:_getWindow(tostring(name), flags)
    window.Visible = flags.Visible ~= false
    window.Root.Visible = window.Visible
    if flags.Size then window.Root.Size = flags.Size end
    if flags.Position then window.Root.Position = flags.Position end
    window.Title.Visible = not flags.NoTitleBar
    window.Content.Position = flags.NoTitleBar
        and UDim2.fromOffset(0, 0)
        or UDim2.fromOffset(0, self.Style.TitleBarHeight)
    window.Content.Size = flags.NoTitleBar
        and UDim2.fromScale(1, 1)
        or UDim2.new(1, 0, 1, -self.Style.TitleBarHeight)
    window.Title.BackgroundColor3 = self._focusedWindowName == tostring(name)
        and self.Style.TitleBgActive or self.Style.TitleBg
    table.insert(self.WindowStack, { Window = self.CurrentWindow, Parent = self.CurrentParent, Scope = self._scope, Order = self._order })
    self._scope = "Window:" .. tostring(name)
    self.CurrentWindow, self.CurrentParent = window, window.Content
    self._order = 0
    return window.Visible
end

function ImGui:End()
    assert(#self.WindowStack > 0, "End() called without a matching Begin()")
    local previous = table.remove(self.WindowStack)
    self.CurrentWindow, self.CurrentParent = previous.Window, previous.Parent
    self._scope = previous.Scope
    self._order = previous.Order
end

function ImGui:Text(text, config)
    config = config or {}
    local label = self:_add(config.ID or ("Text:" .. tostring(text)), "TextLabel", {
        Name = "Text", BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 18), Font = config.Font or self.Style.Font,
        TextSize = config.TextSize or self.Style.FontSize, TextColor3 = config.Color or self.Style.Text,
        TextXAlignment = config.Align or Enum.TextXAlignment.Left,
        TextWrapped = config.Wrap == true, RichText = config.RichText == true,
    })
    label.Text = tostring(text == nil and "" or text)
    return label
end

function ImGui:Button(label, config)
    config = config or {}
    local button = self:_add(config.ID or ("Button:" .. tostring(label)), "TextButton", {
        Name = "Button", Size = config.Size or UDim2.new(0, 0, 0, 24),
        AutomaticSize = config.Size and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
        BackgroundColor3 = self.Style.Button, BackgroundTransparency = 0.12, BorderSizePixel = 0,
        AutoButtonColor = false, Font = self.Style.Font, TextSize = self.Style.FontSize,
        TextColor3 = self.Style.Text, Text = tostring(label),
    })
    if not button:FindFirstChildOfClass("UIPadding") then
        make("UIPadding", button, {
            PaddingLeft = UDim.new(0, self.Style.FramePadding.X + 4),
            PaddingRight = UDim.new(0, self.Style.FramePadding.X + 4),
        })
    end
    if not button:FindFirstChildOfClass("UICorner") then round(button, self.Style.FrameRounding) end
    if button:GetAttribute("ImGuiClickConnected") ~= true then
        button:SetAttribute("ImGuiClickConnected", true)
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = self.Style.ButtonHovered
            button.BackgroundTransparency = 0
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = self.Style.Button
            button.BackgroundTransparency = 0.12
        end)
        button.MouseButton1Down:Connect(function() button.BackgroundColor3 = self.Style.ButtonActive end)
        button.MouseButton1Up:Connect(function()
            if button:IsDescendantOf(self.ScreenGui) then
                button.BackgroundColor3 = self.Style.ButtonHovered
                button.BackgroundTransparency = 0
            end
        end)
        button.Activated:Connect(function()
            if button:GetAttribute("ImGuiInputAllowed") ~= true then return end
            local callback = self._callbacks and self._callbacks[config.ID or ("Button:" .. tostring(label))]
            if callback then callback() end
        end)
    end
    self._callbacks = self._callbacks or {}
    self._callbacks[config.ID or ("Button:" .. tostring(label))] = config.Callback
    return button
end

function ImGui:Checkbox(label, value, callback, id)
    local key = id or ("Checkbox:" .. tostring(label))
    local button = self:_add(key, "TextButton", {
        Name = "Checkbox", Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false, Font = self.Style.Font,
        TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local box = button:FindFirstChild("Box") or make("Frame", button, {
        Name = "Box", Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(15, 15),
        BackgroundColor3 = self.Style.FrameBg, BackgroundTransparency = self.Style.FrameBgTransparency,
        BorderSizePixel = 0,
    })
    if not box:FindFirstChildOfClass("UICorner") then round(box, 0) end
    local check = box:FindFirstChild("Check") or make("TextLabel", box, {
        Name = "Check", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = "✓", TextColor3 = self.Style.CheckMark, Font = Enum.Font.GothamBold, TextSize = 14,
    })
    button.Text = "     " .. tostring(label)
    if button:GetAttribute("ImGuiHoverConnected") ~= true then
        button:SetAttribute("ImGuiHoverConnected", true)
        button.MouseEnter:Connect(function() button.BackgroundColor3 = self.Style.HeaderHovered; button.BackgroundTransparency = 0.75 end)
        button.MouseLeave:Connect(function() button.BackgroundTransparency = 1 end)
    end
    check.Visible = value == true
    button:SetAttribute("ImGuiValue", value == true)
    self._callbacks = self._callbacks or {}
    self._callbacks[key] = callback
    if button:GetAttribute("ImGuiClickConnected") ~= true then
        button:SetAttribute("ImGuiClickConnected", true)
        button.Activated:Connect(function()
            if button:GetAttribute("ImGuiInputAllowed") ~= true then return end
            local nextValue = not (button:GetAttribute("ImGuiValue") == true)
            button:SetAttribute("ImGuiValue", nextValue)
            check.Visible = nextValue
            local fn = self._callbacks[key]
            if fn then fn(nextValue) end
        end)
    end
    return value == true
end

-- Matches Dear ImGui's RadioButton(label, active) interaction model.
-- Roblox's retained input events are exposed through a callback.
function ImGui:RadioButton(label, active, callback, id)
    local key = id or ("RadioButton:" .. tostring(label))
    local button = self:_add(key, "TextButton", {
        Name = "RadioButton", Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Font = self.Style.Font,
        TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local circle = button:FindFirstChild("Circle") or make("Frame", button, {
        Name = "Circle", Position = UDim2.fromOffset(1, 2),
        Size = UDim2.fromOffset(15, 15), BackgroundColor3 = self.Style.FrameBg,
        BackgroundTransparency = self.Style.FrameBgTransparency, BorderSizePixel = 0,
    })
    if not circle:FindFirstChildOfClass("UICorner") then
        make("UICorner", circle, { CornerRadius = UDim.new(1, 0) })
        make("UIStroke", circle, { Color = self.Style.Border, Thickness = 1 })
    end
    local dot = circle:FindFirstChild("Dot") or make("Frame", circle, {
        Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(7, 7),
        BackgroundColor3 = self.Style.Accent, BorderSizePixel = 0,
    })
    if not dot:FindFirstChildOfClass("UICorner") then
        make("UICorner", dot, { CornerRadius = UDim.new(1, 0) })
    end
    dot.Visible = active == true
    button.Text = "     " .. tostring(label)
    if button:GetAttribute("ImGuiHoverConnected") ~= true then
        button:SetAttribute("ImGuiHoverConnected", true)
        button.MouseEnter:Connect(function() button.BackgroundColor3 = self.Style.HeaderHovered; button.BackgroundTransparency = 0.75 end)
        button.MouseLeave:Connect(function() button.BackgroundTransparency = 1 end)
    end
    self._callbacks = self._callbacks or {}
    self._callbacks[key] = callback
    if button:GetAttribute("ImGuiClickConnected") ~= true then
        button:SetAttribute("ImGuiClickConnected", true)
        button.Activated:Connect(function()
            if button:GetAttribute("ImGuiInputAllowed") ~= true then return end
            local fn = self._callbacks[key]
            if fn then fn() end
        end)
    end
    return active == true
end

-- Dear ImGui-style normalized progress value with an optional overlay label.

-- Selectable: row selection with optional selected state and callback.
function ImGui:Selectable(label, selected, callback, id)
    local key = id or ("Selectable:" .. tostring(label))
    local button = self:_add(key, "TextButton", {
        Name = "Selectable", Size = UDim2.new(1, 0, 0, 20),
        BackgroundColor3 = selected and self.Style.HeaderActive or self.Style.Header,
        BackgroundTransparency = selected and 0.35 or 1,
        BorderSizePixel = 0, AutoButtonColor = false, Text = tostring(label),
        TextColor3 = self.Style.Text, Font = self.Style.Font, TextSize = self.Style.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    if button:GetAttribute("ImGuiSelectableConnected") ~= true then
        button:SetAttribute("ImGuiSelectableConnected", true)
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = self.Style.HeaderHovered
            button.BackgroundTransparency = 0.35
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = button:GetAttribute("ImGuiSelected") and self.Style.HeaderActive or self.Style.Header
            button.BackgroundTransparency = button:GetAttribute("ImGuiSelected") and 0.35 or 1
        end)
        button.Activated:Connect(function()
            if button:GetAttribute("ImGuiInputAllowed") ~= true then return end
            local fn = self._callbacks and self._callbacks[key]
            if fn then fn(not (button:GetAttribute("ImGuiSelected") == true)) end
        end)
    end
    button:SetAttribute("ImGuiSelected", selected == true)
    button.BackgroundColor3 = selected and self.Style.HeaderActive or self.Style.Header
    button.BackgroundTransparency = selected and 0.35 or 1
    self._callbacks = self._callbacks or {}
    self._callbacks[key] = callback
    return selected == true
end

-- Combo uses a Roblox-native popup list. selected is a 1-based index or an item string.
function ImGui:Combo(label, selected, items, callback, id)
    local key = id or ("Combo:" .. tostring(label))
    items = items or {}
    local selectedIndex = type(selected) == "number" and math.floor(selected) or table.find(items, selected)
    selectedIndex = math.clamp(selectedIndex or 1, 1, math.max(#items, 1))
    local frame = self:_add(key, "Frame", {
        Name = "Combo", Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
        ClipsDescendants = false, ZIndex = 5,
    })
    local title = frame:FindFirstChild("Label") or make("TextLabel", frame, {
        Name = "Label", Size = UDim2.new(0.36, 0, 1, 0), BackgroundTransparency = 1,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    title.Text = tostring(label)
    local choice = frame:FindFirstChild("Choice") or make("TextButton", frame, {
        Name = "Choice", Position = UDim2.new(0.38, 0, 0, 1), Size = UDim2.new(0.62, 0, 0, 24),
        BackgroundColor3 = self.Style.FrameBg, BackgroundTransparency = self.Style.FrameBgTransparency,
        BorderSizePixel = 0, AutoButtonColor = false, Font = self.Style.Font,
        TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
    })
    choice.Text = "  " .. tostring(items[selectedIndex] or "")
    local popup = frame:FindFirstChild("Popup") or make("Frame", frame, {
        Name = "Popup", Position = UDim2.new(0.38, 0, 0, 25),
        Size = UDim2.new(0.62, 0, 0, math.min(#items, 6) * 22),
        BackgroundColor3 = self.Style.PopupBg, BorderSizePixel = 1,
        BorderColor3 = self.Style.Border, Visible = false, ZIndex = 20,
    })
    popup.Size = UDim2.new(0.62, 0, 0, math.min(#items, 6) * 22)
    local layout = popup:FindFirstChildOfClass("UIListLayout") or make("UIListLayout", popup, { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0) })
    layout.Padding = UDim.new(0, 0)
    for index, item in ipairs(items) do
        local option = popup:FindFirstChild("Option_" .. index) or make("TextButton", popup, {
            Name = "Option_" .. index, Size = UDim2.new(1, 0, 0, 22),
            BackgroundColor3 = self.Style.PopupBg, BorderSizePixel = 0,
            AutoButtonColor = false, Font = self.Style.Font, TextSize = self.Style.FontSize,
            TextColor3 = self.Style.Text, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 21,
        })
        option.LayoutOrder = index
        option:SetAttribute("ImGuiOptionIndex", index)
        option.Text = "  " .. tostring(item)
        option.Visible = true
        option.BackgroundColor3 = index == selectedIndex and self.Style.HeaderActive or self.Style.PopupBg
        if option:GetAttribute("ImGuiOptionConnected") ~= true then
            option:SetAttribute("ImGuiOptionConnected", true)
            option.MouseEnter:Connect(function() option.BackgroundColor3 = self.Style.HeaderHovered end)
            option.MouseLeave:Connect(function()
                option.BackgroundColor3 = option:GetAttribute("ImGuiChosen") and self.Style.HeaderActive or self.Style.PopupBg
            end)
            option.Activated:Connect(function()
                if option:GetAttribute("ImGuiInputAllowed") ~= true then return end
                local selected = option:GetAttribute("ImGuiOptionIndex")
                frame:SetAttribute("ImGuiComboIndex", selected)
                choice.Text = "  " .. tostring(items[selected] or "")
                popup.Visible = false
                local fn = self._callbacks and self._callbacks[key]
                if fn then fn(selected, items[selected]) end
            end)
        end
        option:SetAttribute("ImGuiChosen", index == selectedIndex)
    end
    for _, child in ipairs(popup:GetChildren()) do
        if child:IsA("TextButton") then child.Visible = tonumber(child.Name:match("Option_(%d+)")) ~= nil
            and tonumber(child.Name:match("Option_(%d+)")) <= #items end
    end
    local function bindComboInput(target)
        if target:GetAttribute("ImGuiComboInputBound") == true then return end
        target:SetAttribute("ImGuiComboInputBound", true)
        target.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local owner = self.CurrentWindow
                local allowed = owner and owner.Focus and owner.Focus(input.Position) == true
                target:SetAttribute("ImGuiInputAllowed", allowed == true)
            end
        end)
    end
    bindComboInput(choice)
    for _, option in ipairs(popup:GetChildren()) do if option:IsA("TextButton") then bindComboInput(option) end end
    if choice:GetAttribute("ImGuiComboConnected") ~= true then
        choice:SetAttribute("ImGuiComboConnected", true)
        choice.Activated:Connect(function()
            if choice:GetAttribute("ImGuiInputAllowed") ~= true then return end
            popup.Visible = not popup.Visible
        end)
    end
    frame:SetAttribute("ImGuiComboIndex", selectedIndex)
    self._callbacks = self._callbacks or {}
    self._callbacks[key] = callback
    return selectedIndex
end

-- CollapsingHeader and TreeNode expose open state; gate child submissions with the returned boolean.
function ImGui:CollapsingHeader(label, id)
    local key = id or ("CollapsingHeader:" .. tostring(label))
    self._treeState = self._treeState or {}
    local open = self._treeState[key] == true
    local button = self:_add(key, "TextButton", {
        Name = "CollapsingHeader", Size = UDim2.new(1, 0, 0, 22),
        BackgroundColor3 = self.Style.Header, BackgroundTransparency = 0.65,
        BorderSizePixel = 0, AutoButtonColor = false, Font = self.Style.Font,
        TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = (open and "▾  " or "▸  ") .. tostring(label),
    })
    if button:GetAttribute("ImGuiHeaderConnected") ~= true then
        button:SetAttribute("ImGuiHeaderConnected", true)
        button.MouseEnter:Connect(function() button.BackgroundColor3 = self.Style.HeaderHovered end)
        button.MouseLeave:Connect(function() button.BackgroundColor3 = self.Style.Header end)
        button.Activated:Connect(function()
            if button:GetAttribute("ImGuiInputAllowed") ~= true then return end
            local nextOpen = not (self._treeState and self._treeState[key] == true)
            self._treeState[key] = nextOpen
            button:SetAttribute("ImGuiOpen", nextOpen)
            button.Text = (nextOpen and "▾  " or "▸  ") .. tostring(label)
        end)
    end
    button:SetAttribute("ImGuiOpen", open)
    return open
end

function ImGui:TreeNode(label, id)
    local key = id or ("TreeNode:" .. tostring(label))
    self._treeState = self._treeState or {}
    local open = self._treeState[key] == true
    local button = self:_add(key, "TextButton", {
        Name = "TreeNode", Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = (open and "▼  " or "▶  ") .. tostring(label),
    })
    if button:GetAttribute("ImGuiTreeConnected") ~= true then
        button:SetAttribute("ImGuiTreeConnected", true)
        button.Activated:Connect(function()
            if button:GetAttribute("ImGuiInputAllowed") ~= true then return end
            local nextOpen = not (self._treeState and self._treeState[key] == true)
            self._treeState[key] = nextOpen
            button:SetAttribute("ImGuiOpen", nextOpen)
            button.Text = (nextOpen and "▼  " or "▶  ") .. tostring(label)
        end)
    end
    button:SetAttribute("ImGuiOpen", open)
    return open
end

function ImGui:TreePop()
    -- Tree contents are conditionally submitted by the caller; this balances the Dear ImGui-style API.
end

function ImGui:BulletText(text)
    local frame = self:_add("BulletText:" .. tostring(text) .. ":" .. self._order, "Frame", {
        Name = "BulletText", Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
    })
    local bullet = frame:FindFirstChild("Bullet") or make("TextLabel", frame, {
        Name = "Bullet", Size = UDim2.fromOffset(12, 18), BackgroundTransparency = 1,
        Text = "•", TextColor3 = self.Style.Text, Font = self.Style.Font, TextSize = self.Style.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local textLabel = frame:FindFirstChild("Text") or make("TextLabel", frame, {
        Name = "Text", Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -12, 1, 0),
        BackgroundTransparency = 1, Text = tostring(text), TextColor3 = self.Style.Text,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextXAlignment = Enum.TextXAlignment.Left,
    })
    bullet.Text = "•"
    textLabel.Text = tostring(text)
    return frame
end

-- Image accepts a Roblox image asset/content ID or an existing image content string.
function ImGui:Image(image, size, config)
    config = config or {}
    local key = config.ID or ("Image:" .. tostring(image))
    local object = self:_add(key, "ImageLabel", {
        Name = "Image", Size = size or UDim2.fromOffset(64, 64),
        BackgroundTransparency = config.BackgroundTransparency == nil and 1 or config.BackgroundTransparency,
        BackgroundColor3 = config.BackgroundColor or self.Style.FrameBg,
        BorderSizePixel = 0, ScaleType = config.ScaleType or Enum.ScaleType.Fit,
        ImageColor3 = config.TintColor or Color3.new(1, 1, 1),
        ImageTransparency = config.ImageTransparency or 0,
    })
    object.Image = tostring(image or "")
    if config.Radius and not object:FindFirstChildOfClass("UICorner") then round(object, config.Radius) end
    return object
end

function ImGui:ProgressBar(fraction, size, overlay, id)
    local key = id or ("ProgressBar:" .. tostring(overlay or ""))
    local bar = self:_add(key, "Frame", {
        Name = "ProgressBar", Size = size or UDim2.new(1, 0, 0, 18),
        BackgroundColor3 = self.Style.FrameBg, BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    if not bar:FindFirstChildOfClass("UICorner") then round(bar, self.Style.FrameRounding) end
    local fill = bar:FindFirstChild("Fill") or make("Frame", bar, {
        Name = "Fill", BackgroundColor3 = self.Style.Accent, BorderSizePixel = 0,
    })
    fill.Size = UDim2.new(math.clamp(tonumber(fraction) or 0, 0, 1), 0, 1, 0)
    if not fill:FindFirstChildOfClass("UICorner") then round(fill, self.Style.FrameRounding) end
    local label = bar:FindFirstChild("Overlay") or make("TextLabel", bar, {
        Name = "Overlay", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = self.Style.Font, TextSize = self.Style.FontSize,
        TextColor3 = self.Style.Text, TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    label.Text = tostring(overlay or "")

    self._progressBars = self._progressBars or {}
    local controller = self._progressBars[key]
    if not controller then
        controller = { Frame = bar }
        function controller:SetFraction(nextFraction, nextOverlay)
            local fractionValue = math.clamp(tonumber(nextFraction) or 0, 0, 1)
            local currentBar = self.Frame
            local fillObject = currentBar and currentBar:FindFirstChild("Fill")
            local labelObject = currentBar and currentBar:FindFirstChild("Overlay")
            if fillObject then fillObject.Size = UDim2.new(fractionValue, 0, 1, 0) end
            if labelObject and nextOverlay ~= nil then labelObject.Text = tostring(nextOverlay) end
            self.Fraction = fractionValue
            return self
        end
        function controller:SetPercentage(percentage, nextOverlay)
            return self:SetFraction((tonumber(percentage) or 0) / 100, nextOverlay or (tostring(math.floor((tonumber(percentage) or 0) + 0.5)) .. "%"))
        end
        controller.SetValue = controller.SetFraction
        self._progressBars[key] = controller
    end
    controller.Frame = bar
    controller:SetFraction(fraction, overlay)
    return controller
end

function ImGui:SliderFloat(label, value, minValue, maxValue, callback, id)
    minValue, maxValue = minValue or 0, maxValue or 1
    assert(maxValue > minValue, "SliderFloat maxValue must be greater than minValue")
    local key = id or ("Slider:" .. tostring(label))
    local frame = self:_add(key, "Frame", {
        Name = "Slider", Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1,
    })
    local title = frame:FindFirstChild("Label") or make("TextLabel", frame, {
        Name = "Label", Position = UDim2.new(0.70, 0, 0, 0),
        Size = UDim2.new(0.30, 0, 1, 0), BackgroundTransparency = 1,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    })
    title.Text = tostring(label)
    local track = frame:FindFirstChild("Track") or make("TextButton", frame, {
        Name = "Track", Position = UDim2.fromOffset(0, 3), Size = UDim2.new(0.64, 0, 0, 18),
        BackgroundColor3 = self.Style.FrameBg, BackgroundTransparency = self.Style.FrameBgTransparency,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
    })
    if not track:FindFirstChildOfClass("UICorner") then round(track, self.Style.FrameRounding) end
    if track:GetAttribute("ImGuiHoverConnected") ~= true then
        track:SetAttribute("ImGuiHoverConnected", true)
        track.MouseEnter:Connect(function() track.BackgroundColor3 = self.Style.FrameBgHovered end)
        track.MouseLeave:Connect(function() track.BackgroundColor3 = self.Style.FrameBg end)
    end
    local fill = track:FindFirstChild("Fill") or make("Frame", track, {
        Name = "Fill", BackgroundColor3 = self.Style.Accent, BorderSizePixel = 0,
    })
    if not fill:FindFirstChildOfClass("UICorner") then round(fill, self.Style.FrameRounding) end
    local valueText = track:FindFirstChild("Value") or make("TextLabel", track, {
        Name = "Value", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = track.ZIndex + 2,
    })
    local grab = track:FindFirstChild("Grab") or make("Frame", track, {
        Name = "Grab", AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(self.Style.GrabMinSize, 18), BackgroundColor3 = self.Style.SliderGrab,
        BorderSizePixel = 0, ZIndex = track.ZIndex + 1,
    })
    local function positionGrab(alpha)
        grab.Position = UDim2.new(math.clamp(alpha, 0, 1), 0, 0.5, 0)
    end
    local function update(input)
        local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local nextValue = minValue + (maxValue - minValue) * alpha
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        positionGrab(alpha)
        valueText.Text = string.format("%.3f", nextValue)
        local fn = self._callbacks and self._callbacks[key]
        if fn then fn(nextValue) end
    end
    local initialAlpha = math.clamp((value - minValue) / (maxValue - minValue), 0, 1)
    fill.Size = UDim2.new(initialAlpha, 0, 1, 0)
    positionGrab(initialAlpha)
    valueText.Text = string.format("%.3f", value)
    self._callbacks = self._callbacks or {}
    self._callbacks[key] = callback
    if track:GetAttribute("ImGuiSliderConnected") ~= true then
        track:SetAttribute("ImGuiSliderConnected", true)
        local dragging = false
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if track:GetAttribute("ImGuiInputAllowed") ~= true then return end
                dragging = true
                update(input)
            end
        end)
        track.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end
        end))
    end
    return value
end

function ImGui:SliderInt(label, value, minValue, maxValue, callback, id)
    return self:SliderFloat(label, value, minValue, maxValue, function(nextValue)
        if callback then callback(math.floor(nextValue + 0.5)) end
    end, id)
end

function ImGui:InputText(label, value, callback, config)
    config = config or {}
    local key = config.ID or ("Input:" .. tostring(label))
    local frame = self:_add(key, "Frame", {
        Name = "InputText", Size = UDim2.new(1, 0, 0, config.Multiline and 58 or 26),
        BackgroundTransparency = 1,
    })
    local title = frame:FindFirstChild("Label") or make("TextLabel", frame, {
        Name = "Label", Position = UDim2.new(0.70, 0, 0, 0),
        Size = UDim2.new(0.30, 0, 0, 24), BackgroundTransparency = 1,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    })
    title.Text = tostring(label)
    local input = frame:FindFirstChild("Input") or make("TextBox", frame, {
        Name = "Input", Position = UDim2.fromOffset(0, 1),
        Size = UDim2.new(0.64, 0, 0, config.Multiline and 53 or 23),
        BackgroundColor3 = self.Style.FrameBg, BackgroundTransparency = self.Style.FrameBgTransparency,
        BorderSizePixel = 0, ClearTextOnFocus = false, Font = self.Style.Font, TextSize = self.Style.FontSize,
        TextColor3 = self.Style.Text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    if not input:FindFirstChildOfClass("UICorner") then round(input, self.Style.FrameRounding) end
    input.PlaceholderText = config.Placeholder or ""
    input.TextXAlignment = Enum.TextXAlignment.Left
    if input:GetAttribute("ImGuiFocusConnected") ~= true then
        input:SetAttribute("ImGuiFocusConnected", true)
        input.Focused:Connect(function() input.BackgroundColor3 = self.Style.FrameBgActive end)
        input.FocusLost:Connect(function() input.BackgroundColor3 = self.Style.FrameBg end)
    end
    input.MultiLine = config.Multiline == true
    if not input:IsFocused() then input.Text = tostring(value or "") end
    if input:GetAttribute("ImGuiTextConnected") ~= true then
        input:SetAttribute("ImGuiTextConnected", true)
        input:GetPropertyChangedSignal("Text"):Connect(function()
            local fn = self._callbacks and self._callbacks[key]
            if fn then fn(input.Text) end
        end)
    end
    self._callbacks = self._callbacks or {}
    self._callbacks[key] = callback
    return input.Text
end

function ImGui:Separator(text)
    local hasText = text ~= nil and tostring(text) ~= ""
    local frame = self:_add("Separator:" .. tostring(text or self._order), "Frame", {
        Name = "Separator", Size = UDim2.new(1, 0, 0, hasText and 22 or 8), BackgroundTransparency = 1,
    })
    local lineY = hasText and 11 or 4
    if not hasText then
        local line = frame:FindFirstChild("Line") or make("Frame", frame, {
            Name = "Line", Position = UDim2.new(0, 0, 0, lineY),
            Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = self.Style.Separator, BorderSizePixel = 0,
        })
        line.Size = UDim2.new(1, 0, 0, 1)
        line.BackgroundColor3 = self.Style.Separator
        return frame
    end

    local labelText = tostring(text)
    local measured = TextService:GetTextSize(labelText, self.Style.FontSize, self.Style.Font, Vector2.new(1000, 22))
    local labelWidth = math.ceil(measured.X) + 12
    local leftLine = frame:FindFirstChild("LeftLine") or make("Frame", frame, {
        Name = "LeftLine", Position = UDim2.new(0, 0, 0, lineY),
        Size = UDim2.new(0, 8, 0, 1), BackgroundColor3 = self.Style.Separator, BorderSizePixel = 0,
    })
    local label = frame:FindFirstChild("Label") or make("TextLabel", frame, {
        Name = "Label", Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0, labelWidth, 0, 22),
        BackgroundColor3 = self.Style.WindowBg, BorderSizePixel = 0,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 2,
    })
    local rightLine = frame:FindFirstChild("RightLine") or make("Frame", frame, {
        Name = "RightLine", Position = UDim2.new(0, 8 + labelWidth, 0, lineY),
        Size = UDim2.new(1, -(8 + labelWidth), 0, 1),
        BackgroundColor3 = self.Style.Separator, BorderSizePixel = 0,
    })
    label.Text = labelText
    label.Size = UDim2.new(0, labelWidth, 0, 22)
    label.ZIndex = 2
    leftLine.Size = UDim2.new(0, 8, 0, 1)
    rightLine.Position = UDim2.new(0, 8 + labelWidth, 0, lineY)
    rightLine.Size = UDim2.new(1, -(8 + labelWidth), 0, 1)
    return frame
end

function ImGui:Spacing()
    self:_add("Spacing:" .. self._order, "Frame", {
        Name = "Spacing", Size = UDim2.new(1, 0, 0, self.Style.ItemSpacing.Y), BackgroundTransparency = 1,
    })
end

function ImGui:BeginChild(id, size)
    assert(self._frameActive, "Call NewFrame() before BeginChild()")
    assert(self.CurrentParent, "Call Begin() before BeginChild()")
    self._order += 1
    local child = self:_widget("Child:" .. tostring(id), "ScrollingFrame", self.CurrentParent, {
        Name = "Child_" .. tostring(id), Size = size or UDim2.new(1, 0, 0, 120),
        BackgroundColor3 = self.Style.ChildBg, BackgroundTransparency = self.Style.ChildBgTransparency,
        BorderSizePixel = 0, ClipsDescendants = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollingEnabled = true,
        ScrollBarThickness = self.Style.ScrollbarSize, ScrollBarImageColor3 = self.Style.ScrollbarGrab,
    })
    if not child:FindFirstChildOfClass("UICorner") then round(child, self.Style.ChildRounding) end
    if not child:FindFirstChildOfClass("UIPadding") then
        make("UIPadding", child, {
            PaddingLeft = UDim.new(0, self.Style.WindowPadding.X),
            PaddingRight = UDim.new(0, self.Style.WindowPadding.X),
            PaddingTop = UDim.new(0, self.Style.WindowPadding.Y),
            PaddingBottom = UDim.new(0, self.Style.WindowPadding.Y),
        })
    end
    if not child:FindFirstChildOfClass("UIListLayout") then vertical(child, self.Style.ItemSpacing.Y) end
    table.insert(self.WindowStack, { Window = self.CurrentWindow, Parent = self.CurrentParent, Scope = self._scope, Order = self._order })
    self._scope = self._scope .. "/Child:" .. tostring(id)
    self.CurrentParent = child
    self._order = 0
    return true
end

function ImGui:EndChild() self:End() end

function ImGui:ShowDemoWindow()
    if self:Begin("Roblox-ImGui demo", { Size = UDim2.fromOffset(440, 350) }) then
        self:Text("Roblox-ImGui " .. self.Version, { Color = self.Style.Accent })
        self:Separator("Widgets")
        self:Button("Print to output", { Callback = function() print("Roblox-ImGui button clicked") end })
        self._demoChecked = self._demoChecked == true
        self:Checkbox("Demo checkbox", self._demoChecked, function(v) self._demoChecked = v end, "demo-check")
        self._demoFloat = self._demoFloat or 0.35
        self:SliderFloat("Float value", self._demoFloat, 0, 1, function(v) self._demoFloat = v end, "demo-float")
        self._demoInt = self._demoInt or 5
        self:SliderInt("Integer value", self._demoInt, 0, 10, function(v) self._demoInt = v end, "demo-int")
        self._demoText = self._demoText or "Edit me"
        self:InputText("Text input", self._demoText, function(v) self._demoText = v end, { ID = "demo-input" })
    end
    self:End()
end

function ImGui:Render()
    assert(not self._destroyed, "This ImGui context has been destroyed")
    assert(self._frameActive, "Render() called without NewFrame()")
    assert(#self.WindowStack == 0, "Unclosed Begin()/BeginChild(): call End()/EndChild() before Render()")
    for _, object in pairs(self.Widgets) do
        if object.Parent then object.Visible = object:GetAttribute("ImGuiLastSeen") == self.FrameNumber end
    end
    for _, window in pairs(self.Windows) do
        if window.Root.Parent then window.Root.Visible = window.Visible end
    end
    self._frameActive = false
end

function ImGui:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self._frameActive = false
    for _, connection in ipairs(self._connections) do connection:Disconnect() end
    self.ScreenGui:Destroy()
    table.clear(self.Widgets)
    table.clear(self.Windows)
    table.clear(self.WindowStack)
    table.clear(self._scopeStack)
    table.clear(self._callbacks or {})
    table.clear(self._progressBars or {})
 
end

return ImGui
