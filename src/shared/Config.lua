--[[
	Config.lua
	Shared tuning values. Required by both the server and the client,
	so keep it free of anything that only works on one side.
]]

local Config = {}

Config.Course = {
	StageCount = 10, -- how many checkpoints the obby has
	StageSpacing = 70, -- studs between the centre of each platform
	PlatformSize = Vector3.new(44, 2, 44),
	StartHeight = 6,
	HeightStep = 3, -- each stage sits this much higher than the last
}

Config.Economy = {
	CoinsPerPickup = 5,
}

Config.Shop = {
	Speed = { Price = 50, WalkSpeed = 26 },
	Jump = { Price = 75, JumpPower = 65 },
	Trail = { Price = 40 },
}

Config.DataStoreKey = "SkyObby_v1"

Config.Palette = {
	Lobby = Color3.fromRGB(148, 163, 184),
	Platform = Color3.fromRGB(56, 189, 248),
	PlatformAlt = Color3.fromRGB(129, 140, 248),
	Checkpoint = Color3.fromRGB(34, 197, 94),
	Hazard = Color3.fromRGB(239, 68, 68),
	Coin = Color3.fromRGB(250, 204, 21),
	Lava = Color3.fromRGB(249, 115, 22),
}

return Config
