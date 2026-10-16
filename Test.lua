-- XENO GITHUB MODEL LOADER (.rbxm / .rbxmx)
local G = getgenv()

-- Garantindo que a função exista no ambiente Global
G.LoadGithubModel = function(url, retryCount, retryDelay)
	retryCount = retryCount or 0
	retryDelay = retryDelay or 1 -- 1 second delay between retries

	-- Max 3 retries
	if retryCount >= 3 then
		warn("Failed to load model after 3 attempts")
		return nil
	end

	if not (writefile and getcustomasset and request and isfile and delfile) then
		warn("Missing required functions: writefile, getcustomasset, request, isfile, delfile")
		return nil
	end

	-- Generate a consistent filename based on URL hash
	local function getHash(str)
		local hash = 0
		for i = 1, #str do
			hash = (hash * 31 + string.byte(str, i)) % 2^32
		end
		return tostring(hash)
	end

	local fileName = "rebound_" .. getHash(url) .. ".rbxm"

	-- If retrying, delete the potentially corrupted file
	if retryCount > 0 then
		print("Retry " .. retryCount .. ": Cleaning up...")
		pcall(function() 
			if isfile(fileName) then
				delfile(fileName)
			end
		end)
		wait(retryDelay) -- Wait before retrying
	end

	-- Check if file already exists
	local fileExists = false
	local fileCheckSuccess, fileExistsResult = pcall(function()
		return isfile(fileName)
	end)

	if fileCheckSuccess and fileExistsResult then
		fileExists = true
	end

	-- Only download if file doesn't exist
	if not fileExists then
		print("Downloading model from: " .. url)
		local response = request({Url = url, Method = "GET"})
		if response.StatusCode ~= 200 then 
			warn("Download failed (HTTP " .. response.StatusCode .. "), retrying...")
			return G.LoadGithubModel(url, retryCount + 1, retryDelay)
		end
		writefile(fileName, response.Body)
		print("File saved: " .. fileName)
	end

	-- Load the model
	local assetId = getcustomasset(fileName)
	local success, result = pcall(function()
		local objects = game:GetObjects(assetId)
		if objects and #objects > 0 then
			return objects[1]
		end
		return nil
	end)

	if success and result then 
		-- Clone and return fresh instance
		local cloneSuccess, cloned = pcall(function()
			return result:Clone()
		end)

		if cloneSuccess and cloned then
			print("Model loaded and cloned successfully")
			return cloned
		else
			warn("Clone failed: " .. tostring(cloned))
		end
	end

	-- If load fails, delete corrupted file and retry
	warn("Failed to load model: " .. tostring(result))
	pcall(function() 
		if delfile and isfile(fileName) then
			delfile(fileName)
		end
	end)

	return G.LoadGithubModel(url, retryCount + 1, retryDelay)
end
G.LoadGithubAudio = function(url, forceRefresh)
	if not (writefile and getcustomasset and request and isfile) then 
		warn("Missing required functions")
		return nil 
	end

	forceRefresh = forceRefresh or false

	-- Generate a consistent filename based on URL hash
	local function getHash(str)
		local hash = 0
		for i = 1, #str do
			hash = (hash * 31 + string.byte(str, i)) % 2^32
		end
		return tostring(hash)
	end

	-- Detect audio format from URL
	local function getAudioFormat(url)
		if url:match("%.mp3$") then return "mp3"
		elseif url:match("%.ogg$") then return "ogg"
		elseif url:match("%.wav$") then return "wav"
		else return "mp3"
		end
	end

	local audioFormat = getAudioFormat(url)
	local fileName = "rebound_audio_" .. getHash(url) .. "." .. audioFormat

	-- Force refresh: delete existing file
	if forceRefresh and isfile(fileName) and delfile then
		pcall(function() delfile(fileName) end)
		print("🔄 Force refresh: deleted cached audio")
	end

	-- Check if file exists
	local fileExists = isfile(fileName)

	-- Download if file doesn't exist or force refresh
	if not fileExists then
		print("📥 Downloading audio from: " .. url)

		local downloadUrl = url .. "?t=" .. math.random(1, 100000)

		local response = request({
			Url = downloadUrl,
			Method = "GET",
			Headers = {
				["Accept"] = "audio/mpeg, audio/ogg, application/octet-stream"
			}
		})

		if response.StatusCode ~= 200 then
			warn("Xeno: Failed to download audio. Status: " .. response.StatusCode)
			return nil
		end

		writefile(fileName, response.Body)
		print("💾 Audio saved: " .. fileName)
	else
		print("📁 Using cached audio: " .. fileName)
	end

	-- Get custom asset
	local success, assetId = pcall(function()
		return getcustomasset(fileName)
	end)

	if success and assetId then
		print("✅ Audio loaded successfully!")
		return assetId
	end

	warn("Error in getcustomasset: " .. tostring(assetId))

	-- Clean up corrupted file
	pcall(function() 
		if delfile then delfile(fileName) end
	end)

	return nil
end
-- Load achievement library once
local CustomAchievements = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/RegularVynixu/DOORS-Custom-Achievements/main/init.luau"
	))()

-- Achievement function
local function GrantNightmareAchievement()
	if not CustomAchievements:CheckOwned("NightmareReboundBeaten") then
		CustomAchievements:Grant({
			Identifier = "NightmareReboundBeaten",
			Title = "Out Of Many Nightmares",
			Desc = "He ran Out of nightmares...",
			Reason = "Survive Rebound But in Nightmare HC Mode",
			Image = "rbxassetid://139221710369714"
		}, {
			CheckOwned = true,
			Remember = true
		})
	end
end

local function Rebound()
	local repStorage = game.ReplicatedStorage
	local gameData = repStorage.GameData
	local latestRoom = gameData.LatestRoom
	local plusRoom = latestRoom.Value + 1
	local currentRooms = workspace.CurrentRooms
	local killed = false
	local speed = 2.2
	local entity = nil
	local cameraShaker = require(game.ReplicatedStorage.CameraShaker)
	local camera = workspace.CurrentCamera

	local camShake = cameraShaker.new(Enum.RenderPriority.Camera.Value, function(cf)
		camera.CFrame = camera.CFrame * cf
	end)
	camShake:Start()
	local rawUrl = "https://raw.githubusercontent.com/Ilikerobloxdoors/Nightmare-Rebound/main/nightmare%20rebound.rbxm"

	if G.LoadGithubModel then
		entity = G.LoadGithubModel(rawUrl)

		if entity then
			entity.Parent = workspace
		end
	end

	if not entity then
		return
	end
	local entityPart = entity.PrimaryPart
	if GetLastRoom() ~= nil then 
		entityPart.CFrame = GetLastRoom().RoomEnd.CFrame
	else
		entityPart.CFrame = currentRooms:FindFirstChild(latestRoom.Value).RoomEnd.CFrame
	end
	entityPart.CanCollide = false
	entityPart.Anchored = true
	wait(4)
	local rebmoving = G.LoadGithubAudio("https://raw.githubusercontent.com/Francisco1692qzd/RevivedOldHardcore/main/MovingRebound.mp3")
	local moving = Instance.new("Sound")
	moving.SoundId = rebmoving
	moving.Parent = entityPart
	moving.Volume = 10
	moving:Play()--]]
	local function canSeeTarget(target, size)
		if killed == true then
			return
		end

		local origin = entityPart.Position
		local direction = (target.HumanoidRootPart.Position - origin).unit * size
		local ray = Ray.new(origin, direction)

		local hit, pos = workspace:FindPartOnRay(ray, entityPart)

		if hit then
			if hit:IsDescendantOf(target) then
				killed = true
				return true
			end
		else
			return false
		end
	end
	spawn(function()
		while entityPart ~= nil and entity ~= nil do wait(0.5)
			local v = game.Players.LocalPlayer
			if v.Character ~= nil and v.Character.HumanoidRootPart then
				if canSeeTarget(v.Character, 50) and not v.Character:GetAttribute("Hiding") then
					moving:Stop()
					local ReboundJs = Instance.new("ScreenGui")
					local Static = Instance.new("ImageLabel")
					local Rebound = Instance.new("ImageLabel")
					local JSSIZE = Instance.new("ImageLabel")

					ReboundJs.Name = "ReboundJs"
					ReboundJs.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

					Static.Name = "Static"
					Static.Parent = ReboundJs
					Static.BackgroundTransparency = 1
					Static.Size = UDim2.new(11, 0, 111, 0)
					Static.Image = "rbxassetid://236543215"
					Static.ImageTransparency = 1

					Rebound.Name = "Rebound"
					Rebound.Parent = ReboundJs
					Rebound.BackgroundTransparency = 1
					Rebound.Position = UDim2.new(0.4866, 0, 0.4793, 0)
					Rebound.Size = UDim2.new(0.0267, 0, 0.0387, 0)
					Rebound.Image = "rbxassetid://10914800940"

					JSSIZE.Name = "JSSIZE"
					JSSIZE.Parent = ReboundJs
					JSSIZE.BackgroundTransparency = 1
					JSSIZE.Position = UDim2.new(-0.586, 0, -1.251, 0)
					JSSIZE.Size = UDim2.new(2.128, 0, 3.081, 0)
					JSSIZE.Visible = false
					JSSIZE.Image = "rbxassetid://10914800940"

					coroutine.wrap(function()
						local script = Static
						while true do
							script.Image = "rbxassetid://236543215"
							task.wait(0.002)
							script.Rotation = 0
							task.wait(0.002)
							script.Rotation = 180
							task.wait(0.002)
							script.Image = "rbxassetid://236777652"
							task.wait(0.002)
							script.Rotation = 0
							task.wait(0.002)
							script.Rotation = 180
							task.wait(0.002)
						end
					end)()

					coroutine.wrap(function()
						local Plr = game.Players.LocalPlayer
						local gui = ReboundJs
						local static = gui.Static
						local jspos = gui.JSSIZE

						local rebjumpscare = G.LoadGithubAudio("https://raw.githubusercontent.com/Francisco1692qzd/RevivedOldHardcore/main/JumpscareReb.mp3")
						local jumpscare = Instance.new("Sound")
						jumpscare.SoundId = rebjumpscare
						jumpscare.Parent = workspace
						jumpscare.Volume = 5
						jumpscare:Play() game.Debris:AddItem(jumpscare, 10)

						game.TweenService:Create(static, TweenInfo.new(0.5), {ImageTransparency = 0.8}):Play()
						game.TweenService:Create(gui.Rebound, TweenInfo.new(0.5), {Size = jspos.Size, Position = jspos.Position}):Play()
						task.spawn(function()
							wait(0.3)
							Plr.Character:FindFirstChildWhichIsA("Humanoid"):TakeDamage(100)
							game.ReplicatedStorage.GameStats["Player_" .. Plr.Character.Name].Total.DeathCause.Value = "Rebound"
							game.ReplicatedStorage.GameStats["Player_" .. Plr.Character.Name]["1"].DeathCause.Value = "Rebound"
							firesignal(game.ReplicatedStorage.Bricks.DeathHint.OnClientEvent, {"You died to Rebound...","It may trick you by coming through walls or next rooms...", "Hide when this happens!"})
						end)
						wait(0.5)
						game.TweenService:Create(static, TweenInfo.new(1), {ImageTransparency = 1}):Play()
						game.TweenService:Create(gui.Rebound, TweenInfo.new(0.3), {ImageTransparency = 1}):Play()
						wait(1)
						gui:Destroy()
					end)()
				end
			end

			if entityPart and (entityPart.Position - v.Character.HumanoidRootPart.Position).Magnitude <= 60 then
				camShake:Start()
				camShake:ShakeOnce(17, 6, 0.1, 1)
			end
		end
	end)

	for i = latestRoom.Value, 1, -1 do
		if currentRooms:FindFirstChild(i) then
			local room = currentRooms[i]
			if room and room:FindFirstChild("RoomStart") then
				local abc = room:FindFirstChild("RoomEnd")
				local jerk = game.TweenService:Create(entityPart, TweenInfo.new(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0,false,0), {CFrame = abc.CFrame + Vector3.new(0,0.4,0)})
				jerk:Play()
				jerk.Completed:Wait()
			end
		end
	end

	entityPart.Anchored = false
	entityPart.CanCollide = false
	game.Debris:AddItem(entity, 5)
end
local function SpawnReb()
	local maxRebounds = 3
	local survivedRebounds = 0
	local character = game.Players.LocalPlayer.Character
	local rebarrival = G.LoadGithubAudio("https://raw.githubusercontent.com/Francisco1692qzd/RevivedOldHardcore/main/Warning.mp3")
	local arrival = Instance.new("Sound")
	arrival.SoundId = rebarrival
	arrival.Parent = workspace
	arrival.Volume = 5
	arrival:Play() game.Debris:AddItem(arrival, 10)
	local cameraShaker = require(game.ReplicatedStorage.CameraShaker)
	local camera = workspace.CurrentCamera

	local camShake = cameraShaker.new(Enum.RenderPriority.Camera.Value, function(cf)
		camera.CFrame = camera.CFrame * cf
	end)
	local Warn = Instance.new("ColorCorrectionEffect", game.Lighting)
	Warn.TintColor = Color3.fromRGB(190, 65, 65)
	Warn.Saturation = -0.45
	Warn.Contrast = 0.15
	game.TweenService:Create(Warn, TweenInfo.new(15), {
		TintColor = Color3.fromRGB(255, 255, 255),
		Saturation = 0,
		Contrast = 0
	}):Play()                                                  game.Debris:AddItem(Warn, 15)
	camShake:Start()
	camShake:ShakeOnce(12, 3.5, 0.1, 6, 2, 0.5)
	pcall(Rebound)
	while maxRebounds > 0 do
		game.ReplicatedStorage.GameData.LatestRoom.Changed:Wait()
		task.wait(2)

		local success = pcall(Rebound)

		if success and character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if humanoid and humanoid.Health > 0 then
				survivedRebounds = survivedRebounds + 1
			end
		end

		maxRebounds = maxRebounds - 1
	end

	if survivedRebounds >= 3 then
	GrantNightmareAchievement()
	end
		game.ReplicatedStorage.GameData.LatestRoom.Changed:Wait()
		wait(2)
		pcall(Rebound)
		maxRebounds = maxRebounds - 1
	end
end

spawn(SpawnReb)
