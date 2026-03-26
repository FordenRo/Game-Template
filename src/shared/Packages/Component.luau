--!native
local Class = require("./Class")

local components = {}

local Component = {}
Class(Component)

export type Component<Instance> = {
	Instance: Instance,
} & Class.Class

type Self = Component<Instance>

function Component.init(self: Self, instance: Instance)
	self.Instance = instance

	self.Instance.Destroying:Once(
		function() components[self.Instance] = nil end
	)

	components[self.Instance] = self
end

function Component.new<Instance>(instance: Instance): Component<Instance>
	local self: Self = Class.new(Component)

	self:init(instance)

	return self
end

function Component.getComponent<Instance>(instance: Instance): Component<Instance>?
	return components[instance]
end

function Component.Clone(self: Self)
	local cloned = self:Super():Clone()
	cloned.Instance = self.Instance:Clone()
	components[cloned.Instance] = cloned
	return cloned
end

return table.freeze(Component) :: {
	--- Creates a new component
	new: typeof(Component.new),
	--- Returns `Component` from `Instance` or nil if not exists.
	getComponent: typeof(Component.getComponent),
}
