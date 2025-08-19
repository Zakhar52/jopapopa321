-- Проверка и очистка предыдущей версии
if _G.AimLockSystem then
    _G.AimLockSystem:Destroy()
    _G.AimLockSystem = nil
    wait(0.1)
end

-- Создаем глобальную ссылку на систему
_G.AimLockSystem = {}
local system = _G.AimLockSystem

system.Enabled = true
system.Components = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

-- Настройки по умолчанию
local SETTINGS = {
    AIM_KEY = Enum.KeyCode.L,
    TELEPORT_KEY = Enum.KeyCode.T,
    TOGGLE_MENU_KEY = Enum.KeyCode.N, -- Новая клавиша для меню
    LOCK_DISTANCE = 100,
    SMOOTHNESS = 0.2,
    IGNORE_WALLS = true,
    SHOW_TARGET = true,
    SHOW_HITBOXES = false,
    FOV = 60,
    TELEPORT_HEIGHT = 2.5,
    AURA_ENABLED = false,
    AURA_COLOR = Color3.fromRGB(0, 255, 255),
    AURA_INTENSITY = 5,
    AURA_SIZE = 12,
    AURA_PULSE_SPEED = 2
}

-- Состояние системы
local AIM_ENABLED = false
local target = nil
local gui = nil
local aimIndicator = nil
local hitboxes = {}
local auraEffects = {}
local dragging = false
local dragStartPosition = Vector2.new(0, 0)
local frameStartPosition = UDim2.new()
local MENU_VISIBLE = true -- Состояние видимости меню

-- Функция для добавления скруглений
local function applyUICorner(object, cornerRadius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(cornerRadius, 0)
    corner.Parent = object
    return corner
end

-- Функция уничтожения системы
function system:Destroy()
    if self.Components.gui then
        self.Components.gui:Destroy()
    end
    if self.Components.aimIndicator then
        self.Components.aimIndicator:Destroy()
    end
    
    for _, effect in pairs(auraEffects) do
        if effect then
            effect:Destroy()
        end
    end
    auraEffects = {}
    
    for _, playerParts in pairs(hitboxes) do
        for _, part in pairs(playerParts) do
            part:Destroy()
        end
    end
    
    for _, connection in pairs(self.Components.connections or {}) do
        connection:Disconnect()
    end
    
    self.Enabled = false
    _G.AimLockSystem = nil
end

-- Сохраняем компоненты в систему
system.Components.connections = {}

-- Функция переключения видимости меню
local function toggleMenuVisibility()
    MENU_VISIBLE = not MENU_VISIBLE
    
    if gui and gui.Parent then
        gui.Enabled = MENU_VISIBLE
    end
    
    print("Меню:", MENU_VISIBLE and "ОТКРЫТО" or "СКРЫТО")
end

-- Корректная система перетаскивания GUI
local function setupDragging(frame, dragHandle)
    local isDragging = false
    local dragStart = nil
    local frameStart = nil
    
    -- Начало перетаскивания
    local function startDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            frameStart = frame.Position
            
            -- Захватываем мышь для плавного перемещения
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                end
            end)
        end
    end
    
    -- Обновление позиции при перетаскивании
    local function updateDrag(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local currentPosition = Vector2.new(input.Position.X, input.Position.Y)
            local delta = currentPosition - dragStart
            
            -- Плавное перемещение без рывков
            frame.Position = UDim2.new(
                frameStart.X.Scale, 
                frameStart.X.Offset + delta.X,
                frameStart.Y.Scale, 
                frameStart.Y.Offset + delta.Y
            )
        end
    end
    
    -- Окончание перетаскивания
    local function endDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end
    
    -- Подключаем обработчики событий
    local connections = {}
    
    connections.inputBegan = dragHandle.InputBegan:Connect(startDrag)
    connections.inputChanged = UserInputService.InputChanged:Connect(updateDrag)
    connections.inputEnded = UserInputService.InputEnded:Connect(endDrag)
    
    -- Сохраняем соединения для последующей очистки
    for _, conn in pairs(connections) do
        table.insert(system.Components.connections, conn)
    end
end

-- Создание аниме-ауры в стиле Dragon Ball
local function createDragonBallAura()
    for _, effect in pairs(auraEffects) do
        if effect then
            effect:Destroy()
        end
    end
    auraEffects = {}

    local player = Players.LocalPlayer
    if not player.Character then return end

    local humanoid = player.Character:FindFirstChild("Humanoid")
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end

    -- Основная аура вокруг тела
    local mainAura = Instance.new("Part")
    mainAura.Name = "DragonBallAura"
    mainAura.Size = Vector3.new(SETTINGS.AURA_SIZE, SETTINGS.AURA_SIZE, SETTINGS.AURA_SIZE)
    mainAura.Shape = Enum.PartType.Ball
    mainAura.Material = Enum.Material.Neon
    mainAura.Color = SETTINGS.AURA_COLOR
    mainAura.Transparency = 0.9
    mainAura.Anchored = true
    mainAura.CanCollide = false
    mainAura.Parent = workspace

    -- Интенсивное свечение
    local pointLight = Instance.new("PointLight")
    pointLight.Brightness = SETTINGS.AURA_INTENSITY
    pointLight.Range = 15
    pointLight.Color = SETTINGS.AURA_COLOR
    pointLight.Parent = mainAura

    -- Основные частицы ауры
    local mainParticles = Instance.new("ParticleEmitter")
    mainParticles.Texture = "rbxassetid://2425634065"
    mainParticles.Color = ColorSequence.new(SETTINGS.AURA_COLOR)
    mainParticles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 2),
        NumberSequenceKeypoint.new(0.5, 4),
        NumberSequenceKeypoint.new(1, 2)
    })
    mainParticles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.1),
        NumberSequenceKeypoint.new(1, 0.8)
    })
    mainParticles.Lifetime = NumberRange.new(1, 2)
    mainParticles.Rate = 100
    mainParticles.Speed = NumberRange.new(5, 10)
    mainParticles.VelocitySpread = 360
    mainParticles.Parent = mainAura

    -- Пульсация ауры
    local pulseTime = 0
    local function updateAura()
        while SETTINGS.AURA_ENABLED and system.Enabled and mainAura.Parent do
            pulseTime += RunService.Heartbeat:Wait() * SETTINGS.AURA_PULSE_SPEED
            
            local pulse = math.sin(pulseTime) * 0.2 + 1
            mainAura.Size = Vector3.new(SETTINGS.AURA_SIZE, SETTINGS.AURA_SIZE, SETTINGS.AURA_SIZE) * pulse
            pointLight.Brightness = SETTINGS.AURA_INTENSITY + math.sin(pulseTime * 2) * 2
            
            if hrp then
                mainAura.Position = hrp.Position + Vector3.new(0, 2, 0)
            end
            
            if math.random(1, 20) == 1 then
                mainParticles:Emit(10)
            end
        end
    end

    table.insert(auraEffects, mainAura)
    table.insert(auraEffects, pointLight)
    table.insert(auraEffects, mainParticles)

    coroutine.wrap(updateAura)()
end

-- Удаление ауры
local function removeDragonBallAura()
    for _, effect in pairs(auraEffects) do
        if effect then
            effect:Destroy()
        end
    end
    auraEffects = {}
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
    
    system.Components.aimIndicator = aimIndicator
end

-- Бесконечная телепортация
local function teleportToCursor()
    if not Players.LocalPlayer.Character then return end
    
    local camera = workspace.CurrentCamera
    local mousePos = UserInputService:GetMouseLocation()
    local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {Players.LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local distance = 99999
    local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * distance, raycastParams)
    
    local targetPosition = raycastResult and raycastResult.Position or (ray.Origin + ray.Direction * distance)
    local teleportCFrame = CFrame.new(targetPosition + Vector3.new(0, SETTINGS.TELEPORT_HEIGHT, 0))
    
    local hrp = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = teleportCFrame
        
        -- Эффект телепортации
        local effect = Instance.new("Part")
        effect.Size = Vector3.new(3, 0.2, 3)
        effect.Position = targetPosition
        effect.Anchored = true
        effect.CanCollide = false
        effect.Material = Enum.Material.Neon
        effect.Color = Color3.fromRGB(0, 150, 255)
        effect.Transparency = 0.7
        effect.Parent = workspace
        game:GetService("Debris"):AddItem(effect, 1)
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
    while AIM_ENABLED and system.Enabled and RunService.RenderStepped:Wait() do
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

-- Создание интерфейса
local function createGUI()
    if gui then gui:Destroy() end
    
    gui = Instance.new("ScreenGui")
    gui.Name = "AimLockUI"
    gui.Parent = CoreGui
    gui.ResetOnSpawn = false
    gui.Enabled = MENU_VISIBLE -- Устанавливаем начальную видимость
    
    system.Components.gui = gui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 320, 0, 330)
    mainFrame.Position = UDim2.new(0.5, -160, 0.5, -165)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui
    applyUICorner(mainFrame, 0.1)
    
    -- Панель для перетаскивания
    local dragHandle = Instance.new("Frame")
    dragHandle.Name = "DragHandle"
    dragHandle.Size = UDim2.new(1, 0, 0, 30)
    dragHandle.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    dragHandle.BorderSizePixel = 0
    dragHandle.Parent = mainFrame
    applyUICorner(dragHandle, 0.1)
    
    local title = Instance.new("TextLabel")
    title.Text = "ADVANCED CONTROL PANEL"
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 80, 80)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = dragHandle
    
    -- Настраиваем систему перетаскивания
    setupDragging(mainFrame, dragHandle)
    
    -- Кнопка включения аимлока
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Text = "TOGGLE AIMLOCK (L)"
    toggleBtn.Size = UDim2.new(0.9, 0, 0, 30)
    toggleBtn.Position = UDim2.new(0.05, 0, 0.1, 0)
    toggleBtn.BackgroundColor3 = AIM_ENABLED and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.Gotham
    toggleBtn.TextSize = 12
    toggleBtn.Parent = mainFrame
    applyUICorner(toggleBtn, 0.15)
    
    -- Переключатель Wallhack
    local wallhackBtn = Instance.new("TextButton")
    wallhackBtn.Text = "WALLHACK: " .. (SETTINGS.IGNORE_WALLS and "ON" or "OFF")
    wallhackBtn.Size = UDim2.new(0.9, 0, 0, 30)
    wallhackBtn.Position = UDim2.new(0.05, 0, 0.22, 0)
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
    hitboxBtn.Position = UDim2.new(0.05, 0, 0.34, 0)
    hitboxBtn.BackgroundColor3 = SETTINGS.SHOW_HITBOXES and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
    hitboxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    hitboxBtn.Font = Enum.Font.Gotham
    hitboxBtn.TextSize = 12
    hitboxBtn.Parent = mainFrame
    applyUICorner(hitboxBtn, 0.15)
    
    -- Кнопка телепортации
    local teleportBtn = Instance.new("TextButton")
    teleportBtn.Text = "TELEPORT (T)"
    teleportBtn.Size = UDim2.new(0.9, 0, 0, 30)
    teleportBtn.Position = UDim2.new(0.05, 0, 0.46, 0)
    teleportBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 255)
    teleportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    teleportBtn.Font = Enum.Font.Gotham
    teleportBtn.TextSize = 12
    teleportBtn.Parent = mainFrame
    applyUICorner(teleportBtn, 0.15)
    
    -- Кнопка ауры в стиле Dragon Ball
    local auraBtn = Instance.new("TextButton")
    auraBtn.Text = "KI AURA: " .. (SETTINGS.AURA_ENABLED and "ON" or "OFF")
    auraBtn.Size = UDim2.new(0.9, 0, 0, 30)
    auraBtn.Position = UDim2.new(0.05, 0, 0.58, 0)
    auraBtn.BackgroundColor3 = SETTINGS.AURA_ENABLED and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(100, 100, 100)
    auraBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    auraBtn.Font = Enum.Font.Gotham
    auraBtn.TextSize = 12
    auraBtn.Parent = mainFrame
    applyUICorner(auraBtn, 0.15)
    
    -- Информация о переключении меню
    local menuInfo = Instance.new("TextLabel")
    menuInfo.Text = "N - Показать/Скрыть меню"
    menuInfo.Size = UDim2.new(0.9, 0, 0, 30)
    menuInfo.Position = UDim2.new(0.05, 0, 0.70, 0)
    menuInfo.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    menuInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
    menuInfo.Font = Enum.Font.Gotham
    menuInfo.TextSize = 11
    menuInfo.Parent = mainFrame
    applyUICorner(menuInfo, 0.15)
    
    -- Информация о высоте телепортации
    local heightInfo = Instance.new("TextLabel")
    heightInfo.Text = "TELEPORT HEIGHT: " .. SETTINGS.TELEPORT_HEIGHT
    heightInfo.Size = UDim2.new(0.9, 0, 0, 30)
    heightInfo.Position = UDim2.new(0.05, 0, 0.82, 0)
    heightInfo.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    heightInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
    heightInfo.Font = Enum.Font.Gotham
    heightInfo.TextSize = 12
    heightInfo.Parent = mainFrame
    applyUICorner(heightInfo, 0.15)
    
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
    end)
    
    teleportBtn.MouseButton1Click:Connect(function()
        teleportToCursor()
    end)
    
    auraBtn.MouseButton1Click:Connect(function()
        SETTINGS.AURA_ENABLED = not SETTINGS.AURA_ENABLED
        auraBtn.Text = "KI AURA: " .. (SETTINGS.AURA_ENABLED and "ON" or "OFF")
        auraBtn.BackgroundColor3 = SETTINGS.AURA_ENABLED and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(100, 100, 100)
        
        if SETTINGS.AURA_ENABLED then
            createDragonBallAura()
        else
            removeDragonBallAura()
        end
    end)
    
    -- Горячие клавиши
    local keyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed then
            if input.KeyCode == SETTINGS.AIM_KEY then
                AIM_ENABLED = not AIM_ENABLED
                toggleBtn.BackgroundColor3 = AIM_ENABLED and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
                
                if AIM_ENABLED then
                    coroutine.wrap(aimAtTarget)()
                elseif aimIndicator then
                    aimIndicator:Destroy()
                    aimIndicator = nil
                end
            elseif input.KeyCode == SETTINGS.TELEPORT_KEY then
                teleportToCursor()
            elseif input.KeyCode == SETTINGS.TOGGLE_MENU_KEY then
                toggleMenuVisibility()
            end
        end
    end)
    
    table.insert(system.Components.connections, keyConnection)
end

-- Инициализация
createGUI()

-- Очистка при выходе
game:BindToClose(function()
    if system and system.Enabled then
        system:Destroy()
    end
end)

print("Система управления загружена!")
print("N - Показать/Скрыть меню")
print("T - Телепортация") 
print("L - Вкл/Выкл прицеливание")
