local Array = require("../../Packages/Array")
local BitBuffer = require("../../Packages/BitBuffer")
local BitPacket = require("../../Packages/BitPacket")
local Class = require("../../Packages/Class")
local SettingsConfig = require("../../SettingsConfig")

type function SettingsReturnType(config: type)
	local newt = types.newtable()
	for k, v in config:properties() do
		newt:setproperty(k, v.read:readproperty(types.singleton("Default")))
	end
	return newt
end

local PlayerSettings = {}
PlayerSettings.extends = Class

export type SettingsTable = SettingsReturnType<typeof(SettingsConfig)>

export type SettingConfig<T> = {
	Type: string,
	Id: number,
	Default: T,
	Title: string,
	Category: string,
	Min: number,
	Max: number,
	Step: number,
	Options: { string },
	Index: number,
}

export type PlayerSettings = {
	asTable: (self: Self) -> SettingsTable,
	Serialize: (self: Self) -> BitBuffer.BitBuffer,
} & SettingsTable & Class.Class

type Self = {} & PlayerSettings

function PlayerSettings.new(): PlayerSettings
	local self: Self = Class(PlayerSettings)

	for k, v in SettingsConfig do
		self[k] = v.Default
	end

	return self
end

function PlayerSettings.asTable(self: Self) return self.__table end

do
	local TypePackets = {
		Flag = function(config: SettingConfig<boolean>) return BitPacket.Bool end,
		Slider = function(config: SettingConfig<number>)
			local _, bitCount =
				math.frexp((config.Max - config.Min) / config.Step)
			return BitPacket.Optional(
				BitPacket.new(
					function(bb: BitBuffer.BitBuffer, value: number)
						bb:WriteUint(
							math.round((value - config.Min) / config.Step),
							bitCount
						)
					end,
					function(bb: BitBuffer.BitBuffer)
						return bb:ReadUint(bitCount) * config.Step + config.Min
					end
				)
			)
		end,
		Option = function(config: SettingConfig<number>)
			local _, bitCount = math.frexp(#config.Options)
			return BitPacket.Optional(BitPacket.Uint(bitCount))
		end,
	} :: {
		[string]: <V>(config: SettingConfig<V>) -> BitPacket.BitPacket<V>,
	}

	local Packet = BitPacket.new(function(bb: BitBuffer.BitBuffer, value)
		bb:WriteBool(SettingsConfig.v ~= nil)
		if SettingsConfig.v then bb:WriteUint(#SettingsConfig.v - 1) end

		local mappedConfig: Array.Array<{ Key: string, Value: SettingConfig<any> }> =
			Array()
		for k, v in SettingsConfig do
			mappedConfig:Add({ Key = k, Value = v })
		end
		mappedConfig = mappedConfig:Sorted(
			function(a, b) return a.Value.Id < b.Value.Id end
		)

		for _, v in mappedConfig do
			local val = value[v.Key]
			TypePackets[v.Value.Type](v.Value):Write(
				bb,
				if val ~= v.Value.Default or v.Value.Type == "Flag"
					then val
					else nil
			)
		end
	end, function(bb: BitBuffer.BitBuffer)
		local hasVer = bb:ReadBool()
		local config = SettingsConfig
		if SettingsConfig.v then
			local ver = hasVer and bb:ReadUint() or 0
			config = SettingsConfig.v[ver + 1]
		end

		local t = {}
		local mappedConfig: Array.Array<{ Key: string, Value: SettingConfig<any> }> =
			Array()
		for k, v in config do
			mappedConfig:Add({ Key = k, Value = v })
		end
		mappedConfig = mappedConfig:Sorted(
			function(a, b) return a.Value.Id < b.Value.Id end
		)

		for _, v in mappedConfig do
			local success, val = pcall(
				function() return TypePackets[v.Value.Type](v.Value):Read(bb) end
			)
			t[v.Key] = if success and val ~= nil then val else v.Value.Default
		end
		return t
	end)

	function PlayerSettings.Serialize(self: Self) return Packet:Serialize(self) end

	function PlayerSettings.deserialize(
		bb: BitBuffer.BitBuffer
	): PlayerSettings
		return Class(PlayerSettings, Packet:Deserialize(bb))
	end
end

return table.freeze(PlayerSettings) :: {
	new: typeof(PlayerSettings.new),
	deserialize: typeof(PlayerSettings.deserialize),
}
