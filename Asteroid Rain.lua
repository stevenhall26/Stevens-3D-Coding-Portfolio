-- Random Asteroid Rain System
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local ASTEROID_SPAWN_RATE = 0.3 -- Seconds between asteroid spawns during rain
local ASTEROID_DAMAGE = 10 -- Percentage of health to remove
local MAP_SIZE = 500 -- Size of the area where asteroids can spawn
local SPAWN_HEIGHT = 300 -- Height above ground to spawn asteroids
local ASTEROID_LIFETIME = 30 -- How long asteroids stay on ground before cleanup
local MIN_ASTEROID_SIZE = 8
local MAX_ASTEROID_SIZE = 20

-- Rain timing configuration
local MIN_WAIT_TIME = 30 -- Minimum 30 seconds after player loads
local MAX_WAIT_TIME = 90 -- Maximum 90 seconds after player loads (30-90 second range)
local RAIN_DURATION_MIN = 15 -- Minimum rain duration in seconds
local RAIN_DURATION_MAX = 45 -- Maximum rain duration in seconds

-- Game state
local gameStartTime = tick()
local isRaining = false
local rainConnection = nil
local nextRainTime = nil
local rainEndTime = nil
local playersLoaded = {}

-- Create RemoteEvents for client communication
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

-- Create asteroid container
local asteroidFolder = Instance.new("Folder")
asteroidFolder.Name = "AsteroidRain"
asteroidFolder.Parent = workspace

-- Sound effects
local function createSound(soundId, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = SoundService
	return sound
end

local impactSound = createSound("rbxasset://sounds/impact_water.mp3", 0.3)
local warningSound = createSound("rbxasset://sounds/electronicpingshort.wav", 0.6)

-- Calculate next rain time
local function calculateNextRainTime()
	local currentTime = tick()
	local timeSinceStart = currentTime - gameStartTime

	-- If we haven't reached the minimum wait time yet
	if timeSinceStart < MIN_WAIT_TIME then
		-- Schedule rain between MIN_WAIT_TIME and MAX_WAIT_TIME
		nextRainTime = gameStartTime + math.random(MIN_WAIT_TIME, MAX_WAIT_TIME)
	else
		-- Schedule next rain randomly in the future (30-90 seconds from now)
		nextRainTime = currentTime + math.random(MIN_WAIT_TIME, MAX_WAIT_TIME)
	end

	print("Next asteroid rain scheduled for: " .. math.floor(nextRainTime - currentTime) .. " seconds from now")
end

-- Create a single asteroid
local function createAsteroid()
	local asteroid = Instance.new("Part")
	asteroid.Name = "Asteroid"
	asteroid.Material = Enum.Material.Rock
	asteroid.BrickColor = BrickColor.new("Dark stone grey")
	asteroid.Shape = Enum.PartType.Block

	-- Random size
	local size = math.random(MIN_ASTEROID_SIZE, MAX_ASTEROID_SIZE)
	asteroid.Size = Vector3.new(size, size, size)

	-- Random spawn position
	local spawnX = math.random(-MAP_SIZE/2, MAP_SIZE/2)
	local spawnZ = math.random(-MAP_SIZE/2, MAP_SIZE/2)
	asteroid.Position = Vector3.new(spawnX, SPAWN_HEIGHT, spawnZ)

	-- Add some rotation for realism
	asteroid.Rotation = Vector3.new(
		math.random(0, 360),
		math.random(0, 360),
		math.random(0, 360)
	)

	asteroid.Parent = asteroidFolder

	-- Add fire effects
	addFireEffects(asteroid)

	-- Add physics
	addAsteroidPhysics(asteroid)

	-- Add damage detection
	addDamageDetection(asteroid)

	return asteroid
end

-- Add fire and particle effects
local function addFireEffects(asteroid)
	-- Fire effect
	local fire = Instance.new("Fire")
	fire.Size = asteroid.Size.X / 2
	fire.Heat = 15
	fire.Color = Color3.new(1, 0.3, 0)
	fire.SecondaryColor = Color3.new(1, 1, 0)
	fire.Parent = asteroid

	-- Smoke effect
	local smoke = Instance.new("Smoke")
	smoke.Size = asteroid.Size.X / 3
	smoke.Opacity = 0.8
	smoke.RiseVelocity = 10
	smoke.Color = Color3.new(0.2, 0.2, 0.2)
	smoke.Parent = asteroid

	-- Glowing effect
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 2
	pointLight.Range = asteroid.Size.X * 2
	pointLight.Color = Color3.new(1, 0.5, 0)
	pointLight.Parent = asteroid

	-- Particle emitter for sparks
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

-- Add physics to make asteroid fall
local function addAsteroidPhysics(asteroid)
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)

	-- Falling velocity with some random horizontal movement
	bodyVelocity.Velocity = Vector3.new(
		math.random(-20, 20), -- Random X movement
		-80, -- Fast downward movement
		math.random(-20, 20)  -- Random Z movement
	)
	bodyVelocity.Parent = asteroid

	-- Add spinning
	local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
	bodyAngularVelocity.MaxTorque = Vector3.new(5000, 5000, 5000)
	bodyAngularVelocity.AngularVelocity = Vector3.new(
		math.random(-10, 10),
		math.random(-10, 10),
		math.random(-10, 10)
	)
	bodyAngularVelocity.Parent = asteroid

	-- Detect ground impact
	local function onTouched(hit)
		if hit.Name == "Baseplate" or hit.Parent == workspace.Terrain or hit.Name == "Ground" then
			-- Create impact effect
			createImpactEffect(asteroid.Position)

			-- Remove physics but keep asteroid on ground
			if bodyVelocity then bodyVelocity:Destroy() end
			if bodyAngularVelocity then bodyAngularVelocity:Destroy() end

			-- Play impact sound
			local impactSoundClone = impactSound:Clone()
			impactSoundClone.Parent = asteroid
			impactSoundClone:Play()

			-- Clean up sound after playing
			Debris:AddItem(impactSoundClone, 3)

			-- Schedule asteroid cleanup
			Debris:AddItem(asteroid, ASTEROID_LIFETIME)
		end
	end

	asteroid.Touched:Connect(onTouched)
end

-- Create impact explosion effect
local function createImpactEffect(position)
	-- Create explosion
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = 30
	explosion.BlastPressure = 100000
	explosion.Parent = workspace

	-- Create crater effect
	local crater = Instance.new("Part")
	crater.Name = "Crater"
	crater.Size = Vector3.new(10, 1, 10)
	crater.Material = Enum.Material.Concrete
	crater.BrickColor = BrickColor.new("Dark stone grey")
	crater.Position = position - Vector3.new(0, 2, 0)
	crater.Anchored = true
	crater.Shape = Enum.PartType.Cylinder
	crater.Parent = asteroidFolder

	-- Remove crater after some time
	Debris:AddItem(crater, ASTEROID_LIFETIME)
end

-- Add damage detection for players
local function addDamageDetection(asteroid)
	local damageDealt = {}

	local function onTouched(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if humanoid then
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and not damageDealt[player] then
				damageDealt[player] = true

				-- Calculate damage (10% of max health)
				local damage = humanoid.MaxHealth * (ASTEROID_DAMAGE / 100)

				-- Apply damage
				humanoid.Health = math.max(0, humanoid.Health - damage)

				-- Create damage indicator
				createDamageIndicator(hit.Parent, damage)

				print(player.Name .. " hit by asteroid! Took " .. damage .. " damage.")
			end
		end
	end

	asteroid.Touched:Connect(onTouched)
end

-- Create floating damage number
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

	-- Animate damage number
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

	-- Clean up
	Debris:AddItem(billboardGui, 2)
end

-- Start asteroid rain
local function startAsteroidRain()
	if isRaining then return end

	isRaining = true
	local rainDuration = math.random(RAIN_DURATION_MIN, RAIN_DURATION_MAX)
	rainEndTime = tick() + rainDuration

	print("??? ASTEROID RAIN STARTED! Duration: " .. rainDuration .. " seconds")

	-- Notify all players
	for _, player in pairs(Players:GetPlayers()) do
		rainStartEvent:FireClient(player, rainDuration)
	end

	-- Play warning sound
	warningSound:Play()

	-- Start spawning asteroids
	local lastSpawnTime = 0
	rainConnection = RunService.Heartbeat:Connect(function()
		local currentTime = tick()

		-- Check if rain should end
		if currentTime >= rainEndTime then
			stopAsteroidRain()
			return
		end

		-- Spawn asteroids
		if currentTime - lastSpawnTime >= ASTEROID_SPAWN_RATE then
			createAsteroid()
			lastSpawnTime = currentTime
		end
	end)
end

-- Stop asteroid rain
local function stopAsteroidRain()
	if not isRaining then return end

	isRaining = false

	if rainConnection then
		rainConnection:Disconnect()
		rainConnection = nil
	end

	print("?? Asteroid rain ended!")

	-- Notify all players
	for _, player in pairs(Players:GetPlayers()) do
		rainEndEvent:FireClient(player)
	end

	-- Schedule next rain
	calculateNextRainTime()
end

-- Send warning before rain starts
local function sendRainWarning()
	print("?? Asteroid rain incoming in 10 seconds!")

	for _, player in pairs(Players:GetPlayers()) do
		rainWarningEvent:FireClient(player, 10)
	end

	-- Play warning sound
	warningSound:Play()

	-- Start rain after warning
	wait(10)
	startAsteroidRain()
end

-- Main game loop
local function gameLoop()
	local currentTime = tick()

	-- Check if it's time for the next rain
	if nextRainTime and currentTime >= nextRainTime - 10 and not isRaining then
		-- Send warning 10 seconds before rain
		nextRainTime = nil -- Prevent multiple warnings
		spawn(sendRainWarning)
	end
end

-- Player management
Players.PlayerAdded:Connect(function(player)
	playersLoaded[player] = tick()

	-- Admin commands
	player.Chatted:Connect(function(message)
		if player.Name == "Yy0n" then -- Replace with your username
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

-- Initialize the system
calculateNextRainTime()
RunService.Heartbeat:Connect(gameLoop)

print("??? Random Asteroid Rain System Loaded!")
print("? First rain will occur between 30-90 seconds after game start")
print("?? Rain duration: " .. RAIN_DURATION_MIN .. "-" .. RAIN_DURATION_MAX .. " seconds")
print("?? Each asteroid deals " .. ASTEROID_DAMAGE .. "% damage")
