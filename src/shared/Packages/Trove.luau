local RunService = game:GetService("RunService")

-- Preloads globals
local task = task
local table = table

--- Represents all trackable objects by Trove.
type Trackable =
	Instance
	| RBXScriptConnection
	| thread
	| ((...any) -> ...any)
	| Destroyable
	| Disconnectable

type Destroyable = {
	Destroy: (self: Destroyable) -> (),
}

type Disconnectable = {
	Disconnect: (self: Disconnectable) -> (),
}

export type Trove = {
	--[[
		Creates and adds another trove to itself. This is just shorthand
		for `trove:Add(Trove.new())`. This is useful for contexts where
		the trove object is present, but the class itself isn't.

		This does _not_ clone the trove. In other words, the objects in the
		trove are not given to the new constructed trove. This is simply to
		construct a new Trove and add it as an object to track.

		```lua
		local trove = Trove.new()
		local subTrove = trove:Extend()

		trove:Clean() -- Cleans up the subTrove too
		```
	]]
	Extend: (self: Trove) -> Trove,

	--[[
		Calls `RunService:BindToRenderStep` and registers a function in the
		trove that will call `RunService:UnbindFromRenderStep` on cleanup.

		```lua
		trove:BindToRenderStep("Test", Enum.RenderPriority.Last.Value, function(dt)
			-- Do something
		end)
		```
	]]
	BindToRenderStep: (
		self: Trove,
		name: string,
		priority: number,
		fn: (dt: number) -> ()
	) -> (),

	--[[
		Adds an object to the trove. Once the trove is cleaned or
		destroyed, the object will also be cleaned up.

		The following types are accepted (e.g. `typeof(object)`):

		| Type | Cleanup |
		| ---- | ------- |
		| `Instance` | `object:Destroy()` |
		| `RBXScriptConnection` | `object:Disconnect()` |
		| `function` | `object()` |
		| `thread` | `task.cancel(object)` |
		| `table` | `object:Destroy()` _or_ `object:Disconnect()` |
		| `table` with `cleanupMethod` | `object:<cleanupMethod>()` |

		Returns the object added.

		```lua
		-- Add a part to the trove, then destroy the trove,
		-- which will also destroy the part:
		local part = Instance.new("Part")
		trove:Add(part)
		trove:Destroy()

		-- Add a function to the trove:
		trove:Add(function()
			print("Cleanup!")
		end)
		trove:Destroy()

		-- Standard cleanup from table:
		local tbl = {}
		function tbl:Destroy()
			print("Cleanup")
		end
		trove:Add(tbl)

		-- Custom cleanup from table:
		local tbl = {}
		function tbl:DoSomething()
			print("Do something on cleanup")
		end
		trove:Add(tbl, "DoSomething")
		```
	]]
	Add: <T>(self: Trove, object: T & Trackable, cleanupMethod: string?) -> T,

	--- Adds all passed objects in the trove.
	AddAll: (self: Trove, ...Trackable) -> (),

	--[[
		Removes the object from the Trove and cleans it up.

		```lua
		local part = Instance.new("Part")
		trove:Add(part)
		trove:Remove(part)
		```
	]]
	Remove: <T>(self: Trove, object: T & Trackable) -> (),

	--[[
		Cleans up all objects in the trove. This is
		similar to calling `Remove` on each object
		within the trove.
	]]
	Clean: (self: Trove) -> (),

	--[[
		Returns true if there is no objects in the trove.
		Calling this after `Trove:Clean()` will also
		return true
	]]
	IsEmpty: (self: Trove) -> (),

	--[[
		Attaches the trove to a Roblox instance. Once this
		instance is removed from the game (parent or ancestor's
		parent set to `nil`), the trove will automatically
		clean up.

		This inverses the ownership of the Trove object, and should
		only be used when necessary. In other words, the attached
		instance dictates when the trove is cleaned up, rather than
		the trove dictating the cleanup of the instance.

		```lua
		trove:AttachToInstance(somePart)
		trove:Add(function()
			print("Cleaned")
		end)

		-- Destroying the part will cause the trove to clean up, thus "Cleaned" printed:
		somePart:Destroy()
		```
	]]
	AttachToInstance: (self: Trove, instance: Instance) -> RBXScriptConnection,

	--[[
		Cleans up all objects in the trove. This is
		similar to calling `Remove` on each object
		within the trove.
	]]
	Destroy: (self: Trove) -> (),
}

type Self = { objects: { [any]: (any) -> () } } & Trove

--[[
	A Trove is helpful for tracking any sort of object during
	runtime that needs to get cleaned up at some point.
]]
local Trove = {}
Trove.__index = Trove

--[[
	Constructs a Trove object.

	```lua
	local trove = Trove.new()
	```
]]
function Trove.new(): Trove return setmetatable({ objects = {} }, Trove) end

do
	local TABLE_CLEAN_METHODS = { "Destroy", "Disconnect" }
	local CLEAN_METHODS = {
		Instance = function(v) v:Destroy() end,
		RBXScriptConnection = function(v) v:Disconnect() end,
		["function"] = function(v) v() end,
		thread = function(v: thread) task.cancel(v) end,
		table = function(v)
			for _, method in TABLE_CLEAN_METHODS do
				if typeof(v[method]) ~= "function" then continue end

				v[method](v)
				return
			end
			error(`Could'nt find cleanup method for {v}`)
		end,
	}

	function Trove.Add(self: Self, object: any, cleanupMethod: string?)
		local method = CLEAN_METHODS[typeof(object)]
		assert(method, `Can't add object with type {typeof(object)}`)
		self.objects[object] = method
		return object
	end
end

function Trove.AddAll(self: Self, ...)
	for _, v in { ... } do
		self:Add(v)
	end
end

function Trove.BindToRenderStep(
	self: Self,
	name: string,
	priority: number,
	fn: (dt: number) -> ()
)
	RunService:BindToRenderStep(name, priority, fn)
	self:Add(function() RunService:UnbindFromRenderStep(name) end)
end

function Trove.Remove(self: Self, object: any)
	self.objects[object](object)
	self.objects[object] = nil
end

function Trove.Extend(self: Self) return self:Add(Trove.new()) end

function Trove.Clean(self: Self)
	for k, v in self.objects do
		v(k)
	end
	table.clear(self.objects)
end

function Trove.IsEmpty(self: Self) return next(self.objects) == nil end

function Trove.AttachToInstance(self: Self, instance: Instance)
	return self:Add(instance.Destroying:Connect(function() self:Destroy() end))
end

function Trove.Destroy(self: Self) self:Clean() end

return table.freeze(Trove) :: {
	--- Creates a Trove.
	new: typeof(Trove.new),
}
