--[[
    Replicated interface

    Written by: FordenRo
    Version: 1.0.0
]]

--!native
local RunService = game:GetService("RunService")

local Class = require("./Class")
local Signal = require("./Signal")

local Replicated = {}
Replicated.extends = Class

export type Replicated = {
	--- **Server-only** Fired when `SendServer()` is called on the client.
	ServerReceived: Signal.Signal<Player, ...any>,
	--- **Client-only** Fired when `SendClient()` is called on the server.
	ClientReceived: Signal.Signal<...any>,

	--- **Client-only** Fires `ServerReceived` signal and `onServerReceived` method on the server.
	SendServer: (self: Replicated, ...any) -> (),
	--- **Server-only** Fires `ClientReceived` signal and `onClientReceived` method on the specific client.
	SendClient: (self: Replicated, player: Player, ...any) -> (),
	--- **Server-only** Fires `ClientReceived` signal and `onClientReceived` method on all clients.
	SendAllClients: (self: Replicated, ...any) -> (),

	--- **Client-only** Fires `ServerReceived` signal and `onServerReceived` method on the server unreliable.
	--- Has a 1000 byte limit to the payload of the event. Events with larger payloads are dropped.
	USendServer: (self: Replicated, ...any) -> (),
	--- **Server-only** Fires `ClientReceived` signal and `onClientReceived` method on the specific client unreliable.
	--- Has a 1000 byte limit to the payload of the event. Events with larger payloads are dropped.
	USendClient: (self: Replicated, player: Player, ...any) -> (),
	--- **Server-only** Fires `ClientReceived` signal and `onClientReceived` method on all clients unreliable.
	--- Has a 1000 byte limit to the payload of the event. Events with larger payloads are dropped.
	USendAllClients: (self: Replicated, ...any) -> (),

	--- **Client-only** Invokes `onClientInvoked` method on the server.
	InvokeServer: (self: Replicated, ...any) -> ...any,
	--- **Server-only** Invokes `onServerInvoked` method on the client.
	InvokeClient: (self: Replicated, player: Player, ...any) -> ...any,

	--- Creates `RemoteEvent`, `UnreliableRemoteEvent` and `RemoteFunction` of provided arguments.
	CreateRemotes: (
		(self: Replicated, parent: Instance, prefix: string?) -> ()
	) & ((self: Replicated, scope: string) -> ()),
}

type Self = {
	RE: RemoteEvent,
	URE: UnreliableRemoteEvent,
	RF: RemoteFunction,

	onServerInvoked: ((self: Self, player: Player, ...any) -> ...any)?,
	onClientInvoked: ((self: Self, ...any) -> ...any)?,

	onServerReceived: ((self: Self, player: Player, ...any) -> ())?,
	onClientReceived: ((self: Self, ...any) -> ())?,
} & Replicated

function Replicated.onExtended(self: Self)
	error("Replicated can only be implemented.")
end

function Replicated.onImplemented(self: Self)
	self.ServerReceived = Signal.new()
	self.ClientReceived = Signal.new()
end

function Replicated.CreateRemotes(
	self: Self,
	obj: Instance | string,
	prefix: string?
)
	local parent: Instance
	local name: string
	if typeof(obj) == "Instance" then
		parent = obj
		name = prefix or "Replicated"
	elseif typeof(obj) == "string" then
		parent = script
		name = obj
	else
		error(`Argument must be a string or Instance, but not {typeof(obj)}.`)
		return
	end

	if RunService:IsServer() then
		initServer(self, parent, name)
	else
		initClient(self, parent, name)
	end
end

function initServer(self: Self, parent: Instance, name: string)
	self.RE = Instance.new("RemoteEvent")
	self.RE.Name = `{name}RE`
	self.RE.Parent = parent

	self.URE = Instance.new("UnreliableRemoteEvent")
	self.URE.Name = `{name}URE`
	self.URE.Parent = parent

	self.RF = Instance.new("RemoteFunction")
	self.RF.Name = `{name}RF`
	self.RF.Parent = parent

	local function callback(...)
		if self.onServerReceived then self:onServerReceived(...) end
		self.ServerReceived:Fire(...)
	end
	self.RE.OnServerEvent:Connect(callback)
	self.URE.OnServerEvent:Connect(callback)
	self.RF.OnServerInvoke = function(...)
		if self.onServerInvoked then return self:onServerInvoked(...) end
		error("No onServerInvoked method implemented")
	end
end

function initClient(self: Self, parent: Instance, name: string)
	self.RE = parent:WaitForChild(`{name}RE`)
	self.URE = parent:WaitForChild(`{name}URE`)
	self.RF = parent:WaitForChild(`{name}RF`)

	local function callback(...)
		if self.onClientReceived then self:onClientReceived(...) end
		self.ClientReceived:Fire(...)
	end
	self.RE.OnClientEvent:Connect(callback)
	self.URE.OnClientEvent:Connect(callback)
	self.RF.OnClientInvoke = function(...)
		if self.onClientInvoked then return self:onClientInvoked(...) end
		error("No onClientInvoked method implemented")
	end
end

function Replicated.SendServer(self: Self, ...) self.RE:FireServer(...) end

function Replicated.SendClient(self: Self, player: Player, ...)
	self.RE:FireClient(player, ...)
end

function Replicated.SendAllClients(self: Self, ...) self.RE:FireAllClients(...) end

function Replicated.USendServer(self: Self, ...) self.URE:FireServer(...) end

function Replicated.USendClient(self: Self, player: Player, ...)
	self.RE:FireClient(player, ...)
end

function Replicated.USendAllClients(self: Self, ...)
	self.URE:FireAllClients(...)
end

function Replicated.InvokeServer(self: Self, ...)
	return self.RF:InvokeServer(...)
end

function Replicated.InvokeClient(self: Self, player: Player, ...)
	return self.RF:InvokeClient(player, ...)
end

return table.freeze(Replicated) :: {
	CreateRemotes: index<Replicated, "CreateRemotes">,
}
