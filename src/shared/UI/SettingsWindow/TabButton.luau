local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Component = require("../../Packages/Component")
local SettingTypes = require("../../Services/SettingsService/SettingTypes")

local TabButton = { change = {} }
TabButton.extends = Component

export type TabButton = {
	Selected: boolean,
	Activated: RBXScriptSignal,
} & Component.Component<
	{ UIStroke: UIStroke } & TextButton
>

type Self = TabButton

function TabButton.new(tab: SettingTypes.Tab): TabButton
	local self: Self =
		Component(ReplicatedStorage.UI.Settings.TabButton:Clone(), TabButton)

	self.Instance.Text = tab.Title
	self.Instance.LayoutOrder = tab.Index
	self.Activated = self.Instance.Activated

	return self
end

function TabButton.change.Selected(self: Self)
	self.Instance.Interactable = not self.Selected

	local tweenInfo = TweenInfo.new(0.2)
	TweenService:Create(self.Instance, tweenInfo, {
		BackgroundColor3 = self.Selected and Color3.fromRGB(90, 110, 130)
			or Color3.fromRGB(60, 70, 80),
	}):Play()
	TweenService:Create(self.Instance.UIStroke, tweenInfo, {
		Transparency = self.Selected and 0.4 or 0.8,
	}):Play()
end

return table.freeze(TabButton) :: {
	new: typeof(TabButton.new),
}
