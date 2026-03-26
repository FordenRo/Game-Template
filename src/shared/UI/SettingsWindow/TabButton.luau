local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Class = require("../../Packages/Class")
local Component = require("../../Packages/Component")
local SettingTypes = require("../../Services/SettingsService/SettingTypes")

local TabButton = {}
Class(TabButton, Component)

export type TabButton = {
	Selected: boolean,
	Activated: RBXScriptSignal,
} & Component.Component<
	{ UIStroke: UIStroke } & TextButton
>

type Self = TabButton

function TabButton.init(self: Self, tab: SettingTypes.Tab)
	self:Super():init(ReplicatedStorage.UI.Settings.TabButton:Clone())

	self.Instance.Text = tab.Title
	self.Instance.LayoutOrder = tab.Index
	self.Activated = self.Instance.Activated
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
	new: (tab: SettingTypes.Tab) -> TabButton,
}
