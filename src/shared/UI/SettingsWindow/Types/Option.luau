local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Component = require("../../../Packages/Component")
local SettingTypes = require("../../../Services/SettingsService/SettingTypes")
local Trove = require("../../../Packages/Trove")

local Option = { change = {} }
Option.extends = Component

export type Option = {
	Value: number,
	Expanded: boolean,
} & Component.Component<{
	Content: {
		Title: TextLabel,
		Description: TextLabel,
	} & Frame,
	Option: {
		Title: TextLabel,
		ArrowHolder: { Arrow: ImageLabel } & Frame,
	} & ImageButton,
} & ImageButton>

type Self = {
	trove: Trove.Trove,
	menu: Frame,
	lastValue: number,
	config: SettingTypes.Option,
	buttons: { TextButton },
} & Option

local function updateMenu(self: Self)
	local option = self.Instance.Option
	self.menu.Position = UDim2.fromOffset(
		option.AbsolutePosition.X,
		option.AbsolutePosition.Y + option.AbsoluteSize.Y
	)
end

local function initMenu(self: Self)
	local holder = Instance.new("ScreenGui")
	holder.Name = "OptionMenuHolder"
	holder.DisplayOrder = 1
	holder.Parent = Players.LocalPlayer.PlayerGui

	self.menu = ReplicatedStorage.UI.Settings.Types.OptionMenu:Clone()
	self.menu.Parent = holder

	local hovered = false
	self.trove:AddAll(
		holder,
		UserInputService.InputBegan:Connect(function()
			if self.Expanded and not hovered then self.Expanded = false end
		end),
		UserInputService.InputChanged:Connect(function(input)
			if
				self.Expanded
				and not hovered
				and input.UserInputType == Enum.UserInputType.MouseWheel
			then
				self.Expanded = false
			end
		end),
		self.menu.MouseEnter:Connect(function() hovered = true end),
		self.menu.MouseLeave:Connect(function() hovered = false end)
	)
end

local function initButtons(self: Self)
	self.buttons = {}

	local button = self.menu.Option :: TextButton
	for k, v in self.config.Options do
		local clone = button:Clone()
		clone.Text = v
		clone.Parent = self.menu

		self.trove:Add(clone.Activated:Connect(function()
			self.Expanded = false
			self.Value = k
		end))
		self.buttons[k] = clone
	end
	button:Destroy()
end

function Option.new(config: SettingTypes.Option): Option
	local self: Self =
		Component(ReplicatedStorage.UI.Settings.Types.Option:Clone(), Option)

	self.Instance.Content.Title.Text = config.Title
	self.Instance.Content.Description.Text = config.Description
	self.Instance.Content.Description.Visible = config.Description ~= ""
	self.Instance.LayoutOrder = config.Index
	self.config = config
	self.trove = Trove.new()

	initMenu(self)
	initButtons(self)

	local option = self.Instance.Option
	self.trove:AddAll(
		option.Activated:Connect(
			function() self.Expanded = not self.Expanded end
		),
		option
			:GetPropertyChangedSignal("AbsolutePosition")
			:Connect(function() updateMenu(self) end),
		option:GetPropertyChangedSignal("AbsoluteSize"):Connect(
			function()
				self.menu.Size = UDim2.fromOffset(option.AbsoluteSize.X, 0)
			end
		)
	)
	self.Expanded = false
	self.Value = config.Default

	self.trove:AttachToInstance(self.Instance)
	return self
end

function Option.change.Value(self: Self)
	if self.lastValue then self.buttons[self.lastValue].Visible = true end
	self.lastValue = self.Value

	self.buttons[self.Value].Visible = false
	self.Instance.Option.Title.Text = self.config.Options[self.Value]
end

local tweenInfo =
	TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
function Option.change.Expanded(self: Self)
	TweenService:Create(
		self.Instance.Option.ArrowHolder.Arrow,
		tweenInfo,
		{ Rotation = self.Expanded and 180 or 0 }
	):Play()

	self.menu.Visible = self.Expanded
	self.Instance.Option.Interactable = not self.Expanded
end

return table.freeze(Option) :: {
	new: typeof(Option.new),
}
