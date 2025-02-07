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

    TargetPart = "HumanoidRootPart",

    SilentAimMethod = "Raycast",

    

    FOVRadius = 130,

    FOVVisible = false,

    ShowSilentAimTarget = false, 

    

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

    ViewportPointToRay = {

        ArgCountRequired = 2,

        Args = { "number", "number" }

    },

    ScreenPointToRay = {

        ArgCountRequired = 2,

        Args = { "number", "number" }

    },

    Raycast = {

        ArgCountRequired = 3,

        Args = { "Instance", "Vector3", "Vector3", "RaycastParams" }

    },

    FindPartOnRay = {

        ArgCountRequired = 2,

        Args = { "Ray", "Instance", "boolean", "boolean" }

    },

    FindPartOnRayWithIgnoreList = {

        ArgCountRequired = 3,

        Args = { "Ray", "table", "boolean", "boolean" }

    },

    FindPartOnRayWithWhitelist = { 

        ArgCountRequired = 3,

        Args = { "Ray", "table", "boolean", "boolean" }

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

    local Camera = workspace.CurrentCamera

    local Closest

    local DistanceToMouse

    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    

    for _, Player in next, GetPlayers(Players) do

        if Player == LocalPlayer then continue end

        if Toggles.TeamCheck.Value and Player.Team == LocalPlayer.Team then continue end

        

        local Character = Player.Character

        if not Character then continue end

        

        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")

        local Humanoid = FindFirstChild(Character, "Humanoid")

        if not HumanoidRootPart or not Humanoid or Humanoid.Health <= 0 then continue end

        

        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)

        if not OnScreen then continue end

        

        local Distance = (center - ScreenPosition).Magnitude

        if Distance <= (DistanceToMouse or Options.Radius.Value or 2000) then

            Closest = Options.TargetPart.Value == "Random" and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]] or Character[Options.TargetPart.Value]

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







local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/Foratio/refs/heads/main/mobileLib.lua"))()

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



SilentAimSettings.BulletTP = false





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



Main:AddToggle("BulletTP", {

    Text = "Bullet Teleport",

    Default = SilentAimSettings.BulletTP,

    Tooltip = "Teleports bullet origin to target"

}):OnChanged(function()

    SilentAimSettings.BulletTP = Toggles.BulletTP.Value

end)



Main:AddToggle("CheckForFireFunc", {

    Text = "Check For Fire Function",

    Default = SilentAimSettings.CheckForFireFunc,

    Tooltip = "Checks if the method is called from a fire function"

}):OnChanged(function()

    SilentAimSettings.CheckForFireFunc = Toggles.CheckForFireFunc.Value

end)



Main:AddDropdown("TargetPart", {

    AllowNull = true, 

    Text = "Target Part", 

    Default = SilentAimSettings.TargetPart, 

    Values = {"Head", "HumanoidRootPart"
