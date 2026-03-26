local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Class = require("../../Packages/Class")
local Component = require("../../Packages/Component")

--#region Constants
local CORE_PROPERTIES = {
	"ChatActive",
	"PointsNotificationActive",
	"BadgesNotificationsActive",
	"TopbarEnabled",
	"DevConsoleVisible",
}

local CORE_FUNCTIONS = {
	"PromptSendFriendRequest",
	"PromptUnfriend",
	"PromptBlockPlayer",
	"PromptUnblockPlayer",
}

local CORE_GUI_PROPERTIES = {
	CoreGuiEnabled = Enum.CoreGuiType.All,
	ChatEnabled = Enum.CoreGuiType.Chat,
	BackpackEnabled = Enum.CoreGuiType.Backpack,
	AvatarSwitchedEnabled = Enum.CoreGuiType.AvatarSwitcher,
	CapturesEnabled = Enum.CoreGuiType.Captures,
	PlayerListEnabled = Enum.CoreGuiType.PlayerList,
	EmotesMenuEnabled = Enum.CoreGuiType.EmotesMenu,
	HealthEnabled = Enum.CoreGuiType.Health,
	SelfViewEnabled = Enum.CoreGuiType.SelfView,
}
--#endregion

local BaseInterfaceController = { get = {}, set = {}, change = {} }
BaseInterfaceController.extends = Component

--#region Types

export type BaseInterfaceController = {
	--- Toggles the visibility of the interface.
	Enabled: boolean,
	--- TODO: comment
	CurrentWindow: GuiObject?,

	--- Adds `GuiObject` to the interface.
	Add: (
		self: BaseInterfaceController,
		object: Instance | Component.Component<Instance>
	) -> (),

	--- Returns a list of all `GuiObject` instances occupying the given position on the screen.
	GetGuiObjectsAtPosition: (
		self: BaseInterfaceController,
		position: Vector2
	) -> { GuiObject },
	--- Returns a list of all `GuiObject` instances occupying the circle at the given position of the radius.
	GetGuiObjectsInCircle: (
		self: BaseInterfaceController,
		position: Vector2,
		radius: number
	) -> { GuiObject },

	--- Core values ---

	--- Controls whether the chat is active.
	ChatActive: boolean,
	--- Controls whether notifications for earned player points will appear.
	PointsNotificationActive: boolean,
	--- Controls whether notifications for earned badges will appear.
	BadgesNotificationsActive: boolean,
	--[[
		Determines whether the topbar is displayed. Disabling the topbar will also disable all CoreGuis such as the chat, inventory, and player list (for example, those set with SetCoreGuiEnabled).

		When disabled, the region the topbar once occupied will still capture mouse events; however, buttons placed there will not respond to clicks. The origin of GUI space will still be offset 36 pixels from the top of the screen.
	]]
	TopbarEnabled: boolean,
	--- Determines whether the Developer Console is visible.
	DevConsoleVisible: boolean,
	--- Determines the behavior, if any, of the reset button given a boolean or a function to be fired when a player requests to reset.
	ResetButtonCallback: () -> () | boolean,

	--- Determines whether all available core UIs are enabled.
	CoreGuiEnabled: boolean,
	--- Determines whether the text chat window is enabled.
	ChatEnabled: boolean,
	--- Determines whether the character's Backpack is enabled.
	BackpackEnabled: boolean,
	--- Determines whether the `Avatar Switcher` that allows users to change their platform avatar is enabled.
	AvatarSwitchedEnabled: boolean,
	--- Determines whether the "capture" button along the right side of the screen is enabled.
	CapturesEnabled: boolean,
	--- Determines whether the dynamically updated Players list, commonly used as a leaderboard is enabled.
	PlayerListEnabled: boolean,
	--- Determines whether the popup menu of character emotes is enabled.
	EmotesMenuEnabled: boolean,
	--- Determines whether the character's Health bar is enabled.
	HealthEnabled: boolean,
	--- Determines whether the player's perspective or view of their own character is enabled.
	SelfViewEnabled: boolean,

	--- Core functions ---

	--- Prompts the current player to send a connection request to the given Player.
	PromptSendFriendRequest: (
		self: BaseInterfaceController,
		player: Player
	) -> (),
	--- Prompts the current player to remove a given Player from their connections list.
	PromptUnfriend: (self: BaseInterfaceController, player: Player) -> (),
	--- Prompts the current player to block the given Player.
	PromptBlockPlayer: (
		self: BaseInterfaceController,
		player: Player
	) -> (),
	--- Prompts the current player to unblock the given Player.
	PromptUnblockPlayer: (
		self: BaseInterfaceController,
		player: Player
	) -> (),
	--- Causes a non-intrusive notification to appear at the bottom right of the screen. The notification may have up to two buttons.
	SendNotification: (
		self: BaseInterfaceController,
		title: string,
		text: string,
		props: NotificationProperties?
	) -> (),
} & Component.Component<ScreenGui>

type Self = {
	windowConn: RBXScriptConnection?,
	lastWindow: GuiObject?,
} & BaseInterfaceController

type NotificationProperties = {
	--- The image to display with the notification.
	Icon: string?,
	--- Duration (in seconds) the notification should stay visible. Default is 5.
	Duration: number?,
	--- A callback that should be invoked with the text of the button pressed by the player.
	Callback: ((string) -> ())?,
	--- The text to display on the first button.
	Button1: string?,
	--- The text to display on the second button.
	Button2: string?,
}

--#endregion

function BaseInterfaceController.new(): BaseInterfaceController
	local screen = Instance.new("ScreenGui")
	screen.Name = "Interface"
	screen.Enabled = false
	screen.Parent = Players.LocalPlayer.PlayerGui

	local self: Self = Component(screen, BaseInterfaceController)

	self.Enabled = false

	self:RawSet("ResetButtonCallback", true)

	return self
end

function BaseInterfaceController.change.Enabled(self: Self)
	self.Instance.Enabled = self.Enabled
end

function BaseInterfaceController.change.CurrentWindow(self: Self)
	if self.windowConn then
		self.windowConn:Disconnect()
		self.windowConn = nil
	end
	if self.lastWindow then self.lastWindow:Destroy() end

	if self.CurrentWindow then
		self.windowConn = self.CurrentWindow.Destroying:Once(
			function() self.CurrentWindow = nil end
		)
		self.CurrentWindow.Parent = self.Instance
	end
end

function BaseInterfaceController.Add(
	self: Self,
	object: Instance | Component.Component<Instance>
)
	if Class.isClass(object) and object:IsA(Component) then
		object = (object :: Component.Component<Instance>).Instance
	end

	if typeof(object) == "Instance" then
		object.Parent = self.Instance
		return
	end
	error("The object must be of type Instance or Component")
end

function BaseInterfaceController.GetGuiObjectsAtPosition(
	self: Self,
	position: Vector2
)
	return Players.LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(
		position.X,
		position.Y
	)
end

function BaseInterfaceController.GetGuiObjectsInCircle(
	self: Self,
	position: Vector2,
	radius: number
)
	return Players.LocalPlayer.PlayerGui:GetGuiObjectsInCircle(position, radius)
end

function BaseInterfaceController.SendNotification(
	self: Self,
	title: string,
	text: string,
	props: NotificationProperties?
)
	props = props or {}
	props.Title = title
	props.Text = text

	if props.Callback then
		local event = Instance.new("BindableFunction")
		event.OnInvoke = props.Callback
		props.Callback = event
	end

	StarterGui:SetCore("SendNotification", props)
end

function BaseInterfaceController.change.ResetButtonCallback(self: Self)
	local value = self.ResetButtonCallback
	if typeof(self.ResetButtonCallback) == "function" then
		local event = Instance.new("BindableEvent")
		event.Event:Connect(function() self.ResetButtonCallback() end)
		value = event
	end
	StarterGui:SetCore("ResetButtonCallback", value)
end

--#region Bind properties
for _, prop in CORE_PROPERTIES do
	BaseInterfaceController.get[prop] = function(self: Self)
		return StarterGui:GetCore(prop)
	end
	BaseInterfaceController.set[prop] = function(self: Self, v: any)
		return StarterGui:SetCore(prop, v)
	end
end

for _, callback in CORE_FUNCTIONS do
	BaseInterfaceController[callback] = function(self: Self, ...)
		StarterGui:SetCore(callback, ...)
	end
end

for prop, coreGui in CORE_GUI_PROPERTIES do
	BaseInterfaceController.get[prop] = function(self: Self)
		return StarterGui:GetCoreGuiEnabled(coreGui)
	end
	BaseInterfaceController.set[prop] = function(self: Self, v: boolean)
		StarterGui:SetCoreGuiEnabled(coreGui, v)
	end
end
--#endregion

return table.freeze(BaseInterfaceController) :: {
	new: typeof(BaseInterfaceController.new),
}
