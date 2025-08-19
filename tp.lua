local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local settings = {
    TeleportKey = Enum.KeyCode.LeftControl,
    HeightOffset = 2.5,
    TeleportEffect = true,
    EffectDuration = 0.8,
    SmoothTeleport = true,
    TweenDuration = 0.3,
    InfiniteDistance = true  -- Новая настройка бесконечной дистанции
}

-- Кэшируем часто используемые объекты
local camera = workspace.CurrentCamera
local character, humanoid, rootPart

-- Авто-обновление ссылок на персонажа
local function updateCharacterReferences()
    character = player.Character
    if character then
        humanoid = character:FindFirstChildOfClass("Humanoid")
        rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
    end
end

-- Создаем эффект телепортации
local function createTeleportEffect(position)
    if not settings.TeleportEffect then return end
    
    local effect = Instance.new("Part")
    effect.Size = Vector3.new(3, 0.2, 3)
    effect.Position = position - Vector3.new(0, settings.HeightOffset-0.1, 0)
    effect.Anchored = true
    effect.CanCollide = false
    effect.Material = Enum.Material.Neon
    effect.Color = Color3.fromHSV(tick()%5/5, 1, 1)
    effect.Transparency = 0.5
    effect.TopSurface = Enum.SurfaceType.Smooth
    effect.BottomSurface = Enum.SurfaceType.Smooth
    
    local ring = effect:Clone()
    ring.Size = Vector3.new(2, 0.2, 2)
    ring.Position = effect.Position + Vector3.new(0, 0.5, 0)
    
    effect.Parent = workspace
    ring.Parent = workspace
    
    game:GetService("Debris"):AddItem(effect, settings.EffectDuration)
    game:GetService("Debris"):AddItem(ring, settings.EffectDuration)
    
    -- Анимация исчезновения
    for _, part in pairs({effect, ring}) do
        local tween = TweenService:Create(
            part,
            TweenInfo.new(settings.EffectDuration, Enum.EasingStyle.Quad),
            {Transparency = 1}
        )
        tween:Play()
    end
end

-- Плавная телепортация
local function smoothTeleport(cframe)
    if not settings.SmoothTeleport or not humanoid then
        rootPart.CFrame = cframe
        return
    end
    
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    local tween = TweenService:Create(
        rootPart,
        TweenInfo.new(settings.TweenDuration, Enum.EasingStyle.Quad),
        {CFrame = cframe}
    )
    tween:Play()
    
    tween.Completed:Wait()
    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

-- Основная функция телепортации (бесконечная версия)
local function teleportToCursor()
    updateCharacterReferences()
    if not character or not humanoid or not rootPart then return end
    
    local mousePos = UserInputService:GetMouseLocation()
    local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    -- Если включена бесконечная дистанция, используем очень большое значение
    local distance = settings.InfiniteDistance and 99999 or 150
    
    local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * distance, raycastParams)
    
    -- Если нет пересечения с объектами, телепортируемся "вдаль"
    local targetPosition = raycastResult and raycastResult.Position or (ray.Origin + ray.Direction * distance)
    local teleportCFrame = CFrame.new(targetPosition + Vector3.new(0, settings.HeightOffset, 0))
    
    createTeleportEffect(teleportCFrame.Position)
    smoothTeleport(teleportCFrame)
end

-- Инициализация
player.CharacterAdded:Connect(updateCharacterReferences)
updateCharacterReferences()

-- Обработка ввода
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == settings.TeleportKey then
        teleportToCursor()
    end
end)

print(string.format(
    [[
Телепорт активирован (бесконечная версия)!
Клавиша: %s
Высота: %.1f
Плавный переход: %s
Эффекты: %s
]],
    settings.TeleportKey,
    settings.HeightOffset,
    settings.SmoothTeleport and "Вкл" or "Выкл",
    settings.TeleportEffect and "Вкл" or "Выкл"
))