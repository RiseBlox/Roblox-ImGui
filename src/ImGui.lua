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
    Button = Color3.fromRGB(41, 74, 122), ButtonHovered = Color3.fromRGB(83, 164, 255),
    ButtonActive = Color3.fromRGB(66, 112, 169),
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
        FrameNumber = 0, _idStack = {}, _order = 0, _windowOrder = 0,
        _connections = {}, _callbacks = {}, _treeState = {}, _progressBars = {},
        _frameActive = false, _destroyed = false, _treeStack = {},
        _lastItem = nil, _sameLineRow = nil, _sameLineRequested = false,
        _indentStack = {}, _groupStack = {}, _itemWidthStack = {}, _nextItemWidth = nil, _columnsStack = {}, _columnWidths = {},
    }, ImGui)
    for key, value in pairs(config.Style or {}) do self.Style[key] = value end

    return self
end

function ImGui:PushID(id)
    assert(self._frameActive, "PushID() must be called between NewFrame() and Render()")
    table.insert(self._idStack, tostring(id))
end

function ImGui:PopID()
    assert(self._frameActive, "PopID() must be called between NewFrame() and Render()")
    assert(#self._idStack > 0, "PopID() called without a matching PushID()")
    table.remove(self._idStack)
end
function ImGui:GetID(id)
    local prefix = table.concat(self._idStack, "/")
    return (prefix ~= "" and prefix .. "/" or "") .. tostring(id)
end

-- Match _widget() identity exactly so callbacks cannot collide across windows,
-- child regions, tree scopes, or explicit PushID() scopes.
function ImGui:_callbackKey(id)
    local localKey = self:GetID(id)
    return (self._scope ~= "" and self._scope .. "/" or "") .. localKey
end

-- Centralized connection ownership. Every event listener created by this context is
-- registered here so Destroy() can disconnect it, including global input listeners.
function ImGui:_connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self._connections, connection)
    return connection
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
    object:SetAttribute("ImGuiWidgetKey", key)
    object:SetAttribute("ImGuiLastSeen", self.FrameNumber)

    -- Any click on a widget makes its owning window active.
    local currentWindow = self.CurrentWindow
    if currentWindow and object:GetAttribute("ImGuiFocusConnected") ~= true then
        object:SetAttribute("ImGuiFocusConnected", true)
        local function activateOwner()
            if currentWindow and currentWindow.Focus then currentWindow.Focus() end
        end
        self:_connect(object.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                local accepted = currentWindow and currentWindow.Focus and currentWindow.Focus(input.Position) == true
                object:SetAttribute("ImGuiInputAllowed", accepted == true)
            end
        end)
    end
    return object
end

local function measuredItemWidth(object)
    local width = object.AbsoluteSize.X
    if object:IsA("TextLabel") then
        width = math.max(object.TextBounds.X + 2, 1)
    elseif object:IsA("TextButton") and object.AutomaticSize == Enum.AutomaticSize.X then
        width = math.max(object.AbsoluteSize.X, object.TextBounds.X + 12)
    end
    return math.max(math.floor(width + 0.5), 1)
end

local function makeHorizontalRow(self, previous)
    local parent = self.CurrentParent
    local itemKey = previous:GetAttribute("ImGuiWidgetKey") or previous.Name
    local row = self:_widget("SameLineRow:" .. itemKey, "Frame", parent, {
        Name = "ImGuiSameLineRow", BackgroundTransparency = 1,
        BorderSizePixel = 0, Active = false, Size = UDim2.new(1, 0, 0, math.max(previous.AbsoluteSize.Y, previous.Size.Y.Offset, 1)),
    })
    if not row:FindFirstChildOfClass("UIListLayout") then
        make("UIListLayout", row, {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, self.Style.ItemInnerSpacing.X),
            VerticalAlignment = Enum.VerticalAlignment.Center,
        })
    end
    row.LayoutOrder = previous.LayoutOrder
    previous.Parent = row
    previous.Size = UDim2.fromOffset(measuredItemWidth(previous), math.max(previous.AbsoluteSize.Y, previous.Size.Y.Offset, 1))
    previous.AutomaticSize = Enum.AutomaticSize.None
    previous.LayoutOrder = 1
    return row
end

function ImGui:_add(id, className, properties)
    assert(self._frameActive, "Call NewFrame() before creating widgets")
    assert(self.CurrentParent, "Call Begin() before creating widgets")
    self._order += 1
    local parent = self.CurrentParent
    local row = self._sameLineRequested and self._sameLineRow or nil
    if row then
        parent = row
    else
        self._sameLineRow = nil
    end
    local object = self:_widget(id, className, parent, properties)
    if row then
        local height = math.max(object.AbsoluteSize.Y, object.Size.Y.Offset, 1)
        object.Size = UDim2.fromOffset(measuredItemWidth(object), height)
        object.AutomaticSize = Enum.AutomaticSize.None
        object.LayoutOrder = #row:GetChildren()
        row.Size = UDim2.new(1, 0, 0, math.max(row.Size.Y.Offset, height))
    end
    self._sameLineRequested = false
    self._lastItem = object
    return object
end

function ImGui:NewFrame()
    assert(not self._destroyed, "This ImGui context has been destroyed")
    assert(not self._frameActive, "NewFrame() called before the previous frame was rendered")
    self.FrameNumber += 1
    self._order = 0
    self.WindowStack = {}
    self._scopeStack = {}
    self._treeStack = {}
    self._lastItem, self._sameLineRow, self._sameLineRequested = nil, nil, false
    self._indentStack, self._groupStack = {}, {}
    self._itemWidthStack, self._nextItemWidth = {}, nil
    self._columnsStack = {}
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
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        ScrollBarThickness = style.ScrollbarSize, ScrollBarImageColor3 = style.ScrollbarGrab,
        ScrollBarImageTransparency = 0,
    })
    make("UIPadding", content, {
        PaddingLeft = UDim.new(0, style.WindowPadding.X),
        -- Match the left inset so controls and text have balanced margins.
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
    self:_connect(title.MouseEnter, function()
        if self._focusedWindowName ~= name then title.BackgroundColor3 = style.TitleBgHovered end
    end)
    self:_connect(title.MouseLeave, function()
        if self._focusedWindowName ~= name then title.BackgroundColor3 = style.TitleBg end
    end)
    self:_connect(title.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            focusWindow(input.Position)
        end
    end)

    local dragOrigin, startPosition
    self:_connect(title.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if focusWindow(input.Position) ~= true then return end
            dragOrigin, startPosition = input.Position, root.Position
        end
    end)
    self:_connect(UserInputService.InputChanged, function(input)
        if not dragOrigin or not startPosition then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragOrigin
        root.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragOrigin, startPosition = nil, nil
        end
    end)
    -- Clicking empty space in the window body also activates the window.
    local function focusOnPointer(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            focusWindow(input.Position)
        end
    end
    self:_connect(root.InputBegan, focusOnPointer)
    self:_connect(content.InputBegan, focusOnPointer)
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
    table.insert(self.WindowStack, { Kind = "Window", Window = self.CurrentWindow, Parent = self.CurrentParent, Scope = self._scope, Order = self._order, LastItem = self._lastItem, SameLineRow = self._sameLineRow, SameLineRequested = self._sameLineRequested })
    self._lastItem, self._sameLineRow, self._sameLineRequested = nil, nil, false
    self._scope = "Window:" .. tostring(name)
    self.CurrentWindow, self.CurrentParent = window, window.Content
    self._order = 0
    return window.Visible
end

function ImGui:End()
    assert(#self.WindowStack > 0, "End() called without a matching Begin()")
    assert(self.WindowStack[#self.WindowStack].Kind == "Window", "End() cannot close a child region; call EndChild()")
    local previous = table.remove(self.WindowStack)
    self.CurrentWindow, self.CurrentParent = previous.Window, previous.Parent
    self._scope = previous.Scope
    self._order = previous.Order
    self._lastItem, self._sameLineRow, self._sameLineRequested = previous.LastItem, previous.SameLineRow, previous.SameLineRequested
end

local function justifyText(text, width, font, fontSize)
    width = math.max(width - 2, 1)
    local output = {}
    local function measure(value)
        return TextService:GetTextSize(value, fontSize, font, Vector2.new(10000, fontSize + 4)).X
    end

    for paragraph in (text .. "\n"):gmatch("(.-)\n") do
        if paragraph == "" then
            table.insert(output, "")
        else
            local words = {}
            for word in paragraph:gmatch("%S+") do
                table.insert(words, word)
            end

            local lines, current = {}, {}
            for _, word in ipairs(words) do
                local candidate = table.concat(current, " ")
                candidate = candidate == "" and word or (candidate .. " " .. word)
                if #current > 0 and measure(candidate) > width then
                    table.insert(lines, current)
                    current = {word}
                else
                    table.insert(current, word)
                end
            end
            if #current > 0 then
                table.insert(lines, current)
            end

            for lineIndex, lineWords in ipairs(lines) do
                local gapCount = #lineWords - 1
                if gapCount <= 0 or lineIndex == #lines then
                    table.insert(output, table.concat(lineWords, " "))
                else
                    local gaps = table.create(gapCount, " ")
                    local function build()
                        local pieces = {lineWords[1]}
                        for i = 1, gapCount do
                            table.insert(pieces, gaps[i])
                            table.insert(pieces, lineWords[i + 1])
                        end
                        return table.concat(pieces)
                    end

                    -- Add spacing evenly, but never allow the rendered line
                    -- to exceed the measured safe width.
                    local gapIndex = 1
                    while true do
                        gaps[gapIndex] ..= " "
                        if measure(build()) > width then
                            gaps[gapIndex] = string.sub(gaps[gapIndex], 1, -2)
                            break
                        end
                        gapIndex = gapIndex % gapCount + 1
                    end
                    table.insert(output, build())
                end
            end
        end
    end
    return table.concat(output, "\n")
end

function ImGui:Text(text, config)
    config = config or {}
    local label = self:_add(config.ID or ("Text:" .. tostring(text)), "TextLabel", {
        Name = "Text", BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 18), Font = config.Font or self.Style.Font,
        TextSize = config.TextSize or self.Style.FontSize, TextColor3 = config.Color or self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = config.Wrap ~= false and config.RichText == true,
        RichText = config.RichText == true,
    })
    local rawText = tostring(text == nil and "" or text)
    -- Put the safety margin inside the TextLabel itself. Unlike changing a
    -- ScrollingFrame's canvas or child Size, UIPadding constrains the label's
    -- text-rendering rectangle, so glyphs cannot paint beneath the scrollbar.
    local textPadding = label:FindFirstChild("ImGuiTextSafetyPadding")
    if not textPadding then
        textPadding = make("UIPadding", label, {
            Name = "ImGuiTextSafetyPadding",
            PaddingRight = UDim.new(0, 0),
        })
    else
        textPadding.PaddingRight = UDim.new(0, 0)
    end
    if config.Wrap == false or config.Align ~= nil or config.RichText == true then
        label.TextWrapped = config.Wrap ~= false
        label.Text = rawText
    else
        label.TextWrapped = false
        local function refreshJustification()
            if not label.Parent then return end
            -- The owning window/child ScrollingFrame reserves scrollbar space
            -- through its right UIPadding, so the label's own width is the true
            -- usable text width. Do not subtract the scrollbar twice here.
            -- The parent content container owns the shared right gutter.
            -- Do not add another per-label inset: that made otherwise identical
            -- windows end their justified lines at different positions.
            local width = math.max(label.AbsoluteSize.X, 1)
            label.Text = justifyText(rawText, width, config.Font or self.Style.Font, config.TextSize or self.Style.FontSize)
        end
        refreshJustification()
        if label:GetAttribute("ImGuiJustifyConnected") ~= true then
            label:SetAttribute("ImGuiJustifyConnected", true)
            self:_connect(label:GetPropertyChangedSignal("AbsoluteSize"), refreshJustification)
        end
    end
    return label
end

function ImGui:Button(label, config)
    config = config or {}
    local key = config.ID or ("Button:" .. tostring(label))
    local button = self:_add(key, "TextButton", {
        Name = "Button", Size = config.Size or UDim2.new(0, 0, 0, 24),
        AutomaticSize = config.Size and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
        -- These are the idle defaults. The interaction state is reapplied
        -- below on every submission so the frame loop cannot erase hover/press.
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

    local function refreshButtonVisual()
        local pressed = button:GetAttribute("ImGuiPressed") == true
        local hovered = button:GetAttribute("ImGuiHovered") == true
        if pressed then
            button.BackgroundColor3 = self.Style.ButtonActive
            button.BackgroundTransparency = 0
        elseif hovered then
            button.BackgroundColor3 = self.Style.ButtonHovered
            button.BackgroundTransparency = 0
        else
            button.BackgroundColor3 = self.Style.Button
            button.BackgroundTransparency = 0.12
        end
        button.TextColor3 = self.Style.Text
    end

    if button:GetAttribute("ImGuiClickConnected") ~= true then
        button:SetAttribute("ImGuiClickConnected", true)
        button:SetAttribute("ImGuiHovered", false)
        button:SetAttribute("ImGuiPressed", false)

        self:_connect(button.MouseEnter, function()
            button:SetAttribute("ImGuiHovered", true)
            refreshButtonVisual()
        end)
        self:_connect(button.MouseLeave, function()
            button:SetAttribute("ImGuiHovered", false)
            refreshButtonVisual()
        end)
        self:_connect(button.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                button:SetAttribute("ImGuiPressed", true)
                refreshButtonVisual()
            end
        end)
        self:_connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                button:SetAttribute("ImGuiPressed", false)
                refreshButtonVisual()
            end
        end)
        self:_connect(button.Activated, function()
            if button:GetAttribute("ImGuiInputAllowed") ~= true then return end
            local callback = self._callbacks and self._callbacks[self:_callbackKey(key)]
            if callback then callback() end
        end)
    end

    self._callbacks = self._callbacks or {}
    self._callbacks[self:_callbackKey(key)] = config.Callback
    -- _widget reapplies its property table every frame. Reassert the state
    -- after that reset so hover and active feedback remains visible.
    refreshButtonVisual()
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
        self:_connect(button.MouseEnter, function() button.BackgroundColor3 = self.Style.HeaderHovered; button.BackgroundTransparency = 0.75 end)
        self:_connect(button.MouseLeave, function() button.BackgroundTransparency = 1 end)
    end
    check.Visible = value == true
    button:SetAttribute("ImGuiValue", value == true)
    self._callbacks = self._callbacks or {}
    self._callbacks[self:_callbackKey(key)] = callback
    if button:GetAttribute("ImGuiClickConnected") ~= true then
        button:SetAttribute("ImGuiClickConnected", true)
        self:_connect(button.Activated, function()
            if button:GetAttribute("ImGuiInputAllowed") ~= true then return end
            local nextValue = not (button:GetAttribute("ImGuiValue") == true)
            button:SetAttribute("ImGuiValue", nextValue)
            check.Visible = nextValue
            local fn = self._callbacks[self:_callbackKey(key)]
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
        self:_connect(button.MouseEnter, function() button.BackgroundColor3 = self.Style.HeaderHovered; button.BackgroundTransparency = 0.75 end)
        self:_connect(button.MouseLeave, function() button.BackgroundTransparency = 1 end)
    end
    self._callbacks = self._callbacks or {}
    self._callbacks[self:_callbackKey(key)] = callback
    if button:GetAttribute("ImGuiClickConnected") ~= true then
        button:SetAttribute("ImGuiClickConnected", true)
        self:_connect(button.Activated, function()
            if button:GetAttribute("ImGuiInputAllowed") ~= true then return end
            local fn = self._callbacks[self:_callbackKey(key)]
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
        self:_connect(button.MouseEnter, function()
            button.BackgroundColor3 = self.Style.HeaderHovered
            button.BackgroundTransparency = 0.35
        end)
        self:_connect(button.MouseLeave, function()
            button.BackgroundColor3 = button:GetAttribute("ImGuiSelected") and self.Style.HeaderActive or self.Style.Header
            button.BackgroundTransparency = button:GetAttribute("ImGuiSelected") and 0.35 or 1
        end)
        self:_connect(button.Activated, function()
            if button:GetAttribute("ImGuiInputAllowed") ~= true then return end
            local fn = self._callbacks and self._callbacks[self:_callbackKey(key)]
            if fn then fn(not (button:GetAttribute("ImGuiSelected") == true)) end
        end)
    end
    button:SetAttribute("ImGuiSelected", selected == true)
    button.BackgroundColor3 = selected and self.Style.HeaderActive or self.Style.Header
    button.BackgroundTransparency = selected and 0.35 or 1
    self._callbacks = self._callbacks or {}
    self._callbacks[self:_callbackKey(key)] = callback
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
        Name = "Label", Size = UDim2.new(0.38, -8, 1, 0), BackgroundTransparency = 1,
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
        BorderColor3 = self.Style.Border, Visible = false, ZIndex = 20, ClipsDescendants = true,
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
            self:_connect(option.MouseEnter, function() option.BackgroundColor3 = self.Style.HeaderHovered end)
            self:_connect(option.MouseLeave, function()
                option.BackgroundColor3 = option:GetAttribute("ImGuiChosen") and self.Style.HeaderActive or self.Style.PopupBg
            end)
            self:_connect(option.Activated, function()
                if option:GetAttribute("ImGuiInputAllowed") ~= true then return end
                local selected = option:GetAttribute("ImGuiOptionIndex")
                frame:SetAttribute("ImGuiComboIndex", selected)
                choice.Text = "  " .. tostring(items[selected] or "")
                popup.Visible = false
                local fn = self._callbacks and self._callbacks[self:_callbackKey(key)]
                if fn then fn(selected, items[selected]) end
            end)
        end
        option:SetAttribute("ImGuiChosen", index == selectedIndex)
    end
    for _, child in ipairs(popup:GetChildren()) do
        if child:IsA("TextButton") then child.Visible = tonumber(child.Name:match("Option_(%d+)")) ~= nil
            and tonumber(child.Name:match("Option_(%d+)")) <= #items end
    end
    local ownerWindow = self.CurrentWindow
    local function bindComboInput(target)
        if target:GetAttribute("ImGuiComboInputBound") == true then return end
        target:SetAttribute("ImGuiComboInputBound", true)
        self:_connect(target.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local allowed = ownerWindow and ownerWindow.Focus and ownerWindow.Focus(input.Position) == true
                target:SetAttribute("ImGuiInputAllowed", allowed == true)
            end
        end)
    end
    bindComboInput(choice)
    for _, option in ipairs(popup:GetChildren()) do if option:IsA("TextButton") then bindComboInput(option) end end
    if choice:GetAttribute("ImGuiComboConnected") ~= true then
        choice:SetAttribute("ImGuiComboConnected", true)
        self:_connect(choice.Activated, function()
            if choice:GetAttribute("ImGuiInputAllowed") ~= true then return end
            popup.Visible = not popup.Visible
        end)
    end
    frame:SetAttribute("ImGuiComboIndex", selectedIndex)
    self._callbacks = self._callbacks or {}
    self._callbacks[self:_callbackKey(key)] = callback
    return selectedIndex
end

-- CollapsingHeader and TreeNode expose open state; gate child submissions with the returned boolean.
function ImGui:CollapsingHeader(label, id)
    local key = id or ("CollapsingHeader:" .. tostring(label))
    local stateKey = self:_callbackKey(key)
    self._treeState = self._treeState or {}
    local open = self._treeState[stateKey] == true
    local button = self:_add(key, "TextButton", {
        Name = "CollapsingHeader", Size = UDim2.new(1, 0, 0, 22),
        BackgroundColor3 = self.Style.Header, BackgroundTransparency = 0.65,
        BorderSizePixel = 0, AutoButtonColor = false, Font = self.Style.Font,
        TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = (open and "▾  " or "▸  ") .. tostring(label),
    })
    if button:GetAttribute("ImGuiHeaderConnected") ~= true then
        button:SetAttribute("ImGuiHeaderConnected", true)
        self:_connect(button.MouseEnter, function() button.BackgroundColor3 = self.Style.HeaderHovered end)
        self:_connect(button.MouseLeave, function() button.BackgroundColor3 = self.Style.Header end)
        self:_connect(button.Activated, function()
            if button:GetAttribute("ImGuiInputAllowed") ~= true then return end
            local nextOpen = not (self._treeState and self._treeState[stateKey] == true)
            self._treeState[stateKey] = nextOpen
            button:SetAttribute("ImGuiOpen", nextOpen)
            button.Text = (nextOpen and "▾  " or "▸  ") .. tostring(label)
        end)
    end
    button:SetAttribute("ImGuiOpen", open)
    return open
end

function ImGui:TreeNode(label, id)
    local key = id or ("TreeNode:" .. tostring(label))
    local stateKey = self:_callbackKey(key)
    self._treeState = self._treeState or {}
    local open = self._treeState[stateKey] == true
    local button = self:_add(key, "TextButton", {
        Name = "TreeNode", Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = (open and "▼  " or "▶  ") .. tostring(label),
    })
    if button:GetAttribute("ImGuiTreeConnected") ~= true then
        button:SetAttribute("ImGuiTreeConnected", true)
        self:_connect(button.Activated, function()
            if button:GetAttribute("ImGuiInputAllowed") ~= true then return end
            local nextOpen = not (self._treeState and self._treeState[stateKey] == true)
            self._treeState[stateKey] = nextOpen
            button:SetAttribute("ImGuiOpen", nextOpen)
            button.Text = (nextOpen and "▼  " or "▶  ") .. tostring(label)
        end)
    end
    button:SetAttribute("ImGuiOpen", open)
    if open then
        local parent = self.CurrentParent
        local children = self:_widget("TreeChildren:" .. key, "Frame", parent, {
            Name = "TreeChildren", Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        })
        if not children:FindFirstChildOfClass("UIPadding") then
            make("UIPadding", children, { PaddingLeft = UDim.new(0, 14) })
        end
        if not children:FindFirstChildOfClass("UIListLayout") then vertical(children, self.Style.ItemSpacing.Y) end
        table.insert(self._treeStack, {
            Parent = self.CurrentParent, Scope = self._scope, Order = self._order,
        })
        self.CurrentParent = children
        self._scope = self._scope .. "/Tree:" .. key
        self._order = 0
    end
    return open
end

function ImGui:TreePop()
    assert(#self._treeStack > 0, "TreePop() called without a matching open TreeNode()")
    local previous = table.remove(self._treeStack)
    self.CurrentParent, self._scope, self._order = previous.Parent, previous.Scope, previous.Order
end

-- BulletText uses a 1-based nesting level: filled circle, hollow circle, square.
-- Levels beyond three repeat the marker pattern while continuing to indent.
function ImGui:BulletText(text, level)
    level = math.max(1, math.floor(tonumber(level) or 1))
    local markers = { "•", "◦", "▪" }
    local marker = markers[((level - 1) % #markers) + 1]
    local indent = (level - 1) * 14
    local frame = self:_add("BulletText:" .. tostring(text) .. ":" .. tostring(level) .. ":" .. self._order, "Frame", {
        Name = "BulletText", Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
    })
    local bullet = frame:FindFirstChild("Bullet") or make("TextLabel", frame, {
        Name = "Bullet", Size = UDim2.fromOffset(12, 18), BackgroundTransparency = 1,
        TextColor3 = self.Style.Text, Font = self.Style.Font, TextSize = self.Style.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local textLabel = frame:FindFirstChild("Text") or make("TextLabel", frame, {
        Name = "Text", BackgroundTransparency = 1, TextColor3 = self.Style.Text,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextXAlignment = Enum.TextXAlignment.Left,
    })
    bullet.Position = UDim2.fromOffset(indent, 0)
    bullet.Text = marker
    textLabel.Position = UDim2.fromOffset(indent + 12, 0)
    textLabel.Size = UDim2.new(1, -(indent + 12), 1, 0)
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
    local itemWidth, availableWidth = self:_consumeItemWidth(0.64)
    local key = id or ("Slider:" .. tostring(label))
    local frame = self:_add(key, "Frame", {
        Name = "Slider", Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
    })
    local title = frame:FindFirstChild("Label") or make("TextLabel", frame, {
        Name = "Label", Position = UDim2.fromOffset(itemWidth + 8, 0),
        Size = UDim2.new(1, -(itemWidth + 8), 1, 0), BackgroundTransparency = 1,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    })
    title.Text = tostring(label)
    title.Position = UDim2.fromOffset(itemWidth + 8, 0)
    title.Size = UDim2.new(1, -(itemWidth + 8), 1, 0)
    local track = frame:FindFirstChild("Track") or make("TextButton", frame, {
        Name = "Track", Position = UDim2.new(0, 0, 0.5, -9), Size = UDim2.fromOffset(itemWidth, 18),
        BackgroundColor3 = self.Style.FrameBg, BackgroundTransparency = self.Style.FrameBgTransparency,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
    })
    track.Size = UDim2.fromOffset(itemWidth, 18)
    track.ClipsDescendants = true
    if not track:FindFirstChildOfClass("UICorner") then round(track, self.Style.FrameRounding) end

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
    if track:GetAttribute("ImGuiHoverConnected") ~= true then
        track:SetAttribute("ImGuiHoverConnected", true)
        track:SetAttribute("ImGuiHovered", false)
        track:SetAttribute("ImGuiPressed", false)
        self:_connect(track.MouseEnter, function()
            track:SetAttribute("ImGuiHovered", true)
        end)
        self:_connect(track.MouseLeave, function()
            track:SetAttribute("ImGuiHovered", false)
        end)
        self:_connect(track.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                track:SetAttribute("ImGuiPressed", true)
            end
        end)
        self:_connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                track:SetAttribute("ImGuiPressed", false)
            end
        end)
    end
    local function refreshSliderVisual()
        local pressed = track:GetAttribute("ImGuiPressed") == true
        local hovered = track:GetAttribute("ImGuiHovered") == true
        -- Reapply interaction colors after the retained widget's per-frame defaults.
        track.BackgroundColor3 = hovered and not pressed and self.Style.FrameBgHovered or self.Style.FrameBg
        track.BackgroundTransparency = hovered and not pressed and 0.08 or self.Style.FrameBgTransparency
        grab.BackgroundColor3 = pressed and self.Style.ButtonActive
            or hovered and self.Style.ButtonHovered or self.Style.SliderGrab
        local grabWidth = pressed and 14 or hovered and 12 or self.Style.GrabMinSize
        grab.Size = UDim2.fromOffset(grabWidth, 18)
    end
    local function positionGrab(alpha)
        grab.Position = UDim2.new(math.clamp(alpha, 0, 1), 0, 0.5, 0)
    end
    local function update(input)
        local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local nextValue = minValue + (maxValue - minValue) * alpha
        -- Keep a single movable grab visible across the entire range.
        positionGrab(alpha)
        valueText.Text = string.format("%.3f", nextValue)
        local fn = self._callbacks and self._callbacks[self:_callbackKey(key)]
        if fn then fn(nextValue) end
    end
    value = math.clamp(tonumber(value) or minValue, minValue, maxValue)
    local initialAlpha = math.clamp((value - minValue) / (maxValue - minValue), 0, 1)
    grab.Visible = true
    positionGrab(initialAlpha)
    valueText.Text = string.format("%.3f", value)
    self._callbacks = self._callbacks or {}
    self._callbacks[self:_callbackKey(key)] = callback
    refreshSliderVisual()
    if track:GetAttribute("ImGuiSliderConnected") ~= true then
        track:SetAttribute("ImGuiSliderConnected", true)
        local dragging = false
        local ownerWindow = self.CurrentWindow
        self:_connect(track.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local allowed = ownerWindow and ownerWindow.Focus and ownerWindow.Focus(input.Position) == true
                track:SetAttribute("ImGuiInputAllowed", allowed == true)
                if not allowed then return end
                dragging = true
                update(input)
            end
        end)
        self:_connect(track.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        self:_connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end
        end)
    end
    return value
end

function ImGui:SliderInt(label, value, minValue, maxValue, callback, id)
    return self:SliderFloat(label, value, minValue, maxValue, function(nextValue)
        if callback then callback(math.floor(nextValue + 0.5)) end
    end, id)
end


-- Numeric drag controls. Horizontal pointer movement changes the value by speed per pixel.
function ImGui:DragFloat(label, value, speed, minValue, maxValue, callback, id, integer)
    speed = tonumber(speed) or 0.01
    minValue, maxValue = tonumber(minValue), tonumber(maxValue)
    assert(speed > 0, "DragFloat speed must be greater than zero")
    assert(not (minValue and maxValue) or maxValue > minValue, "DragFloat maxValue must be greater than minValue")
    value = tonumber(value) or 0
    if minValue then value = math.max(value, minValue) end
    if maxValue then value = math.min(value, maxValue) end
    local itemWidth, availableWidth = self:_consumeItemWidth(0.62)
    local key = id or ("DragFloat:" .. tostring(label))
    local frame = self:_add(key, "Frame", {Name = "DragFloat", Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1})
    local title = frame:FindFirstChild("Label") or make("TextLabel", frame, {
        Name = "Label", Size = UDim2.new(0.36, 0, 1, 0), BackgroundTransparency = 1,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    })
    title.Text = tostring(label)
    title.Size = UDim2.new(1, -(itemWidth + 8), 1, 0)
    local drag = frame:FindFirstChild("Drag") or make("TextButton", frame, {
        Name = "Drag", Position = UDim2.new(1, -itemWidth, 0, 1), Size = UDim2.fromOffset(itemWidth, 24),
        BackgroundColor3 = self.Style.FrameBg, BackgroundTransparency = self.Style.FrameBgTransparency,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "", Font = self.Style.Font,
        TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
    })
    drag.Position = UDim2.new(1, -itemWidth, 0, 1)
    drag.Size = UDim2.fromOffset(itemWidth, 24)
    if not drag:FindFirstChildOfClass("UICorner") then round(drag, self.Style.FrameRounding) end
    local dragFill = drag:FindFirstChild("Fill") or make("Frame", drag, {
        Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = self.Style.Accent,
        BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = drag.ZIndex,
    })
    if not dragFill:FindFirstChildOfClass("UICorner") then round(dragFill, self.Style.FrameRounding) end
    local valueLabel = drag:FindFirstChild("Value") or make("TextLabel", drag, {
        Name = "Value", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = drag.ZIndex + 1,
    })
    local function formatDragValue(number)
        return integer and string.format("%d", math.floor(number + 0.5)) or string.format("%.3f", number)
    end
    local function updateDragFill(number)
        if minValue ~= nil and maxValue ~= nil then
            dragFill.Size = UDim2.new(math.clamp((number - minValue) / (maxValue - minValue), 0, 1), 0, 1, 0)
        else
            dragFill.Size = UDim2.fromScale(0, 1)
        end
    end
    valueLabel.Text = formatDragValue(value)
    if drag:GetAttribute("ImGuiDragFillInitialized") ~= true then
        updateDragFill(value)
        drag:SetAttribute("ImGuiDragFillInitialized", true)
    elseif drag:GetAttribute("ImGuiIsDragging") ~= true then
        updateDragFill(value)
    end
    drag:SetAttribute("ImGuiDragValue", value)
    drag:SetAttribute("ImGuiDragSpeed", speed)
    drag:SetAttribute("ImGuiDragMin", minValue)
    drag:SetAttribute("ImGuiDragMax", maxValue)
    self._callbacks = self._callbacks or {}
    self._callbacks[self:_callbackKey(key)] = callback
    if drag:GetAttribute("ImGuiDragConnected") ~= true then
        drag:SetAttribute("ImGuiDragConnected", true)
        local ownerWindow = self.CurrentWindow
        local dragging, lastX = false, nil
        local function applyDelta(deltaX, pointerX)
            local low, high = drag:GetAttribute("ImGuiDragMin"), drag:GetAttribute("ImGuiDragMax")
            local current = tonumber(drag:GetAttribute("ImGuiDragValue")) or 0
            local nextValue
            if low ~= nil and high ~= nil and high > low then
                -- Match SliderFloat: pointer position maps directly to the
                -- complete bounded range, including the initial click.
                local alpha = math.clamp(
                    (pointerX - drag.AbsolutePosition.X) / math.max(drag.AbsoluteSize.X, 1),
                    0, 1
                )
                nextValue = low + (high - low) * alpha
            else
                local configuredSpeed = tonumber(drag:GetAttribute("ImGuiDragSpeed")) or 0.01
                nextValue = current + deltaX * configuredSpeed
                if low ~= nil then nextValue = math.max(nextValue, low) end
                if high ~= nil then nextValue = math.min(nextValue, high) end
            end
            drag:SetAttribute("ImGuiDragValue", nextValue)
            valueLabel.Text = formatDragValue(nextValue)
            local fillAlpha = 0
            if low ~= nil and high ~= nil and high > low then
                fillAlpha = math.clamp((nextValue - low) / (high - low), 0, 1)
            end
            dragFill.Size = UDim2.new(fillAlpha, 0, 1, 0)
            local fn = self._callbacks and self._callbacks[self:_callbackKey(key)]
            if fn then fn(nextValue) end
        end
        self:_connect(drag.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local allowed = ownerWindow and ownerWindow.Focus and ownerWindow.Focus(input.Position) == true
            drag:SetAttribute("ImGuiInputAllowed", allowed == true)
            if allowed then
                dragging, lastX = true, input.Position.X
                drag:SetAttribute("ImGuiIsDragging", true)
                applyDelta(0, input.Position.X)
            end
        end)
        self:_connect(drag.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging, lastX = false, nil
                drag:SetAttribute("ImGuiIsDragging", false)
            end
        end)
        self:_connect(UserInputService.InputChanged, function(input)
            if not dragging or lastX == nil then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local nextX = input.Position.X
            applyDelta(nextX - lastX, nextX)
            lastX = nextX
        end)
        self:_connect(drag.MouseEnter, function() drag.BackgroundColor3 = self.Style.FrameBgHovered end)
        self:_connect(drag.MouseLeave, function() drag.BackgroundColor3 = self.Style.FrameBg end)
    end
    return value
end

function ImGui:DragInt(label, value, speed, minValue, maxValue, callback, id)
    return self:DragFloat(label, value, speed or 1, minValue, maxValue, function(nextValue)
        if callback then callback(math.floor(nextValue + 0.5)) end
    end, id, true)
end

local function numericInput(self, label, value, callback, config, integer)
    config = config or {}
    local key = config.ID or ((integer and "InputInt:" or "InputFloat:") .. tostring(label))
    local minValue, maxValue = tonumber(config.Min), tonumber(config.Max)
    assert(not (minValue and maxValue) or maxValue >= minValue, "Numeric input Min must not exceed Max")
    local function normalize(candidate)
        candidate = tonumber(candidate)
        if not candidate or candidate ~= candidate or candidate == math.huge or candidate == -math.huge then return nil end
        if integer then candidate = math.floor(candidate + 0.5) end
        if minValue then candidate = math.max(candidate, minValue) end
        if maxValue then candidate = math.min(candidate, maxValue) end
        return candidate
    end
    value = normalize(value) or 0
    local itemWidth, availableWidth = self:_consumeItemWidth(0.64)
    local frame = self:_add(key, "Frame", {Name = integer and "InputInt" or "InputFloat", Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1})
    local title = frame:FindFirstChild("Label") or make("TextLabel", frame, {
        Name = "Label", Position = UDim2.fromOffset(itemWidth + 8, 0), Size = UDim2.new(1, -(itemWidth + 8), 0, 24),
        BackgroundTransparency = 1, Font = self.Style.Font, TextSize = self.Style.FontSize,
        TextColor3 = self.Style.Text, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    title.Text = tostring(label)
    title.Position = UDim2.fromOffset(itemWidth + 8, 0)
    title.Size = UDim2.new(1, -(itemWidth + 8), 0, 24)
    local input = frame:FindFirstChild("Input") or make("TextBox", frame, {
        Name = "Input", Position = UDim2.fromOffset(0, 1), Size = UDim2.fromOffset(itemWidth, 23),
        BackgroundColor3 = self.Style.FrameBg, BackgroundTransparency = self.Style.FrameBgTransparency,
        BorderSizePixel = 0, ClearTextOnFocus = false, Font = self.Style.Font,
        TextSize = self.Style.FontSize, TextColor3 = self.Style.Text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    input.Position = UDim2.fromOffset(0, 1)
    input.Size = UDim2.fromOffset(itemWidth, 23)
    if not input:FindFirstChildOfClass("UICorner") then round(input, self.Style.FrameRounding) end
    input.PlaceholderText = config.Placeholder or (integer and "0" or "0.000")
    input:SetAttribute("ImGuiNumericValue", value)
    local decimals = math.clamp(math.floor(tonumber(config.Decimals) or 3), 0, 8)
    if not input:IsFocused() then
        input.Text = integer and tostring(value) or string.format("%." .. tostring(decimals) .. "f", value)
    end
    self._callbacks = self._callbacks or {}
    self._callbacks[self:_callbackKey(key)] = callback
    if input:GetAttribute("ImGuiNumericConnected") ~= true then
        input:SetAttribute("ImGuiNumericConnected", true)
        self:_connect(input.Focused, function() input.BackgroundColor3 = self.Style.FrameBgActive end)
        self:_connect(input.FocusLost, function()
            input.BackgroundColor3 = self.Style.FrameBg
            local nextValue = normalize(input.Text)
            if nextValue == nil then
                local previous = tonumber(input:GetAttribute("ImGuiNumericValue")) or 0
                input.Text = integer and tostring(previous) or string.format("%." .. tostring(decimals) .. "f", previous)
                return
            end
            input:SetAttribute("ImGuiNumericValue", nextValue)
            input.Text = integer and tostring(nextValue) or string.format("%." .. tostring(decimals) .. "f", nextValue)
            local fn = self._callbacks and self._callbacks[self:_callbackKey(key)]
            if fn then fn(nextValue) end
        end)
    end
    return value
end

function ImGui:InputFloat(label, value, callback, config)
    return numericInput(self, label, value, callback, config, false)
end

function ImGui:InputInt(label, value, callback, config)
    return numericInput(self, label, value, callback, config, true)
end

-- Item-width stack and one-shot width, following Dear ImGui's positive/negative width rules.
local function contentWidth(self)
    local parent = self.CurrentParent
    if not parent then return 1 end
    local width = parent.AbsoluteSize.X
    if width <= 0 then
        width = parent.Size.X.Offset
        if parent.Parent and parent.Parent:IsA("GuiObject") then
            width += parent.Parent.AbsoluteSize.X * parent.Size.X.Scale
        end
    end
    local padding = parent:FindFirstChildOfClass("UIPadding")
    if padding then
        width -= padding.PaddingLeft.Offset + padding.PaddingRight.Offset
    end
    return math.max(width, 1)
end

function ImGui:SetNextItemWidth(width)
    assert(self._frameActive and self.CurrentParent, "SetNextItemWidth() must be called inside Begin()")
    width = tonumber(width)
    assert(width and width == width and width ~= math.huge and width ~= -math.huge,
        "SetNextItemWidth(width) expects a finite number")
    self._nextItemWidth = width
end

function ImGui:PushItemWidth(width)
    assert(self._frameActive and self.CurrentParent, "PushItemWidth() must be called inside Begin()")
    width = tonumber(width)
    assert(width and width == width and width ~= math.huge and width ~= -math.huge,
        "PushItemWidth(width) expects a finite number")
    table.insert(self._itemWidthStack, width)
end

function ImGui:PopItemWidth()
    assert(#self._itemWidthStack > 0, "PopItemWidth() called without a matching PushItemWidth()")
    table.remove(self._itemWidthStack)
end

function ImGui:CalcItemWidth()
    local width = self._nextItemWidth
    if width == nil then width = self._itemWidthStack[#self._itemWidthStack] end
    local available = contentWidth(self)
    if width == nil then return math.max(1, math.floor(available * 0.64 + 0.5)) end
    if width < 0 then width = available + width end
    return math.max(1, math.floor(math.min(width, available) + 0.5))
end

function ImGui:_consumeItemWidth(defaultFraction)
    local requested = self._nextItemWidth
    self._nextItemWidth = nil
    if requested == nil then requested = self._itemWidthStack[#self._itemWidthStack] end
    local available = contentWidth(self)
    if requested == nil then
        return math.max(1, math.floor(available * (defaultFraction or 0.64) + 0.5)), available
    end
    local width = requested < 0 and (available + requested) or requested
    return math.max(1, math.floor(math.min(width, available) + 0.5)), available
end

function ImGui:InputText(label, value, callback, config)
    config = config or {}
    local itemWidth = self:_consumeItemWidth(0.64)
    local key = config.ID or ("Input:" .. tostring(label))
    local frame = self:_add(key, "Frame", {
        Name = "InputText", Size = UDim2.new(1, 0, 0, config.Multiline and 58 or 26),
        BackgroundTransparency = 1,
    })
    local title = frame:FindFirstChild("Label") or make("TextLabel", frame, {
        Name = "Label", Position = UDim2.fromOffset(itemWidth + 8, 0),
        Size = UDim2.new(1, -(itemWidth + 8), 0, 24), BackgroundTransparency = 1,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    })
    title.Text = tostring(label)
    title.Position = UDim2.fromOffset(itemWidth + 8, 0)
    title.Size = UDim2.new(1, -(itemWidth + 8), 0, 24)
    local input = frame:FindFirstChild("Input") or make("TextBox", frame, {
        Name = "Input", Position = UDim2.fromOffset(0, 1),
        Size = UDim2.fromOffset(itemWidth, config.Multiline and 53 or 23),
        BackgroundColor3 = self.Style.FrameBg, BackgroundTransparency = self.Style.FrameBgTransparency,
        BorderSizePixel = 0, ClearTextOnFocus = false, Font = self.Style.Font, TextSize = self.Style.FontSize,
        TextColor3 = self.Style.Text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    input.Position = UDim2.fromOffset(0, 1)
    input.Size = UDim2.fromOffset(itemWidth, config.Multiline and 53 or 23)
    if not input:FindFirstChildOfClass("UICorner") then round(input, self.Style.FrameRounding) end
    input.PlaceholderText = config.Placeholder or ""
    input.TextXAlignment = Enum.TextXAlignment.Left
    if input:GetAttribute("ImGuiFocusConnected") ~= true then
        input:SetAttribute("ImGuiFocusConnected", true)
        self:_connect(input.Focused, function() input.BackgroundColor3 = self.Style.FrameBgActive end)
        self:_connect(input.FocusLost, function() input.BackgroundColor3 = self.Style.FrameBg end)
    end
    input.MultiLine = config.Multiline == true
    if not input:IsFocused() then input.Text = tostring(value or "") end
    if input:GetAttribute("ImGuiTextConnected") ~= true then
        input:SetAttribute("ImGuiTextConnected", true)
        self:_connect(input:GetPropertyChangedSignal("Text"), function()
            local fn = self._callbacks and self._callbacks[self:_callbackKey(key)]
            if fn then fn(input.Text) end
        end)
    end
    self._callbacks = self._callbacks or {}
    self._callbacks[self:_callbackKey(key)] = callback
    return input.Text
end

local function colorPreviewRow(self, label, color, key, toggle)
    color = typeof(color) == "Color3" and color or Color3.new(1, 1, 1)
    local frame = self:_add(key, "Frame", {
        Name = "ColorControl", Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
    })
    local title = frame:FindFirstChild("Label") or make("TextLabel", frame, {
        Name = "Label", Size = UDim2.new(0.36, 0, 1, 0), BackgroundTransparency = 1,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    })
    title.Text = tostring(label)
    local swatch = frame:FindFirstChild("Swatch") or make("TextButton", frame, {
        Name = "Swatch", Position = UDim2.new(0.38, 0, 0, 1), Size = UDim2.new(0.62, 0, 0, 24),
        BackgroundColor3 = color, BorderSizePixel = 0, AutoButtonColor = false,
        Text = "", ZIndex = 2,
    })
    swatch.BackgroundColor3 = color
    local hex = string.format("#%02X%02X%02X",
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5))
    local value = swatch:FindFirstChild("Hex") or make("TextLabel", swatch, {
        Name = "Hex", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = Color3.new(1, 1, 1),
        TextStrokeTransparency = 0.65, Text = hex, ZIndex = 3,
    })
    value.Text = hex
    if toggle and swatch:GetAttribute("ImGuiColorToggleConnected") ~= true then
        swatch:SetAttribute("ImGuiColorToggleConnected", true)
        local ownerWindow = self.CurrentWindow
        self:_connect(swatch.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local allowed = ownerWindow and ownerWindow.Focus and ownerWindow.Focus(input.Position) == true
                swatch:SetAttribute("ImGuiInputAllowed", allowed == true)
            end
        end)
        self:_connect(swatch.Activated, function()
            if swatch:GetAttribute("ImGuiInputAllowed") ~= true then return end
            frame:SetAttribute("ImGuiColorOpen", frame:GetAttribute("ImGuiColorOpen") ~= true)
        end)
    end
    return frame
end

local function submitColorChannels(self, key, color, callback)
    local hue, saturation, brightness = Color3.toHSV(color)
    self:SliderFloat("Hue", hue, 0, 1, function(nextHue)
        if callback then callback(Color3.fromHSV(nextHue, saturation, brightness)) end
    end, key .. "/Hue")
    self:SliderFloat("Saturation", saturation, 0, 1, function(nextSaturation)
        if callback then callback(Color3.fromHSV(hue, nextSaturation, brightness)) end
    end, key .. "/Saturation")
    self:SliderFloat("Value", brightness, 0, 1, function(nextBrightness)
        if callback then callback(Color3.fromHSV(hue, saturation, nextBrightness)) end
    end, key .. "/Value")
end

-- Compact color editor. Clicking the swatch expands HSV controls beneath it.
function ImGui:ColorEdit(label, color, callback, id)
    local key = id or ("ColorEdit:" .. tostring(label))
    local frame = colorPreviewRow(self, label, color, key, true)
    self._callbacks = self._callbacks or {}
    self._callbacks[self:_callbackKey(key)] = callback
    if frame:GetAttribute("ImGuiColorOpen") == true then
        submitColorChannels(self, key, color, callback)
    end
    return color
end

-- Always-visible HSV color picker with a live color preview.
function ImGui:ColorPicker(label, color, callback, id)
    local key = id or ("ColorPicker:" .. tostring(label))
    colorPreviewRow(self, label, color, key, false)
    submitColorChannels(self, key, color, callback)
    return color
end

function ImGui:Separator(text)
    local hasText = text ~= nil and tostring(text) ~= ""
    local frame = self:_add("Separator:" .. tostring(text or self._order), "Frame", {
        Name = "Separator", Size = UDim2.new(1, 0, 0, hasText and 22 or 8), BackgroundTransparency = 1,
    })
    local leftInset = 0
    local rightInset = 2
    local labelGap = 5
    local leftLineWidth = 12
    local lineY = hasText and 11 or 4

    if not hasText then
        local line = frame:FindFirstChild("Line") or make("Frame", frame, {
            Name = "Line", Position = UDim2.new(0, leftInset, 0, lineY),
            Size = UDim2.new(1, -(leftInset + rightInset), 0, 1),
            BackgroundColor3 = self.Style.Separator, BorderSizePixel = 0,
        })
        line.Position = UDim2.new(0, leftInset, 0, lineY)
        line.Size = UDim2.new(1, -(leftInset + rightInset), 0, 1)
        line.BackgroundColor3 = self.Style.Separator
        return frame
    end

    -- Split the rule around the caption: a short leading rule, the caption,
    -- then a flexible trailing rule that stops just before the scrollbar.
    local labelText = tostring(text)
    local measured = TextService:GetTextSize(labelText, self.Style.FontSize, self.Style.Font, Vector2.new(1000, 22))
    local labelWidth = math.ceil(measured.X) + 2
    local labelX = leftLineWidth + labelGap
    local leftLine = frame:FindFirstChild("LeftLine") or make("Frame", frame, {
        Name = "LeftLine", Position = UDim2.new(0, leftInset, 0, lineY),
        Size = UDim2.new(0, leftLineWidth, 0, 1),
        BackgroundColor3 = self.Style.Separator, BorderSizePixel = 0,
    })
    local label = frame:FindFirstChild("Label") or make("TextLabel", frame, {
        Name = "Label", Position = UDim2.fromOffset(labelX, 0), Size = UDim2.new(0, labelWidth, 0, 22),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = self.Style.Font, TextSize = self.Style.FontSize, TextColor3 = self.Style.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 2,
    })
    local rightLine = frame:FindFirstChild("RightLine") or make("Frame", frame, {
        Name = "RightLine", Position = UDim2.new(0, labelX + labelWidth + labelGap, 0, lineY),
        Size = UDim2.new(1, -(labelX + labelWidth + labelGap + rightInset), 0, 1),
        BackgroundColor3 = self.Style.Separator, BorderSizePixel = 0,
    })
    leftLine.Position = UDim2.new(0, leftInset, 0, lineY)
    leftLine.Size = UDim2.new(0, leftLineWidth, 0, 1)
    leftLine.BackgroundColor3 = self.Style.Separator
    label.Text = labelText
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(labelX, 0)
    label.Size = UDim2.new(0, labelWidth, 0, 22)
    label.ZIndex = 2
    rightLine.Position = UDim2.new(0, labelX + labelWidth + labelGap, 0, lineY)
    rightLine.Size = UDim2.new(1, -(labelX + labelWidth + labelGap + rightInset), 0, 1)
    rightLine.BackgroundColor3 = self.Style.Separator
    return frame
end

-- Place the next submitted item beside the previously submitted item.
function ImGui:SameLine()
    assert(self._frameActive and self.CurrentParent, "SameLine() must be called inside Begin()")
    assert(self._lastItem and self._lastItem.Parent, "SameLine() requires a preceding item")
    if not self._sameLineRow then
        self._sameLineRow = makeHorizontalRow(self, self._lastItem)
    elseif self._lastItem.Parent ~= self._sameLineRow then
        self._lastItem.Parent = self._sameLineRow
        self._lastItem.Size = UDim2.fromOffset(measuredItemWidth(self._lastItem), math.max(self._lastItem.AbsoluteSize.Y, 1))
        self._lastItem.AutomaticSize = Enum.AutomaticSize.None
        self._lastItem.LayoutOrder = #self._sameLineRow:GetChildren()
    end
    self._sameLineRequested = true
end

-- Explicitly return subsequent items to the normal vertical flow.
function ImGui:NewLine()
    self._sameLineRequested = false
    self._sameLineRow = nil
    self._lastItem = nil
end

function ImGui:Dummy(size)
    assert(typeof(size) == "UDim2", "Dummy(size) expects a UDim2")
    return self:_add("Dummy:" .. self._order, "Frame", {
        Name = "Dummy", Size = size, BackgroundTransparency = 1,
        BorderSizePixel = 0, Active = false, Selectable = false,
    })
end

local function openLayoutScope(self, name, paddingLeft)
    assert(self._frameActive and self.CurrentParent, name .. "() must be called inside Begin()")
    local parent = self.CurrentParent
    self._order += 1
    local container = self:_widget(name .. ":" .. self._order, "Frame", parent, {
        Name = "ImGui" .. name, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        BorderSizePixel = 0, LayoutOrder = self._order,
    })
    if not container:FindFirstChildOfClass("UIListLayout") then vertical(container, self.Style.ItemSpacing.Y) end
    if paddingLeft and paddingLeft > 0 then
        local padding = container:FindFirstChild("ImGuiIndentPadding")
        if not padding then padding = make("UIPadding", container, { Name = "ImGuiIndentPadding" }) end
        padding.PaddingLeft = UDim.new(0, paddingLeft)
    end
    table.insert(self._groupStack, { Parent = parent, LastItem = self._lastItem, Container = container, Kind = name })
    self.CurrentParent = container
    self._lastItem, self._sameLineRow, self._sameLineRequested = nil, nil, false
    return container
end

local function closeLayoutScope(self, name)
    local scope = self._groupStack[#self._groupStack]
    assert(scope and scope.Kind == name, name .. "() called without a matching opener")
    table.remove(self._groupStack)
    self.CurrentParent = scope.Parent
    self._lastItem, self._sameLineRow, self._sameLineRequested = scope.Container, nil, false
end

function ImGui:Indent(width)
    width = tonumber(width) or self.Style.IndentSpacing or 14
    assert(width >= 0, "Indent(width) expects a non-negative width")
    openLayoutScope(self, "Indent", width)
end

function ImGui:Unindent()
    closeLayoutScope(self, "Indent")
end

function ImGui:BeginGroup()
    openLayoutScope(self, "Group", 0)
end

function ImGui:EndGroup()
    closeLayoutScope(self, "Group")
end

function ImGui:Spacing(amount)
    local height = math.max(0, tonumber(amount) or self.Style.ItemSpacing.Y)
    return self:_add("Spacing:" .. self._order, "Frame", {
        Name = "Spacing", Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1,
        BorderSizePixel = 0, Active = false, Selectable = false,
    })
end


-- Legacy Dear ImGui-style columns. Each column owns an independent vertical flow.
local function columnAvailableWidth(columns)
    local width = columns.Container.AbsoluteSize.X
    if width <= 0 then
        width = columns.Parent.AbsoluteSize.X
        local padding = columns.Parent:FindFirstChildOfClass("UIPadding")
        if padding then width -= padding.PaddingLeft.Offset + padding.PaddingRight.Offset end
    end
    return math.max(width, 1)
end

local function resolvedColumnWidths(columns)
    local available = columnAvailableWidth(columns)
    local fixedTotal, flexibleCount = 0, 0
    for index = 1, columns.Count do
        local fixed = columns.Widths[index]
        if fixed then fixedTotal += fixed else flexibleCount += 1 end
    end
    local fixedScale = fixedTotal > available and available / fixedTotal or 1
    local remaining = math.max(available - math.min(fixedTotal, available), 0)
    local flexibleWidth = flexibleCount > 0 and remaining / flexibleCount or 0
    local result = {}
    for index = 1, columns.Count do
        result[index] = columns.Widths[index] and columns.Widths[index] * fixedScale or flexibleWidth
    end
    return available, result
end

local function refreshColumnWidths(self, columns)
    local available, widths = resolvedColumnWidths(columns)
    for index = 1, columns.Count do
        local column = columns.Frames[index]
        column.Size = UDim2.new(widths[index] / available, 0, 0, 0)
        column.LayoutOrder = index
    end
    local boundary = 0
    for index, border in ipairs(columns.Borders) do
        boundary += widths[index]
        border.Position = UDim2.fromOffset(math.floor(boundary - 1), 0)
        border.Size = UDim2.fromOffset(1, math.max(columns.Content.AbsoluteSize.Y, 1))
    end
end

function ImGui:Columns(count, id, border)
    assert(self._frameActive and self.CurrentParent, "Columns() must be called inside Begin()")
    count = math.floor(tonumber(count) or 1)
    assert(count >= 1 and count <= 64, "Columns(count) expects a count between 1 and 64")
    assert(#self._columnsStack == 0, "Nested Columns() scopes are not supported")
    local key = tostring(id or ("Columns:" .. tostring(self._order + 1)))
    local parent, previousLastItem = self.CurrentParent, self._lastItem
    local container = self:_add("Columns:" .. key, "Frame", {
        Name = "ImGuiColumns", Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0,
    })
    local content = self:_widget("Columns:" .. key .. ":Content", "Frame", container, {
        Name = "ColumnsContent", Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0,
    })
    local layout = content:FindFirstChildOfClass("UIListLayout")
    if not layout then
        layout = make("UIListLayout", content, {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 0),
            VerticalAlignment = Enum.VerticalAlignment.Top,
        })
    end
    local widths = self._columnWidths[key] or {}
    self._columnWidths[key] = widths
    local columns = {
        Key = key, Count = count, Index = 1, Parent = parent, Container = container, Content = content,
        Frames = {}, Borders = {}, Widths = widths, PreviousLastItem = previousLastItem,
        PreviousOrder = self._order - 1, Border = border ~= false,
    }
    for index = 1, count do
        local column = self:_widget("Columns:" .. key .. ":Column:" .. index, "Frame", content, {
            Name = "Column" .. index, Size = UDim2.new(1 / count, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0,
            LayoutOrder = index,
        })
        if not column:FindFirstChildOfClass("UIListLayout") then vertical(column, self.Style.ItemSpacing.Y) end
        columns.Frames[index] = column
        if columns.Border and index < count then
            local line = self:_widget("Columns:" .. key .. ":Border:" .. index, "Frame", container, {
                Name = "ColumnBorder" .. index, BackgroundColor3 = self.Style.Separator,
                BorderSizePixel = 0, Size = UDim2.new(0, 1, 1, 0), ZIndex = 3,
            })
            columns.Borders[index] = line
        end
    end
    table.insert(self._columnsStack, columns)
    refreshColumnWidths(self, columns)
    self.CurrentParent = columns.Frames[1]
    self._order = 0
    self._lastItem, self._sameLineRow, self._sameLineRequested = nil, nil, false
end

function ImGui:NextColumn()
    local columns = self._columnsStack[#self._columnsStack]
    assert(columns, "NextColumn() called outside Columns()")
    columns.Index = columns.Index % columns.Count + 1
    self.CurrentParent = columns.Frames[columns.Index]
    self._order = 0
    self._lastItem, self._sameLineRow, self._sameLineRequested = nil, nil, false
end

function ImGui:GetColumnIndex()
    local columns = self._columnsStack[#self._columnsStack]
    return columns and (columns.Index - 1) or 0
end

function ImGui:GetColumnWidth(columnIndex)
    local columns = self._columnsStack[#self._columnsStack]
    if not columns then return contentWidth(self) end
    local index = tonumber(columnIndex) or -1
    if index == -1 then index = columns.Index - 1 end
    index = math.floor(index) + 1
    assert(index >= 1 and index <= columns.Count, "GetColumnWidth() column index is out of range")
    refreshColumnWidths(self, columns)
    local actual = columns.Frames[index].AbsoluteSize.X
    if actual > 0 then return actual end
    local _, widths = resolvedColumnWidths(columns)
    return math.floor(widths[index] + 0.5)
end

function ImGui:SetColumnWidth(columnIndex, width)
    local columns = self._columnsStack[#self._columnsStack]
    assert(columns, "SetColumnWidth() called outside Columns()")
    local index = math.floor(tonumber(columnIndex) or -1)
    if index == -1 then index = columns.Index - 1 end
    index += 1
    assert(index >= 1 and index <= columns.Count, "SetColumnWidth() column index is out of range")
    width = tonumber(width)
    assert(width and width > 0 and width == width and width < math.huge,
        "SetColumnWidth() expects a positive finite pixel width")
    columns.Widths[index] = width
    refreshColumnWidths(self, columns)
end

function ImGui:EndColumns()
    local columns = table.remove(self._columnsStack)
    assert(columns, "EndColumns() called without a matching Columns()")
    self.CurrentParent = columns.Parent
    self._order = columns.PreviousOrder + 1
    self._lastItem, self._sameLineRow, self._sameLineRequested = columns.Container, nil, false
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
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
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
    table.insert(self.WindowStack, { Kind = "Child", Window = self.CurrentWindow, Parent = self.CurrentParent, Scope = self._scope, Order = self._order, LastItem = self._lastItem, SameLineRow = self._sameLineRow, SameLineRequested = self._sameLineRequested })
    self._lastItem, self._sameLineRow, self._sameLineRequested = nil, nil, false
    self._scope = self._scope .. "/Child:" .. tostring(id)
    self.CurrentParent = child
    self._order = 0
    return true
end

function ImGui:EndChild()
    assert(#self.WindowStack > 0 and self.WindowStack[#self.WindowStack].Kind == "Child",
        "EndChild() called without a matching BeginChild()")
    local previous = table.remove(self.WindowStack)
    self.CurrentWindow, self.CurrentParent = previous.Window, previous.Parent
    self._scope = previous.Scope
    self._order = previous.Order
    self._lastItem, self._sameLineRow, self._sameLineRequested = previous.LastItem, previous.SameLineRow, previous.SameLineRequested
end

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
    assert(#self._treeStack == 0, "Unclosed TreeNode(): call TreePop() before Render()")
    assert(#self._idStack == 0, "Unclosed PushID(): call PopID() before Render()")
    assert(#self._groupStack == 0, "Unclosed Indent()/BeginGroup(): close layout scopes before Render()")
    assert(#self._columnsStack == 0, "Unclosed Columns(): call EndColumns() before Render()")
    assert(#self._itemWidthStack == 0, "Unclosed PushItemWidth(): call PopItemWidth() before Render()")
    assert(self._nextItemWidth == nil, "SetNextItemWidth() was not consumed by an item before Render()")
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
    table.clear(self._treeStack)
    table.clear(self._groupStack)
    table.clear(self._indentStack)
    table.clear(self._itemWidthStack)
    table.clear(self._columnsStack)
    table.clear(self._columnWidths)
    self._nextItemWidth = nil
    table.clear(self._callbacks or {})
    table.clear(self._progressBars or {})
 
end

return ImGui
