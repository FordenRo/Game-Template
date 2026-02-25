local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Component = require("../../../Packages/Component")
local SettingTypes = require("../../../Services/SettingsService/SettingTypes")
local Trove = require("../../../Packages/Trove")

local Flag = { change = {} }
Flag.extends = Component

export type Flag = {
	Value: boolean,
} & Component.Component<{
	Content: {
		Title: TextLabel,
		Description: TextLabel,
	} & Frame,
	CheckBox: { Check: ImageLabel } & ImageButton,
} & Frame>

type Self = Flag

function Flag.new(config: SettingTypes.Flag): Flag
	local self: Self =
		Component(ReplicatedStorage.UI.Settings.Types.Flag:Clone(), Flag)

	self.Instance.Content.Title.Text = config.Title
	self.Instance.Content.Description.Text = config.Description
	self.Instance.Content.Description.Visible = config.Description ~= ""
	self.Instance.LayoutOrder = config.Index

	local trove = Trove.new()
	trove:Add(
		self.Instance.CheckBox.Activated:Connect(
			function() self.Value = not self.Value end
		)
	)
	self.Value = config.Default

	trove:AttachToInstance(self.Instance)
	return self
end

function Flag.change.Value(self: Self)
	TweenService:Create(self.Instance.CheckBox.Check, TweenInfo.new(0.1), {
		ImageTransparency = self.Value and 0 or 1,
	}):Play()
end

return table.freeze(Flag) :: {
	new: typeof(Flag.new),
}
