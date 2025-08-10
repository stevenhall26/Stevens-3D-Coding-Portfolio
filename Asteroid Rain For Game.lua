local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local ASTEROID_SPAWN_RATE = 0.3 
local ASTEROID_DAMAGE = 10 
local MAP_SIZE = 500 
local SPAWN_HEIGHT = 300 
local ASTEROID_LIFETIME = 30 
local MIN_ASTEROID_SIZE = 8
local MAX_ASTEROID_SIZE = 20


local MIN_WAIT_TIME = 30
local MAX_WAIT_TIME = 90 
local RAIN_DURATION_MIN = 15
local RAIN_DURATION_MAX = 45


local gameStartTime = tick()
local isRaining = false
local rainConnection = nil
local nextRainTime = nil
local rainEndTime = nil
local playersLoaded = {}


local remoteEvents = Instance.new("Folder")
remoteEvents.Name = "AsteroidEvents"
remoteEvents.Parent = ReplicatedStorage

local rainStartEvent = Instance.new("RemoteEvent")
rainStartEvent.Name = "RainStart"
rainStartEvent.Parent = remoteEvents

local rainEndEvent = Instance.new("RemoteEvent")
rainEndEvent.Name = "RainEnd"
rainEndEvent.Parent = remoteEvents

local rainWarningEvent = Instance.new("RemoteEvent")
rainWarningEvent.Name = "RainWarning"
rainWarningEvent.Parent = remoteEvents


local asteroidFolder = Instance.new("Folder")
asteroidFolder.Name = "AsteroidRain"
asteroidFolder.Parent = workspace


local function createSound(soundId, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = SoundService
	return sound
end

local impactSound = createSound("rbxasset://sounds/impact_water.mp3", 0.3)
local warningSound = createSound("rbxasset://sounds/electronicpingshort.wav", 0.6)


local function calculateNextRainTime()
	local currentTime = tick()
	local timeSinceStart = currentTime - gameStartTime

	
	if timeSinceStart < MIN_WAIT_TIME then
		
		nextRainTime = gameStartTime + math.random(MIN_WAIT_TIME, MAX_WAIT_TIME)
	else
		
		nextRainTime = currentTime + math.random(MIN_WAIT_TIME, MAX_WAIT_TIME)
	end

	print("Next asteroid rain scheduled for: " .. math.floor(nextRainTime - currentTime) .. " seconds from now")
end


local function createAsteroid()
	local asteroid = Instance.new("Part")
	asteroid.Name = "Asteroid"
	asteroid.Material = Enum.Material.Rock
	asteroid.BrickColor = BrickColor.new("Dark stone grey")
	asteroid.Shape = Enum.PartType.Block

	
	local size = math.random(MIN_ASTEROID_SIZE, MAX_ASTEROID_SIZE)
	asteroid.Size = Vector3.new(size, size, size)

	
	local spawnX = math.random(-MAP_SIZE/2, MAP_SIZE/2)
	local spawnZ = math.random(-MAP_SIZE/2, MAP_SIZE/2)
	asteroid.Position = Vector3.new(spawnX, SPAWN_HEIGHT, spawnZ)

	-
	asteroid.Rotation = Vector3.new(
		math.random(0, 360),
		math.random(0, 360),
		math.random(0, 360)
	)

	asteroid.Parent = asteroidFolder

	
	addFireEffects(asteroid)

	
	addAsteroidPhysics(asteroid)

	
	addDamageDetection(asteroid)

	return asteroid
end


local function addFireEffects(asteroid)
	
	local fire = Instance.new("Fire")
	fire.Size = asteroid.Size.X / 2
	fire.Heat = 15
	fire.Color = Color3.new(1, 0.3, 0)
	fire.SecondaryColor = Color3.new(1, 1, 0)
	fire.Parent = asteroid

	
	local smoke = Instance.new("Smoke")
	smoke.Size = asteroid.Size.X / 3
	smoke.Opacity = 0.8
	smoke.RiseVelocity = 10
	smoke.Color = Color3.new(0.2, 0.2, 0.2)
	smoke.Parent = asteroid

	
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 2
	pointLight.Range = asteroid.Size.X * 2
	pointLight.Color = Color3.new(1, 0.5, 0)
	pointLight.Parent = asteroid

	
	local attachment = Instance.new("Attachment")
	attachment.Parent = asteroid

	local sparks = Instance.new("ParticleEmitter")
	sparks.Parent = attachment
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Lifetime = NumberRange.new(0.5, 1.5)
	sparks.Rate = 50
	sparks.SpreadAngle = Vector2.new(45, 45)
	sparks.Speed = NumberRange.new(5, 15)
	sparks.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 0.5, 0)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 0, 0))
	}
	sparks.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0)
	}
end


local function addAsteroidPhysics(asteroid)
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)

	
	bodyVelocity.Velocity = Vector3.new(
		math.random(-20, 20), 
		-80, 
		math.random(-20, 20)  
	)
	bodyVelocity.Parent = asteroid

	
	local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
	bodyAngularVelocity.MaxTorque = Vector3.new(5000, 5000, 5000)
	bodyAngularVelocity.AngularVelocity = Vector3.new(
		math.random(-10, 10),
		math.random(-10, 10),
		math.random(-10, 10)
	)
	bodyAngularVelocity.Parent = asteroid

	
	local function onTouched(hit)
		if hit.Name == "Baseplate" or hit.Parent == workspace.Terrain or hit.Name == "Ground" then
			
			createImpactEffect(asteroid.Position)

			
			if bodyVelocity then bodyVelocity:Destroy() end
			if bodyAngularVelocity then bodyAngularVelocity:Destroy() end

			
			local impactSoundClone = impactSound:Clone()
			impactSoundClone.Parent = asteroid
			impactSoundClone:Play()

			
			Debris:AddItem(impactSoundClone, 3)

			
			Debris:AddItem(asteroid, ASTEROID_LIFETIME)
		end
	end

	asteroid.Touched:Connect(onTouched)
end


local function createImpactEffect(position)
	
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = 30
	explosion.BlastPressure = 100000
	explosion.Parent = workspace

	
	local crater = Instance.new("Part")
	crater.Name = "Crater"
	crater.Size = Vector3.new(10, 1, 10)
	crater.Material = Enum.Material.Concrete
	crater.BrickColor = BrickColor.new("Dark stone grey")
	crater.Position = position - Vector3.new(0, 2, 0)
	crater.Anchored = true
	crater.Shape = Enum.PartType.Cylinder
	crater.Parent = asteroidFolder

	
	Debris:AddItem(crater, ASTEROID_LIFETIME)
end


local function addDamageDetection(asteroid)
	local damageDealt = {}

	local function onTouched(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if humanoid then
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and not damageDealt[player] then
				damageDealt[player] = true

				
				local damage = humanoid.MaxHealth * (ASTEROID_DAMAGE / 100)

				
				humanoid.Health = math.max(0, humanoid.Health - damage)

				
				createDamageIndicator(hit.Parent, damage)

				print(player.Name .. " hit by asteroid! Took " .. damage .. " damage.")
			end
		end
	end

	asteroid.Touched:Connect(onTouched)
end


local function createDamageIndicator(character, damage)
	local head = character:FindFirstChild("Head")
	if not head then return end

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(2, 0, 1, 0)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.Parent = head

	local damageLabel = Instance.new("TextLabel")
	damageLabel.Size = UDim2.new(1, 0, 1, 0)
	damageLabel.BackgroundTransparency = 1
	damageLabel.Text = "-" .. math.floor(damage)
	damageLabel.TextColor3 = Color3.new(1, 0, 0)
	damageLabel.TextScaled = true
	damageLabel.Font = Enum.Font.SourceSansBold
	damageLabel.TextStrokeTransparency = 0
	damageLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	damageLabel.Parent = billboardGui

	
	local tween = TweenService:Create(
		billboardGui,
		TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{StudsOffset = Vector3.new(0, 8, 0)}
	)
	tween:Play()

	local fadeTween = TweenService:Create(
		damageLabel,
		TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{TextTransparency = 1}
	)
	fadeTween:Play()

	
	Debris:AddItem(billboardGui, 2)
end


local function startAsteroidRain()
	if isRaining then return end

	isRaining = true
	local rainDuration = math.random(RAIN_DURATION_MIN, RAIN_DURATION_MAX)
	rainEndTime = tick() + rainDuration

	print("??? ASTEROID RAIN STARTED! Duration: " .. rainDuration .. " seconds")

	
	for _, player in pairs(Players:GetPlayers()) do
		rainStartEvent:FireClient(player, rainDuration)
	end

	
	warningSound:Play()

	
	local lastSpawnTime = 0
	rainConnection = RunService.Heartbeat:Connect(function()
		local currentTime = tick()

		
		if currentTime >= rainEndTime then
			stopAsteroidRain()
			return
		end

		
		if currentTime - lastSpawnTime >= ASTEROID_SPAWN_RATE then
			createAsteroid()
			lastSpawnTime = currentTime
		end
	end)
end


local function stopAsteroidRain()
	if not isRaining then return end

	isRaining = false

	if rainConnection then
		rainConnection:Disconnect()
		rainConnection = nil
	end

	print("?? Asteroid rain ended!")

	
	for _, player in pairs(Players:GetPlayers()) do
		rainEndEvent:FireClient(player)
	end

	
	calculateNextRainTime()
end


local function sendRainWarning()
	print("?? Asteroid rain incoming in 10 seconds!")

	for _, player in pairs(Players:GetPlayers()) do
		rainWarningEvent:FireClient(player, 10)
	end

	
	warningSound:Play()

	
	wait(10)
	startAsteroidRain()
end


local function gameLoop()
	local currentTime = tick()

	
	if nextRainTime and currentTime >= nextRainTime - 10 and not isRaining then
		
		nextRainTime = nil 
		spawn(sendRainWarning)
	end
end


Players.PlayerAdded:Connect(function(player)
	playersLoaded[player] = tick()

	
	player.Chatted:Connect(function(message)
		if player.Name == "Yy0n" then 
			if message:lower() == "/startrain" then
				startAsteroidRain()
			elseif message:lower() == "/stoprain" then
				stopAsteroidRain()
			elseif message:lower() == "/nextrain" then
				if nextRainTime then
					local timeUntilRain = nextRainTime - tick()
					print("Next rain in: " .. math.floor(timeUntilRain) .. " seconds")
				else
					print("Rain is currently active or no rain scheduled")
				end
			elseif message:lower() == "/schedulerain" then
				calculateNextRainTime()
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playersLoaded[player] = nil
end)


calculateNextRainTime()
RunService.Heartbeat:Connect(gameLoop)

print("??? Random Asteroid Rain System Loaded!")
print("? First rain will occur between 30-90 seconds after game start")
print("?? Rain duration: " .. RAIN_DURATION_MIN .. "-" .. RAIN_DURATION_MAX .. " seconds")
print("?? Each asteroid deals " .. ASTEROID_DAMAGE .. "% damage")
