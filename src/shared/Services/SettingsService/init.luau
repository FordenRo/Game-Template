local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BitBuffer = require("../Packages/BitBuffer")
local Class = require("../Packages/Class")
local PlayerSettings = require("@self/PlayerSettings")
local Replicated = require("../Packages/Replicated")

local SettingsService = {}
SettingsService.extends = Class
SettingsService.implements = { Replicated }

local settings: { [Player]: PlayerSettings.PlayerSettings } = {}

export type SettingsService = {
	--- Settings with default values.
	DefaultSettings: PlayerSettings.PlayerSettings,

	--- **Client-only** LocalPlayer's settings.
	Settings: PlayerSettings.PlayerSettings,

	--- **Server-only** Get player's settings.
	GetPlayerSettings: (
		self: SettingsService,
		player: Player
	) -> PlayerSettings.PlayerSettings,
} & Class.Class

type Self = Replicated.Replicated & SettingsService

function SettingsService.new(): SettingsService
	local self: Self = Class(SettingsService)

	self.DefaultSettings = PlayerSettings.new()

	self:CreateRemotes(script)
	if RunService:IsClient() then initClient(self) end

	return self
end

function initClient(self: Self)
	self.Settings =
		PlayerSettings.deserialize(BitBuffer.fromBase64(self:InvokeServer()))

	self.Settings.Changed:Connect(
		function(key) self:SendServer(key, self.Settings[key]) end
	)
end

function SettingsService.GetPlayerSettings(self: Self, player: Player)
	assert(
		RunService:IsServer(),
		"GetPlayerSettings can only be called on the server."
	)

	local playerSettings = settings[player]
	if not playerSettings then
		local datastore = DataStoreService:GetDataStore("Settings")
		local data = datastore:GetAsync(tostring(player.UserId))
		if data then
			playerSettings =
				PlayerSettings.deserialize(BitBuffer.fromBase64(data))
		else
			playerSettings = PlayerSettings.new()
		end
		settings[player] = playerSettings
	end

	local changedConn = playerSettings.Changed:Connect(
		function(key) self:SendClient(player, key, playerSettings[key]) end
	)

	local conn
	conn = Players.PlayerRemoving:Connect(function(removingPlayer)
		if removingPlayer ~= player then return end

		local datastore = DataStoreService:GetDataStore("Settings")
		if playerSettings:asTable() ~= self.DefaultSettings:asTable() then
			datastore:SetAsync(
				tostring(player.UserId),
				playerSettings:Serialize():toBase64()
			)
		else
			datastore:RemoveAsync(tostring(player.UserId))
		end

		changedConn:Disconnect()
		conn:Disconnect()
	end)

	return playerSettings
end

--#region Replication

function SettingsService.onServerReceived(
	self: Self,
	player: Player,
	key: string,
	value: any
)
	settings[player]:RawSet(key, value)
end

function SettingsService.onClientReceived(
	self: Self,
	key: string,
	value: any
)
	self.Settings:RawSet(key, value)
end

function SettingsService.onServerInvoked(self: Self, player: Player)
	return self:GetPlayerSettings(player):Serialize():toBase64()
end

--#endregion

return SettingsService.new()
