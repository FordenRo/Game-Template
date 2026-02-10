--[[
	SettingsService

	Written by: FordenRo
	Version: 0.1.0
]]

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

export type SettingsService = {
	--- Settings with default values.
	DefaultSettings: PlayerSettings.PlayerSettings,

	--- **Client-Only** LocalPlayer's settings.
	Settings: PlayerSettings.PlayerSettings,

	--- **Server-Only** Get player's settings.
	GetPlayerSettings: (
		self: SettingsService,
		player: Player
	) -> PlayerSettings.PlayerSettings,
} & Class.Class

type Self = {
	settings: { [Player]: PlayerSettings.PlayerSettings },
} & Replicated.Replicated & SettingsService

function SettingsService.new(): SettingsService
	local self: Self = Class(SettingsService)

	self.DefaultSettings = PlayerSettings.new()

	self:CreateRemotes(script)
	if RunService:IsServer() then
		initServer(self)
	else
		initClient(self)
	end

	return self
end

function initServer(self: Self) self.settings = {} end

function initClient(self: Self)
	self.Settings = PlayerSettings.deserialize(
		BitBuffer.fromBuffer(self:InvokeServer(Players.LocalPlayer))
	)

	self.Settings.Changed:Connect(
		function(key) self:SendServer(key, self.Settings[key]) end
	)
end

function SettingsService.onServerReceived(
	self: Self,
	player: Player,
	key: string,
	value: any
)
	self.settings[player]:RawSet(key, value)
end

function SettingsService.onClientReceived(
	self: Self,
	key: string,
	value: any
)
	self.Settings:RawSet(key, value)
end

function SettingsService.onServerInvoked(self: Self, player: Player)
	return self:GetPlayerSettings(player):Serialize():toBuffer()
end

function SettingsService.GetPlayerSettings(self: Self, player: Player)
	assert(
		RunService:IsServer(),
		"GetPlayerSettings can only be called on the server."
	)

	local playerSettings = self.settings[player]
	if not playerSettings then
		local datastore = DataStoreService:GetDataStore("Settings")
		local data = datastore:GetAsync(tostring(player.UserId))
		if data then
			playerSettings =
				PlayerSettings.deserialize(BitBuffer.fromBuffer(data))
		else
			playerSettings = PlayerSettings.new()
		end
		self.settings[player] = playerSettings
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
				playerSettings:Serialize():toBuffer()
			)
		else
			datastore:RemoveAsync(tostring(player.UserId))
		end

		changedConn:Disconnect()
		conn:Disconnect()
	end)

	return playerSettings
end

return SettingsService.new()
