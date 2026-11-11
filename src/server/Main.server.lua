--[[
	Main.server.lua
	Builds the whole obby course at runtime and runs all server-side logic:
	checkpoints, coins, hazards, the shop, and DataStore saving.

	Nothing here depends on parts placed by hand in Studio, so the place
	works even if you start from a completely empty baseplate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local dataStore = DataStoreService:GetDataStore(Config.DataStoreKey)

local session = {} -- [Player] = { Stage = n, Coins = n, Owned = {} }
local checkpoints = {} -- [stage] = BasePart
local movers = {} -- platforms that slide back and forth
local spinners = {} -- parts that rotate on the spot

----------------------------------------------------------------------
-- Remotes
----------------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = remotes

local buyEvent = Instance.new("RemoteEvent")
buyEvent.Name = "Buy"
buyEvent.Parent = remotes

remotes.Parent = ReplicatedStorage

----------------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------------

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

-- Returns the humanoid and the owning Player (either may be nil).
local function humanoidFromHit(hit)
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, nil
	end
	return humanoid, Players:GetPlayerFromCharacter(model)
end

-- Damages whatever touches `part`, with a short per-character cooldown.
local function makeHazard(part, damage)
	local lastHit = {}
	part.Touched:Connect(function(hit)
		local humanoid = humanoidFromHit(hit)
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		local character = humanoid.Parent
		local now = os.clock()
		if lastHit[character] and now - lastHit[character] < 0.5 then
			return
		end
		lastHit[character] = now
		humanoid:TakeDamage(damage)
	end)
end

local function statsFor(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end
	return leaderstats:FindFirstChild("Stage"), leaderstats:FindFirstChild("Coins")
end

local function awardCoins(player, amount)
	local data = session[player]
	if not data then
		return
	end
	data.Coins += amount
	local _, coinsValue = statsFor(player)
	if coinsValue then
		coinsValue.Value = data.Coins
	end
end

local function reachStage(player, stage)
	local data = session[player]
	if not data or stage <= data.Stage then
		return
	end
	data.Stage = math.min(stage, Config.Course.StageCount)
	local stageValue = statsFor(player)
	if stageValue then
		stageValue.Value = data.Stage
	end
	if data.Stage >= Config.Course.StageCount then
		notifyEvent:FireClient(player, "Course complete! You reached the top.")
	else
		notifyEvent:FireClient(player, "Checkpoint " .. data.Stage .. " saved")
	end
end

----------------------------------------------------------------------
-- Course construction
----------------------------------------------------------------------

local function buildCourse()
	local folder = Instance.new("Folder")
	folder.Name = "Course"
	folder.Parent = Workspace

	-- Lobby ------------------------------------------------------------
	newPart({
		Name = "Lobby",
		Size = Vector3.new(64, 2, 64),
		CFrame = CFrame.new(0, 0, 0),
		Color = Config.Palette.Lobby,
		Parent = folder,
	})

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LobbySpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(14, 1, 14)
	spawnLocation.CFrame = CFrame.new(0, 1.5, 0)
	spawnLocation.Color = Config.Palette.Checkpoint
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = folder

	-- Kill plane under everything -------------------------------------
	local lava = newPart({
		Name = "Lava",
		Size = Vector3.new(2400, 4, 800),
		CFrame = CFrame.new(Config.Course.StageCount * Config.Course.StageSpacing / 2, -40, 0),
		Color = Config.Palette.Lava,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	lava.Touched:Connect(function(hit)
		local humanoid = humanoidFromHit(hit)
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end)

	-- Stages -----------------------------------------------------------
	for stage = 1, Config.Course.StageCount do
		local x = stage * Config.Course.StageSpacing
		local y = Config.Course.StartHeight + (stage - 1) * Config.Course.HeightStep
		local size = Config.Course.PlatformSize

		newPart({
			Name = "Stage" .. stage,
			Size = size,
			CFrame = CFrame.new(x, y, 0),
			Color = (stage % 2 == 0) and Config.Palette.PlatformAlt or Config.Palette.Platform,
			Parent = folder,
		})

		-- Checkpoint pad
		local checkpoint = newPart({
			Name = "Checkpoint" .. stage,
			Size = Vector3.new(12, 0.6, 12),
			CFrame = CFrame.new(x, y + size.Y / 2 + 0.3, 0),
			Color = Config.Palette.Checkpoint,
			Material = Enum.Material.Neon,
			Parent = folder,
		})
		checkpoints[stage] = checkpoint
		checkpoint.Touched:Connect(function(hit)
			local _, player = humanoidFromHit(hit)
			if player then
				reachStage(player, stage)
			end
		end)

		-- One obstacle pattern per stage, cycling through four kinds
		local variant = (stage - 1) % 4

		if variant == 0 then
			-- Rotating hazard bar sweeping the platform
			local bar = newPart({
				Name = "Spinner" .. stage,
				Size = Vector3.new(size.X * 0.8, 1, 1.4),
				CFrame = CFrame.new(x, y + 4, 0),
				Color = Config.Palette.Hazard,
				Material = Enum.Material.Neon,
				Parent = folder,
			})
			table.insert(spinners, { part = bar, base = bar.CFrame, speed = 1.6 + stage * 0.05 })
			makeHazard(bar, 100)
		elseif variant == 1 then
			-- Sliding platform in the gap before this stage
			local mover = newPart({
				Name = "Mover" .. stage,
				Size = Vector3.new(12, 1, 12),
				CFrame = CFrame.new(x - Config.Course.StageSpacing / 2, y - 1, 0),
				Color = Config.Palette.PlatformAlt,
				Parent = folder,
			})
			table.insert(movers, {
				part = mover,
				base = mover.CFrame,
				axis = Vector3.new(0, 0, 1),
				amplitude = 14,
				speed = 1.1,
				phase = stage,
			})
		elseif variant == 2 then
			-- Three stepping pillars across the gap
			for i = 1, 3 do
				local px = x - Config.Course.StageSpacing + (Config.Course.StageSpacing * i / 4)
				newPart({
					Name = "Pillar" .. stage .. "_" .. i,
					Size = Vector3.new(8, 1.5, 8),
					CFrame = CFrame.new(px, y - 1 + i * 0.6, 0),
					Color = Config.Palette.Platform,
					Parent = folder,
				})
			end
		else
			-- Hazard blocks to weave around on the platform
			for i = 1, 3 do
				local block = newPart({
					Name = "Hazard" .. stage .. "_" .. i,
					Size = Vector3.new(5, 3, 5),
					CFrame = CFrame.new(x - 10 + (i - 1) * 10, y + size.Y / 2 + 1.5, (i % 2 == 0) and 9 or -9),
					Color = Config.Palette.Hazard,
					Material = Enum.Material.Neon,
					Parent = folder,
				})
				makeHazard(block, 100)
			end
		end

		-- Coins floating above the platform
		for c = 1, 3 do
			local coin = newPart({
				Name = "Coin",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, 3, 3),
				CFrame = CFrame.new(x, y + size.Y / 2 + 3, -8 + (c - 1) * 8) * CFrame.Angles(0, math.rad(90), 0),
				Color = Config.Palette.Coin,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
			table.insert(spinners, { part = coin, base = coin.CFrame, speed = 2.4 })

			local taken = false
			coin.Touched:Connect(function(hit)
				if taken then
					return
				end
				local _, player = humanoidFromHit(hit)
				if not player then
					return
				end
				taken = true
				awardCoins(player, Config.Economy.CoinsPerPickup)
				coin:Destroy()
			end)
		end
	end

	-- Animate movers and spinners -------------------------------------
	RunService.Heartbeat:Connect(function(deltaTime)
		local now = os.clock()
		for _, mover in ipairs(movers) do
			mover.part.CFrame = mover.base + mover.axis * (math.sin(now * mover.speed + mover.phase) * mover.amplitude)
		end
		for _, spinner in ipairs(spinners) do
			spinner.part.CFrame = spinner.base * CFrame.Angles(0, now * spinner.speed, 0)
		end
	end)
end

----------------------------------------------------------------------
-- Upgrades
----------------------------------------------------------------------

local function applyUpgrades(player)
	local data = session[player]
	local character = player.Character
	if not data or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if data.Owned.Speed then
		humanoid.WalkSpeed = Config.Shop.Speed.WalkSpeed
	end

	if data.Owned.Jump then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = Config.Shop.Jump.JumpPower
	end

	if data.Owned.Trail and not character:FindFirstChild("CoinTrail") then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			local top = Instance.new("Attachment")
			top.Name = "TrailTop"
			top.Position = Vector3.new(0, 1.5, 0)
			top.Parent = root

			local bottom = Instance.new("Attachment")
			bottom.Name = "TrailBottom"
			bottom.Position = Vector3.new(0, -1.5, 0)
			bottom.Parent = root

			local trail = Instance.new("Trail")
			trail.Name = "CoinTrail"
			trail.Attachment0 = top
			trail.Attachment1 = bottom
			trail.Lifetime = 0.6
			trail.Color = ColorSequence.new(Config.Palette.Coin)
			trail.Parent = root
		end
	end
end

----------------------------------------------------------------------
-- Players
----------------------------------------------------------------------

local function onPlayerAdded(player)
	local data = { Stage = 1, Coins = 0, Owned = {} }

	local loaded, stored = pcall(function()
		return dataStore:GetAsync("player_" .. player.UserId)
	end)

	if loaded and type(stored) == "table" then
		data.Stage = math.clamp(tonumber(stored.Stage) or 1, 1, Config.Course.StageCount)
		data.Coins = math.max(0, tonumber(stored.Coins) or 0)
		if type(stored.Owned) == "table" then
			data.Owned = stored.Owned
		end
	end

	session[player] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local stageValue = Instance.new("IntValue")
	stageValue.Name = "Stage"
	stageValue.Value = data.Stage
	stageValue.Parent = leaderstats

	local coinValue = Instance.new("IntValue")
	coinValue.Name = "Coins"
	coinValue.Value = data.Coins
	coinValue.Parent = leaderstats

	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		local checkpoint = checkpoints[data.Stage]
		if root and checkpoint then
			task.wait(0.15)
			character:PivotTo(checkpoint.CFrame + Vector3.new(0, 6, 0))
		end
		applyUpgrades(player)
	end)

	-- Delay the welcome so the client HUD is listening by the time it fires
	task.delay(5, function()
		if player.Parent then
			local nextStage = math.min(data.Stage + 1, Config.Course.StageCount)
			notifyEvent:FireClient(player, "Reach checkpoint " .. nextStage .. " to progress")
		end
	end)
end

local function onPlayerRemoving(player)
	local data = session[player]
	if not data then
		return
	end
	session[player] = nil

	local saved, err = pcall(function()
		dataStore:SetAsync("player_" .. player.UserId, data)
	end)
	if not saved then
		warn("[SkyObby] Could not save " .. player.Name .. ": " .. tostring(err))
	end
end

----------------------------------------------------------------------
-- Shop
----------------------------------------------------------------------

buyEvent.OnServerEvent:Connect(function(player, itemName)
	if type(itemName) ~= "string" then
		return
	end

	local item = Config.Shop[itemName]
	local data = session[player]
	if not item or not data then
		return
	end

	if data.Owned[itemName] then
		notifyEvent:FireClient(player, "You already own " .. itemName .. ".")
		return
	end

	if data.Coins < item.Price then
		notifyEvent:FireClient(player, "Need " .. item.Price .. " coins - you have " .. data.Coins .. ".")
		return
	end

	data.Coins -= item.Price
	data.Owned[itemName] = true
	local _, coinValue = statsFor(player)
	if coinValue then
		coinValue.Value = data.Coins
	end

	applyUpgrades(player)
	notifyEvent:FireClient(player, "Purchased " .. itemName .. "!")
end)

----------------------------------------------------------------------
-- Boot
----------------------------------------------------------------------

buildCourse()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for player, data in pairs(session) do
		pcall(function()
			dataStore:SetAsync("player_" .. player.UserId, data)
		end)
	end
	task.wait(1)
end)

print("[SkyObby] Server ready - " .. Config.Course.StageCount .. " stages built.")
