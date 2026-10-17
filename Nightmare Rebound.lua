local G = getgenv()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

-- Audio loader with URL-based caching
G.LoadGithubAudio = function(url)
    if not (writefile and getcustomasset and request) then
        return nil
    end

    local function generateFileName(input)
        local hash = 0
        for i = 1, #input do
            hash = (hash * 31 + string.byte(input, i)) % 2^32
        end
        return "rebound_fix_" .. tostring(hash) .. ".mp3"
    end

    local fileName = generateFileName(url)

    local exists = false
    pcall(function()
        exists = isfile and isfile(fileName)
    end)

    if exists then
        local ok, asset = pcall(getcustomasset, fileName)
        if ok then
            return asset
        end
    end

    local ok, response = pcall(function()
        return request({
            Url = url,
            Method = "GET",
            Headers = {
                ["Accept"] =
                    "audio/mpeg, audio/ogg, application/octet-stream"
            }
        })
    end)

    if not ok or not response or response.StatusCode ~= 200 then
        warn("Rebound: failed to download audio:", url)
        return nil
    end

    local saved = pcall(writefile, fileName, response.Body)
    if not saved then
        return nil
    end

    local assetOK, asset = pcall(getcustomasset, fileName)
    if assetOK then
        return asset
    end

    warn("Rebound: couldn't load audio asset:", tostring(asset))
    return nil
end

-- Model loader with URL-based caching
G.LoadGithubModel = function(url)
    if not (writefile and getcustomasset and request) then
        return nil
    end

    local hash = 0
    for i = 1, #url do
        hash = (hash * 31 + string.byte(url, i)) % 2^32
    end

    local fileName = "rebound_" .. tostring(hash) .. ".rbxm"

    local function loadModel()
        local assetId = getcustomasset(fileName)
        local objects = game:GetObjects(assetId)
        return objects and objects[1]
    end

    local exists = false
    pcall(function()
        exists = isfile and isfile(fileName)
    end)

    if exists then
        local ok, model = pcall(loadModel)
        if ok and model then
            return model
        end
    end

    local ok, response = pcall(function()
        return request({
            Url = url,
            Method = "GET"
        })
    end)

    if not ok or not response or response.StatusCode ~= 200 then
        warn("Rebound: failed to download model:", url)
        return nil
    end

    local saved = pcall(writefile, fileName, response.Body)
    if not saved then
        return nil
    end

    local loaded, model = pcall(loadModel)
    if loaded then
        return model
    end

    warn("Rebound: couldn't load model:", tostring(model))
    return nil
end

-- Custom achievement setup
local CustomAchievements

pcall(function()
    CustomAchievements = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/RegularVynixu/DOORS-Custom-Achievements/main/init.luau"
    ))()
end)

local function GrantNightmareAchievement()
    if not CustomAchievements then
        warn("Rebound: custom achievements module unavailable")
        return
    end

    local ok, err = pcall(function()
        if CustomAchievements:CheckOwned("OutOfManyNightmares") then
            return
        end

        CustomAchievements:Grant({
            Identifier = "OutOfManyNightmares",
            Title = "Out of Many Nightmares",
            Desc = "He ran out of nightmares",
            Reason = "Survive And Encounter Rebound",
            Image = "rbxassetid://136737940723651"
        }, {
            CheckOwned = true,
            Remember = true
        })
    end)

    if not ok then
        warn("Rebound achievement error:", err)
    end
end

local function Rebound()
    local gameData = ReplicatedStorage:WaitForChild("GameData")
    local latestRoom = gameData:WaitForChild("LatestRoom")
    local currentRooms = workspace:WaitForChild("CurrentRooms")

    local plusRoom = latestRoom.Value + 1
    local killed = false
    local speed = 2

    local camera = workspace.CurrentCamera
    local cameraShaker = require(
        ReplicatedStorage:WaitForChild("CameraShaker")
    )

    local camShake = cameraShaker.new(
        Enum.RenderPriority.Camera.Value,
        function(cf)
            camera.CFrame = camera.CFrame * cf
        end
    )
    camShake:Start()

    -- Nightmare Rebound model
    local rawURL =
        "https://raw.githubusercontent.com/Ilikerobloxdoors/Nightmare-Rebound/main/nightmare%20rebound.rbxm"

    local entity
    local ok, result = pcall(function()
        return G.LoadGithubModel(rawURL)
    end)

    if ok then
        entity = result
    end

    if not entity then
        warn("Nightmare Rebound model failed to load")
        return false
    end

    entity.Parent = workspace

    local function GetLastRoom()
        return currentRooms:FindFirstChild(tostring(plusRoom))
            or currentRooms:FindFirstChild(plusRoom)
    end

    local entityPart = entity.PrimaryPart
        or entity:FindFirstChildWhichIsA("BasePart", true)

    if not entityPart then
        entity:Destroy()
        warn("Nightmare Rebound has no BasePart")
        return false
    end

    local lastRoom = GetLastRoom()
    local roomExit = lastRoom and lastRoom:FindFirstChild("RoomExit")

    if not roomExit then
        entity:Destroy()
        warn("Couldn't find the next room's exit")
        return false
    end

    entityPart.CFrame =
        roomExit.CFrame + Vector3.new(0, 0.6, 0)

    entityPart.CanCollide = false
    entityPart.Anchored = true

    task.wait(4)

    -- Don't spawn during Seek
    if workspace:FindFirstChild("SeekMovingNewClone")
        or workspace:FindFirstChild("SeekMoving") then
        entity:Destroy()
        return false
    end

    -- Movement audio
    local moving = Instance.new("Sound")
    moving.Name = "ReboundMoving"
    moving.Parent = entityPart
    moving.Volume = 10

    local movingAudio = G.LoadGithubAudio(
        "https://raw.githubusercontent.com/Francisco1692qzd/RevivedOldHardcore/main/MovingRebound.mp3"
    )

    if movingAudio then
        moving.SoundId = movingAudio
        moving:Play()
    end

    local function isBossActive()
        local room = latestRoom.Value

        if room == 50 or room == 100 then
            return true
        end

        if workspace:FindFirstChild("SeekMovingNewClone")
            or workspace:FindFirstChild("SeekMoving") then
            return true
        end

        for _, sound in ipairs(ReplicatedStorage:GetDescendants()) do
            if sound:IsA("Sound")
                and sound.IsPlaying
                and (sound.Name:find("Music")
                    or sound.Name == "Shade") then
                return true
            end
        end

        return false
    end

    local function canSeeTarget(target, size)
        if killed or isBossActive() then
            return false
        end

        local root = target and target:FindFirstChild("HumanoidRootPart")
        if not root then
            return false
        end

        local origin = entityPart.Position
        local offset = root.Position - origin

        if offset.Magnitude == 0 then
            return false
        end

        local ray = Ray.new(origin, offset.Unit * size)
        local hit = workspace:FindPartOnRay(ray, entity)

        if hit and hit:IsDescendantOf(target) then
            killed = true
            return true
        end

        return false
    end

    -- Player detection and jumpscare
    task.spawn(function()
        while entity.Parent and entityPart.Parent do
            task.wait(0.5)

            local character = LocalPlayer.Character
            local root = character
                and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character
                and character:FindFirstChildWhichIsA("Humanoid")

            if root and humanoid and humanoid.Health > 0 then
                if canSeeTarget(character, 50)
                    and not character:GetAttribute("Hiding") then

                    moving:Stop()

                    local gui = Instance.new("ScreenGui")
                    gui.Name = "ReboundJs"
                    gui.IgnoreGuiInset = true
                    gui.ResetOnSpawn = false
                    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

                    local static = Instance.new("ImageLabel")
                    static.Name = "Static"
                    static.Parent = gui
                    static.BackgroundTransparency = 1
                    static.Size = UDim2.new(1, 0, 1, 0)
                    static.Image = "rbxassetid://236543215"
                    static.ImageTransparency = 1

                    local reboundImage = Instance.new("ImageLabel")
                    reboundImage.Name = "Rebound"
                    reboundImage.Parent = gui
                    reboundImage.BackgroundTransparency = 1
                    reboundImage.Position =
                        UDim2.new(0.4866, 0, 0.4793, 0)
                    reboundImage.Size =
                        UDim2.new(0.0267, 0, 0.0387, 0)
                    reboundImage.Image = "rbxassetid://10914800940"

                    local jsSize = Instance.new("ImageLabel")
                    jsSize.Name = "JSSIZE"
                    jsSize.Parent = gui
                    jsSize.BackgroundTransparency = 1
                    jsSize.Position =
                        UDim2.new(-0.586, 0, -1.251, 0)
                    jsSize.Size =
                        UDim2.new(2.128, 0, 3.081, 0)
                    jsSize.Visible = false
                    jsSize.Image = "rbxassetid://10914800940"

                    task.spawn(function()
                        while gui.Parent do
                            static.Image = "rbxassetid://236543215"
                            task.wait(0.002)
                            static.Rotation = 0
                            task.wait(0.002)
                            static.Rotation = 180
                            task.wait(0.002)
                            static.Image = "rbxassetid://236777652"
                            task.wait(0.002)
                            static.Rotation = 0
                            task.wait(0.002)
                            static.Rotation = 180
                            task.wait(0.002)
                        end
                    end)

                    task.spawn(function()
                        local jumpscareAudio = G.LoadGithubAudio(
                            "https://raw.githubusercontent.com/Francisco1692qzd/RevivedOldHardcore/main/JumpscareReb.mp3"
                        )

                        if jumpscareAudio then
                            local jumpscare = Instance.new("Sound")
                            jumpscare.SoundId = jumpscareAudio
                            jumpscare.Parent = workspace
                            jumpscare.Volume = 5
                            jumpscare:Play()
                            Debris:AddItem(jumpscare, 10)
                        end

                        TweenService:Create(
                            static,
                            TweenInfo.new(0.5),
                            {ImageTransparency = 0.2}
                        ):Play()

                        TweenService:Create(
                            reboundImage,
                            TweenInfo.new(0.5),
                            {
                                Size = jsSize.Size,
                                Position = jsSize.Position
                            }
                        ):Play()

                        task.wait(0.3)

                        if humanoid.Parent and humanoid.Health > 0 then
                            humanoid:TakeDamage(100)
                        end

                        local stats = ReplicatedStorage:FindFirstChild("GameStats")
                        local playerStats = stats
                            and stats:FindFirstChild(
                                "Player_" .. character.Name
                            )

                        local total = playerStats
                            and playerStats:FindFirstChild("Total")
                        local deathCause = total
                            and total:FindFirstChild("DeathCause")

                        if deathCause then
                            deathCause.Value = "Rebound"
                        end

                        local hints = {
                            "You died to the entity designated as Rebound...",
                            "He could trick you by coming through the next doors in the next few seconds!",
                            "Whenever this happens, do not go forward, stay on your desired hiding spot!"
                        }

                        local hintFolder =
                            ReplicatedStorage:FindFirstChild("RemotesFolder")
                            or ReplicatedStorage:FindFirstChild("Bricks")

                        local deathHint =
                            hintFolder and hintFolder:FindFirstChild("DeathHint")

                        if deathHint then
                            pcall(function()
                                if hintFolder.Name == "RemotesFolder" then
                                    firesignal(
                                        deathHint.OnClientEvent,
                                        hints,
                                        "Blue"
                                    )
                                else
                                    firesignal(deathHint.OnClientEvent, hints)
                                end
                            end)
                        end

                        task.wait(0.5)

                        if gui.Parent then
                            TweenService:Create(
                                static,
                                TweenInfo.new(1),
                                {ImageTransparency = 1}
                            ):Play()

                            TweenService:Create(
                                reboundImage,
                                TweenInfo.new(0.3),
                                {ImageTransparency = 1}
                            ):Play()
                        end

                        task.wait(1)
                        gui:Destroy()
                    end)
                end

                if entityPart.Parent
                    and (entityPart.Position - root.Position).Magnitude <= 60 then
                    camShake:Start()
                    camShake:ShakeOnce(14, 9, 0, 2, 1, 6)
                end
            end
        end
    end)

    -- Move Rebound backwards through the rooms
    for i = latestRoom.Value, 1, -1 do
        if not entity.Parent or not entityPart.Parent then
            return false
        end

        local room = currentRooms:FindFirstChild(tostring(i))
            or currentRooms:FindFirstChild(i)

        if room then
            local entrance = room:FindFirstChild("RoomEntrance")

            if entrance then
                local tween = TweenService:Create(
                    entityPart,
                    TweenInfo.new(
                        speed,
                        Enum.EasingStyle.Sine,
                        Enum.EasingDirection.Out
                    ),
                    {
                        CFrame =
                            entrance.CFrame + Vector3.new(0, 0.9, 0)
                    }
                )

                tween:Play()
                local playbackState = tween.Completed:Wait()

                if playbackState ~= Enum.PlaybackState.Completed then
                    return false
                end
            end
        end
    end

    if entityPart.Parent then
        entityPart.Anchored = false
        entityPart.CanCollide = false
    end

    Debris:AddItem(entity, 5)

    return true
end

-- Spawn Nightmare Rebound and run five encounters
local function SpawnReb()
    local maxEncounters = 5
    local allCompleted = true

    -- Arrival warning sound
    local warningAudio = G.LoadGithubAudio(
        "https://raw.githubusercontent.com/Francisco1692qzd/RevivedOldHardcore/main/Warning.mp3"
    )

    if warningAudio then
        local arrival = Instance.new("Sound")
        arrival.Name = "NightmareReboundWarning"
        arrival.SoundId = warningAudio
        arrival.Parent = workspace
        arrival.Volume = 5
        arrival:Play()

        Debris:AddItem(arrival, 10)
    end

    -- Camera shake
    local camera = workspace.CurrentCamera
    local cameraShaker = require(
        ReplicatedStorage:WaitForChild("CameraShaker")
    )

    local camShake = cameraShaker.new(
        Enum.RenderPriority.Camera.Value,
        function(cf)
            camera.CFrame = camera.CFrame * cf
        end
    )

    -- Red arrival effect
    local warnEffect = Instance.new("ColorCorrectionEffect")
    warnEffect.Name = "NightmareReboundWarningEffect"
    warnEffect.TintColor = Color3.fromRGB(255, 45, 45)
    warnEffect.Saturation = -0.7
    warnEffect.Contrast = 0.2
    warnEffect.Parent = Lighting

    TweenService:Create(
        warnEffect,
        TweenInfo.new(15),
        {
            TintColor = Color3.fromRGB(255, 255, 255),
            Saturation = 0,
            Contrast = 0
        }
    ):Play()

    Debris:AddItem(warnEffect, 15)

    camShake:Start()
    camShake:ShakeOnce(12, 4, 0, 6, 2, 0.5)

    -- Exactly five encounter attempts
    for i = 1, maxEncounters do
        print(
            "Nightmare Rebound encounter "
            .. i .. "/" .. maxEncounters
        )

        local ok, completed = pcall(Rebound)

        if not ok then
            warn("Nightmare Rebound error:", completed)
            allCompleted = false
        elseif not completed then
            allCompleted = false
        end

        -- Wait for the next room before the next encounter
        if i < maxEncounters then
            local latestRoom =
                ReplicatedStorage.GameData.LatestRoom

            latestRoom.Changed:Wait()
            task.wait(2)
        end
    end

    -- Only award the achievement after all five runs finish
    local character = LocalPlayer.Character
    local humanoid = character
        and character:FindFirstChildWhichIsA("Humanoid")

    if allCompleted and humanoid and humanoid.Health > 0 then
        GrantNightmareAchievement()
        print("Nightmare Rebound: all five encounters completed!")
    else
        warn(
            "Nightmare Rebound: achievement not granted; "
            .. "five successful encounters were not completed."
        )
    end
end

local ok, err = pcall(SpawnReb)

if not ok then
    warn("Nightmare Rebound startup error:", err)
end
