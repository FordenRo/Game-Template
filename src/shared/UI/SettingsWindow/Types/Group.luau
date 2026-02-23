local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Component = require("../../../Packages/Component")
local SettingTypes = require("../../../Services/SettingsService/SettingTypes")
local Trove = require("../../../Packages/Trove")

local Group = { change = {} }
Group.extends = Component

export type Group = setmetatable<{
	Expanded: boolean,
}, { __index: Component.Component<{
	UIPadding: UIPadding,
	UIStroke: UIStroke,
	Content: { UIListLayout: UIListLayout } & Frame,
	Button: {
		Content: {
			Title: TextLabel,
			Description: TextLabel,
		} & Frame,
		Arrow: ImageLabel,
	} & ImageButton,
} & ImageButton> }>

type Self = setmetatable<{
	size: number,
	trove: Trove.Trove,
}, { __index: Group }>

local function initChild(self: Self, child: Instance)
	if not child:IsA("GuiObject") then return end

	local cSize = child.AbsoluteSize.Y
	self.size += cSize + 8

	self.trove:Add(
		child:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self.size += child.AbsoluteSize.Y - cSize
			cSize = child.AbsoluteSize.Y
		end)
	)
end

function Group.new(config: SettingTypes.Group): Group
	local self: Self =
		Component(ReplicatedStorage.UI.Settings.Types.Group:Clone(), Group)

	self.Instance.Button.Content.Title.Text = config.Title
	self.Instance.Button.Content.Description.Text = config.Description
	self.Instance.Button.Content.Description.Visible = config.Description ~= ""
	self.Instance.LayoutOrder = config.Index
	self.Expanded = false
	self.trove = Trove.new()

	self.trove:AddAll(
		self.Instance.Content.ChildAdded:Connect(
			function(v) initChild(self, v) end
		),
		self.Instance.Button.Activated:Connect(
			function() self.Expanded = not self.Expanded end
		)
	)

	self.size = 5
	for _, v in self.Instance.Content:GetChildren() do
		initChild(self, v)
	end

	self.trove:AttachToInstance(self.Instance)
	return self
end

function Group.change.size(self: Self)
	if not self.Expanded then return end

	self.Instance.Content.Size = UDim2.new(1, 0, 0, self.size)
end

local tweenInfo =
	TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
function Group.change.Expanded(self: Self)
	TweenService:Create(self.Instance, tweenInfo, {
		BackgroundTransparency = self.Expanded and 0.6 or 0,
	}):Play()
	TweenService:Create(self.Instance.Button.Arrow, tweenInfo, {
		Rotation = self.Expanded and 180 or 0,
	}):Play()
	TweenService:Create(self.Instance.UIStroke, tweenInfo, {
		Transparency = self.Expanded and 0.8 or 1,
	}):Play()

	local padding = UDim.new(0, self.Expanded and 3 or 0)
	TweenService:Create(self.Instance.UIPadding, tweenInfo, {
		PaddingBottom = padding,
		PaddingLeft = padding,
		PaddingRight = padding,
		PaddingTop = padding,
	}):Play()

	TweenService:Create(self.Instance.Content, tweenInfo, {
		Size = UDim2.new(1, 0, 0, self.Expanded and self.size or 0),
	}):Play()
end

return table.freeze(Group) :: {
	new: typeof(Group.new),
}
