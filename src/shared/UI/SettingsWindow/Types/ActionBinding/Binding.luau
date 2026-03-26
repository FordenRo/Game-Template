local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Class = require("../../../../Packages/Class")
local Component = require("../../../../Packages/Component")
local InputService = require("../../../../Services/InputService")
local InputTypes = require("../../../../Services/InputService/InputTypes")
local Trove = require("../../../../Packages/Trove")

local Binding = {}
Class(Binding, Component)

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

function Binding.init(self: Self, inputBinding: InputBinding)
	self:Super():init(ReplicatedStorage.UI.Settings.Types.Binding:Clone())

	self.InputBinding = inputBinding
	self.Instance.Text = InputService:GetStringForBinding(self.InputBinding)

	local trove = Trove.new()
	trove:Add(
		self.InputBinding.Changed:Connect(
			function()
				self.Instance.Text =
					InputService:GetStringForBinding(self.InputBinding)
			end
		),
		self.Instance.Activated:Connect(function()
			InputService.Enabled = false
			self.Instance.Text = "..."

			local subTrove = trove:Extend()
			subTrove:AddAll(
				UserInputService.InputBegan:Connect(function(input)
					if not input.KeyCode then return end

					if input.KeyCode == Enum.KeyCode.Escape then
						subTrove:Destroy()
						return
					end

					self.InputBinding.KeyCode = input.KeyCode
					subTrove:Destroy()
				end),
				function()
					self.Instance.Text =
						InputService:GetStringForBinding(self.InputBinding)
					InputService.Enabled = true
				end
			)
		end)
	)

	trove:AttachToInstance(self.Instance)
end

return table.freeze(Binding) :: {
	new: (inputBinding: InputBinding) -> Binding,
}
