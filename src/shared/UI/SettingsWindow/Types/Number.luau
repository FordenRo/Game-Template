local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require("../../../Packages/Component")
local SettingTypes = require("../../../Services/SettingsService/SettingTypes")
local Trove = require("../../../Packages/Trove")

local Number = { set = {} }
Number.extends = Component

export type Number = setmetatable<{
	Value: number,
}, { __index: Component.Component<{
	Content: {
		Title: TextLabel,
		Description: TextLabel,
	} & Frame,
	Control: {
		Reset: ImageButton,
		Value: TextBox,
	} & Frame,
} & Frame> }>

type Self = setmetatable<{
	config: SettingTypes.Slider,
	reset: ImageButton,
	box: TextBox,
}, { __index: Number }>

local function setBoxValue(self: Self, x: number)
	local l = self.config.Step >= 1 and 0 or self.config.Step >= 0.1 and 1 or 2
	self.box.Text = string.format(`%.{l}f`, x)
end

function Number.new(config: SettingTypes.Slider): Number
	local self: Self =
		Component(ReplicatedStorage.UI.Settings.Types.Number:Clone(), Number)

	self.config = config
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

function Number.set.Value(self: Self, value: number)
	value = mapped(self, value)
	setBoxValue(self, value)
	self.reset.Visible = value ~= self.config.Default

	if value == self:RawGet("Value") then return end
	self:RawSet("Value", value)
	return true
end

return table.freeze(Number) :: {
	new: typeof(Number.new),
}
