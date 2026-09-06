local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Exact Lucky Block tiers
local LUCKY_BLOCKS = {
    "Awakening", "Calamity", "Common", "Domain", 
    "Epic", "Frame", "Legacy", "Legendary", 
    "Manga", "Mythic", "New Era", "Prodigy", 
    "Rare", "Secret", "Transcendent", "Uncommon"
}

local selectedBlock = "Common"
local autoBuyActive = false
local statusCallback = nil

-- Modern UI Palette
local COLORS = {
    Background = Color3.fromRGB(15, 15, 20),
    CardBg = Color3.fromRGB(24, 24, 32),
    Accent = Color3.fromRGB(114, 137, 218),
    AccentGlow = Color3.fromRGB(88, 101, 242),
    TextPrimary = Color3.fromRGB(240, 240, 245),
    TextMuted = Color3.fromRGB(140, 140, 160),
    Success = Color3.fromRGB(67, 181, 129),
    Danger = Color3.fromRGB(240, 71, 71),
    ButtonInactive = Color3.fromRGB(32, 34, 42)
}

-- Keypress simulator
local function pressE()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

-- Universal Click simulator
local function clickButton(button)
    if not button then return end
    
    if getconnections then
        for _, connection in ipairs(getconnections(button.MouseButton1Click)) do
            connection:Fire()
        end
        for _, connection in ipairs(getconnections(button.Activated)) do
            connection:Fire()
        end
    end

    local absolutePos = button.AbsolutePosition
    local absoluteSize = button.AbsoluteSize
    local centerX = absolutePos.X + (absoluteSize.X / 2)
    local centerY = absolutePos.Y + (absoluteSize.Y / 2) + 36
    
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
end

-- Main Buy Routine
local function executeBuyProcess()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
    if not humanoidRootPart then return end

    if statusCallback then statusCallback("Teleporting to shop...") end
    
    local shopFolder = Workspace:WaitForChild("luckyblocks", 5)
    if not shopFolder then
        if statusCallback then statusCallback("Err: luckyblocks missing!") end
        return
    end

    local shopTarget = shopFolder:FindFirstChildWhichIsA("BasePart") or shopFolder:FindFirstChildWhichIsA("Model")
    if not shopTarget then
        if statusCallback then statusCallback("Err: Shop model missing!") end
        return
    end

    local shopCFrame = shopTarget:IsA("Model") and (shopTarget:GetPrimaryPartCFrame() or shopTarget:FindFirstChildWhichIsA("BasePart").CFrame) or shopTarget.CFrame
    humanoidRootPart.CFrame = shopCFrame * CFrame.new(0, 3, 0)
    task.wait(0.4)

    if statusCallback then statusCallback("Opening shop UI...") end
    pressE()
    task.wait(0.6)

    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local targetBlockFrame = nil

    for _, element in ipairs(playerGui:GetDescendants()) do
        if element.Name == selectedBlock and (element:IsA("Frame") or element:IsA("ImageLabel") or element:IsA("TextLabel")) then
            targetBlockFrame = element:IsA("Frame") and element or element.Parent
            break
        end
    end

    if not targetBlockFrame then
        for _, element in ipairs(playerGui:GetDescendants()) do
            if element:IsA("ScrollingFrame") and element.Visible then
                local currentOffset = 0
                local maxScroll = element.AbsoluteCanvasSize.Y
                
                while currentOffset <= maxScroll and autoBuyActive do
                    element.CanvasPosition = Vector2.new(0, currentOffset)
                    task.wait(0.05)
                    
                    local found = element:FindFirstChild(selectedBlock, true)
                    if found then
                        targetBlockFrame = found:IsA("Frame") and found or found.Parent
                        break
                    end
                    currentOffset = currentOffset + 120
                end
            end
            if targetBlockFrame then break end
        end
    end

    local buyMaxButton = nil
    if targetBlockFrame then
        buyMaxButton = targetBlockFrame:FindFirstChild("BuyMax", true)
    end

    if not buyMaxButton then
        for _, element in ipairs(playerGui:GetDescendants()) do
            if element.Name == "BuyMax" and (element:IsA("TextButton") or element:IsA("ImageButton")) and element.Visible then
                buyMaxButton = element
                break
            end
        end
    end

    if buyMaxButton then
        clickButton(buyMaxButton)
        if statusCallback then statusCallback("Bought: " .. selectedBlock) end
    else
        if statusCallback then statusCallback("Err: BuyMax missing!") end
    end
end

-- Premium GUI Builder
local function createGUI()
    local parentTarget = CoreGui:FindFirstChild("RobloxGui") or LocalPlayer:WaitForChild("PlayerGui")
    if parentTarget:FindFirstChild("LuckyBlockProGUI") then
        parentTarget.LuckyBlockProGUI:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "LuckyBlockProGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = parentTarget

    -- Window Outer Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 260, 0, 390)
    MainFrame.Position = UDim2.new(0.5, -130, 0.35, -195)
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
    MainStroke.Transparency = 0.6
    MainStroke.Parent = MainFrame

    -- Header Title Bar
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 42)
    Header.BackgroundTransparency = 1
    Header.Parent = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -50, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "LUCKYBLOCK HUB"
    Title.TextColor3 = COLORS.TextPrimary
    Title.TextSize = 14
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header

    local SubTitle = Instance.new("TextLabel")
    SubTitle.Size = UDim2.new(1, -20, 0, 15)
    SubTitle.Position = UDim2.new(0, 15, 0, 26)
    SubTitle.BackgroundTransparency = 1
    SubTitle.Text = "Select block & toggle auto-buy"
    SubTitle.TextColor3 = COLORS.TextMuted
    SubTitle.TextSize = 10
    SubTitle.Font = Enum.Font.Gotham
    SubTitle.TextXAlignment = Enum.TextXAlignment.Left
    SubTitle.Parent = Header

    -- Scroll Area
    local ScrollContainer = Instance.new("Frame")
    ScrollContainer.Size = UDim2.new(1, -24, 0, 220)
    ScrollContainer.Position = UDim2.new(0, 12, 0, 48)
    ScrollContainer.BackgroundColor3 = COLORS.CardBg
    ScrollContainer.BorderSizePixel = 0
    ScrollContainer.Parent = MainFrame

    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 8)
    ContainerCorner.Parent = ScrollContainer

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -8, 1, -8)
    ScrollFrame.Position = UDim2.new(0, 4, 0, 4)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, (#LUCKY_BLOCKS * 32) + 6)
    ScrollFrame.ScrollBarThickness = 3
    ScrollFrame.ScrollBarImageColor3 = COLORS.Accent
    ScrollFrame.Parent = ScrollContainer

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 4)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = ScrollFrame

    local buttonMap = {}

    for _, blockName in ipairs(LUCKY_BLOCKS) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -4, 0, 28)
        btn.BackgroundColor3 = (blockName == selectedBlock) and COLORS.Accent or COLORS.ButtonInactive
        btn.Text = "   " .. blockName
        btn.TextColor3 = (blockName == selectedBlock) and Color3.fromRGB(255, 255, 255) or COLORS.TextMuted
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamMedium
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.Parent = ScrollFrame

        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 6)
        BtnCorner.Parent = btn

        buttonMap[blockName] = btn

        btn.MouseButton1Click:Connect(function()
            selectedBlock = blockName
            for name, button in pairs(buttonMap) do
                local isSelected = (name == selectedBlock)
                TweenService:Create(button, TweenInfo.new(0.2), {
                    BackgroundColor3 = isSelected and COLORS.Accent or COLORS.ButtonInactive,
                    TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or COLORS.TextMuted
                }):Play()
            end
        end)
    end

    -- Status Bar Display
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, -24, 0, 20)
    StatusLabel.Position = UDim2.new(0, 12, 0, 276)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 = COLORS.TextMuted
    StatusLabel.TextSize = 11
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = MainFrame

    statusCallback = function(msg)
        StatusLabel.Text = "Status: " .. msg
    end

    -- Action Toggle Button
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(1, -24, 0, 42)
    ToggleButton.Position = UDim2.new(0, 12, 0, 302)
    ToggleButton.BackgroundColor3 = COLORS.Success
    ToggleButton.Text = "START AUTO BUY"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.TextSize = 13
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.AutoButtonColor = false
    ToggleButton.Parent = MainFrame

    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 8)
    ToggleCorner.Parent = ToggleButton

    -- Hide Keybind Footnote
    local KeybindInfo = Instance.new("TextLabel")
    KeybindInfo.Size = UDim2.new(1, 0, 0, 15)
    KeybindInfo.Position = UDim2.new(0, 0, 0, 354)
    KeybindInfo.BackgroundTransparency = 1
    KeybindInfo.Text = "Press [Right Control] to Hide/Show"
    KeybindInfo.TextColor3 = COLORS.TextMuted
    KeybindInfo.TextSize = 9
    KeybindInfo.Font = Enum.Font.Gotham
    KeybindInfo.Parent = MainFrame

    -- Toggle Loop & UI Animations
    ToggleButton.MouseButton1Click:Connect(function()
        autoBuyActive = not autoBuyActive
        
        if autoBuyActive then
            TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.Danger}):Play()
            ToggleButton.Text = "STOP AUTO BUY"
            
            task.spawn(function()
                while autoBuyActive do
                    executeBuyProcess()
                    task.wait(1.2)
                end
                StatusLabel.Text = "Status: Stopped"
            end)
        else
            TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.Success}):Play()
            ToggleButton.Text = "START AUTO BUY"
        end
    end)

    -- Toggle UI Visibility via Right Control key
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.RightControl then
            MainFrame.Visible = not MainFrame.Visible
        end
    end)
end

createGUI()
