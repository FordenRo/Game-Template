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

export type InputService = setmetatable<{
	GetStringForAction: (self: InputService, action: InputAction) -> string,
}, {
	__index: setmetatable<InputsTable, { __index: Class.Class }>,
}>

type Self = setmetatable<Replicated.Replicated, { __index: InputService }>

function InputService.new(): InputService
	local self: Self = Class(InputService)

	self:CreateRemotes(script)
	if RunService:IsClient() then initClient(self) end

	return self
end

local function getInputs(self: Self)
	return Packet:Deserialize(BitBuffer.fromBase64(self:InvokeServer()))
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

do
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

function InputService.onServerReceived(self: Self, player: Player, b: buffer)
	local datastore = DataStoreService:GetDataStore("Inputs")
	datastore:SetAsync(tostring(player.UserId), b)
end

function InputService.onServerInvoked(self: Self, player: Player)
	local datastore = DataStoreService:GetDataStore("Inputs")
	return datastore:GetAsync(tostring(player.UserId))
end

do
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

	local function ActionPacket(action) return BitPacket.Array(BindingPacket) end

	local function ContextPacket(context)
		local actions: Array.Array<{ Key: string, Value: ActionConfig }> =
			Array()
		for k, v in context.Actions do
			actions:Add({ Key = k, Value = v })
		end
		actions = actions:Sorted(
			function(a, b) return a.Value.Id < b.Value.Id end
		)

		return BitPacket.new(function(bb: BitBuffer.BitBuffer, value)
			for _, v in actions do
				bb:WriteBool(true)
				ActionPacket(v.Value.Bindings):Write(bb, value)
			end
			bb:WriteBool(false)
		end, function(bb: BitBuffer.BitBuffer)
			local t = {}
			for _, v in actions do
				if not bb:ReadBool() then break end
				t[v.Key] = ActionPacket(v.Value):Read(bb)
			end
			return t
		end)
	end

	Packet = BitPacket.new(function(bb: BitBuffer.BitBuffer, value)
		local mappedConfig: Array.Array<{ Key: string, Value: InputConfig }> =
			Array()
		for k, v in InputsConfig do
			mappedConfig:Add({ Key = k, Value = v })
		end
		mappedConfig = mappedConfig:Sorted(
			function(a, bb) return a.Value.Id < bb.Value.Id end
		)

		for _, v in mappedConfig do
			ContextPacket(v.Value):Write(bb, value)
		end
	end, function(bb: BitBuffer.BitBuffer)
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
	end)
end

return InputService.new()
