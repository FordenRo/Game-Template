local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Array = require("../Packages/Array")
local BitBuffer = require("../Packages/BitBuffer")
local BitPacket = require("../Packages/BitPacket")
local Class = require("../Packages/Class")
local InputsConfig = require("../InputsConfig")
local Replicated = require("../Packages/Replicated")

local InputService = {}
InputService.extends = Class
InputService.implements = { Replicated }

local Packet

--#region Types

type function InputsReturnType(
	config: type,
	context: type,
	action: type,
	binding: type
)
	local newt = types.newtable()
	for ck, cv in config:properties() do
		local cont = types.newtable()
		for ak, av in
			cv.read:readproperty(types.singleton("Actions")):properties()
		do
			cont:setreadproperty(ak, action)
		end
		newt:setreadproperty(ck, types.intersectionof(cont, context))
	end
	return newt
end

export type InputsTable = InputsReturnType<
	typeof(InputsConfig),
	InputContext,
	InputAction,
	InputBinding
>

type BindingConfig = {
	KeyCode: string,
	UIButton: GuiObject,
}

type ActionConfig = {
	Type: Enum.InputActionType,
	Id: number,
	Title: string,
	Bindings: { BindingConfig },
}

type InputConfig = {
	Id: number,
	Title: string,
	Actions: { [string]: ActionConfig },
}

export type InputService = {
	GetStringForAction: (self: InputService, action: InputAction) -> string,
} & InputsTable & Class.Class

type Self = Replicated.Replicated & InputService

--#endregion

function InputService.new(): InputService
	local self: Self = Class(InputService)

	self:CreateRemotes(script)
	if RunService:IsClient() then initClient(self) end

	return self
end

local function getInputs(self: Self)
	local data = self:InvokeServer()
	if data then
		return Packet:Deserialize(BitBuffer.fromBase64(data))
	else
		return {}
	end
end

function initClient(self: Self)
	local inputs = getInputs(self)
	for ck, cv in InputsConfig :: { [string]: InputConfig } do
		local context = Instance.new("InputContext")
		context.Name = ck
		context.Parent = script
		self[ck] = context

		for ak, av in cv.Actions do
			local action = Instance.new("InputAction")
			action.Name = ak
			action.Type = av.Type
			action.Parent = context

			for bk, bv in av.Bindings do
				local binding = Instance.new("InputBinding")
				binding.Name = bk
				binding.Parent = action

				local bind = ((inputs[ck] or {})[ak] or {})[bk]
				for k, v in bv do
					binding[k] = bind or v
				end
			end
		end
	end

	Players.PlayerRemoving:Connect(function(leavingPlayer)
		if Players.LocalPlayer ~= leavingPlayer then return end

		self:SendServer(Packet:Serialize(self):toBase64())
	end)
end

do -- GetStringForAction method
	local ACTION_TYPE_MAP = {
		[Enum.InputActionType.Bool] = { "KeyCode" },
		[Enum.InputActionType.Direction1D] = { "Up", "Down" },
		[Enum.InputActionType.Direction2D] = { "Up", "Left", "Down", "Right" },
		[Enum.InputActionType.Direction3D] = {
			"Forward",
			"Backward",
			"Up",
			"Left",
			"Down",
			"Right",
		},
	}
	function InputService.GetStringForAction(self: Self, action: InputAction)
		local binds = {}
		for _, binding in action:GetChildren() do
			if not binding:IsA("InputBinding") then continue end

			local keyCodes = {}
			for _, k in ACTION_TYPE_MAP[action.Type] do
				table.insert(
					keyCodes,
					UserInputService:GetStringForKeyCode(binding[k])
				)
			end
			table.insert(binds, table.concat(keyCodes, "/"))
		end
		return table.concat(binds, ", ")
	end
end

--#region Replication

function InputService.onServerReceived(self: Self, player: Player, b: buffer)
	local datastore = DataStoreService:GetDataStore("Inputs")
	datastore:SetAsync(tostring(player.UserId), b)
end

function InputService.onServerInvoked(self: Self, player: Player)
	local datastore = DataStoreService:GetDataStore("Inputs")
end

--#endregion

do -- Packet
	local OptionalKeyCodePacket =
		BitPacket.Optional(BitPacket.EnumItem(Enum.KeyCode))
	local BindingPacket = BitPacket.Packet({
		KeyCode = OptionalKeyCodePacket,
		Up = OptionalKeyCodePacket,
		Down = OptionalKeyCodePacket,
		Left = OptionalKeyCodePacket,
		Right = OptionalKeyCodePacket,
		Forward = OptionalKeyCodePacket,
		Backward = OptionalKeyCodePacket,
	})

	local function ActionPacket(action: ActionConfig)
		return BitPacket.Array(BindingPacket, 5)
	end

	local function ContextPacket(context: InputConfig)
		local actions: Array.Array<{ Key: string, Value: ActionConfig }> =
			Array()
		for k, v in context.Actions do
			actions:Add({ Key = k, Value = v })
		end
		actions = actions:Sorted(
			function(a, b) return a.Value.Id < b.Value.Id end
		)

		return BitPacket.new(
			function(bb: BitBuffer.BitBuffer, value: InputContext)
				for _, v in actions do
					bb:WriteBool(true)
					ActionPacket(v.Value):Write(bb, value[v.Key])
				end
				bb:WriteBool(false)
			end,
			function(bb: BitBuffer.BitBuffer)
				local t = {}
				for _, v in actions do
					if not bb:ReadBool() then break end
					t[v.Key] = ActionPacket(v.Value):Read(bb)
				end
				return t
			end
		)
	end

	Packet = BitPacket.new(
		function(bb: BitBuffer.BitBuffer, value: InputService)
			local mappedConfig: Array.Array<{ Key: string, Value: InputConfig }> =
				Array()
			for k, v in InputsConfig do
				mappedConfig:Add({ Key = k, Value = v })
			end
			mappedConfig = mappedConfig:Sorted(
				function(a, bb) return a.Value.Id < bb.Value.Id end
			)

			for _, v in mappedConfig do
				ContextPacket(v.Value):Write(bb, value[v.Key])
			end
		end,
		function(bb: BitBuffer.BitBuffer)
			local t = {}
			local mappedConfig: Array.Array<{ Key: string, Value: InputConfig }> =
				Array()
			for k, v in InputsConfig do
				mappedConfig:Add({ Key = k, Value = v })
			end
			mappedConfig = mappedConfig:Sorted(
				function(a, b) return a.Value.Id < b.Value.Id end
			)

			for _, v in mappedConfig do
				t[v.Key] = ContextPacket(v.Value.Actions):Read(bb)
			end
			return t
		end
	)
end

return InputService.new()
