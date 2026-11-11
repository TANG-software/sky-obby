--[[
	Main.client.lua
	Builds the HUD: stage/coin counters, a shop panel, and toast messages.
	Everything is created in code, so there is nothing to lay out by hand.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyEvent = remotes:WaitForChild("Notify")
local buyEvent = remotes:WaitForChild("Buy")

local THEME = {
	Panel = Color3.fromRGB(30, 41, 59),
	PanelLight = Color3.fromRGB(51, 65, 85),
	Accent = Color3.fromRGB(56, 189, 248),
	Text = Color3.fromRGB(241, 245, 249),
	Muted = Color3.fromRGB(148, 163, 184),
	Coin = Color3.fromRGB(250, 204, 21),
	Green = Color3.fromRGB(34, 197, 94),
}

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function corner(parent, radius)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius or 10)
	uiCorner.Parent = parent
	return uiCorner
end

local function stroke(parent, color, thickness)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = color or THEME.PanelLight
	uiStroke.Thickness = thickness or 1.5
	uiStroke.Parent = parent
	return uiStroke
end

local function label(props)
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = props.font or FONT
	textLabel.TextColor3 = props.color or THEME.Text
	textLabel.TextSize = props.size or 16
	textLabel.TextXAlignment = props.xAlign or Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.Text = props.text or ""
	for key, value in pairs(props) do
		if key ~= "font" and key ~= "color" and key ~= "size" and key ~= "xAlign" and key ~= "text" then
			textLabel[key] = value
		end
	end
	return textLabel
end

local function button(props)
	local textButton = Instance.new("TextButton")
	textButton.AutoButtonColor = true
	textButton.BackgroundColor3 = props.color or THEME.PanelLight
	textButton.BorderSizePixel = 0
	textButton.Font = FONT_BOLD
	textButton.TextColor3 = THEME.Text
	textButton.TextSize = props.size or 15
	textButton.Text = props.text or ""
	textButton.Parent = props.parent
	textButton.AnchorPoint = props.anchorPoint or Vector2.new(0, 0)
	textButton.Position = props.position or UDim2.fromOffset(0, 0)
	textButton.Size = props.size2 or UDim2.fromOffset(120, 40)
	corner(textButton, props.radius or 8)
	return textButton
end

----------------------------------------------------------------------
-- Root GUI
----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "ObbyHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

----------------------------------------------------------------------
-- Stats card
----------------------------------------------------------------------

local statsCard = Instance.new("Frame")
statsCard.Name = "StatsCard"
statsCard.Position = UDim2.fromOffset(20, 20)
statsCard.Size = UDim2.fromOffset(220, 96)
statsCard.BackgroundColor3 = THEME.Panel
statsCard.BackgroundTransparency = 0.1
statsCard.BorderSizePixel = 0
statsCard.Parent = gui
corner(statsCard, 12)
stroke(statsCard, THEME.PanelLight, 2)

label({
	Text = "STAGE",
	Size = UDim2.fromOffset(80, 14),
	Position = UDim2.fromOffset(16, 12),
	color = THEME.Muted,
	size = 12,
	font = FONT_BOLD,
	Parent = statsCard,
})

local stageValueLabel = label({
	Text = "1",
	Size = UDim2.fromOffset(80, 34),
	Position = UDim2.fromOffset(16, 24),
	color = THEME.Accent,
	size = 30,
	font = FONT_BOLD,
	Parent = statsCard,
})

label({
	Text = "/ " .. Config.Course.StageCount,
	Size = UDim2.fromOffset(80, 34),
	Position = UDim2.fromOffset(58, 34),
	color = THEME.Muted,
	size = 14,
	font = FONT_BOLD,
	Parent = statsCard,
})

local coinDot = Instance.new("Frame")
coinDot.Size = UDim2.fromOffset(14, 14)
coinDot.Position = UDim2.fromOffset(16, 68)
coinDot.BackgroundColor3 = THEME.Coin
coinDot.BorderSizePixel = 0
coinDot.Parent = statsCard
corner(coinDot, 7)

local coinLabel = label({
	Text = "0",
	Size = UDim2.fromOffset(120, 20),
	Position = UDim2.fromOffset(38, 65),
	color = THEME.Coin,
	size = 16,
	font = FONT_BOLD,
	Parent = statsCard,
})

-- Keep the counters in sync with the server's leaderstats
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 20)
	if not leaderstats then
		return
	end
	local stageStat = leaderstats:WaitForChild("Stage")
	local coinStat = leaderstats:WaitForChild("Coins")

	local function refreshStage()
		stageValueLabel.Text = tostring(stageStat.Value)
	end
	local function refreshCoins()
		coinLabel.Text = tostring(coinStat.Value)
	end

	refreshStage()
	refreshCoins()
	stageStat.Changed:Connect(refreshStage)
	coinStat.Changed:Connect(refreshCoins)
end)

----------------------------------------------------------------------
-- Toasts
----------------------------------------------------------------------

local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.AnchorPoint = Vector2.new(0.5, 0)
toastHolder.Position = UDim2.new(0.5, 0, 0, 24)
toastHolder.Size = UDim2.fromOffset(420, 60)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = gui

local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 8)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastHolder

local toastCount = 0

local function toast(message)
	toastCount += 1

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = THEME.Panel
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(400, 44)
	frame.LayoutOrder = toastCount
	frame.Parent = toastHolder
	corner(frame, 10)
	stroke(frame, THEME.Accent, 1.5)

	local text = label({
		Text = message,
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		size = 15,
		xAlign = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	text.TextWrapped = true

	task.delay(3, function()
		local fade = TweenService:Create(frame, TweenInfo.new(0.4), {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(400, 0),
		})
		TweenService:Create(text, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		fade:Play()
		fade.Completed:Wait()
		frame:Destroy()
	end)
end

notifyEvent.OnClientEvent:Connect(toast)

----------------------------------------------------------------------
-- Shop
----------------------------------------------------------------------

local shopPanel = Instance.new("Frame")
shopPanel.Name = "Shop"
shopPanel.AnchorPoint = Vector2.new(0.5, 0.5)
shopPanel.Position = UDim2.fromScale(0.5, 0.5)
shopPanel.Size = UDim2.fromOffset(360, 320)
shopPanel.BackgroundColor3 = THEME.Panel
shopPanel.BackgroundTransparency = 0.05
shopPanel.BorderSizePixel = 0
shopPanel.Visible = false
shopPanel.Parent = gui
corner(shopPanel, 14)
stroke(shopPanel, THEME.Accent, 2)

label({
	Text = "UPGRADE SHOP",
	Size = UDim2.new(1, -32, 0, 24),
	Position = UDim2.fromOffset(16, 16),
	color = THEME.Text,
	size = 18,
	font = FONT_BOLD,
	Parent = shopPanel,
})

label({
	Text = "Spend coins you collect on the course.",
	Size = UDim2.new(1, -32, 0, 18),
	Position = UDim2.fromOffset(16, 40),
	color = THEME.Muted,
	size = 13,
	Parent = shopPanel,
})

local shopList = Instance.new("Frame")
shopList.Position = UDim2.fromOffset(16, 70)
shopList.Size = UDim2.new(1, -32, 0, 200)
shopList.BackgroundTransparency = 1
shopList.Parent = shopPanel

local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 10)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shopList

local DESCRIPTIONS = {
	Speed = "+6 walk speed",
	Jump = "Jump higher",
	Trail = "Golden coin trail",
}

local order = { "Speed", "Jump", "Trail" }

for index, itemName in ipairs(order) do
	local item = Config.Shop[itemName]

	local row = Instance.new("Frame")
	row.BackgroundColor3 = THEME.PanelLight
	row.BackgroundTransparency = 0.3
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, 60)
	row.LayoutOrder = index
	row.Parent = shopList
	corner(row, 10)

	label({
		Text = itemName,
		Size = UDim2.fromOffset(150, 20),
		Position = UDim2.fromOffset(14, 10),
		size = 15,
		font = FONT_BOLD,
		Parent = row,
	})

	label({
		Text = DESCRIPTIONS[itemName] or "",
		Size = UDim2.fromOffset(150, 16),
		Position = UDim2.fromOffset(14, 30),
		color = THEME.Muted,
		size = 12,
		Parent = row,
	})

	label({
		Text = tostring(item.Price) .. " coins",
		Size = UDim2.fromOffset(104, 20),
		Position = UDim2.fromOffset(230, 10),
		color = THEME.Coin,
		size = 13,
		font = FONT_BOLD,
		xAlign = Enum.TextXAlignment.Right,
		Parent = row,
	})

	button({
		Text = "BUY",
		Parent = row,
		position = UDim2.fromOffset(230, 32),
		size2 = UDim2.fromOffset(104, 22),
		size = 13,
		color = THEME.Accent,
		radius = 6,
	}).MouseButton1Click:Connect(function()
		buyEvent:FireServer(itemName)
	end)
end

local closeButton = button({
	Text = "CLOSE",
	Parent = shopPanel,
	anchorPoint = Vector2.new(0.5, 0),
	position = UDim2.new(0.5, 0, 0, 278),
	size2 = UDim2.fromOffset(140, 30),
	size = 14,
	color = THEME.PanelLight,
})

closeButton.MouseButton1Click:Connect(function()
	shopPanel.Visible = false
end)

local shopToggle = button({
	Text = "SHOP",
	Parent = gui,
	anchorPoint = Vector2.new(1, 1),
	position = UDim2.new(1, -24, 1, -24),
	size2 = UDim2.fromOffset(130, 46),
	size = 16,
	color = THEME.Accent,
	radius = 10,
})

shopToggle.MouseButton1Click:Connect(function()
	shopPanel.Visible = not shopPanel.Visible
end)

----------------------------------------------------------------------
-- Controls hint
----------------------------------------------------------------------

label({
	Text = "WASD to move  •  Space to jump  •  collect coins, dodge red",
	Size = UDim2.new(1, -48, 0, 18),
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 24, 1, -24),
	color = THEME.Muted,
	size = 13,
	xAlign = Enum.TextXAlignment.Left,
	Parent = gui,
})
