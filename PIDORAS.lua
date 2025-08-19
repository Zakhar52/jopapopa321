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
    LOCK_DISTANCE = 100,
    SMOOTHNESS = 0.2,
    IGNORE_WALLS = true,
    SHOW_TARGET = true,
    SHOW_HITBOXES = false,
    FOV = 60,
    TELEPORT_HEIGHT = 2.5,
    AURA_ENABLED = false,
    AURA_COLOR = Color3.fromRGB(0, 255, 255), -- Голубой цвет как у SSJ
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
local dragStartPos = Vector2.new(0, 0)
local frameStartPos = Vector2.new(0, 0)

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
    
    -- Удаляем все эффекты ауры
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

-- Создание аниме-ауры в стиле Dragon Ball
local function createDragonBallAura()
    -- Очищаем предыдущие эффекты
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

    -- Энергетические всполохи (как в аниме)
    local energyParticles = Instance.new("ParticleEmitter")
    energyParticles.Texture = "rbxassetid://243664672"
    energyParticles.Color = ColorSequence.new(SETTINGS.AURA_COLOR)
    energyParticles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 3),
        NumberSequenceKeypoint.new(1, 1)
    })
    energyParticles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 0.9)
    })
    energyParticles.Lifetime = NumberRange.new(0.5, 1)
    energyParticles.Rate = 50
    energyParticles.Speed = NumberRange.new(10, 20)
    energyParticles.Rotation = NumberRange.new(0, 360)
    energyParticles.Parent = mainAura

    -- Эффект электрических разрядов
    local lightningParticles = Instance.new("ParticleEmitter")
    lightningParticles.Texture = "rbxassetid://245221102"
    lightningParticles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 200))
    lightningParticles.Size = NumberSequence.new(1, 3)
    lightningParticles.Transparency = NumberSequence.new(0.3, 0.8)
    lightningParticles.Lifetime = NumberRange.new(0.3, 0.7)
    lightningParticles.Rate = 30
    lightningParticles.Speed = NumberRange.new(15, 25)
    lightningParticles.Parent = mainAura

    -- Аура вокруг рук
    local function createHandAuras()
        local handParts = {}
        if humanoid.RigType == Enum.HumanoidRigType.R6 then
            handParts = {
                player.Character:FindFirstChild("Left Arm"),
                player.Character:FindFirstChild("Right Arm")
            }
        else
            handParts = {
                player.Character:FindFirstChild("LeftHand"),
                player.Character:FindFirstChild("RightHand"),
                player.Character:FindFirstChild("LeftLowerArm"),
                player.Character:FindFirstChild("RightLowerArm")
            }
        end

        for _, hand in pairs(handParts) do
            if hand then
                local handGlow = Instance.new("PointLight")
                handGlow.Brightness = 3
                handGlow.Range = 8
                handGlow.Color = SETTINGS.AURA_COLOR
                handGlow.Parent = hand

                local handParticles = Instance.new("ParticleEmitter")
                handParticles.Texture = "rbxassetid://2425634065"
                handParticles.Color = ColorSequence.new(SETTINGS.AURA_COLOR)
                handParticles.Size = NumberSequence.new(0.5, 1.5)
                handParticles.Lifetime = NumberRange.new(0.5, 1)
                handParticles.Rate = 25
                handParticles.Speed = NumberRange.new(3, 7)
                handParticles.Parent = hand

                table.insert(auraEffects, handGlow)
                table.insert(auraEffects, handParticles)
            end
        end
    end

    createHandAuras()

    -- Пульсация ауры
    local pulseTime = 0
    local function updateAura()
        while SETTINGS.AURA_ENABLED and system.Enabled and mainAura.Parent do
            pulseTime += RunService.Heartbeat:Wait() * SETTINGS.AURA_PULSE_SPEED
            
            -- Пульсация размера
            local pulse = math.sin(pulseTime) * 0.2 + 1
            mainAura.Size = Vector3.new(SETTINGS.AURA_SIZE, SETTINGS.AURA_SIZE, SETTINGS.AURA_SIZE) * pulse
            
            -- Пульсация свечения
            pointLight.Brightness = SETTINGS.AURA_INTENSITY + math.sin(pulseTime * 2) * 2
            
            -- Следование за игроком
            if hrp then
                mainAura.Position = hrp.Position + Vector3.new(0, 2, 0)
            end
            
            -- Случайные вспышки энергии
            if math.random(1, 20) == 1 then
                mainParticles:Emit(10)
            end
        end
    end

    table.insert(auraEffects, mainAura)
    table.insert(auraEffects, pointLight)
    table.insert(auraEffects, mainParticles)
    table.insert(auraEffects, energyParticles)
    table.insert(auraEffects, lightningParticles)

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

-- Создание интерфейса с UICorner
local function createGUI()
    if gui then gui:Destroy() end
    
    gui = Instance.new("ScreenGui")
    gui.Name = "AimLockUI"
    gui.Parent = CoreGui
    
    system.Components.gui = gui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 320, 0, 330)
    mainFrame.Position = UDim2.new(0.5, -160, 0.5, -165)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui
    applyUICorner(mainFrame, 0.1)
    
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    applyUICorner(titleBar, 0.1)
    
    local title = Instance.new("TextLabel")
    title.Text = "ADVANCED CONTROL PANEL"
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 80, 80)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = titleBar
    
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
    
    -- Слайдер дистанции
    local distanceSlider = Instance.new("TextLabel")
    distanceSlider.Text = "DISTANCE: " .. SETTINGS.LOCK_DISTANCE
    distanceSlider.Size = UDim2.new(0.9, 0, 0, 30)
    distanceSlider.Position = UDim2.new(0.05, 0, 0.70, 0)
    distanceSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    distanceSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
    distanceSlider.Font = Enum.Font.Gotham
    distanceSlider.TextSize = 12
    distanceSlider.Parent = mainFrame
    applyUICorner(distanceSlider, 0.15)
    
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
    
    -- Логика перемещения окна
    local dragConnection = titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStartPos = Vector2.new(input.Position.X, input.Position.Y)
            frameStartPos = Vector2.new(mainFrame.Position.X.Offset, mainFrame.Position.Y.Offset)
        end
    end)
    table.insert(system.Components.connections, dragConnection)
    
    local moveConnection = UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = Vector2.new(input.Position.X, input.Position.Y)
            local delta = mousePos - dragStartPos
            mainFrame.Position = UDim2.new(0, frameStartPos.X + delta.X, 0, frameStartPos.Y + delta.Y)
        end
    end)
    table.insert(system.Components.connections, moveConnection)
    
    local endConnection = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    table.insert(system.Components.connections, endConnection)
    
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
            end
        end
    end)
    table.insert(system.Components.connections, keyConnection)
end

-- Обработка смены персонажа
local function onCharacterAdded(character)
    if SETTINGS.AURA_ENABLED then
        -- Пересоздаем ауру при появлении нового персонажа
        removeDragonBallAura()
        wait(1)
        createDragonBallAura()
    end
end

-- Инициализация
local player = Players.LocalPlayer
if player then
    local charConnection = player.CharacterAdded:Connect(onCharacterAdded)
    table.insert(system.Components.connections, charConnection)
    
    if player.Character then
        onCharacterAdded(player.Character)
    end
end

for _, otherPlayer in ipairs(Players:GetPlayers()) do
    if otherPlayer ~= player then
        local charConnection = otherPlayer.CharacterAdded:Connect(function(character)
            if SETTINGS.SHOW_HITBOXES then
                updateHitboxes()
            end
        end)
        table.insert(system.Components.connections, charConnection)
    end
end

local playerAddedConnection = Players.PlayerAdded:Connect(function(newPlayer)
    if newPlayer ~= player then
        local charConnection = newPlayer.CharacterAdded:Connect(function(character)
            if SETTINGS.SHOW_HITBOXES then
                updateHitboxes()
            end
        end)
        table.insert(system.Components.connections, charConnection)
    end
end)
table.insert(system.Components.connections, playerAddedConnection)

local playerRemovedConnection = Players.PlayerRemoving:Connect(function(leftPlayer)
    if hitboxes[leftPlayer] then
        for _, part in pairs(hitboxes[leftPlayer]) do
            part:Destroy()
        end
        hitboxes[leftPlayer] = nil
    end
end)
table.insert(system.Components.connections, playerRemovedConnection)

createGUI()

-- Очистка при выходе
game:BindToClose(function()
    if system and system.Enabled then
        system:Destroy()
    end
end)

print("Система управления с аурой в стиле Dragon Ball загружена!")
