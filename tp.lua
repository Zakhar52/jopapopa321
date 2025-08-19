local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

-- Настройки по умолчанию
local SETTINGS = {
    AIM_KEY = Enum.KeyCode.L,
    LOCK_DISTANCE = 100,
    SMOOTHNESS = 0.2,
    IGNORE_WALLS = true,
    SHOW_TARGET = true,
    SHOW_HITBOXES = false,
    FOV = 60
}

-- Состояние системы
local AIM_ENABLED = false
local target = nil
local gui = nil
local aimIndicator = nil
local hitboxes = {}
local dragging = false
local dragStartPos = Vector2.new(0, 0)
local frameStartPos = Vector2.new(0, 0)

-- Функция для добавления скруглений
local function applyUICorner(object, cornerRadius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(cornerRadius, 0)
    corner.Parent = object
    return corner
end

-- Создание 3D индикатора цели
local function createAimIndicator()
    if aimIndicator then aimIndicator:Destroy() end
    
    aimIndicator = Instance.new("Part")
    aimIndicator.Name = "AimLockTarget"
    aimIndicator.Size = Vector3.new(1.5, 1.5, 1.5)
    aimIndicator.Shape = Enum.PartType.Ball
    aimIndicator.Material = Enum.Material.Neon
    aimIndicator.Color = Color3.fromRGB(255, 50, 50)
    aimIndicator.Transparency = 0.7
    aimIndicator.Anchored = true
    aimIndicator.CanCollide = false
    aimIndicator.Parent = workspace
end

-- Создание/удаление хитбоксов
local function updateHitboxes()
    for player, parts in pairs(hitboxes) do
        for _, part in pairs(parts) do
            part:Destroy()
        end
    end
    hitboxes = {}

    if not SETTINGS.SHOW_HITBOXES then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer and player.Character then
            hitboxes[player] = {}
            for _, part in ipairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    local hitbox = Instance.new("BoxHandleAdornment")
                    hitbox.Name = "HitboxVisualizer"
                    hitbox.Adornee = part
                    hitbox.AlwaysOnTop = true
                    hitbox.ZIndex = 10
                    hitbox.Size = part.Size
                    hitbox.Transparency = 0.7
                    hitbox.Color3 = Color3.fromRGB(0, 255, 255)
                    hitbox.Parent = part
                    table.insert(hitboxes[player], hitbox)
                end
            end
        end
    end
end

-- Поиск цели с учетом FOV
local function findTarget()
    local closestTarget = nil
    local closestAngle = math.rad(SETTINGS.FOV)
    local closestDistance = SETTINGS.LOCK_DISTANCE
    
    local localPlayer = Players.LocalPlayer
    if not localPlayer.Character then return nil end
    
    local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local camera = workspace.CurrentCamera
    local cameraPos = camera.CFrame.Position
    local cameraLook = camera.CFrame.LookVector
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
            if targetHrp then
                local direction = (targetHrp.Position - cameraPos).Unit
                local angle = math.acos(cameraLook:Dot(direction))
                local distance = (targetHrp.Position - hrp.Position).Magnitude
                
                if angle <= closestAngle and distance <= closestDistance then
                    if SETTINGS.IGNORE_WALLS then
                        closestTarget = targetHrp
                        closestAngle = angle
                        closestDistance = distance
                    else
                        local raycastParams = RaycastParams.new()
                        raycastParams.FilterDescendantsInstances = {localPlayer.Character}
                        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                        
                        local raycastResult = workspace:Raycast(cameraPos, direction * distance, raycastParams)
                        if not raycastResult then
                            closestTarget = targetHrp
                            closestAngle = angle
                            closestDistance = distance
                        end
                    end
                end
            end
        end
    end
    
    return closestTarget
end

-- Плавное наведение камеры
local function aimAtTarget()
    while AIM_ENABLED and RunService.RenderStepped:Wait() do
        target = findTarget()
        
        if target then
            local camera = workspace.CurrentCamera
            local newCFrame = CFrame.lookAt(camera.CFrame.Position, target.Position)
            camera.CFrame = camera.CFrame:Lerp(newCFrame, SETTINGS.SMOOTHNESS)
            
            if SETTINGS.SHOW_TARGET then
                if not aimIndicator then
                    createAimIndicator()
                end
                aimIndicator.Position = target.Position + Vector3.new(0, 2, 0)
                aimIndicator.Transparency = 0.3
            end
        elseif aimIndicator then
            aimIndicator.Transparency = 1
        end
    end
end

-- Создание интерфейса с UICorner
local function createGUI()
    if gui then gui:Destroy() end
    
    gui = Instance.new("ScreenGui")
    gui.Name = "AimLockUI"
    gui.Parent = CoreGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 320, 0, 250)
    mainFrame.Position = UDim2.new(0.5, -160, 0.5, -125)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui
    applyUICorner(mainFrame, 0.1) -- Скругление основного фрейма
    
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    applyUICorner(titleBar, 0.1) -- Скругление верхней панели
    
    local title = Instance.new("TextLabel")
    title.Text = "AIMLOCK CONTROL PANEL"
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 80, 80)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = titleBar
    
    -- Кнопка включения
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Text = "TOGGLE AIMLOCK (L)"
    toggleBtn.Size = UDim2.new(0.9, 0, 0, 35)
    toggleBtn.Position = UDim2.new(0.05, 0, 0.15, 0)
    toggleBtn.BackgroundColor3 = AIM_ENABLED and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.Gotham
    toggleBtn.TextSize = 12
    toggleBtn.Parent = mainFrame
    applyUICorner(toggleBtn, 0.15) -- Скругление кнопки
    
    -- Переключатель Wallhack
    local wallhackBtn = Instance.new("TextButton")
    wallhackBtn.Text = "WALLHACK: " .. (SETTINGS.IGNORE_WALLS and "ON" or "OFF")
    wallhackBtn.Size = UDim2.new(0.9, 0, 0, 30)
    wallhackBtn.Position = UDim2.new(0.05, 0, 0.35, 0)
    wallhackBtn.BackgroundColor3 = SETTINGS.IGNORE_WALLS and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
    wallhackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    wallhackBtn.Font = Enum.Font.Gotham
    wallhackBtn.TextSize = 12
    wallhackBtn.Parent = mainFrame
    applyUICorner(wallhackBtn, 0.15)
    
    -- Переключатель хитбоксов
    local hitboxBtn = Instance.new("TextButton")
    hitboxBtn.Text = "HITBOXES: " .. (SETTINGS.SHOW_HITBOXES and "ON" or "OFF")
    hitboxBtn.Size = UDim2.new(0.9, 0, 0, 30)
    hitboxBtn.Position = UDim2.new(0.05, 0, 0.55, 0)
    hitboxBtn.BackgroundColor3 = SETTINGS.SHOW_HITBOXES and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
    hitboxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    hitboxBtn.Font = Enum.Font.Gotham
    hitboxBtn.TextSize = 12
    hitboxBtn.Parent = mainFrame
    applyUICorner(hitboxBtn, 0.15)
    
    -- Слайдер дистанции
    local distanceSlider = Instance.new("TextLabel")
    distanceSlider.Text = "DISTANCE: " .. SETTINGS.LOCK_DISTANCE
    distanceSlider.Size = UDim2.new(0.9, 0, 0, 30)
    distanceSlider.Position = UDim2.new(0.05, 0, 0.75, 0)
    distanceSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    distanceSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
    distanceSlider.Font = Enum.Font.Gotham
    distanceSlider.TextSize = 12
    distanceSlider.Parent = mainFrame
    applyUICorner(distanceSlider, 0.15)
    
    -- Логика перемещения окна
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStartPos = Vector2.new(input.Position.X, input.Position.Y)
            frameStartPos = Vector2.new(mainFrame.Position.X.Offset, mainFrame.Position.Y.Offset)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = Vector2.new(input.Position.X, input.Position.Y)
            local delta = mousePos - dragStartPos
            mainFrame.Position = UDim2.new(0, frameStartPos.X + delta.X, 0, frameStartPos.Y + delta.Y)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    -- Обработчики кнопок
    toggleBtn.MouseButton1Click:Connect(function()
        AIM_ENABLED = not AIM_ENABLED
        toggleBtn.BackgroundColor3 = AIM_ENABLED and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
        
        if AIM_ENABLED then
            coroutine.wrap(aimAtTarget)()
        elseif aimIndicator then
            aimIndicator:Destroy()
            aimIndicator = nil
        end
    end)
    
    wallhackBtn.MouseButton1Click:Connect(function()
        SETTINGS.IGNORE_WALLS = not SETTINGS.IGNORE_WALLS
        wallhackBtn.Text = "WALLHACK: " .. (SETTINGS.IGNORE_WALLS and "ON" or "OFF")
        wallhackBtn.BackgroundColor3 = SETTINGS.IGNORE_WALLS and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
    end)
    
    hitboxBtn.MouseButton1Click:Connect(function()
        SETTINGS.SHOW_HITBOXES = not SETTINGS.SHOW_HITBOXES
        hitboxBtn.Text = "HITBOXES: " .. (SETTINGS.SHOW_HITBOXES and "ON" or "OFF")
        hitboxBtn.BackgroundColor3 = SETTINGS.SHOW_HITBOXES and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
        updateHitboxes()
    end)
    
    -- Горячая клавиша
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.KeyCode == SETTINGS.AIM_KEY and not gameProcessed then
            AIM_ENABLED = not AIM_ENABLED
            toggleBtn.BackgroundColor3 = AIM_ENABLED and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
            
            if AIM_ENABLED then
                coroutine.wrap(aimAtTarget)()
            elseif aimIndicator then
                aimIndicator:Destroy()
                aimIndicator = nil
            end
        end
    end)
end

-- Обработка новых игроков
local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(character)
        if SETTINGS.SHOW_HITBOXES then
            updateHitboxes()
        end
    end)
    
    player.CharacterRemoving:Connect(function()
        if hitboxes[player] then
            for _, part in pairs(hitboxes[player]) do
                part:Destroy()
            end
            hitboxes[player] = nil
        end
    end)
end

-- Инициализация
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    if hitboxes[player] then
        for _, part in pairs(hitboxes[player]) do
            part:Destroy()
        end
        hitboxes[player] = nil
    end
end)

createGUI()

-- Очистка при выходе
game:BindToClose(function()
    if aimIndicator then
        aimIndicator:Destroy()
    end
    if gui then
        gui:Destroy()
    end
    for _, playerParts in pairs(hitboxes) do
        for _, part in pairs(playerParts) do
            part:Destroy()
        end
    end
end)

print("AimLock система с улучшенным UI успешно загружена!")
