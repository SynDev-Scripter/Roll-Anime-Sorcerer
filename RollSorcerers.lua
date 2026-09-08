local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local EventConfig = nil

pcall(function()
    EventConfig = require(
        ReplicatedStorage
            :WaitForChild("Config")
            :WaitForChild("EventConfig")
    )
end)

local LUCKY_BLOCKS = {
    "Awakening",
    "Calamity",
    "Common",
    "Domain",
    "Epic",
    "Frame",
    "Legacy",
    "Legendary",
    "Manga",
    "Mythic",
    "New Era",
    "Prodigy",
    "Rare",
    "Secret",
    "Transcendent",
    "Uncommon"
}

local selectedBlocks = {
    Common = true
}

local autoBuyActive = false
local busy = false
local returnAfterBuying = true
local cycleDelay = 1.5
local statusCallback = nil
local updateSelectedCallback = nil
local updateDelayCallback = nil

local COLORS = {
    Background = Color3.fromRGB(15, 15, 20),
    CardBg = Color3.fromRGB(24, 24, 32),
    Accent = Color3.fromRGB(114, 137, 218),
    AccentDark = Color3.fromRGB(75, 90, 175),

    TextPrimary = Color3.fromRGB(240, 240, 245),
    TextMuted = Color3.fromRGB(140, 140, 160),

    Success = Color3.fromRGB(67, 181, 129),
    Danger = Color3.fromRGB(240, 71, 71),
    Warning = Color3.fromRGB(250, 166, 26),

    ButtonInactive = Color3.fromRGB(32, 34, 42),
    ButtonHover = Color3.fromRGB(42, 44, 54)
}

local function setStatus(message)
    if statusCallback then
        statusCallback(message)
    end
end

local function getSelectedCount()
    local count = 0

    for _, blockName in ipairs(LUCKY_BLOCKS) do
        if selectedBlocks[blockName] then
            count += 1
        end
    end

    return count
end

local function getSelectedList()
    local list = {}

    for _, blockName in ipairs(LUCKY_BLOCKS) do
        if selectedBlocks[blockName] then
            table.insert(list, blockName)
        end
    end

    return list
end

local function pressE()
    VirtualInputManager:SendKeyEvent(
        true,
        Enum.KeyCode.E,
        false,
        game
    )

    task.wait(0.08)

    VirtualInputManager:SendKeyEvent(
        false,
        Enum.KeyCode.E,
        false,
        game
    )
end

local function clickButton(button)
    if not button then
        return false
    end

    if not button:IsA("GuiButton") then
        return false
    end

    if not button.Visible then
        return false
    end

    if getconnections then
        local success, connections = pcall(function()
            return getconnections(button.Activated)
        end)

        if success and connections and #connections > 0 then
            for _, connection in ipairs(connections) do
                pcall(function()
                    connection:Fire()
                end)
            end

            return true
        end

        success, connections = pcall(function()
            return getconnections(button.MouseButton1Click)
        end)

        if success and connections and #connections > 0 then
            for _, connection in ipairs(connections) do
                pcall(function()
                    connection:Fire()
                end)
            end

            return true
        end
    end

    local position = button.AbsolutePosition
    local size = button.AbsoluteSize

    local centerX = position.X + size.X / 2
    local centerY = position.Y + size.Y / 2

    VirtualInputManager:SendMouseButtonEvent(
        centerX,
        centerY,
        0,
        true,
        game,
        1
    )

    task.wait(0.04)

    VirtualInputManager:SendMouseButtonEvent(
        centerX,
        centerY,
        0,
        false,
        game,
        1
    )

    return true
end

local function getShopTarget()
    local shopFolder = Workspace:FindFirstChild("luckyblocks")

    if not shopFolder then
        return nil
    end

    if shopFolder:IsA("BasePart") then
        return shopFolder
    end

    if shopFolder:IsA("Model") then
        return shopFolder
    end

    for _, object in ipairs(shopFolder:GetDescendants()) do
        if object:IsA("Model") then
            return object
        end
    end

    for _, object in ipairs(shopFolder:GetDescendants()) do
        if object:IsA("BasePart") then
            return object
        end
    end

    return nil
end

local function getTargetCFrame(target)
    if not target then
        return nil
    end

    if target:IsA("Model") then
        return target:GetPivot()
    end

    if target:IsA("BasePart") then
        return target.CFrame
    end

    return nil
end

local function findBuyButton(root)
    if not root then
        return nil
    end

    for _, object in ipairs(root:GetDescendants()) do
        if object:IsA("GuiButton") then
            local lowerName = string.lower(object.Name)

            if lowerName == "buymax"
                or lowerName == "buy_max"
                or lowerName == "maxbuy"
            then
                return object
            end

            if object:IsA("TextButton") then
                local text = string.lower(object.Text)

                if string.find(text, "buy max", 1, true)
                    or string.find(text, "buymax", 1, true)
                then
                    return object
                end
            end
        end
    end

    return nil
end

local function findContainerWithBuyButton(object)
    if not object then
        return nil, nil
    end

    local current = object

    for _ = 1, 7 do
        if not current then
            break
        end

        local buyButton = findBuyButton(current)

        if buyButton then
            return current, buyButton
        end

        current = current.Parent
    end

    return nil, nil
end

local function findBlockDirectly(playerGui, blockName)
    for _, object in ipairs(playerGui:GetDescendants()) do
        if object.Name == blockName then
            local container, button = findContainerWithBuyButton(object)

            if button then
                return container, button
            end
        end
    end

    return nil, nil
end

local function findVisibleScrollingFrames(playerGui)
    local frames = {}

    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("ScrollingFrame") and object.Visible then
            table.insert(frames, object)
        end
    end

    return frames
end

local function scrollSearch(playerGui, blockName)
    local scrollingFrames = findVisibleScrollingFrames(playerGui)

    for _, scrollingFrame in ipairs(scrollingFrames) do
        local oldPosition = scrollingFrame.CanvasPosition

        local maxY = math.max(
            0,
            scrollingFrame.AbsoluteCanvasSize.Y
                - scrollingFrame.AbsoluteWindowSize.Y
        )

        local step = math.max(
            80,
            math.floor(scrollingFrame.AbsoluteWindowSize.Y * 0.45)
        )

        local position = 0

        while position <= maxY + step do
            scrollingFrame.CanvasPosition = Vector2.new(
                0,
                math.min(position, maxY)
            )

            task.wait(0.04)

            local found = scrollingFrame:FindFirstChild(
                blockName,
                true
            )

            if found then
                local container, button =
                    findContainerWithBuyButton(found)

                if button then
                    return container, button
                end
            end

            position += step
        end

        scrollingFrame.CanvasPosition = oldPosition
    end

    return nil, nil
end

local function findLuckyBlock(playerGui, blockName)
    local container, button =
        findBlockDirectly(playerGui, blockName)

    if button then
        return container, button
    end

    return scrollSearch(playerGui, blockName)
end

local function openShop()
    local character = LocalPlayer.Character
        or LocalPlayer.CharacterAdded:Wait()

    local rootPart = character:WaitForChild(
        "HumanoidRootPart",
        5
    )

    if not rootPart then
        return false, nil
    end

    local originalCFrame = rootPart.CFrame

    setStatus("Finding Lucky Block shop...")

    local shopTarget = getShopTarget()

    if not shopTarget then
        setStatus("ERROR: luckyblocks shop not found")
        return false, originalCFrame
    end

    local shopCFrame = getTargetCFrame(shopTarget)

    if not shopCFrame then
        setStatus("ERROR: couldn't get shop position")
        return false, originalCFrame
    end

    setStatus("Moving to shop...")

    rootPart.CFrame = shopCFrame * CFrame.new(0, 3, 0)

    task.wait(0.35)

    setStatus("Opening shop...")

    pressE()

    task.wait(0.55)

    return true, originalCFrame
end

local function returnToPosition(originalCFrame)
    if not returnAfterBuying then
        return
    end

    if not originalCFrame then
        return
    end

    local character = LocalPlayer.Character

    if not character then
        return
    end

    local rootPart = character:FindFirstChild(
        "HumanoidRootPart"
    )

    if rootPart then
        rootPart.CFrame = originalCFrame
    end
end

local function buySelectedBlocks(isAutoRun)
    if busy then
        return
    end

    local blocks = getSelectedList()

    if #blocks == 0 then
        setStatus("Select at least 1 Lucky Block")
        return
    end

    busy = true

    local success, originalCFrame = openShop()

    if not success then
        busy = false
        return
    end

    local playerGui = LocalPlayer:WaitForChild(
        "PlayerGui"
    )

    local bought = 0
    local failed = {}

    for index, blockName in ipairs(blocks) do
        if isAutoRun and not autoBuyActive then
            break
        end

        setStatus(
            "Buying "
                .. blockName
                .. " ["
                .. index
                .. "/"
                .. #blocks
                .. "]"
        )

        local _, buyButton =
            findLuckyBlock(playerGui, blockName)

        if buyButton then
            local clicked = clickButton(buyButton)

            if clicked then
                bought += 1
            else
                table.insert(failed, blockName)
            end
        else
            table.insert(failed, blockName)
        end

        task.wait(0.15)
    end

    returnToPosition(originalCFrame)

    if #failed == 0 then
        setStatus(
            "Finished - bought "
                .. bought
                .. "/"
                .. #blocks
                .. " selected"
        )
    else
        setStatus(
            "Bought "
                .. bought
                .. "/"
                .. #blocks
                .. " | Missing: "
                .. table.concat(failed, ", ")
        )
    end

    busy = false
end

local function getEventDisplayName(eventId)
    if not EventConfig or not eventId then
        return "Unknown"
    end

    local success, eventData = pcall(function()
        return EventConfig.GetEvent(eventId)
    end)

    if success and eventData then
        return eventData.Name or tostring(eventId)
    end

    return tostring(eventId)
end

local function getUpcomingEvents()
    if not EventConfig then
        return "Unknown", "Unknown"
    end

    local success, state = pcall(function()
        return EventConfig.GetState()
    end)

    if not success or not state then
        return "Unknown", "Unknown"
    end

    local nextEventId
    local afterEventId

    if state.IsEventActive then
        nextEventId = EventConfig.ChooseEvent(
            state.CycleIndex + 1
        )

        afterEventId = EventConfig.ChooseEvent(
            state.CycleIndex + 2
        )
    else
        nextEventId =
            state.SelectedEventId
            or EventConfig.ChooseEvent(
                state.CycleIndex
            )

        afterEventId = EventConfig.ChooseEvent(
            state.CycleIndex + 1
        )
    end

    return
        getEventDisplayName(nextEventId),
        getEventDisplayName(afterEventId)
end

local function createGUI()
    local parentTarget =
        CoreGui:FindFirstChild("RobloxGui")
        or LocalPlayer:WaitForChild("PlayerGui")

    local oldGui =
        parentTarget:FindFirstChild("LuckyBlockProGUI")

    if oldGui then
        oldGui:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")

    ScreenGui.Name = "LuckyBlockProGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = false
    ScreenGui.Parent = parentTarget

    local MainFrame = Instance.new("Frame")

    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 320, 0, 575)
    MainFrame.Position =
        UDim2.new(0.5, -160, 0.5, -287)

    MainFrame.BackgroundColor3 = COLORS.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")

    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")

    MainStroke.Color = COLORS.Accent
    MainStroke.Thickness = 1.5
    MainStroke.Transparency = 0.5
    MainStroke.Parent = MainFrame

    local Header = Instance.new("Frame")

    Header.Size = UDim2.new(1, 0, 0, 54)
    Header.BackgroundTransparency = 1
    Header.Parent = MainFrame

    local Title = Instance.new("TextLabel")

    Title.Size = UDim2.new(1, -30, 0, 24)
    Title.Position = UDim2.new(0, 15, 0, 8)
    Title.BackgroundTransparency = 1
    Title.Text = "LUCKYBLOCK HUB"
    Title.TextColor3 = COLORS.TextPrimary
    Title.TextSize = 15
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header

    local Subtitle = Instance.new("TextLabel")

    Subtitle.Size = UDim2.new(1, -30, 0, 16)
    Subtitle.Position = UDim2.new(0, 15, 0, 30)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text =
        "Select multiple blocks to buy"
    Subtitle.TextColor3 = COLORS.TextMuted
    Subtitle.TextSize = 10
    Subtitle.Font = Enum.Font.Gotham
    Subtitle.TextXAlignment =
        Enum.TextXAlignment.Left

    Subtitle.Parent = Header

    local SelectionTop = Instance.new("Frame")

    SelectionTop.Size =
        UDim2.new(1, -24, 0, 32)

    SelectionTop.Position =
        UDim2.new(0, 12, 0, 58)

    SelectionTop.BackgroundTransparency = 1
    SelectionTop.Parent = MainFrame

    local SelectedLabel =
        Instance.new("TextLabel")

    SelectedLabel.Size =
        UDim2.new(0.42, 0, 1, 0)

    SelectedLabel.BackgroundTransparency = 1
    SelectedLabel.TextColor3 = COLORS.TextMuted
    SelectedLabel.TextSize = 10
    SelectedLabel.Font = Enum.Font.GothamMedium
    SelectedLabel.TextXAlignment =
        Enum.TextXAlignment.Left

    SelectedLabel.Parent = SelectionTop

    local SelectAllButton =
        Instance.new("TextButton")

    SelectAllButton.Size =
        UDim2.new(0.27, -3, 0, 26)

    SelectAllButton.Position =
        UDim2.new(0.45, 0, 0, 3)

    SelectAllButton.BackgroundColor3 =
        COLORS.ButtonInactive

    SelectAllButton.Text = "SELECT ALL"
    SelectAllButton.TextColor3 =
        COLORS.TextPrimary

    SelectAllButton.TextSize = 9
    SelectAllButton.Font = Enum.Font.GothamBold
    SelectAllButton.AutoButtonColor = false
    SelectAllButton.Parent = SelectionTop

    local SelectAllCorner =
        Instance.new("UICorner")

    SelectAllCorner.CornerRadius =
        UDim.new(0, 6)

    SelectAllCorner.Parent = SelectAllButton

    local ClearButton = Instance.new("TextButton")

    ClearButton.Size =
        UDim2.new(0.27, -3, 0, 26)

    ClearButton.Position =
        UDim2.new(0.73, 3, 0, 3)

    ClearButton.BackgroundColor3 =
        COLORS.ButtonInactive

    ClearButton.Text = "CLEAR"
    ClearButton.TextColor3 = COLORS.TextPrimary
    ClearButton.TextSize = 9
    ClearButton.Font = Enum.Font.GothamBold
    ClearButton.AutoButtonColor = false
    ClearButton.Parent = SelectionTop

    local ClearCorner = Instance.new("UICorner")

    ClearCorner.CornerRadius = UDim.new(0, 6)
    ClearCorner.Parent = ClearButton

    local ScrollContainer = Instance.new("Frame")

    ScrollContainer.Size =
        UDim2.new(1, -24, 0, 245)

    ScrollContainer.Position =
        UDim2.new(0, 12, 0, 94)

    ScrollContainer.BackgroundColor3 =
        COLORS.CardBg

    ScrollContainer.BorderSizePixel = 0
    ScrollContainer.Parent = MainFrame

    local ContainerCorner =
        Instance.new("UICorner")

    ContainerCorner.CornerRadius =
        UDim.new(0, 8)

    ContainerCorner.Parent = ScrollContainer

    local ScrollFrame =
        Instance.new("ScrollingFrame")

    ScrollFrame.Size =
        UDim2.new(1, -8, 1, -8)

    ScrollFrame.Position =
        UDim2.new(0, 4, 0, 4)

    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 3
    ScrollFrame.ScrollBarImageColor3 =
        COLORS.Accent

    ScrollFrame.CanvasSize =
        UDim2.new(
            0,
            0,
            0,
            (#LUCKY_BLOCKS * 34) + 4
        )

    ScrollFrame.Parent = ScrollContainer

    local UIListLayout =
        Instance.new("UIListLayout")

    UIListLayout.Padding = UDim.new(0, 5)
    UIListLayout.SortOrder =
        Enum.SortOrder.LayoutOrder

    UIListLayout.Parent = ScrollFrame

    local buttonMap = {}

    local function updateBlockButton(
        blockName
    )
        local button = buttonMap[blockName]

        if not button then
            return
        end

        local selected =
            selectedBlocks[blockName] == true

        TweenService:Create(
            button,
            TweenInfo.new(0.15),
            {
                BackgroundColor3 =
                    selected
                    and COLORS.Accent
                    or COLORS.ButtonInactive,

                TextColor3 =
                    selected
                    and Color3.fromRGB(
                        255,
                        255,
                        255
                    )
                    or COLORS.TextMuted
            }
        ):Play()

        if selected then
            button.Text =
                "  ✓  " .. blockName
        else
            button.Text =
                "      " .. blockName
        end
    end

    local function updateAllButtons()
        for _, blockName in ipairs(
            LUCKY_BLOCKS
        ) do
            updateBlockButton(blockName)
        end

        SelectedLabel.Text =
            "SELECTED: "
            .. getSelectedCount()
            .. "/"
            .. #LUCKY_BLOCKS
    end

    updateSelectedCallback =
        updateAllButtons

    for _, blockName in ipairs(
        LUCKY_BLOCKS
    ) do
        local button =
            Instance.new("TextButton")

        button.Size =
            UDim2.new(1, -4, 0, 29)

        button.BackgroundColor3 =
            COLORS.ButtonInactive

        button.Text =
            "      " .. blockName

        button.TextColor3 =
            COLORS.TextMuted

        button.TextSize = 11
        button.Font = Enum.Font.GothamMedium
        button.TextXAlignment =
            Enum.TextXAlignment.Left

        button.AutoButtonColor = false
        button.Parent = ScrollFrame

        local corner =
            Instance.new("UICorner")

        corner.CornerRadius =
            UDim.new(0, 6)

        corner.Parent = button

        buttonMap[blockName] = button

        button.MouseButton1Click:Connect(
            function()
                selectedBlocks[blockName] =
                    not selectedBlocks[
                        blockName
                    ]

                updateAllButtons()
            end
        )

        button.MouseEnter:Connect(function()
            if not selectedBlocks[
                blockName
            ] then
                TweenService:Create(
                    button,
                    TweenInfo.new(0.1),
                    {
                        BackgroundColor3 =
                            COLORS.ButtonHover
                    }
                ):Play()
            end
        end)

        button.MouseLeave:Connect(function()
            updateBlockButton(blockName)
        end)
    end

    SelectAllButton.MouseButton1Click:Connect(
        function()
            for _, blockName in ipairs(
                LUCKY_BLOCKS
            ) do
                selectedBlocks[
                    blockName
                ] = true
            end

            updateAllButtons()
        end
    )

    ClearButton.MouseButton1Click:Connect(
        function()
            table.clear(selectedBlocks)
            updateAllButtons()
        end
    )

    updateAllButtons()

    local SettingsFrame =
        Instance.new("Frame")

    SettingsFrame.Size =
        UDim2.new(1, -24, 0, 45)

    SettingsFrame.Position =
        UDim2.new(0, 12, 0, 347)

    SettingsFrame.BackgroundColor3 =
        COLORS.CardBg

    SettingsFrame.BorderSizePixel = 0
    SettingsFrame.Parent = MainFrame

    local SettingsCorner =
        Instance.new("UICorner")

    SettingsCorner.CornerRadius =
        UDim.new(0, 8)

    SettingsCorner.Parent = SettingsFrame

    local DelayLabel =
        Instance.new("TextLabel")

    DelayLabel.Size =
        UDim2.new(0, 120, 1, 0)

    DelayLabel.Position =
        UDim2.new(0, 10, 0, 0)

    DelayLabel.BackgroundTransparency = 1
    DelayLabel.TextColor3 =
        COLORS.TextPrimary

    DelayLabel.TextSize = 10
    DelayLabel.Font =
        Enum.Font.GothamMedium

    DelayLabel.TextXAlignment =
        Enum.TextXAlignment.Left

    DelayLabel.Parent = SettingsFrame

    local MinusButton =
        Instance.new("TextButton")

    MinusButton.Size =
        UDim2.new(0, 30, 0, 27)

    MinusButton.Position =
        UDim2.new(1, -105, 0.5, -13)

    MinusButton.BackgroundColor3 =
        COLORS.ButtonInactive

    MinusButton.Text = "-"
    MinusButton.TextColor3 =
        COLORS.TextPrimary

    MinusButton.Font =
        Enum.Font.GothamBold

    MinusButton.TextSize = 14
    MinusButton.Parent = SettingsFrame

    local MinusCorner =
        Instance.new("UICorner")

    MinusCorner.CornerRadius =
        UDim.new(0, 6)

    MinusCorner.Parent = MinusButton

    local PlusButton =
        Instance.new("TextButton")

    PlusButton.Size =
        UDim2.new(0, 30, 0, 27)

    PlusButton.Position =
        UDim2.new(1, -70, 0.5, -13)

    PlusButton.BackgroundColor3 =
        COLORS.ButtonInactive

    PlusButton.Text = "+"
    PlusButton.TextColor3 =
        COLORS.TextPrimary

    PlusButton.Font =
        Enum.Font.GothamBold

    PlusButton.TextSize = 14
    PlusButton.Parent = SettingsFrame

    local PlusCorner =
        Instance.new("UICorner")

    PlusCorner.CornerRadius =
        UDim.new(0, 6)

    PlusCorner.Parent = PlusButton

    local function updateDelay()
        DelayLabel.Text =
            string.format(
                "CYCLE DELAY: %.1fs",
                cycleDelay
            )
    end

    updateDelayCallback = updateDelay

    MinusButton.MouseButton1Click:Connect(
        function()
            cycleDelay =
                math.max(
                    0.5,
                    cycleDelay - 0.5
                )

            updateDelay()
        end
    )

    PlusButton.MouseButton1Click:Connect(
        function()
            cycleDelay =
                math.min(
                    30,
                    cycleDelay + 0.5
                )

            updateDelay()
        end
    )

    updateDelay()

    local ReturnButton =
        Instance.new("TextButton")

    ReturnButton.Size =
        UDim2.new(1, -24, 0, 28)

    ReturnButton.Position =
        UDim2.new(0, 12, 0, 400)

    ReturnButton.BackgroundColor3 =
        COLORS.AccentDark

    ReturnButton.TextColor3 =
        COLORS.TextPrimary

    ReturnButton.TextSize = 10
    ReturnButton.Font =
        Enum.Font.GothamMedium

    ReturnButton.AutoButtonColor = false
    ReturnButton.Parent = MainFrame

    local ReturnCorner =
        Instance.new("UICorner")

    ReturnCorner.CornerRadius =
        UDim.new(0, 7)

    ReturnCorner.Parent = ReturnButton

    local function updateReturnButton()
        ReturnButton.Text =
            "RETURN AFTER BUY: "
            .. (
                returnAfterBuying
                and "ON"
                or "OFF"
            )

        ReturnButton.BackgroundColor3 =
            returnAfterBuying
            and COLORS.AccentDark
            or COLORS.ButtonInactive
    end

    ReturnButton.MouseButton1Click:Connect(
        function()
            returnAfterBuying =
                not returnAfterBuying

            updateReturnButton()
        end
    )

    updateReturnButton()

    local BuyOnceButton =
        Instance.new("TextButton")

    BuyOnceButton.Size =
        UDim2.new(0.46, 0, 0, 38)

    BuyOnceButton.Position =
        UDim2.new(0, 12, 0, 436)

    BuyOnceButton.BackgroundColor3 =
        COLORS.Accent

    BuyOnceButton.Text = "BUY ONCE"
    BuyOnceButton.TextColor3 =
        Color3.fromRGB(255,255,255)

    BuyOnceButton.TextSize = 11
    BuyOnceButton.Font =
        Enum.Font.GothamBold

    BuyOnceButton.AutoButtonColor = false
    BuyOnceButton.Parent = MainFrame

    local BuyOnceCorner =
        Instance.new("UICorner")

    BuyOnceCorner.CornerRadius =
        UDim.new(0, 8)

    BuyOnceCorner.Parent = BuyOnceButton

    local AutoButton =
        Instance.new("TextButton")

    AutoButton.Size =
        UDim2.new(0.46, 0, 0, 38)

    AutoButton.Position =
        UDim2.new(0.54, -12, 0, 436)

    AutoButton.BackgroundColor3 =
        COLORS.Success

    AutoButton.Text = "START AUTO"
    AutoButton.TextColor3 =
        Color3.fromRGB(255,255,255)

    AutoButton.TextSize = 11
    AutoButton.Font =
        Enum.Font.GothamBold

    AutoButton.AutoButtonColor = false
    AutoButton.Parent = MainFrame

    local AutoCorner =
        Instance.new("UICorner")

    AutoCorner.CornerRadius =
        UDim.new(0, 8)

    AutoCorner.Parent = AutoButton

    local StatusLabel =
        Instance.new("TextLabel")

    StatusLabel.Size =
        UDim2.new(1, -24, 0, 18)

    StatusLabel.Position =
        UDim2.new(0, 12, 0, 478)

    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 =
        COLORS.TextMuted

    StatusLabel.TextSize = 9
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextXAlignment =
        Enum.TextXAlignment.Left

    StatusLabel.TextTruncate =
        Enum.TextTruncate.AtEnd

    StatusLabel.Parent = MainFrame

    statusCallback = function(message)
        StatusLabel.Text =
            "Status: " .. message
    end

    local EventFrame =
        Instance.new("Frame")

    EventFrame.Size =
        UDim2.new(1, -24, 0, 48)

    EventFrame.Position =
        UDim2.new(0, 12, 0, 500)

    EventFrame.BackgroundColor3 =
        COLORS.CardBg

    EventFrame.BorderSizePixel = 0
    EventFrame.Parent = MainFrame

    local EventCorner =
        Instance.new("UICorner")

    EventCorner.CornerRadius =
        UDim.new(0, 8)

    EventCorner.Parent = EventFrame

    local NextEventLabel =
        Instance.new("TextLabel")

    NextEventLabel.Size =
        UDim2.new(1, -16, 0, 20)

    NextEventLabel.Position =
        UDim2.new(0, 8, 0, 4)

    NextEventLabel.BackgroundTransparency = 1
    NextEventLabel.Text = "NEXT: Loading..."
    NextEventLabel.TextColor3 =
        COLORS.TextPrimary
    NextEventLabel.TextSize = 10
    NextEventLabel.Font =
        Enum.Font.GothamBold
    NextEventLabel.TextXAlignment =
        Enum.TextXAlignment.Left

    NextEventLabel.Parent = EventFrame

    local AfterEventLabel =
        Instance.new("TextLabel")

    AfterEventLabel.Size =
        UDim2.new(1, -16, 0, 18)

    AfterEventLabel.Position =
        UDim2.new(0, 8, 0, 25)

    AfterEventLabel.BackgroundTransparency = 1
    AfterEventLabel.Text = "AFTER: Loading..."
    AfterEventLabel.TextColor3 =
        COLORS.TextMuted
    AfterEventLabel.TextSize = 9
    AfterEventLabel.Font =
        Enum.Font.GothamMedium
    AfterEventLabel.TextXAlignment =
        Enum.TextXAlignment.Left

    AfterEventLabel.Parent = EventFrame

    task.spawn(function()
        while ScreenGui.Parent do
            local nextEvent, afterEvent =
                getUpcomingEvents()

            NextEventLabel.Text =
                "NEXT: " .. nextEvent

            AfterEventLabel.Text =
                "AFTER: " .. afterEvent

            task.wait(1)
        end
    end)

    local KeybindLabel =
        Instance.new("TextLabel")

    KeybindLabel.Size =
        UDim2.new(1, 0, 0, 14)

    KeybindLabel.Position =
        UDim2.new(0, 0, 1, -16)

    KeybindLabel.BackgroundTransparency = 1

    KeybindLabel.Text =
        "[Right Control] Hide / Show"

    KeybindLabel.TextColor3 =
        COLORS.TextMuted

    KeybindLabel.TextSize = 8
    KeybindLabel.Font = Enum.Font.Gotham
    KeybindLabel.Parent = MainFrame

    BuyOnceButton.MouseButton1Click:Connect(
        function()
            if busy then
                setStatus(
                    "Already processing..."
                )
                return
            end

            task.spawn(function()
                buySelectedBlocks(false)
            end)
        end
    )

    AutoButton.MouseButton1Click:Connect(
        function()
            autoBuyActive =
                not autoBuyActive

            if autoBuyActive then
                AutoButton.Text =
                    "STOP AUTO"

                TweenService:Create(
                    AutoButton,
                    TweenInfo.new(0.2),
                    {
                        BackgroundColor3 =
                            COLORS.Danger
                    }
                ):Play()

                task.spawn(function()
                    while autoBuyActive do
                        if not busy then
                            buySelectedBlocks(
                                true
                            )
                        end

                        local waited = 0

                        while
                            autoBuyActive
                            and waited
                                < cycleDelay
                        do
                            task.wait(0.1)
                            waited += 0.1
                        end
                    end

                    setStatus("Stopped")
                end)
            else
                AutoButton.Text =
                    "START AUTO"

                TweenService:Create(
                    AutoButton,
                    TweenInfo.new(0.2),
                    {
                        BackgroundColor3 =
                            COLORS.Success
                    }
                ):Play()

                setStatus(
                    "Stopping..."
                )
            end
        end
    )

    UserInputService.InputBegan:Connect(
        function(input, processed)
            if processed then
                return
            end

            if input.KeyCode
                == Enum.KeyCode.RightControl
            then
                MainFrame.Visible =
                    not MainFrame.Visible
            end
        end
    )

    setStatus("Idle - select Lucky Blocks")
end

createGUI()
