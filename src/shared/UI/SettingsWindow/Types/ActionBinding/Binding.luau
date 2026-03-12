local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require("../../../../Packages/Component")
local InputService = require("../../../../Services/InputService")
local InputTypes = require("../../../../Services/InputService/InputTypes")
local Trove = require("../../../../Packages/Trove")

local Binding = {}
Binding.extends = Component

export type Binding = {
	Type: Enum.InputActionType,
	InputBinding: InputBinding,
} & Component.Component<{
	More: ImageButton,
} & TextButton>

type BoolBinding =
	index<index<InputTypes.BoolAction, "Bindings">, number>
	& Binding
type MouseBinding =
	index<index<InputTypes.MouseAction, "Bindings">, number>
	& Binding
type Action1DBinding =
	index<index<InputTypes.Action1D, "Bindings">, number>
	& Binding
type Action2DBinding =
	index<index<InputTypes.Action2D, "Bindings">, number>
	& Binding
type Action3DBinding =
	index<index<InputTypes.Action3D, "Bindings">, number>
	& Binding

type Self = Binding

function Binding.new(inputBinding: InputBinding): Binding
	local self: Self =
		Component(ReplicatedStorage.UI.Settings.Types.Binding:Clone(), Binding)

	self.InputBinding = inputBinding
	self.Instance.Text =
		InputService:GetStringForAction(self.InputBinding.Parent)

	local trove = Trove.new()
	trove:Add(
		self.InputBinding
			:GetPropertyChangedSignal("KeyCode")
			:Connect(function() end)
	)

	trove:AttachToInstance(self.Instance)
	return self
end

return table.freeze(Binding) :: {
	new: typeof(Binding.new),
}
