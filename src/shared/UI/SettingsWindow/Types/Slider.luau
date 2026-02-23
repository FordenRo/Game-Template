local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require("../../../Packages/Component")
local SettingTypes = require("../../../Services/SettingsService/SettingTypes")
local Trove = require("../../../Packages/Trove")

local Slider = { set = {} }
Slider.extends = Component

export type Slider = setmetatable<{
	Value: number,
}, { __index: Component.Component<{
	Content: {
		Title: TextLabel,
		Description: TextLabel,
	} & Frame,
	Control: {
		Slider: {
			Fill: Frame,
			Handle: {
				UIDragDetector: UIDragDetector,
			} & Frame,
		} & Frame,
		Reset: ImageButton,
		Value: TextBox,
	} & Frame,
} & Frame> }>

type Self = setmetatable<{
	config: SettingTypes.Slider,
	drag: UIDragDetector,
	reset: ImageButton,
	box: TextBox,
}, { __index: Slider }>

local function toNormal(self: Self, x: number)
	return x * self.config.Max + self.config.Min
end
local function toRelative(self: Self, x: number)
	return (x - self.config.Min) / self.config.Max
end

local function setBoxValue(self: Self, x: number)
	local l = self.config.Step >= 1 and 0 or self.config.Step >= 0.1 and 1 or 2
	self.box.Text = string.format(`%.{l}f`, x)
end

local function setDragValue(self: Self, x: number)
	self.drag.DragUDim2 = UDim2.fromScale(toRelative(self, x) - 0.5, 0)
end

function Slider.new(config: SettingTypes.Slider): Slider
	local self: Self =
		Component(ReplicatedStorage.UI.Settings.Types.Slider:Clone(), Slider)

	self.config = config
	self.drag = self.Instance.Control.Slider.Handle.UIDragDetector
	self.box = self.Instance.Control.Value
	self.reset = self.Instance.Control.Reset

	self.Instance.Content.Title.Text = config.Title
	self.Instance.Content.Description.Text = config.Description
	self.Instance.Content.Description.Visible = config.Description ~= ""
	self.Instance.LayoutOrder = config.Index

	local trove = Trove.new()
	trove:AddAll(
		self.box.FocusLost:Connect(function()
			local value = tonumber((self.box.Text:gsub(",", ".")))
			if not value then
				setBoxValue(self, self.Value)
				return
			end
			self.Value = value
		end),

		self.drag.DragContinue:Connect(function()
			local value = toNormal(self, self.drag.DragUDim2.X.Scale + 0.5)
			setBoxValue(self, value)
		end),

		self.drag.DragEnd:Connect(
			function()
				self.Value = toNormal(self, self.drag.DragUDim2.X.Scale + 0.5)
			end
		),

		self.reset.Activated:Connect(
			function() self.Value = self.config.Default end
		)
	)
	self.Value = config.Default

	trove:AttachToInstance(self.Instance)
	return self
end

local function mapped(self: Self, x: number)
	return math.clamp(
		self.config.Step * math.round(x / self.config.Step),
		self.config.Min,
		self.config.Max
	)
end

function Slider.set.Value(self: Self, value: number)
	value = mapped(self, value)
	setBoxValue(self, value)
	setDragValue(self, value)
	self.reset.Visible = value ~= self.config.Default

	if value == self:RawGet("Value") then return end
	self:RawSet("Value", value)
	return true
end

return table.freeze(Slider) :: {
	new: typeof(Slider.new),
}
