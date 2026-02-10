--[[
	Signal module

	Written by: FordenRo
	Version: 0.3.0
]]

-- Preload globals
local table = table
local task = task
local coroutine = coroutine

local Connection = {}
Connection.__index = Connection

--[[
	Represents a connection to a signal.
    
	```lua
	local connection = signal:Connect(function() end)
	print(connection.Connected) --> true
	connection:Disconnect()
	print(connection.Connected) --> false
	```
]]
export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

type ConnectionSelf = {
	signal: Self,
	next: ConnectionSelf,
	callback: (...any) -> (),
} & Connection

function Connection.new(signal, callback: (...any) -> ()): Connection
	local self: ConnectionSelf = setmetatable({}, Connection)

	self.Connected = true
	self.callback = callback
	self.signal = signal

	return self
end

function Connection.Disconnect(self: ConnectionSelf)
	if not self.Connected then return end
	self.Connected = false

	-- Unhook the node, but DON'T clear it. That way any fire calls that are
	-- currently sitting on this node will be able to iterate forwards off of
	-- it, but any subsequent fire calls will not hit it, and it will be GCed
	-- when no more fire calls are sitting on it.
	if self.signal.handlerListHead == self then
		self.signal.handlerListHead = self.next
	else
		local prev = self.signal.handlerListHead
		while prev and prev.next ~= self do
			prev = prev.next
		end
		if prev then prev.next = self.next end
	end
end

local Signal = {}
Signal.__index = Signal

export type Signal<T...> = {
	--[[
		Fire the signal, which will call all of the connected functions with the given arguments.
		```lua
		signal:Fire("Hello")

		-- Any number of arguments can be fired:
		signal:Fire("Hello", 32, {Test = "Test"}, true)
		```
	]]
	Fire: (self: Signal<T...>, T...) -> (),

	--[[
		Same as `Fire`, but uses `task.defer` internally & doesn't take advantage of thread reuse.
		```lua
		signal:FireDeferred("Hello")
		```
	]]
	FireDeferred: (self: Signal<T...>, T...) -> (),

	--[[
		Connects a function to the signal, which will be called anytime the signal is fired.
		```lua
		signal:Connect(function(msg, num)
			print(msg, num)
		end)

		signal:Fire("Hello", 25)
		```
	]]
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,

	--[[
		Connects a function to the signal, which will be called the next time the signal fires. Once
		the connection is triggered, it will disconnect itself.
		```lua
		signal:Once(function(msg, num)
			print(msg, num)
		end)

		signal:Fire("Hello", 25)
		signal:Fire("This message will not go through", 10)
		```
	]]
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,

	--[[
		Disconnects all connections from the signal.
		```lua
		signal:DisconnectAll()
		```
	]]
	DisconnectAll: (self: Signal<T...>) -> (),

	--[[
		Cleans up the signal.

		Technically, this is only necessary if the signal is created using
		`Signal.wrap`. Connections should be properly GC'd once the signal
		is no longer referenced anywhere. However, it is still good practice
		to include ways to strictly clean up resources. Calling `Destroy`
		on a signal will also disconnect all connections immediately.
		```lua
		signal:Destroy()
		```
	]]
	Destroy: (self: Signal<T...>) -> (),

	--[[
		Yields the current thread until the signal is fired, and returns the arguments fired from the signal.
		Yielding the current thread is not always desirable. If the desire is to only capture the next event
		fired, using `Once` might be a better solution.
		```lua
		task.spawn(function()
			local msg, num = signal:Wait()
			print(msg, num) --> "Hello", 32
		end)
		signal:Fire("Hello", 32)
		```
	]]
	Wait: (self: Signal<T...>) -> T...,
}

type Self = {
	handlerListHead: ConnectionSelf?,
	proxyHandler: RBXScriptConnection?,
	yieldedThreads: { thread },
} & Signal<...any>

function Signal.new<T...>(): Signal<T...>
	local self: Self = setmetatable({}, Signal)

	self.yieldedThreads = {}

	return self
end

function Signal.wrap<T...>(rbxScriptSignal: RBXScriptSignal<T...>): Signal<T...>
	assert(
		typeof(rbxScriptSignal) == "RBXScriptSignal",
		"Argument #1 to Signal.wrap must be a RBXScriptSignal; got "
			.. typeof(rbxScriptSignal)
	)

	local signal: Self = Signal.new()

	signal.proxyHandler = rbxScriptSignal:Connect(
		function(...) signal:Fire(...) end
	)

	return signal
end

function Signal.isSignal(obj: any)
	return type(obj) == "table" and getmetatable(obj) == Signal
end

function Signal.Connect(self: Self, callback: (...any) -> ())
	local connection: ConnectionSelf = Connection.new(self, callback)

	if self.handlerListHead then
		connection.next = self.handlerListHead
		self.handlerListHead = connection
	else
		self.handlerListHead = connection
	end
	return connection
end

function Signal.Once(self: Self, callback: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal.DisconnectAll(self: Self)
	local item = self.handlerListHead
	while item do
		item.Connected = false
		item = item.next
	end
	self.handlerListHead = nil

	for _, thread in self.yieldedThreads do
		if coroutine.status(thread) == "suspended" then
			warn(
				debug.traceback(
					thread,
					"signal disconnected; yielded thread cancelled",
					2
				)
			)
			task.cancel(thread)
		end
	end
	table.clear(self.yieldedThreads)
end

function Signal.Fire(self: Self, ...)
	local item = self.handlerListHead
	while item do
		if item.Connected then
			task.spawn(function(...)
				if item.Connected then item.callback(...) end
			end, ...)
		end
		item = item.next
	end
end

function Signal.FireDeferred(self: Self, ...)
	local item = self.handlerListHead
	while item do
		task.defer(function(...)
			if item.Connected then item.callback(...) end
		end, ...)
		item = item.next
	end
end

function Signal.Wait(self: Self)
	local thread = coroutine.running()
	table.insert(self.yieldedThreads, thread)

	self:Once(function(...)
		table.remove(
			self.yieldedThreads,
			table.find(self.yieldedThreads, thread)
		)

		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, ...)
		end
	end)
	return coroutine.yield()
end

function Signal.Destroy(self: Self)
	self:DisconnectAll()
	if self.proxyHandler then self.proxyHandler:Disconnect() end
end

function Signal.__tostring(self: Self) return "Signal" end

return table.freeze(Signal) :: {
	--- Creates a new Signal
	new: typeof(Signal.new),

	--[[
		Creates a new Signal that wraps around an RBXScriptSignal.

		For example:
		```lua
		local signal = Signal.wrap(workspace.ChildAdded)
		signal:Connect(function(part) print(part.Name .. " added") end)
		Instance.new("Part").Parent = workspace
		```
	]]
	wrap: typeof(Signal.wrap),

	--- Checks if a `obj` is a `Signal`
	isSignal: typeof(Signal.isSignal),
}
