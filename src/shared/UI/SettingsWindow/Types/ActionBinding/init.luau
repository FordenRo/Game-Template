local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Binding = require("@self/Binding")
local Class = require("../../../Packages/Class")
local Component = require("../../../Packages/Component")
local InputTypes = require("../../../Services/InputService/InputTypes")
local Trove = require("../../../Packages/Trove")

local ActionBinding = {}
Class(ActionBinding, Component)

export type ActionBinding = setmetatable<{
	InputAction: InputAction,
	Config: InputTypes.BaseAction,
	Bindings: { Binding.Binding },
}, { __index: Component.Component<{
	Content: {
		Title: TextLabel,
		Description: TextLabel,
	} & Frame,
	Control: {
		Reset: ImageButton,
		Add: TextButton,
	} & Frame,
} & Frame> }>

type Self = ActionBinding

function ActionBinding.init(
	self: Self,
	inputAction: InputAction,
	config: InputTypes.BaseAction
)
	self:Super():init(ReplicatedStorage.UI.Settings.Types.ActionBinding:Clone())

	self.Config = config
	self.InputAction = inputAction

	self.Instance.Content.Title.Text = config.Title
	self.Instance.Content.Description.Text = config.Description
	self.Instance.Content.Description.Visible = config.Description ~= ""
	self.Instance.LayoutOrder = config.Index

	local trove = Trove.new()
	trove:AddAll(
		self.Instance.Control.Reset.Activated:Connect(function() end),
		self.Instance.Control.Add.Activated:Connect(function() end)
	)

	for _, v in inputAction:GetChildren() do
		if not v:IsA("InputBinding") then continue end

		local binding = Binding.new(v)
		binding.Instance.Parent = self.Instance.Control
	end

	trove:AttachToInstance(self.Instance)
end

-- function ActionBinding.AddBinding(self: Self) end

return table.freeze(ActionBinding) :: {
	new: (
		inputAction: InputAction,
		config: InputTypes.BaseAction
	) -> ActionBinding,
}
