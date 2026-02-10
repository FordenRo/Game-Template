local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Array = require("../Packages/Array")
local Component = require("../Packages/Component")
local Flag = require("@self/Types/Flag")
local Group = require("@self/Types/Group")
local Number = require("@self/Types/Number")
local Option = require("@self/Types/Option")
local SettingTypes = require("../Services/SettingsService/SettingTypes")
local SettingsConfig = require("../SettingsConfig")
local SettingsService = require("../Services/SettingsService")
local Slider = require("@self/Types/Slider")
local Trove = require("../Packages/Trove")

local Types = { Flag = Flag, Slider = Slider, Number = Number, Option = Option }

local TabButton = { change = {} }
TabButton.extends = Component

type TabButton = {
	Selected: boolean,
	Activated: RBXScriptSignal,
} & Component.Component<{ UIStroke: UIStroke } & TextButton>

function TabButton.new(tab: SettingTypes.Tab): TabButton
	local self: TabButton =
		Component(ReplicatedStorage.UI.Settings.TabButton:Clone(), TabButton)

	self.Instance.Text = tab.Title
	self.Instance.LayoutOrder = tab.Index
	self.Activated = self.Instance.Activated

	return self
end

function TabButton.change.Selected(self: TabButton)
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

local SettingsWindow = { change = {} }
SettingsWindow.extends = Component

export type SettingsWindow = {
	CurrentTab: SettingTypes.Tab,

	AddTab: (self: SettingsWindow, tab: SettingTypes.Tab, content: Frame) -> (),
	HighlightSetting: (self: SettingsWindow, value: BaseSettingType) -> (),
	Destroy: (self: SettingsWindow) -> (),
} & Component.Component<{
	Content: ScrollingFrame,
	Sidebar: {
		Tabs: Frame,
		Control: { Close: TextButton } & Frame,
	} & Frame,
} & Frame>

type BaseSettingType = {
	Type: string,
	Title: string,
	Parent: SettingTypes.Tab | SettingTypes.Group,
	Index: number,
}

type Self = {
	trove: Trove.Trove,
	tabContents: { [SettingTypes.Tab]: Frame },
	tabButtons: { [SettingTypes.Tab]: TabButton },
	lastTab: SettingTypes.Tab,
	settings: { [BaseSettingType]: { Value: any } & Component.Component<Frame> },
	groups: { [SettingTypes.Group]: Group.Group },
} & SettingsWindow

local function initTabs(self: Self)
	self.tabContents = {}
	self.tabButtons = {}
	local tabs = Array.fromTable(SettingsConfig)
		:Mapped(function(v) return v.Parent end)
		:Unified()
		:Filtered(function(v) return v.Type == "Tab" end)
	for _, tab in tabs do
		local content = Instance.new("Frame")
		content.Size = UDim2.fromScale(1, 0)
		content.AutomaticSize = Enum.AutomaticSize.Y
		content.BackgroundTransparency = 1
		content.Visible = false

		local listLayout = Instance.new("UIListLayout")
		listLayout.Padding = UDim.new(0, 10)
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Parent = content

		self:AddTab(tab, content)
	end
	task.defer(function() self.CurrentTab = tabs[1] end)
end

local function initGroup(self: Self, groupConfig: SettingTypes.Group)
	local group = self.groups[groupConfig]
	if group then return group.Instance.Content end

	group = Group.new(groupConfig)
	group.Instance.Parent = groupConfig.Parent.Type == "Tab"
			and self.tabContents[groupConfig.Parent]
		or initGroup(self, groupConfig.Parent)

	self.groups[groupConfig] = group
	return group.Instance.Content
end

local function initSettings(self: Self)
	self.groups = {}
	self.settings = {}
	for k, v in SettingsConfig :: { [string]: BaseSettingType } do
		local setting = Types[v.Type].new(v)
		setting.Instance.Parent = v.Parent.Type == "Tab"
				and self.tabContents[v.Parent]
			or initGroup(self, v.Parent)

		setting.Value = SettingsService.LocalSettings[k]
		self.settings[v] = setting

		self.trove:Add(
			setting:GetPropertyChangedSignal("Value"):Connect(
				function() SettingsService.LocalSettings[k] = setting.Value end
			)
		)
	end
end

function SettingsWindow.new(): SettingsWindow
	local self: Self = Component(
		ReplicatedStorage.UI.Settings.SettingsWindow:Clone(),
		SettingsWindow
	)

	self.trove = Trove.new()

	initTabs(self)
	initSettings(self)

	self.trove:Add(
		self.Instance.Sidebar.Control.Close.Activated:Connect(
			function() self:Destroy() end
		)
	)

	self.trove:AttachToInstance(self.Instance)
	return self
end

function SettingsWindow.change.CurrentTab(self: Self)
	if self.lastTab then
		self.tabContents[self.lastTab].Visible = false
		self.tabButtons[self.lastTab].Selected = false
	end
	self.lastTab = self.CurrentTab

	self.tabContents[self.CurrentTab].Visible = true
	self.tabButtons[self.CurrentTab].Selected = true

	self.Instance.Content.CanvasPosition = Vector2.zero
end

function SettingsWindow.AddTab(
	self: Self,
	tab: SettingTypes.Tab,
	content: Frame
)
	local button = TabButton.new(tab)
	button.Instance.Parent = self.Instance.Sidebar.Tabs

	self.trove:Add(
		button.Activated:Connect(function() self.CurrentTab = tab end)
	)

	content.Parent = self.Instance.Content
	self.tabContents[tab] = content
	self.tabButtons[tab] = button
end

function goto(self: Self, instance: GuiObject)
	local content = self.Instance.Content
	local offset = instance.AbsolutePosition.Y - content.AbsolutePosition.Y
	local tween = TweenService:Create(
		content,
		TweenInfo.new((offset / 150) ^ 0.7, Enum.EasingStyle.Sine),
		{
			CanvasPosition = Vector2.new(
				content.CanvasPosition.X,
				offset + content.CanvasPosition.Y
			),
		}
	)
	tween:Play()
	tween.Completed:Wait()
end

function SettingsWindow.HighlightSetting(self: Self, value: BaseSettingType)
	local groups = Array() :: Array.Array<SettingTypes.Group>

	local parent = value.Parent
	while parent do
		groups:Add(parent)
		parent = parent.Parent
	end
	groups = groups:Reversed()
	local tab = groups:Remove(1)

	self.CurrentTab = tab
	task.defer(function()
		for _, groupConfig in groups do
			local group = self.groups[groupConfig]
			goto(self, group.Instance)
			group.Expanded = true
			task.wait(0.1)
		end
		goto(self, self.settings[value].Instance)
	end)
end

function SettingsWindow.Destroy(self: Self) self.Instance:Destroy() end

return table.freeze(SettingsWindow) :: {
	new: typeof(SettingsWindow.new),
}
