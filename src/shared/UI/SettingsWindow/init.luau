local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ActionBinding = require("@self/Types/ActionBinding")
local Array = require("../Packages/Array")
local Class = require("../Packages/Class")
local Component = require("../Packages/Component")
local Group = require("@self/Types/Group")
local InputTypes = require("../Services/InputService/InputTypes")
local InputsConfig = require("../InputsConfig")
local SettingTypes = require("../Services/SettingsService/SettingTypes")
local SettingsConfig = require("../SettingsConfig")
local SettingsService = require("../Services/SettingsService")
local TabButton = require("@self/TabButton")
local Trove = require("../Packages/Trove")

local InputService
if script.Parent.Parent.Services:FindFirstChild("InputService") then
	InputService = require("../Services/InputService")
end

local Types = {}
for _, v in script.Types:GetChildren() do
	if v:IsA("ModuleScript") then Types[v.Name] = require(v) end
end

local INPUTS_TAB = SettingTypes.Tab("Input", -1)

local SettingsWindow = {}
Class(SettingsWindow, Component)

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
	tabButtons: { [SettingTypes.Tab]: TabButton.TabButton },
	lastTab: SettingTypes.Tab,
	settings: { [BaseSettingType]: { Value: any } & Component.Component<Frame> },
	groups: { [SettingTypes.Group]: Group.Group },
} & SettingsWindow

local function createTabContent()
	local content = Instance.new("Frame")
	content.Size = UDim2.fromScale(1, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Visible = false

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = content

	return content
end

local function initTabs(self: Self)
	self.tabContents = {}
	self.tabButtons = {}
	local tabs = Array.fromTable(SettingsConfig)
		:Mapped(function(v) return v.Parent end)
		:Unified()
		:Filtered(function(v) return v.Type == "Tab" end)
	for _, tab in tabs do
		self:AddTab(tab, createTabContent())
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

		setting.Value = SettingsService.Settings[k]
		self.settings[v] = setting

		self.trove:Add(
			setting
				:GetPropertyChangedSignal("Value")
				:Connect(
					function() SettingsService.Settings[k] = setting.Value end
				)
		)
	end
end

local function initInputs(self: Self)
	local content = createTabContent()
	self:AddTab(INPUTS_TAB, content)

	for ck, cv in InputsConfig :: { [string]: InputTypes.Context } do
		local context = InputService[ck]
		local groupContent = initGroup(self, {
			Title = ck,
			Description = cv.Description,
			Index = cv.Index,
			Parent = INPUTS_TAB,
		})
		for ak, av in cv.Actions do
			local action = context[ak]
			local binding = ActionBinding.new(action, av)
			binding.Instance.Parent = groupContent
		end
	end
end

function SettingsWindow.init(self: Self)
	self:Super():init(ReplicatedStorage.UI.Settings.SettingsWindow:Clone())

	self.trove = Trove.new()

	initTabs(self)
	initSettings(self)
	initInputs(self)

	self.trove:Add(
		self.Instance.Sidebar.Control.Close.Activated:Connect(
			function() self:Destroy() end
		)
	)

	self.trove:AttachToInstance(self.Instance)
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
	new: () -> SettingsWindow,
}
