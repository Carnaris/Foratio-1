if not game:IsLoaded() then 
    game.Loaded:Wait()
end

if not syn or not protectgui then
    getgenv().protectgui = function() end
end

if bypass_adonis then
    task.spawn(function()
        local g = getinfo or debug.getinfo
        local d = false
        local h = {}

        local x, y

        setthreadidentity(2)

        for i, v in getgc(true) do
            if typeof(v) == "table" then
                local a = rawget(v, "Detected")
                local b = rawget(v, "Kill")
            
                if typeof(a) == "function" and not x then
                    x = a
                    local o; o = hookfunction(x, function(c, f, n)
                        if c ~= "_" then
                            if d then
                                warn(`Adonis AntiCheat flagged\nMethod: {c}\nInfo: {f}`)
                            end
                        end
                        
                        return true
                    end)
                    table.insert(h, x)
                end

                if rawget(v, "Variables") and rawget(v, "Process") and typeof(b) == "function" and not y then
                    y = b
                    local o; o = hookfunction(y, function(f)
                        if d then
                            warn(`Adonis AntiCheat tried to kill (fallback): {f}`)
                        end
                    end)
                    table.insert(h, y)
                end
            end
        end

        local o; o = hookfunction(getrenv().debug.info, newcclosure(function(...)
            local a, f = ...

            if x and a == x then
                if d then
                    warn(`zins | adonis bypassed`)
                end

                return coroutine.yield(coroutine.running())
            end
            
            return o(...)
        end))

        setthreadidentity(7)
    end)
end

local SilentAimSettings = {
    Enabled = false,
    
    ClassName = "PasteWare  |  aimwhere",
    ToggleKey = "U",
    
    TeamCheck = false,
    VisibleCheck = false, 
    TargetPart = "HumanoidRootPart",
    SilentAimMethod = "Raycast",
    
    FOVRadius = 130,
    FOVVisible = false,
    ShowSilentAimTarget = false, 
    
    MouseHitPrediction = false,
    MouseHitPredictionAmount = 0.165,
    HitChance = 100
}

getgenv().SilentAimSettings = Settings

local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local GetChildren = game.GetChildren
local GetPlayers = Players.GetPlayers
local WorldToScreen = Camera.WorldToScreenPoint
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local FindFirstChild = game.FindFirstChild
local RenderStepped = RunService.RenderStepped
local GuiInset = GuiService.GetGuiInset
local GetMouseLocation = UserInputService.GetMouseLocation

local resume = coroutine.resume 
local create = coroutine.create

local ValidTargetParts = {"Head", "HumanoidRootPart"}
local PredictionAmount = 0.165

local mouse_box = Drawing.new("Square")
mouse_box.Visible = true 
mouse_box.ZIndex = 999 
mouse_box.Color = Color3.fromRGB(54, 57, 241)
mouse_box.Thickness = 20 
mouse_box.Size = Vector2.new(20, 20)
mouse_box.Filled = true 

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = 180
fov_circle.Filled = false
fov_circle.Visible = false
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(54, 57, 241)

local ExpectedArguments = {
    FindPartOnRayWithIgnoreList = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Ray", "table", "boolean", "boolean"
        }
    },
    FindPartOnRayWithWhitelist = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Ray", "table", "boolean"
        }
    },
    FindPartOnRay = {
        ArgCountRequired = 2,
        Args = {
            "Instance", "Ray", "Instance", "boolean", "boolean"
        }
    },
    Raycast = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Vector3", "Vector3", "RaycastParams"
        }
    }
}

function CalculateChance(Percentage)

    Percentage = math.floor(Percentage)


    local chance = math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100) / 100


    return chance <= Percentage / 100
end


local function getPositionOnScreen(Vector)
    local Vec3, OnScreen = WorldToScreen(Camera, Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function ValidateArguments(Args, RayMethod)
    local Matches = 0
    if #Args < RayMethod.ArgCountRequired then
        return false
    end
    for Pos, Argument in next, Args do
        if typeof(Argument) == RayMethod.Args[Pos] then
            Matches = Matches + 1
        end
    end
    return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position)
    return (Position - Origin).Unit * 1000
end

local function getMousePosition()
    return GetMouseLocation(UserInputService)
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character
    
    if not (PlayerCharacter or LocalPlayerCharacter) then return end 
    
    local PlayerRoot = FindFirstChild(PlayerCharacter, Options.TargetPart.Value) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")
    
    if not PlayerRoot then return end 
    
    local CastPoints, IgnoreList = {PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter}, {LocalPlayerCharacter, PlayerCharacter}
    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)
    
    return ((ObscuringObjects == 0 and true) or (ObscuringObjects > 0 and false))
end

local function getClosestPlayer()
    if not Options.TargetPart.Value then return end
    local Closest
    local DistanceToMouse
    for _, Player in next, GetPlayers(Players) do
        if Player == LocalPlayer then continue end
        if Toggles.TeamCheck.Value and Player.Team == LocalPlayer.Team then continue end

        local Character = Player.Character
        if not Character then continue end
        
        if Toggles.VisibleCheck.Value and not IsPlayerVisible(Player) then continue end

        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")
        if not HumanoidRootPart or not Humanoid or Humanoid and Humanoid.Health <= 0 then continue end

        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
        if not OnScreen then continue end

        local Distance = (getMousePosition() - ScreenPosition).Magnitude
        if Distance <= (DistanceToMouse or Options.Radius.Value or 2000) then
            Closest = ((Options.TargetPart.Value == "Random" and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]) or Character[Options.TargetPart.Value])
            DistanceToMouse = Distance
        end
    end
    return Closest
end


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local isLockedOn = false
local targetPlayer = nil
local lockEnabled = false
local smoothingFactor = 0.1
local predictionFactor = 0.0
local bodyPartSelected = "Head"
local aimLockEnabled = false 


local function getBodyPart(character, part)
    return character:FindFirstChild(part) and part or "Head"
end

local function getNearestPlayerToMouse()
    if not aimLockEnabled then return nil end 
    local nearestPlayer = nil
    local shortestDistance = math.huge
    local mousePosition = Camera:ViewportPointToRay(Mouse.X, Mouse.Y).Origin

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(bodyPartSelected) then
            local part = player.Character[bodyPartSelected]
            local screenPosition, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local distance = (Vector2.new(screenPosition.X, screenPosition.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                if distance < shortestDistance then
                    nearestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end
    return nearestPlayer
end

local function toggleLockOnPlayer()
    if not lockEnabled or not aimLockEnabled then return end

    if isLockedOn then
        isLockedOn = false
        targetPlayer = nil
    else
        targetPlayer = getNearestPlayerToMouse()
        if targetPlayer and targetPlayer.Character then
            local part = getBodyPart(targetPlayer.Character, bodyPartSelected)
            if targetPlayer.Character:FindFirstChild(part) then
                isLockedOn = true
            end
        end
    end
end


RunService.RenderStepped:Connect(function()
    if aimLockEnabled and lockEnabled and isLockedOn and targetPlayer and targetPlayer.Character then
        local partName = getBodyPart(targetPlayer.Character, bodyPartSelected)
        local part = targetPlayer.Character:FindFirstChild(partName)

        if part and targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * predictionFactor)
            local currentCameraPosition = Camera.CFrame.Position

            Camera.CFrame = CFrame.new(currentCameraPosition, predictedPosition) * CFrame.new(0, 0, smoothingFactor)
        else
            isLockedOn = false
            targetPlayer = nil
        end
    end
end)



local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/Foratio/refs/heads/main/linoralib.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/Foratio/refs/heads/main/manage2.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/Foratio/refs/heads/main/manager.lua"))()


local Window = Library:CreateWindow({
    Title = 'PasteWare  |  aimwhere',
    Center = true,
    AutoShow = true,  
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local GeneralTab = Window:AddTab("Main")
local aimbox = GeneralTab:AddRightGroupbox("AimLock settings")
local velbox = GeneralTab:AddRightGroupbox("Anti Lock")
local frabox = GeneralTab:AddRightGroupbox("Movement")
local ExploitTab = Window:AddTab("Exploits")
local WarTycoonBox = ExploitTab:AddLeftGroupbox("War Tycoon")
local ACSEngineBox = ExploitTab:AddRightGroupbox("weapon settings")
local VisualsTab = Window:AddTab("Visuals")
local settingsTab = Window:AddTab("Settings")


ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:ApplyToTab(settingsTab)
SaveManager:BuildConfigSection(settingsTab)

aimbox:AddToggle("aimLock_Enabled", {
    Text = "enable/disable AimLock",
    Default = false,
    Tooltip = "Toggle the AimLock feature on or off.",
    Callback = function(value)
        aimLockEnabled = value
        if not aimLockEnabled then
            lockEnabled = false
            isLockedOn = false
            targetPlayer = nil
        end
    end
})

aimbox:AddToggle("aim_Enabled", {
    Text = "aimlock keybind",
    Default = false,
    Tooltip = "Toggle AimLock on or off.",
    Callback = function(value)
        lockEnabled = value
        if not lockEnabled then
            isLockedOn = false
            targetPlayer = nil
        end
    end,
}):AddKeyPicker("aim_Enabled_KeyPicker", {
    Default = "Q", 
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "AimLock Key",
    Tooltip = "Key to toggle AimLock",
    Callback = function()
        toggleLockOnPlayer()
    end,
})

aimbox:AddSlider("Smoothing", {
    Text = "Camera Smoothing",
    Default = 0.1,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Tooltip = "Adjust camera smoothing factor.",
    Callback = function(value)
        smoothingFactor = value
    end,
})


aimbox:AddSlider("Prediction", {
    Text = "Prediction Factor",
    Default = 0.0,
    Min = 0,
    Max = 2,
    Rounding = 2,
    Tooltip = "Adjust prediction for target movement.",
    Callback = function(value)
        predictionFactor = value
    end,
})

aimbox:AddDropdown("BodyParts", {
    Values = {"Head", "UpperTorso", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm"},
    Default = "Head",
    Multi = false,
    Text = "Target Body Part",
    Tooltip = "Select which body part to lock onto.",
    Callback = function(value)
        bodyPartSelected = value
    end,
})


local reverseResolveIntensity = 5
getgenv().Desync = false
getgenv().DesyncEnabled = false  


game:GetService("RunService").Heartbeat:Connect(function()
    if getgenv().DesyncEnabled then  
        if getgenv().Desync then
            local player = game.Players.LocalPlayer
            local character = player.Character
            if not character then return end 

            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then return end

            local originalVelocity = humanoidRootPart.Velocity

            local randomOffset = Vector3.new(
                math.random(-1, 1) * reverseResolveIntensity * 1000,
                math.random(-1, 1) * reverseResolveIntensity * 1000,
                math.random(-1, 1) * reverseResolveIntensity * 1000
            )

            humanoidRootPart.Velocity = randomOffset
            humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(
                0,
                math.random(-1, 1) * reverseResolveIntensity * 0.001,
                0
            )

            game:GetService("RunService").RenderStepped:Wait()

            humanoidRootPart.Velocity = originalVelocity
        end
    end
end)

velbox:AddToggle("desyncMasterEnabled", {
    Text = "Enable Desync",
    Default = false,
    Tooltip = "Enable or disable the entire desync system.",
    Callback = function(value)
        getgenv().DesyncEnabled = value  
    end
})


velbox:AddToggle("desyncEnabled", {
    Text = "Desync keybind",
    Default = false,
    Tooltip = "Enable or disable reverse resolve desync.",
    Callback = function(value)
        getgenv().Desync = value
    end
}):AddKeyPicker("desyncToggleKey", {
    Default = "V", 
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Desync Toggle Key",
    Tooltip = "Toggle to enable/disable velocity desync.",
    Callback = function(value)
        getgenv().Desync = value
    end
})


velbox:AddSlider("ReverseResolveIntensity", {
    Text = "velocity intensity",
    Default = 5,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Tooltip = "Adjust the intensity of the reverse resolve effect.",
    Callback = function(value)
        reverseResolveIntensity = value
    end
})



local antiLockEnabled = false
local resolverIntensity = 1.0
local resolverMethod = "Recalculate"


RunService.RenderStepped:Connect(function()
    if aimLockEnabled and isLockedOn and targetPlayer and targetPlayer.Character then
        local partName = getBodyPart(targetPlayer.Character, bodyPartSelected)
        local part = targetPlayer.Character:FindFirstChild(partName)

        if part and targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * predictionFactor)

            if antiLockEnabled then
                if resolverMethod == "Recalculate" then

                    predictedPosition = predictedPosition + (part.AssemblyLinearVelocity * resolverIntensity)
                elseif resolverMethod == "Randomize" then

                    predictedPosition = predictedPosition + Vector3.new(
                        math.random() * resolverIntensity - (resolverIntensity / 2),
                        math.random() * resolverIntensity - (resolverIntensity / 2),
                        math.random() * resolverIntensity - (resolverIntensity / 2)
                    )
                elseif resolverMethod == "Invert" then

                    predictedPosition = predictedPosition - (part.AssemblyLinearVelocity * resolverIntensity * 2)
                end
            end

            local currentCameraPosition = Camera.CFrame.Position
            Camera.CFrame = CFrame.new(currentCameraPosition, predictedPosition) * CFrame.new(0, 0, smoothingFactor)
        else
            isLockedOn = false
            targetPlayer = nil
        end
    end
end)

aimbox:AddToggle("antiLock_Enabled", {
    Text = "Enable Anti Lock Resolver",
    Default = false,
    Tooltip = "Toggle the Anti Lock Resolver on or off.",
    Callback = function(value)
        antiLockEnabled = value
    end,
})

aimbox:AddSlider("ResolverIntensity", {
    Text = "Resolver Intensity",
    Default = 1.0,
    Min = 0,
    Max = 5,
    Rounding = 2,
    Tooltip = "Adjust the intensity of the Anti Lock Resolver.",
    Callback = function(value)
        resolverIntensity = value
    end,
})

aimbox:AddDropdown("ResolverMethods", {
    Values = {"Recalculate", "Randomize", "Invert"},
    Default = "Recalculate", 
    Multi = false,
    Text = "Resolver Method",
    Tooltip = "Select the method used by the Anti Lock Resolver.",
    Callback = function(value)
        resolverMethod = value
    end,
})


local MainBOX = GeneralTab:AddLeftTabbox("silent aim")
local Main = MainBOX:AddTab("silent aim")


Main:AddToggle("aim_Enabled", {Text = "Enabled"})
    :AddKeyPicker("aim_Enabled_KeyPicker", {
        Default = "U", 
        SyncToggleState = true, 
        Mode = "Toggle", 
        Text = "Enabled", 
        NoUI = false
    })

Options.aim_Enabled_KeyPicker:OnClick(function()
    SilentAimSettings.Enabled = not SilentAimSettings.Enabled
    Toggles.aim_Enabled.Value = SilentAimSettings.Enabled
    Toggles.aim_Enabled:SetValue(SilentAimSettings.Enabled)
    mouse_box.Visible = SilentAimSettings.Enabled
end)


Main:AddToggle("TeamCheck", {
    Text = "Team Check", 
    Default = SilentAimSettings.TeamCheck
}):OnChanged(function()
    SilentAimSettings.TeamCheck = Toggles.TeamCheck.Value
end)


Main:AddToggle("VisibleCheck", {
    Text = "Visible Check", 
    Default = SilentAimSettings.VisibleCheck
}):OnChanged(function()
    SilentAimSettings.VisibleCheck = Toggles.VisibleCheck.Value
end)


Main:AddDropdown("TargetPart", {
    AllowNull = true, 
    Text = "Target Part", 
    Default = SilentAimSettings.TargetPart, 
    Values = {"Head", "HumanoidRootPart", "Random"}
}):OnChanged(function()
    SilentAimSettings.TargetPart = Options.TargetPart.Value
end)


Main:AddDropdown("Method", {
    AllowNull = true, 
    Text = "Silent Aim Method", 
    Default = SilentAimSettings.SilentAimMethod, 
    Values = {
        "Raycast",
        "FindPartOnRay",
        "FindPartOnRayWithWhitelist",
        "FindPartOnRayWithIgnoreList",
        "Mouse.Hit/Target"
    }
}):OnChanged(function() 
    SilentAimSettings.SilentAimMethod = Options.Method.Value 
end)


Main:AddSlider("HitChance", {
    Text = "Hit Chance",
    Default = 100,
    Min = 0,
    Max = 100,
    Rounding = 1,
    Compact = false,
}):OnChanged(function()
    SilentAimSettings.HitChance = Options.HitChance.Value
end)


local FieldOfViewBOX = GeneralTab:AddLeftTabbox("Field Of View") do
    local Main = FieldOfViewBOX:AddTab("Visuals")
    

    Main:AddToggle("Visible", {Text = "Show FOV Circle"})
        :AddColorPicker("Color", {Default = Color3.fromRGB(54, 57, 241)})
        :OnChanged(function()
            fov_circle.Visible = Toggles.Visible.Value
            SilentAimSettings.FOVVisible = Toggles.Visible.Value
        end)


    Main:AddSlider("Radius", {
        Text = "FOV Circle Radius", 
        Min = 0, 
        Max = 360, 
        Default = 130, 
        Rounding = 0
    }):OnChanged(function()
        fov_circle.Radius = Options.Radius.Value
        SilentAimSettings.FOVRadius = Options.Radius.Value
    end)


    Main:AddToggle("MousePosition", {Text = "Show Silent Aim Target"})
        :AddColorPicker("MouseVisualizeColor", {Default = Color3.fromRGB(54, 57, 241)})
        :OnChanged(function()
            mouse_box.Visible = Toggles.MousePosition.Value 
            SilentAimSettings.ShowSilentAimTarget = Toggles.MousePosition.Value 
        end)
end


local MiscellaneousBOX = GeneralTab:AddLeftTabbox("Miscellaneous") do
    local PredictionTab = MiscellaneousBOX:AddTab("Prediction")
    

    PredictionTab:AddToggle("Prediction", {Text = "Mouse.Hit/Target Prediction"})
        :OnChanged(function()
            SilentAimSettings.MouseHitPrediction = Toggles.Prediction.Value
        end)
    

    PredictionTab:AddSlider("Amount", {
        Text = "Prediction Amount", 
        Min = 0.165, 
        Max = 1, 
        Default = 0.165, 
        Rounding = 3
    }):OnChanged(function()
        PredictionAmount = Options.Amount.Value
        SilentAimSettings.MouseHitPredictionAmount = Options.Amount.Value
    end)
end


resume(create(function()
    RenderStepped:Connect(function()
        if Toggles.MousePosition.Value and Toggles.aim_Enabled.Value then
            if getClosestPlayer() then 
                local Root = getClosestPlayer().Parent.PrimaryPart or getClosestPlayer()
                local RootToViewportPoint, IsOnScreen = WorldToViewportPoint(Camera, Root.Position);

                mouse_box.Visible = IsOnScreen
                mouse_box.Position = Vector2.new(RootToViewportPoint.X, RootToViewportPoint.Y)
            else 
                mouse_box.Visible = false 
                mouse_box.Position = Vector2.new()
            end
        end
        
        if Toggles.Visible.Value then 
            fov_circle.Visible = Toggles.Visible.Value
            fov_circle.Color = Options.Color.Value
            fov_circle.Position = getMousePosition()
        end
    end)
end))


local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local Method = getnamecallmethod()
    local Arguments = {...}
    local self = Arguments[1]
    local chance = CalculateChance(SilentAimSettings.HitChance)
    if Toggles.aim_Enabled.Value and self == workspace and not checkcaller() and chance == true then
        if Method == "FindPartOnRayWithIgnoreList" and Options.Method.Value == Method then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithIgnoreList) then
                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)

                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif Method == "FindPartOnRayWithWhitelist" and Options.Method.Value == Method then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithWhitelist) then
                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)

                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif (Method == "FindPartOnRay" or Method == "findPartOnRay") and Options.Method.Value:lower() == Method:lower() then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRay) then
                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)

                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif Method == "Raycast" and Options.Method.Value == Method then
            if ValidateArguments(Arguments, ExpectedArguments.Raycast) then
                local A_Origin = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    Arguments[3] = getDirection(A_Origin, HitPart.Position)

                    return oldNamecall(unpack(Arguments))
                end
            end
        end
    end
    return oldNamecall(...)
end))

local oldIndex = nil 
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, Index)
    if self == Mouse and not checkcaller() and Toggles.aim_Enabled.Value and Options.Method.Value == "Mouse.Hit/Target" and getClosestPlayer() then
        local HitPart = getClosestPlayer()
         
        if Index == "Target" or Index == "target" then 
            return HitPart
        elseif Index == "Hit" or Index == "hit" then 
            return ((Toggles.Prediction.Value and (HitPart.CFrame + (HitPart.Velocity * PredictionAmount))) or (not Toggles.Prediction.Value and HitPart.CFrame))
        elseif Index == "X" or Index == "x" then 
            return self.X 
        elseif Index == "Y" or Index == "y" then 
            return self.Y 
        elseif Index == "UnitRay" then 
            return Ray.new(self.Origin, (self.Hit - self.Origin).Unit)
        end
    end

    return oldIndex(self, Index)
end))


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local BOXEnabled, TRAEnabled, NameTagsEnabled, teamCheckEnabled = false, false, false, false
local espBoxes, espTracers, espNameTags = {}, {}, {}
local boxColor, tracerColor, nameTagColor = Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255)

local function createESPBox(color)
    local box = Drawing.new("Square")
    box.Color, box.Thickness, box.Filled, box.Visible = color, 1, false, false
    return box
end

local function createTracer(color)
    local tracer = Drawing.new("Line")
    tracer.Color, tracer.Thickness, tracer.Visible = color, 2, false
    return tracer
end

local function createNameTag(color, text)
    local nameTag = Drawing.new("Text")
    nameTag.Color, nameTag.Text, nameTag.Size, nameTag.Center, nameTag.Outline, nameTag.OutlineColor, nameTag.Visible = color, text, 15, true, true, Color3.fromRGB(0, 0, 0), false
    return nameTag
end

local function smoothInterpolation(from, to, factor)
    return from + (to - from) * factor
end

local function updateESPBoxes()
    if BOXEnabled then
        for player, box in pairs(espBoxes) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                if teamCheckEnabled and player.Team == Players.LocalPlayer.Team then
                    box.Visible = false
                else
                    local rootPart = player.Character.HumanoidRootPart
                    local screenPosition, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                    if onScreen then
                        local distance = screenPosition.Z
                        local scaleFactor = 70 / distance
                        local boxWidth = 30 * scaleFactor
                        local boxHeight = 50 * scaleFactor
                        box.Size = Vector2.new(boxWidth, boxHeight)
                        box.Position = Vector2.new(screenPosition.X - boxWidth / 2, screenPosition.Y - boxHeight / 2)
                        box.Visible = true
                    else
                        box.Visible = false
                    end
                end
            else
                box.Visible = false
            end
        end
    end
end

local function updateTracers()
    if TRAEnabled then
        for player, tracer in pairs(espTracers) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                if teamCheckEnabled and player.Team == Players.LocalPlayer.Team then
                    tracer.Visible = false
                else
                    local rootPart = player.Character.HumanoidRootPart
                    local screenPosition, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                    if onScreen then
                        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        local targetPosition = Vector2.new(screenPosition.X, screenPosition.Y)
                        tracer.From = smoothInterpolation(tracer.From, screenCenter, 0.1)
                        tracer.To = smoothInterpolation(tracer.To, targetPosition, 0.1)
                        tracer.Visible = true
                    else
                        tracer.Visible = false
                    end
                end
            else
                tracer.Visible = false
            end
        end
    end
end

local function updateNameTags()
    if NameTagsEnabled then
        for player, nameTag in pairs(espNameTags) do
            if player.Character and player.Character:FindFirstChild("Head") then
                if teamCheckEnabled and player.Team == Players.LocalPlayer.Team then
                    nameTag.Visible = false
                else
                    local headPosition, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position)
                    if onScreen then
                        nameTag.Position = Vector2.new(headPosition.X, headPosition.Y - 30)
                        nameTag.Visible = true
                    else
                        nameTag.Visible = false
                    end
                end
            else
                nameTag.Visible = false
            end
        end
    end
end

local function addESP(player)
    if player ~= Players.LocalPlayer then
        local box = createESPBox(boxColor)
        espBoxes[player] = box
        player.CharacterAdded:Connect(function()
            espBoxes[player] = box
        end)
    end
end

local function addTracer(player)
    if player ~= Players.LocalPlayer then
        local tracer = createTracer(tracerColor)
        espTracers[player] = tracer
        player.CharacterAdded:Connect(function()
            espTracers[player] = tracer
        end)
    end
end

local function addNameTag(player)
    if player ~= Players.LocalPlayer then
        local nameTag = createNameTag(nameTagColor, player.Name)
        espNameTags[player] = nameTag
        player.CharacterAdded:Connect(function()
            espNameTags[player] = nameTag
        end)
    end
end

local function removeESP(player)
    if espBoxes[player] then
        espBoxes[player].Visible = false
        espBoxes[player] = nil
    end
end

local function removeTracer(player)
    if espTracers[player] then
        espTracers[player].Visible = false
        espTracers[player] = nil
    end
end

local function removeNameTag(player)
    if espNameTags[player] then
        espNameTags[player].Visible = false
        espNameTags[player] = nil
    end
end

Players.PlayerAdded:Connect(addESP)
Players.PlayerRemoving:Connect(removeESP)
Players.PlayerAdded:Connect(addTracer)
Players.PlayerRemoving:Connect(removeTracer)
Players.PlayerAdded:Connect(addNameTag)
Players.PlayerRemoving:Connect(removeNameTag)

for _, player in pairs(Players:GetPlayers()) do
    addESP(player)
    addTracer(player)
    addNameTag(player)
end

RunService.RenderStepped:Connect(updateESPBoxes)
RunService.RenderStepped:Connect(updateTracers)
RunService.RenderStepped:Connect(updateNameTags)

local espbox = VisualsTab:AddLeftGroupbox("esp")

espbox:AddToggle("TeamCheck", {
    Text = "Enable Team Check",
    Default = false,
    Callback = function(state)
        teamCheckEnabled = state
        for player, box in pairs(espBoxes) do
            if player.Team == Players.LocalPlayer.Team then
                box.Visible = false
            end
        end
        for player, tracer in pairs(espTracers) do
            if player.Team == Players.LocalPlayer.Team then
                tracer.Visible = false
            end
        end
        for player, nameTag in pairs(espNameTags) do
            if player.Team == Players.LocalPlayer.Team then
                nameTag.Visible = false
            end
        end
    end,
})

espbox:AddToggle("EspTeamColor", {
    Text = "ESP Team Color",
    Default = false,
    Callback = function(state)
        for player, box in pairs(espBoxes) do
            box.Color = state and player.TeamColor.Color or boxColor
        end
        for player, tracer in pairs(espTracers) do
            tracer.Color = state and player.TeamColor.Color or tracerColor
        end
        for player, nameTag in pairs(espNameTags) do
            nameTag.Color = state and player.TeamColor.Color or nameTagColor
        end
    end,
})

espbox:AddToggle("EnableESP", {
    Text = "Box ESP",
    Default = false,
    Callback = function(state)
        BOXEnabled = state
        for player, box in pairs(espBoxes) do
            box.Visible = state and (teamCheckEnabled and player.Team ~= Players.LocalPlayer.Team or not teamCheckEnabled)
        end
    end,
}):AddColorPicker("BoxColor", {
    Text = "Box Color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(color)
        boxColor = color
        for _, box in pairs(espBoxes) do
            box.Color = color
        end
    end,
})

espbox:AddToggle("EnableNameTags", {
    Text = "Enable NameTags",
    Default = false,
    Callback = function(state)
        NameTagsEnabled = state
        for player, nameTag in pairs(espNameTags) do
            nameTag.Visible = state and (teamCheckEnabled and player.Team ~= Players.LocalPlayer.Team or not teamCheckEnabled)
        end
    end,
}):AddColorPicker("NameTagColor", {
    Text = "NameTag Color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(color)
        nameTagColor = color
        for _, nameTag in pairs(espNameTags) do
            nameTag.Color = color
        end
    end,
})

espbox:AddToggle("EnableTracer", {
    Text = "Enable Tracers",
    Default = false,
    Callback = function(state)
        TRAEnabled = state
        for player, tracer in pairs(espTracers) do
            tracer.Visible = state and (teamCheckEnabled and player.Team ~= Players.LocalPlayer.Team or not teamCheckEnabled)
        end
    end,
}):AddColorPicker("TracerColor", {
    Text = "Tracer Color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(color)
        tracerColor = color
        for _, tracer in pairs(espTracers) do
            tracer.Color = color
        end
    end,
})

local localPlayer = game:GetService("Players").LocalPlayer
local Cmultiplier = 1  
local isSpeedActive = false
local isFlyActive = false
local isNoClipActive = false
local isFunctionalityEnabled = true  
local flySpeed = 1
local camera = workspace.CurrentCamera
local humanoid = nil

frabox:AddToggle("functionalityEnabled", {
    Text = "Enable/Disable movement",
    Default = true,
    Tooltip = "Enable or disable.",
    Callback = function(value)
        isFunctionalityEnabled = value
    end
})

frabox:AddToggle("speedEnabled", {
    Text = "Speed Toggle",
    Default = false,
    Tooltip = "It makes you go fast.",
    Callback = function(value)
        isSpeedActive = value
    end
}):AddKeyPicker("speedToggleKey", {
    Default = "C",  
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Speed Toggle Key",
    Tooltip = "CFrame keybind.",
    Callback = function(value)
        isSpeedActive = value
    end
})

frabox:AddSlider("cframespeed", {
    Text = "CFrame Multiplier",
    Default = 1,
    Min = 1,
    Max = 20,
    Rounding = 1,
    Tooltip = "The CFrame speed.",
    Callback = function(value)
        Cmultiplier = value
    end,
})

frabox:AddToggle("flyEnabled", {
    Text = "CFly Toggle",
    Default = false,
    Tooltip = "Toggle CFrame Fly functionality.",
    Callback = function(value)
        isFlyActive = value
    end
}):AddKeyPicker("flyToggleKey", {
    Default = "F",  
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "CFly Toggle Key",
    Tooltip = "CFrame Fly keybind.",
    Callback = function(value)
        isFlyActive = value
    end
})

frabox:AddSlider("flySpeed", {
    Text = "CFly Speed",
    Default = 1,
    Min = 1,
    Max = 50,
    Rounding = 1,
    Tooltip = "The CFrame Fly speed.",
    Callback = function(value)
        flySpeed = value
    end,
})

frabox:AddToggle("noClipEnabled", {
    Text = "NoClip Toggle",
    Default = false,
    Tooltip = "Enable or disable NoClip.",
    Callback = function(value)
        isNoClipActive = value
    end
}):AddKeyPicker("noClipToggleKey", {
    Default = "N",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "NoClip Toggle Key",
    Tooltip = "Keybind to toggle NoClip.",
    Callback = function(value)
        isNoClipActive = value
    end
})

local hookEnabled = false
local oldNamecall

local function enableBulletHitManipulation(value)
    BManipulation = value
    local remote = game:GetService("ReplicatedStorage").BulletFireSystem.BulletHit

    if BManipulation then
        if not hookEnabled then
            hookEnabled = true
            oldNamecall = hookmetamethod(remote, "__namecall", newcclosure(function(self, ...)
                if typeof(self) == "Instance" then
                    local method = getnamecallmethod()
                    if method and (method == "FireServer" and self == remote) then
                        local HitPart = getClosestPlayer()
                        if HitPart then
                            local remArgs = {...}
                            remArgs[2] = HitPart
                            remArgs[3] = HitPart.Position
                            setnamecallmethod(method)
                            return oldNamecall(self, unpack(remArgs))
                        else
                            setnamecallmethod(method)
                        end
                    end
                end
                return oldNamecall(self, ...)
            end))
        end
    else
        BsManipulation = false
        if hookEnabled then
            hookEnabled = false
            if oldNamecall then
                hookmetamethod(remote, "__namecall", oldNamecall)
            end
        end
    end
end

WarTycoonBox:AddToggle("BulletHit manipulation", {
    Text = "Magic bullet [beta]",
    Default = false,
    Tooltip = "Magic Bullet?",
    Callback = function(value)
        enableBulletHitManipulation(value)
    end
})

local function modifyWeaponSettings(property, value)
    local function findSettingsModule(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("ModuleScript") then
                local success, module = pcall(function() return require(child) end)
                if success and module[property] ~= nil then
                    return module
                end
            end
            local found = findSettingsModule(child)
            if found then
                return found
            end
        end
        return nil
    end

    local player = game:GetService("Players").LocalPlayer
    local backpack = player:WaitForChild("Backpack")
    local character = player.Character or player.CharacterAdded:Wait()
    local foundModules = {}

    if getgenv().WeaponOnHands then
        local toolInHand = character:FindFirstChildOfClass("Tool")
        if toolInHand then
            local settingsModule = findSettingsModule(toolInHand)
            if settingsModule then
                table.insert(foundModules, settingsModule)
            end
        end
    else
        for _, item in pairs(backpack:GetChildren()) do
            local settingsModule = findSettingsModule(item)
            if settingsModule then
                table.insert(foundModules, settingsModule)
            end
        end
    end

    if #foundModules > 0 then
        for _, module in pairs(foundModules) do
            module[property] = value
        end
    end
end

ACSEngineBox:AddToggle("WeaponOnHands", {
    Text = "Weapon In Hands",
    Default = false,
    Tooltip = "Apply changes only to the weapon in hands if enabled.",
    Callback = function(value)
        getgenv().WeaponOnHands = value
    end
})

ACSEngineBox:AddButton('INF AMMO', function()
    modifyWeaponSettings("Ammo", math.huge)
end)

ACSEngineBox:AddButton('NO RECOIL | NO SPREAD', function()
    modifyWeaponSettings("VRecoil", {0, 0})
    modifyWeaponSettings("HRecoil", {0, 0})
    modifyWeaponSettings("MinSpread", 0)
    modifyWeaponSettings("MaxSpread", 0)
    modifyWeaponSettings("RecoilPunch", 0)
    modifyWeaponSettings("AimRecoilReduction", 0)
end)

ACSEngineBox:AddButton('INF BULLET DISTANCE', function()
    modifyWeaponSettings("Distance", 25000)
end)

ACSEngineBox:AddInput("BulletSpeedInput", {
    Text = "Bullet Speed",
    Default = "10000",
    Tooltip = "Set the bullet speed",
    Callback = function(value)
        getgenv().bulletSpeedValue = tonumber(value) or 10000
    end
})

ACSEngineBox:AddButton('CHANGE BULLET SPEED', function()
    modifyWeaponSettings("BSpeed", getgenv().bulletSpeedValue or 10000)
    modifyWeaponSettings("MuzzleVelocity", getgenv().bulletSpeedValue or 10000)
end)

local fireRateInput
fireRateInput = ACSEngineBox:AddInput('FireRateInput', {
    Text = 'Enter Fire Rate',
    Default = '8888',
    Tooltip = 'Type the fire rate value you want to apply.',
})

ACSEngineBox:AddButton('CHANGE FIRE RATE', function()
    modifyWeaponSettings("FireRate", tonumber(fireRateInput.Value) or 8888)
    modifyWeaponSettings("ShootRate", tonumber(fireRateInput.Value) or 8888)
end)

local bulletsInput = ACSEngineBox:AddInput('BulletsInput', {
    Text = 'Enter Bullets',
    Default = '50',
    Tooltip = 'Type the number of bullets you want to apply.',
    Numeric = true
})

ACSEngineBox:AddButton('MULTI BULLETS', function()
    local bulletsValue = tonumber(Options.BulletsInput.Value) or 50
    modifyWeaponSettings("Bullets", bulletsValue)
end)

local inputField
inputField = ACSEngineBox:AddInput('FireModeInput', {
    Text = 'Enter Fire Mode',
    Default = 'Auto',
    Tooltip = 'Type the fire mode you want to apply.',
})

ACSEngineBox:AddButton('CHANGE FIRE MODE', function()
    modifyWeaponSettings("Mode", inputField.Value or 'Auto')
end)

local targetStrafe = GeneralTab:AddLeftGroupbox("Target Strafe")

local strafeEnabled = false
local strafeAllowed = true
local strafeSpeed, strafeRadius = 50, 5
local strafeMode, targetPlayer = "Horizontal", nil
local originalCameraMode = nil

local function updateFovCircle(targetPosition)
    if Toggles.Visible.Value then
        local fov_circle = getFovCircle()
        fov_circle.Position = Vector2.new(targetPosition.X, targetPosition.Y)
        fov_circle.Radius = Options.Radius.Value
    end
end

local function getClosestPlayer()
    local nearest, shortest = nil, math.huge
    local mousePos = Camera:ViewportPointToRay(Mouse.X, Mouse.Y).Origin

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local part = player.Character.Head
            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                if dist < shortest then
                    nearest, shortest = player, dist
                end
            end
        end
    end
    return nearest
end

local function startTargetStrafe()
    if not strafeAllowed then return end
    targetPlayer = getClosestPlayer()
    if targetPlayer and targetPlayer.Character then
        originalCameraMode = game:GetService("Players").LocalPlayer.CameraMode
        game:GetService("Players").LocalPlayer.CameraMode = Enum.CameraMode.Classic

        LocalPlayer.Character:SetPrimaryPartCFrame(targetPlayer.Character.HumanoidRootPart.CFrame)
        Camera.CameraSubject = targetPlayer.Character.Humanoid
        updateFovCircle(targetPlayer.Character.HumanoidRootPart.Position)

        targetPlayer.Character.Humanoid.Died:Connect(stopTargetStrafe)
        targetPlayer.AncestryChanged:Connect(function(_, parent)
            if not parent then stopTargetStrafe() end
        end)
    end
end

local function strafeAroundTarget()
    if not (strafeAllowed and targetPlayer and targetPlayer.Character) then return end

    local targetPos = targetPlayer.Character.HumanoidRootPart.Position
    local angle = tick() * (strafeSpeed / 10)
    local offset = strafeMode == "Horizontal"
        and Vector3.new(math.cos(angle) * strafeRadius, 0, math.sin(angle) * strafeRadius)
        or Vector3.new(math.cos(angle) * strafeRadius, strafeRadius, math.sin(angle) * strafeRadius)

    LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(targetPos + offset))
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocalPlayer.Character.HumanoidRootPart.Position, targetPos)
    updateFovCircle(targetPos)
end

local function stopTargetStrafe()
    Camera.CameraSubject = LocalPlayer.Character.Humanoid
    game:GetService("Players").LocalPlayer.CameraMode = originalCameraMode or Enum.CameraMode.Classic
    strafeEnabled, targetPlayer = false, nil
end

targetStrafe:AddToggle("strafeControlToggle", {
    Text = "Enable/Disable",
    Default = false,
    Tooltip = "Enable or disable the ability to use Target Strafe.",
    Callback = function(value)
        strafeAllowed = value
        if not strafeAllowed and strafeEnabled then
            stopTargetStrafe()
        end
    end
})

targetStrafe:AddToggle("strafeToggle", {
    Text = "Enable Target Strafe",
    Default = false,
    Tooltip = "Enable or disable Target Strafe.",
    Callback = function(value)
        if strafeAllowed then
            strafeEnabled = value
            if strafeEnabled then startTargetStrafe() else stopTargetStrafe() end
        end
    end
}):AddKeyPicker("strafeToggleKey", {
    Default = "L",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Target Strafe Toggle Key",
    Tooltip = "Key to toggle Target Strafe",
    Callback = function(value)
        if strafeAllowed then
            strafeEnabled = value
            if strafeEnabled then startTargetStrafe() else stopTargetStrafe() end
        end
    end
})

targetStrafe:AddDropdown("strafeModeDropdown", {
    AllowNull = false,
    Text = "Target Strafe Mode",
    Default = "Horizontal",
    Values = {"Horizontal", "UP"},
    Tooltip = "Select the strafing mode.",
    Callback = function(value) strafeMode = value end
})

targetStrafe:AddSlider("strafeRadiusSlider", {
    Text = "Strafe Radius",
    Default = 5,
    Min = 1,
    Max = 20,
    Rounding = 1,
    Tooltip = "Set the radius of movement around the target.",
    Callback = function(value) strafeRadius = value end
})

targetStrafe:AddSlider("strafeSpeedSlider", {
    Text = "Strafe Speed",
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 1,
    Tooltip = "Set the speed of strafing around the target.",
    Callback = function(value) strafeSpeed = value end
})

game:GetService("RunService").RenderStepped:Connect(function()
    if strafeEnabled and strafeAllowed then strafeAroundTarget() end
end)

while true do
    task.wait()

    if isFunctionalityEnabled then
        if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            humanoid = localPlayer.Character:FindFirstChild("Humanoid")
            
            if isSpeedActive and humanoid and humanoid.MoveDirection.Magnitude > 0 then
                local moveDirection = humanoid.MoveDirection.Unit
                localPlayer.Character.HumanoidRootPart.CFrame = localPlayer.Character.HumanoidRootPart.CFrame + moveDirection * Cmultiplier
            end

            if isFlyActive then
                local flyDirection = Vector3.zero

                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then
                    flyDirection = flyDirection + camera.CFrame.LookVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) then
                    flyDirection = flyDirection - camera.CFrame.LookVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) then
                    flyDirection = flyDirection - camera.CFrame.RightVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) then
                    flyDirection = flyDirection + camera.CFrame.RightVector
                end

                if flyDirection.Magnitude > 0 then
                    flyDirection = flyDirection.Unit
                end

                local newPosition = localPlayer.Character.HumanoidRootPart.Position + flyDirection * flySpeed
                localPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(newPosition)
                localPlayer.Character.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
            end

            if isNoClipActive then
                for _, v in pairs(localPlayer.Character:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide then
                        v.CanCollide = false
                    end
                end
            end
        end
    end
end

ThemeManager:LoadDefaultTheme()
