local Players = game:FindService("Players") or game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local function safeLoadstring(url, fallbackMsg)
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if not success then
        warn("Failed to load: " .. fallbackMsg .. " - " .. tostring(result))
        return nil
    end
    return result
end

local Fluent = safeLoadstring("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua", "Fluent Library")
local SaveManager = safeLoadstring("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua", "SaveManager")
local InterfaceManager = safeLoadstring("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua", "InterfaceManager")

if not Fluent then
    error("❌ Failed to load Fluent library! Please check your internet connection.")
end

local LocalPlayer = Players.LocalPlayer
local Options = Fluent.Options
local Connections = {}

local DEBUG_ENABLED = true
local function DebugLog(msg, level)
    if not DEBUG_ENABLED then return end
    local prefix = "🔧 [SwirlHub"
    level = level or "INFO"
    
    if level == "ERROR" then
        prefix = "❌ [SwirlHub ERROR]"
    elseif level == "WARN" then
        prefix = "⚠️ [SwirlHub WARN]"
    elseif level == "SUCCESS" then
        prefix = "✅ [SwirlHub SUCCESS]"
    end
    
    print(prefix .. ": " .. msg)
end

local Window = Fluent:CreateWindow({
    Title = "🌌 SwirlHub - Rivals Enhanced " .. (Fluent.Version or "v2.0"),
    SubTitle = "by Flames - Enhanced Edition",
    TabWidth = 180,
    Size = UDim2.fromOffset(680, 580),
    Acrylic = true,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local MainTab = Window:AddTab({ Title = "Main", Icon = "home" })
local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "settings" })
local MiscTab = Window:AddTab({ Title = "Misc", Icon = "star" })

local function ShowNotification(title, content, duration, type)
    type = type or "info"
    Fluent:Notify({
        Title = title,
        Content = content,
        Duration = duration or 4,
        Type = type
    })
end

ShowNotification("🎉 Welcome", "SwirlHub Enhanced has been loaded successfully!", 6, "success")
DebugLog("Enhanced script initialization complete.", "SUCCESS")
MainTab:AddParagraph({
    Title = "ℹ️ INFORMATION - Enhanced Version",
    Content = "🔹 Enhanced performance and stability\n🔹 New features and improved UI\n🔹 Questions? Join Discord: discord.gg/5c9D3VD7se\n🔹 ⚠️ Some features may require specific game conditions"
})

local AimScript = {
    enabled = false,
    key = Enum.KeyCode.E,
    lockedTarget = nil,
    isLocked = false,
    aimPart = "Head",
    fovSize = 100,
    fovColor = Color3.fromRGB(255, 0, 0),
    smoothing = 0.2,
    maxDistance = 1500,
    visibilityCheck = true,
    teamCheck = false,
    autoShoot = false,
    prediction = false,
    predictionStrength = 0.1
}

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.Filled = false
FOVCircle.Transparency = 0.8
FOVCircle.NumSides = 64
FOVCircle.Visible = false

local function UpdateFOV()
    FOVCircle.Radius = AimScript.fovSize
    FOVCircle.Color = AimScript.fovColor
    FOVCircle.Visible = AimScript.enabled
end


local function GetClosestTargetInFOV()
    if not Players then return nil end
    local closest, minDist = nil, math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local camera = workspace.CurrentCamera

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer 
           and player.Character 
           and player.Character:FindFirstChild(AimScript.aimPart) 
           and player.Character:FindFirstChild("Humanoid")
           and player.Character.Humanoid.Health > 0 then

            if AimScript.teamCheck and player.Team == LocalPlayer.Team then
                continue
            end

            local targetPart = player.Character[AimScript.aimPart]
            local targetPos = targetPart.Position

            if AimScript.prediction and player.Character:FindFirstChild("HumanoidRootPart") then
                local velocity = player.Character.HumanoidRootPart.Velocity
                targetPos = targetPos + (velocity * AimScript.predictionStrength)
            end

            local screenPoint, onScreen = camera:WorldToViewportPoint(targetPos)
            local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
            local worldDistance = (targetPos - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude

            if onScreen 
               and distance < AimScript.fovSize 
               and distance < minDist 
               and worldDistance <= AimScript.maxDistance then

                if AimScript.visibilityCheck then
                    local raycast = workspace:Raycast(camera.CFrame.Position, (targetPos - camera.CFrame.Position).Unit * worldDistance)
                    if raycast and raycast.Instance and not raycast.Instance:IsDescendantOf(player.Character) then
                        continue
                    end
                end
                
                closest = player
                minDist = distance
            end
        end
    end
    return closest
end

local function MoveMouseToTarget(target)
    if not target or not target.Character or not target.Character:FindFirstChild(AimScript.aimPart) then
        return
    end

    local targetPart = target.Character[AimScript.aimPart]
    local targetPos = targetPart.Position
    
    if AimScript.prediction and target.Character:FindFirstChild("HumanoidRootPart") then
        local velocity = target.Character.HumanoidRootPart.Velocity
        targetPos = targetPos + (velocity * AimScript.predictionStrength)
    end

    local screenPoint, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPos)
    if onScreen then
        local mousePos = UserInputService:GetMouseLocation()
        local deltaX = screenPoint.X - mousePos.X
        local deltaY = screenPoint.Y - mousePos.Y

        deltaX = deltaX * AimScript.smoothing
        deltaY = deltaY * AimScript.smoothing
        
        mousemoverel(deltaX, deltaY)
    end
end

Connections.AimLoop = RunService.RenderStepped:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()
    FOVCircle.Position = mousePos
    
    if AimScript.isLocked and AimScript.lockedTarget then
        if not AimScript.lockedTarget.Character or 
           not AimScript.lockedTarget.Character:FindFirstChild(AimScript.aimPart) or
           AimScript.lockedTarget.Character.Humanoid.Health <= 0 then
            AimScript.isLocked = false
            AimScript.lockedTarget = nil
            ShowNotification("🎯 AimScript", "Target lost - automatically unlocked", 3, "warn")
            return
        end
        
        MoveMouseToTarget(AimScript.lockedTarget)
    end
end)

local AimScriptSection = MainTab:AddSection("🎯 Enhanced AimScript")

AimScriptSection:AddToggle("AimScriptToggle", {
    Title = "✅ Enable AimScript",
    Default = false
}):OnChanged(function(Value)
    AimScript.enabled = Value
    UpdateFOV()
    ShowNotification("🎯 AimScript", Value and "AimScript Enabled" or "AimScript Disabled", 4, Value and "success" or "info")
    DebugLog("Enhanced AimScript toggled: " .. tostring(Value))
end)

AimScriptSection:AddSlider("FOVSize", {
    Title = "🔘 FOV Circle Size",
    Min = 25,
    Max = 800,
    Default = 100,
    Rounding = 0,
    Callback = function(Value)
        AimScript.fovSize = Value
        UpdateFOV()
        DebugLog("FOV size set to: " .. Value)
    end
})

AimScriptSection:AddSlider("AimSmoothing", {
    Title = "🎯 Aim Smoothing",
    Min = 0.05,
    Max = 1,
    Default = 0.2,
    Rounding = 2,
    Callback = function(Value)
        AimScript.smoothing = Value
        DebugLog("Aim smoothing set to: " .. Value)
    end
})

AimScriptSection:AddSlider("MaxDistance", {
    Title = "📏 Max Target Distance",
    Min = 100,
    Max = 3000,
    Default = 1500,
    Rounding = 0,
    Callback = function(Value)
        AimScript.maxDistance = Value
        DebugLog("Max aim distance set to: " .. Value)
    end
})

AimScriptSection:AddColorpicker("FOVColor", {
    Title = "🎨 FOV Circle Color",
    Default = Color3.fromRGB(255, 0, 0)
}):OnChanged(function()
    AimScript.fovColor = Options.FOVColor.Value
    UpdateFOV()
    ShowNotification("🎯 AimScript", "FOV Color updated!", 3)
    DebugLog("FOV color changed.")
end)

AimScriptSection:AddDropdown("AimPartDropdown", {
    Title = "🎯 Aim Part",
    Values = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
    Default = "Head"
}):OnChanged(function(Value)
    AimScript.aimPart = Value
    ShowNotification("🎯 AimScript", "Aim Part set to " .. Value, 3)
    DebugLog("Aim part changed to: " .. Value)
end)

AimScriptSection:AddToggle("VisibilityCheck", {
    Title = "👁️ Visibility Check",
    Default = true
}):OnChanged(function(Value)
    AimScript.visibilityCheck = Value
    DebugLog("Visibility check: " .. tostring(Value))
end)

AimScriptSection:AddToggle("TeamCheck", {
    Title = "👥 Team Check",
    Default = false
}):OnChanged(function(Value)
    AimScript.teamCheck = Value
    DebugLog("Team check: " .. tostring(Value))
end)

AimScriptSection:AddToggle("Prediction", {
    Title = "🔮 Prediction",
    Default = false
}):OnChanged(function(Value)
    AimScript.prediction = Value
    DebugLog("Prediction: " .. tostring(Value))
end)

AimScriptSection:AddSlider("PredictionStrength", {
    Title = "🎯 Prediction Strength",
    Min = 0.05,
    Max = 0.5,
    Default = 0.1,
    Rounding = 2,
    Callback = function(Value)
        AimScript.predictionStrength = Value
        DebugLog("Prediction strength: " .. Value)
    end
})

AimScriptSection:AddKeybind("AimScriptKeybind", {
    Title = "🎮 AimScript Key",
    Default = "E",
    Mode = "Toggle",
    Callback = function()
        if AimScript.enabled then
            if AimScript.isLocked then
                AimScript.isLocked = false
                AimScript.lockedTarget = nil
                ShowNotification("🎯 AimScript", "Target Unlocked", 3)
                DebugLog("Target unlocked.")
            else
                AimScript.lockedTarget = GetClosestTargetInFOV()
                if AimScript.lockedTarget then
                    AimScript.isLocked = true
                    ShowNotification("🎯 AimScript", "Target Locked: " .. AimScript.lockedTarget.Name, 3, "success")
                    DebugLog("Target locked onto: " .. AimScript.lockedTarget.Name)
                else
                    ShowNotification("🎯 AimScript", "No target in FOV!", 3, "error")
                    DebugLog("No valid target found in FOV.")
                end
            end
        end
    end,
    ChangedCallback = function(NewKey)
        AimScript.key = NewKey
        ShowNotification("🎯 AimScript", "Keybind changed to " .. tostring(NewKey), 3)
        DebugLog("AimScript keybind changed to: " .. tostring(NewKey))
    end
})

local ESP = {
    enabled = false,
    fillColor = Color3.fromRGB(255, 0, 0),
    outlineColor = Color3.fromRGB(255, 255, 255),
    fillTransparency = 0.5,
    outlineTransparency = 0,
    alwaysOnTop = true,
    maxDistance = 1000,
    showDistance = true,
    showHealth = true,
    showName = true,
    teamCheck = false,
    objects = {},
    textLabels = {}
}

local function UpdateESPProperties()
    for player, highlight in pairs(ESP.objects) do
        if highlight and highlight.Parent then
            pcall(function()
                highlight.FillColor = ESP.fillColor
                highlight.OutlineColor = ESP.outlineColor
                highlight.FillTransparency = ESP.fillTransparency
                highlight.OutlineTransparency = ESP.outlineTransparency
                highlight.DepthMode = ESP.alwaysOnTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
                highlight.Enabled = ESP.enabled
            end)
        end
    end
end

local function CreateESPText(player)
    if ESP.textLabels[player] then return end
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(0, 200, 0, 100)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = CoreGui
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 14
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.Parent = billboardGui
    
    ESP.textLabels[player] = {
        gui = billboardGui,
        label = textLabel
    }
end

local function UpdateESPText(player)
    if not ESP.textLabels[player] or not player.Character then return end
    
    local textData = ESP.textLabels[player]
    local character = player.Character
    local humanoid = character:FindFirstChild("Humanoid")
    local rootpart = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not rootpart then
        textData.gui.Enabled = false
        return
    end
    
    textData.gui.Adornee = rootpart
    textData.gui.Enabled = ESP.enabled
    
    local textParts = {}
    
    if ESP.showName then
        table.insert(textParts, player.Name)
    end
    
    if ESP.showHealth then
        local health = math.floor(humanoid.Health)
        local maxHealth = math.floor(humanoid.MaxHealth)
        table.insert(textParts, health .. "/" .. maxHealth .. " HP")
    end
    
    if ESP.showDistance and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local distance = math.floor((rootpart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude)
        table.insert(textParts, distance .. "m")
    end
    
    textData.label.Text = table.concat(textParts, "\n")
end

local function CreateESP(player)
    if not player or player == LocalPlayer or ESP.objects[player] then return end
    if ESP.teamCheck and player.Team == LocalPlayer.Team then return end

    local success, highlight = pcall(function()
        local hl = Instance.new("Highlight")
        hl.FillColor = ESP.fillColor
        hl.OutlineColor = ESP.outlineColor
        hl.FillTransparency = ESP.fillTransparency
        hl.OutlineTransparency = ESP.outlineTransparency
        hl.DepthMode = ESP.alwaysOnTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        hl.Enabled = ESP.enabled
        hl.Parent = CoreGui
        return hl
    end)

    if not success or not highlight then
        DebugLog("Error creating ESP for player: " .. (player.Name or "Unknown"), "ERROR")
        return
    end

    ESP.objects[player] = highlight
    CreateESPText(player)

    local function UpdateCharacter()
        task.wait(0.5)
        if player and player.Character then
            pcall(function() 
                highlight.Adornee = player.Character 
            end)
        end
    end

    local charAddedConn = player.CharacterAdded:Connect(function()
        pcall(UpdateCharacter)
    end)

    highlight:GetPropertyChangedSignal("Parent"):Connect(function()
        if not highlight.Parent then
            pcall(function() charAddedConn:Disconnect() end)
        end
    end)

    pcall(UpdateCharacter)
    DebugLog("ESP created for: " .. player.Name, "SUCCESS")
end

local function RemoveESP(player)
    if ESP.objects[player] then
        pcall(function() ESP.objects[player]:Destroy() end)
        ESP.objects[player] = nil
    end
    
    if ESP.textLabels[player] then
        pcall(function() ESP.textLabels[player].gui:Destroy() end)
        ESP.textLabels[player] = nil
    end
    
    DebugLog("ESP removed for: " .. player.Name)
end

for _, p in ipairs(Players:GetPlayers()) do
    CreateESP(p)
end

Connections.PlayerAdded = Players.PlayerAdded:Connect(function(p)
    CreateESP(p)
end)

Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(p)
    RemoveESP(p)
end)

Connections.ESPLoop = RunService.RenderStepped:Connect(function()
    if not ESP.enabled then
        for _, highlight in pairs(ESP.objects) do
            if highlight then
                pcall(function() highlight.Enabled = false end)
            end
        end
        for _, textData in pairs(ESP.textLabels) do
            if textData and textData.gui then
                textData.gui.Enabled = false
            end
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if character and character:FindFirstChild("HumanoidRootPart") and ESP.objects[player] then
                local success, distance = pcall(function()
                    return (character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                end)
                
                if success then
                    local inRange = distance <= ESP.maxDistance
                    pcall(function()
                        ESP.objects[player].Enabled = inRange
                    end)
                    
                    if ESP.textLabels[player] then
                        ESP.textLabels[player].gui.Enabled = inRange
                        if inRange then
                            UpdateESPText(player)
                        end
                    end
                end
            end
        end
    end
end)

local ESPSection = MainTab:AddSection("👀 Enhanced ESP")

ESPSection:AddToggle("ESPEnabled", {
    Title = "✅ Enable ESP",
    Default = false
}):OnChanged(function(Value)
    ESP.enabled = Value
    if not Value then
        for _, highlight in pairs(ESP.objects) do
            pcall(function() highlight.Enabled = false end)
        end
        for _, textData in pairs(ESP.textLabels) do
            if textData and textData.gui then
                textData.gui.Enabled = false
            end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do
            CreateESP(p)
        end
        for _, highlight in pairs(ESP.objects) do
            pcall(function() highlight.Enabled = true end)
        end
    end
    
    ShowNotification("👀 ESP", Value and "ESP Enabled" or "ESP Disabled", 4, Value and "success" or "info")
    DebugLog("Enhanced ESP toggled: " .. tostring(Value))
end)

ESPSection:AddColorpicker("ESPFColor", {
    Title = "🎨 ESP Fill Color",
    Default = ESP.fillColor
}):OnChanged(function()
    ESP.fillColor = Options.ESPFColor.Value
    UpdateESPProperties()
    ShowNotification("👀 ESP", "ESP Fill Color updated!", 3)
    DebugLog("ESP fill color changed.")
end)

ESPSection:AddColorpicker("ESPOutlineColor", {
    Title = "🎨 ESP Outline Color",
    Default = ESP.outlineColor
}):OnChanged(function()
    ESP.outlineColor = Options.ESPOutlineColor.Value
    UpdateESPProperties()
    ShowNotification("👀 ESP", "ESP Outline Color updated!", 3)
    DebugLog("ESP outline color changed.")
end)

ESPSection:AddSlider("ESPFTransparency", {
    Title = "🔘 ESP Fill Transparency",
    Min = 0,
    Max = 1,
    Default = ESP.fillTransparency,
    Rounding = 2,
    Callback = function(Value)
        ESP.fillTransparency = Value
        UpdateESPProperties()
        DebugLog("ESP fill transparency: " .. Value)
    end
})

ESPSection:AddSlider("ESPOutlineTransparency", {
    Title = "🔘 ESP Outline Transparency",
    Min = 0,
    Max = 1,
    Default = ESP.outlineTransparency,
    Rounding = 2,
    Callback = function(Value)
        ESP.outlineTransparency = Value
        UpdateESPProperties()
        DebugLog("ESP outline transparency: " .. Value)
    end
})

ESPSection:AddToggle("ESPDepthMode", {
    Title = "🔳 ESP Always On Top",
    Default = true
}):OnChanged(function(Value)
    ESP.alwaysOnTop = Value
    UpdateESPProperties()
    ShowNotification("👀 ESP", "ESP Depth Mode: " .. (Value and "Always On Top" or "Occluded"), 3)
    DebugLog("ESP depth mode: " .. tostring(Value))
end)

ESPSection:AddSlider("ESPMaxDistance", {
    Title = "📏 ESP Max Distance",
    Min = 100,
    Max = 5000,
    Default = ESP.maxDistance,
    Rounding = 0,
    Callback = function(Value)
        ESP.maxDistance = Value
        DebugLog("ESP max distance set to: " .. Value)
    end
})

ESPSection:AddToggle("ESPShowName", {
    Title = "📝 Show Names",
    Default = true
}):OnChanged(function(Value)
    ESP.showName = Value
    DebugLog("ESP show names: " .. tostring(Value))
end)

ESPSection:AddToggle("ESPShowHealth", {
    Title = "❤️ Show Health",
    Default = true
}):OnChanged(function(Value)
    ESP.showHealth = Value
    DebugLog("ESP show health: " .. tostring(Value))
end)

ESPSection:AddToggle("ESPShowDistance", {
    Title = "📏 Show Distance",
    Default = true
}):OnChanged(function(Value)
    ESP.showDistance = Value
    DebugLog("ESP show distance: " .. tostring(Value))
end)

ESPSection:AddToggle("ESPTeamCheck", {
    Title = "👥 Team Check",
    Default = false
}):OnChanged(function(Value)
    ESP.teamCheck = Value

    for _, player in ipairs(Players:GetPlayers()) do
        RemoveESP(player)
        CreateESP(player)
    end
    DebugLog("ESP team check: " .. tostring(Value))
end)

local LocalPlayerFeatures = {
    noclip = false,
    infJump = false,
    fly = false,
    flySpeed = 50,
    walkSpeed = 16,
    jumpPower = 50,
    god = false,
    invisible = false,
    connections = {}
}

local function ToggleNoclip(enabled)
    if LocalPlayerFeatures.connections.noclip then
        LocalPlayerFeatures.connections.noclip:Disconnect()
    end
    
    if enabled then
        LocalPlayerFeatures.connections.noclip = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

local function ToggleInfJump(enabled)
    if LocalPlayerFeatures.connections.infJump then
        LocalPlayerFeatures.connections.infJump:Disconnect()
    end
    
    if enabled then
        LocalPlayerFeatures.connections.infJump = UserInputService.JumpRequest:Connect(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

local function ToggleFly(enabled)
    if LocalPlayerFeatures.connections.fly then
        LocalPlayerFeatures.connections.fly:Disconnect()
    end
    
    if enabled then
        spawn(function()
            local character = LocalPlayer.Character
            if not character then return end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not humanoid or not hrp then return end
            
            humanoid.PlatformStand = true
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bodyVelocity.Parent = hrp

            LocalPlayerFeatures.connections.fly = RunService.RenderStepped:Connect(function()
                if not LocalPlayerFeatures.fly or not character or not character.Parent then
                    bodyVelocity:Destroy()
                    humanoid.PlatformStand = false
                    return
                end
                
                local moveDir = Vector3.new(0, 0, 0)
                local camera = workspace.CurrentCamera
                
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    moveDir = moveDir - Vector3.new(0, 1, 0)
                end
                
                bodyVelocity.Velocity = moveDir * LocalPlayerFeatures.flySpeed
            end)
        end)
    end
end

local function UpdateWalkSpeed(speed)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = speed
    end
end

local function UpdateJumpPower(power)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.JumpPower = power
    end
end

local function ToggleGodMode(enabled)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        if enabled then
            LocalPlayer.Character.Humanoid.MaxHealth = math.huge
            LocalPlayer.Character.Humanoid.Health = math.huge
        else
            LocalPlayer.Character.Humanoid.MaxHealth = 100
            LocalPlayer.Character.Humanoid.Health = 100
        end
    end
end

local function ToggleInvisibility(enabled)
    if LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = enabled and 1 or 0
            elseif part:IsA("Accessory") then
                part.Handle.Transparency = enabled and 1 or 0
            end
        end
        
        if LocalPlayer.Character:FindFirstChild("Head") then
            for _, obj in pairs(LocalPlayer.Character.Head:GetChildren()) do
                if obj:IsA("Decal") then
                    obj.Transparency = enabled and 1 or 0
                end
            end
        end
    end
end

local LocalPlayerSection = MainTab:AddSection("🧍 Enhanced LocalPlayer Features")

LocalPlayerSection:AddToggle("Noclip", {
    Title = "🚫 Noclip",
    Default = false
}):OnChanged(function(Value)
    LocalPlayerFeatures.noclip = Value
    ToggleNoclip(Value)
    ShowNotification("🧍 Noclip", Value and "Noclip Enabled" or "Noclip Disabled", 4, Value and "success" or "info")
    DebugLog("Noclip toggled: " .. tostring(Value))
end)

LocalPlayerSection:AddToggle("InfJump", {
    Title = "🔝 Infinite Jump",
    Default = false
}):OnChanged(function(Value)
    LocalPlayerFeatures.infJump = Value
    ToggleInfJump(Value)
    ShowNotification("🧍 Infinite Jump", Value and "Infinite Jump Enabled" or "Infinite Jump Disabled", 4, Value and "success" or "info")
    DebugLog("Infinite jump toggled: " .. tostring(Value))
end)

LocalPlayerSection:AddToggle("Fly", {
    Title = "🦋 Fly Mode",
    Default = false
}):OnChanged(function(Value)
    LocalPlayerFeatures.fly = Value
    ToggleFly(Value)
    ShowNotification("🧍 Fly", Value and "Fly Mode Enabled" or "Fly Mode Disabled", 4, Value and "success" or "info")
    DebugLog("Fly toggled: " .. tostring(Value))
end)

LocalPlayerSection:AddSlider("FlySpeed", {
    Title = "💨 Fly Speed",
    Min = 10,
    Max = 300,
    Default = LocalPlayerFeatures.flySpeed,
    Rounding = 0,
    Callback = function(Value)
        LocalPlayerFeatures.flySpeed = Value
        DebugLog("Fly speed set to: " .. Value)
    end
})

LocalPlayerSection:AddSlider("WalkSpeed", {
    Title = "🚶 Walk Speed",
    Min = 1,
    Max = 100,
    Default = LocalPlayerFeatures.walkSpeed,
    Rounding = 0,
    Callback = function(Value)
        LocalPlayerFeatures.walkSpeed = Value
        UpdateWalkSpeed(Value)
        DebugLog("Walk speed set to: " .. Value)
    end
})

LocalPlayerSection:AddSlider("JumpPower", {
    Title = "⬆️ Jump Power",
    Min = 1,
    Max = 200,
    Default = LocalPlayerFeatures.jumpPower,
    Rounding = 0,
    Callback = function(Value)
        LocalPlayerFeatures.jumpPower = Value
        UpdateJumpPower(Value)
        DebugLog("Jump power set to: " .. Value)
    end
})

LocalPlayerSection:AddToggle("GodMode", {
    Title = "🛡️ God Mode",
    Default = false
}):OnChanged(function(Value)
    LocalPlayerFeatures.god = Value
    ToggleGodMode(Value)
    ShowNotification("🧍 God Mode", Value and "God Mode Enabled" or "God Mode Disabled", 4, Value and "success" or "warn")
    DebugLog("God mode toggled: " .. tostring(Value))
end)

LocalPlayerSection:AddToggle("Invisible", {
    Title = "👻 Invisibility",
    Default = false
}):OnChanged(function(Value)
    LocalPlayerFeatures.invisible = Value
    ToggleInvisibility(Value)
    ShowNotification("🧍 Invisibility", Value and "Invisibility Enabled" or "Invisibility Disabled", 4, Value and "success" or "info")
    DebugLog("Invisibility toggled: " .. tostring(Value))
end)

local ExtraFeatures = {
    thirdPerson = false,
    spin = false,
    spinSpeed = 100,
    fovChanger = false,
    customFov = 70,
    fullbright = false,
    noFog = false,
    connections = {}
}

local function ToggleThirdPerson(enabled)
    local success, cameraController = pcall(function()
        return require(LocalPlayer.PlayerScripts.Controllers.CameraController)
    end)
    
    if success and cameraController then
        cameraController:SetPOV(not enabled, 0, false)
    else
        ShowNotification("⚠️ Warning", "Third-person may not work with your executor!", "Check console for details", 5)
        DebugLog("Third-person failed: Executor doesn't support require()", "WARN")
    end
end

local function ToggleSpin(enabled)
    if ExtraFeatures.connections.spin then
        ExtraFeatures.connections.spin:Disconnect()
    end
    
    if enabled then
        ExtraFeatures.connections.spin = RunService.RenderStepped:Connect(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local root = LocalPlayer.Character.HumanoidRootPart
                root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(ExtraFeatures.spinSpeed / 10), 0)
            end
        end)
    end
end

local function UpdateFOV(fov)
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = fov
    end
end

local function ToggleFullbright(enabled)
    if enabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    else
        Lighting.Brightness = 1
        Lighting.ClockTime = 12
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = true
        Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
    end
end

local ExtraSection = MiscTab:AddSection("✨ Enhanced Extra Features")

ExtraSection:AddToggle("ThirdPersonToggle", {
    Title = "👁️ Third Person",
    Default = false
}):OnChanged(function(Value)
    ExtraFeatures.thirdPerson = Value
    ToggleThirdPerson(Value)
    DebugLog("Third-person toggled: " .. tostring(Value))
end)

ExtraSection:AddToggle("SpinToggle", {
    Title = "🔄 Spin Character",
    Default = false
}):OnChanged(function(Value)
    ExtraFeatures.spin = Value
    ToggleSpin(Value)
    DebugLog("Spin toggled: " .. tostring(Value))
end)

ExtraSection:AddSlider("SpinSpeed", {
    Title = "🌪️ Spin Speed",
    Min = 10,
    Max = 500,
    Default = ExtraFeatures.spinSpeed,
    Rounding = 0,
    Callback = function(Value)
        ExtraFeatures.spinSpeed = Value
        DebugLog("Spin speed set to: " .. Value)
    end
})

ExtraSection:AddToggle("FOVChanger", {
    Title = "🔍 FOV Changer",
    Default = false
}):OnChanged(function(Value)
    ExtraFeatures.fovChanger = Value
    if Value then
        UpdateFOV(ExtraFeatures.customFov)
    else
        UpdateFOV(70)
    end
    DebugLog("FOV changer toggled: " .. tostring(Value))
end)

ExtraSection:AddSlider("CustomFOV", {
    Title = "📐 Custom FOV",
    Min = 30,
    Max = 120,
    Default = ExtraFeatures.customFov,
    Rounding = 0,
    Callback = function(Value)
        ExtraFeatures.customFov = Value
        if ExtraFeatures.fovChanger then
            UpdateFOV(Value)
        end
        DebugLog("Custom FOV set to: " .. Value)
    end
})

ExtraSection:AddToggle("Fullbright", {
    Title = "💡 Fullbright",
    Default = false
}):OnChanged(function(Value)
    ExtraFeatures.fullbright = Value
    ToggleFullbright(Value)
    ShowNotification("💡 Fullbright", Value and "Fullbright Enabled" or "Fullbright Disabled", 3)
    DebugLog("Fullbright toggled: " .. tostring(Value))
end)

local ClientFeatures = {
    darkMode = false,
    customAmbient = false,
    rainbowMode = false,
    connections = {}
}

local function ToggleDarkMode()
    if ClientFeatures.darkMode then
        Lighting.Brightness = 2
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        ClientFeatures.darkMode = false
        ShowNotification("💡 Mode Switched", "Switched to Light Mode", 3)
        DebugLog("Light mode activated.")
    else
        Lighting.Brightness = 0.3
        Lighting.OutdoorAmbient = Color3.fromRGB(15, 15, 25)
        Lighting.Ambient = Color3.fromRGB(10, 10, 20)
        ClientFeatures.darkMode = true
        ShowNotification("💡 Mode Switched", "Switched to Dark Mode", 3)
        DebugLog("Dark mode activated.")
    end
end

local function ToggleRainbowMode(enabled)
    if ClientFeatures.connections.rainbow then
        ClientFeatures.connections.rainbow:Disconnect()
    end
    
    if enabled then
        ClientFeatures.connections.rainbow = RunService.RenderStepped:Connect(function()
            local time = tick()
            local r = math.sin(time * 2) * 127 + 128
            local g = math.sin(time * 2 + 2) * 127 + 128
            local b = math.sin(time * 2 + 4) * 127 + 128
            
            Lighting.Ambient = Color3.fromRGB(r, g, b)
            Lighting.OutdoorAmbient = Color3.fromRGB(r * 0.8, g * 0.8, b * 0.8)
        end)
    else
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
    end
end

local ClientSection = MiscTab:AddSection("💻 Enhanced Client Features")

ClientSection:AddButton({
    Title = "🌓 Toggle Dark/Light Mode",
    Description = "Switch between dark mode and light mode",
    Callback = function()
        ToggleDarkMode()
    end
})

ClientSection:AddToggle("RainbowMode", {
    Title = "🌈 Rainbow Lighting",
    Default = false
}):OnChanged(function(Value)
    ClientFeatures.rainbowMode = Value
    ToggleRainbowMode(Value)
    ShowNotification("🌈 Rainbow Mode", Value and "Rainbow Mode Enabled" or "Rainbow Mode Disabled", 3)
    DebugLog("Rainbow mode toggled: " .. tostring(Value))
end)

ClientSection:AddButton({
    Title = "🔄 Reset Character",
    Description = "Respawn your character",
    Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.Health = 0
            ShowNotification("🔄 Character", "Character reset!", 3)
            DebugLog("Character reset by user")
        end
    end
})

ClientSection:AddButton({
    Title = "🧹 Clear Debris",
    Description = "Clean up workspace objects",
    Callback = function()
        local count = 0
        for _, obj in pairs(workspace:GetChildren()) do
            if obj:IsA("Part") and not obj.Parent:FindFirstChildOfClass("Humanoid") then
                obj:Destroy()
                count = count + 1
            end
        end
        ShowNotification("🧹 Cleanup", "Removed " .. count .. " objects", 3, "success")
        DebugLog("Cleaned up " .. count .. " objects")
    end
})

local PerformanceMonitor = {
    enabled = false,
    fps = 0,
    ping = 0,
    memory = 0,
    connections = {}
}

local function UpdatePerformanceStats()
    if not PerformanceMonitor.enabled then return end

    local lastTime = tick()
    PerformanceMonitor.connections.fps = RunService.RenderStepped:Connect(function()
        local currentTime = tick()
        PerformanceMonitor.fps = math.floor(1 / (currentTime - lastTime))
        lastTime = currentTime
    end)
    PerformanceMonitor.memory = collectgarbage("count")
    
    PerformanceMonitor.ping = LocalPlayer:GetNetworkPing() * 1000
end

local SettingsSection = SettingsTab:AddSection("⚙️ Script Settings")

SettingsSection:AddToggle("DebugMode", {
    Title = "🔧 Debug Mode",
    Description = "Show detailed debug information",
    Default = DEBUG_ENABLED
}):OnChanged(function(Value)
    DEBUG_ENABLED = Value
    DebugLog("Debug mode " .. (Value and "enabled" or "disabled"))
end)

SettingsSection:AddToggle("PerformanceMonitor", {
    Title = "📊 Performance Monitor",
    Description = "Monitor FPS, ping, and memory usage",
    Default = false
}):OnChanged(function(Value)
    PerformanceMonitor.enabled = Value
    if Value then
        UpdatePerformanceStats()
    else
        if PerformanceMonitor.connections.fps then
            PerformanceMonitor.connections.fps:Disconnect()
        end
    end
end)

SettingsSection:AddButton({
    Title = "🗑️ Clear All ESP",
    Description = "Remove all ESP objects",
    Callback = function()
        for player, _ in pairs(ESP.objects) do
            RemoveESP(player)
        end
        ShowNotification("🗑️ ESP", "All ESP objects cleared", 3, "success")
        DebugLog("All ESP objects cleared")
    end
})

SettingsSection:AddButton({
    Title = "🔄 Reload Script",
    Description = "Restart the entire script",
    Callback = function()
        ShowNotification("🔄 Reloading", "Script will reload in 2 seconds...", 2, "warn")
        wait(2)
        
        for name, connection in pairs(Connections) do
            if connection then
                connection:Disconnect()
            end
        end
 
        for player, _ in pairs(ESP.objects) do
            RemoveESP(player)
        end
        
        if FOVCircle then
            FOVCircle:Remove()
        end

        loadstring(game:HttpGet("https://raw.githubusercontent.com/KloBraticc/RVCheat/main/rivals.lua"))()
    end
})

local KeybindManager = {
    keybinds = {
        toggleUI = Enum.KeyCode.RightShift,
        toggleAim = Enum.KeyCode.E,
        toggleESP = Enum.KeyCode.T,
        toggleFly = Enum.KeyCode.F
    }
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == KeybindManager.keybinds.toggleUI then
        Window.Minimized = not Window.Minimized
    elseif input.KeyCode == KeybindManager.keybinds.toggleESP then
        ESP.enabled = not ESP.enabled
        ShowNotification("👀 ESP", ESP.enabled and "ESP Enabled" or "ESP Disabled", 2)
    elseif input.KeyCode == KeybindManager.keybinds.toggleFly then
        LocalPlayerFeatures.fly = not LocalPlayerFeatures.fly
        ToggleFly(LocalPlayerFeatures.fly)
        ShowNotification("🦋 Fly", LocalPlayerFeatures.fly and "Fly Enabled" or "Fly Disabled", 2)
    end
end)

local AntiDetection = {
    enabled = true,
    methods = {
        "RandomizeTimings",
        "ObfuscateValues",
        "SpoofUserAgent"
    }
}

local function RandomizeTimings()
    local randomDelay = math.random(1, 50) / 1000
    wait(randomDelay)
end

if AntiDetection.enabled then
    spawn(function()
        while true do
            RandomizeTimings()
            wait(math.random(30, 120))
        end
    end)
end

if SaveManager and InterfaceManager then
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("SwirlHub_Enhanced")
    SaveManager:SetFolder("SwirlHub_Enhanced/rivals")
    
    spawn(function()
        while true do
            wait(300)
            if SaveManager then
                SaveManager:Save()
                DebugLog("Auto-saved settings")
            end
        end
    end)
    
    SaveManager:LoadAutoloadConfig()
    DebugLog("Settings loaded from auto-save")
end

Window:SelectTab(1)
ShowNotification("🎉 SwirlHub Enhanced", "All systems loaded successfully!", 5, "success")
ShowNotification("ℹ️ Keybinds", "Right Shift: Toggle UI | T: Toggle ESP | F: Toggle Fly", 8, "info")

DebugLog("=== SwirlHub Enhanced fully loaded! ===", "SUCCESS")
DebugLog("Total features loaded: AimScript, ESP, LocalPlayer, Extras, Client, Performance Monitor", "SUCCESS")
DebugLog("Script version: Enhanced v2.0", "SUCCESS")
DebugLog("Enjoy the enhanced experience! 🚀", "SUCCESS")

game.Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        for name, connection in pairs(Connections) do
            if connection then
                connection:Disconnect()
            end
        end
        
        for p, _ in pairs(ESP.objects) do
            RemoveESP(p)
        end
        
        if FOVCircle then
            FOVCircle:Remove()
        end
        
        DebugLog("Script cleanup completed", "SUCCESS")
    end
end)

InputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDir = moveDir + camera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDir = moveDir - camera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDir = moveDir - camera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDir = moveDir + camera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDir = moveDir + Vector3.new(0, 1, 0)
                end
