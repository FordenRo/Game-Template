--!native
local Class = require("./Class")

local Meta = {}
local components = {}

local Component = {}
Component.extends = Class

export type Component<Instance> = {
	Instance: Instance,
} & Class.Class

type Self = Component<Instance>

function Meta.__call<Instance, B, S>(
	_,
	instance: Instance,
	base: B,
	source: S?
): Component<Instance> & B & S
	assert(
		components[instance] == nil,
		`{instance.Name} already has a Component`
	)

	local self: Self = Class(base, source)

	self.Instance = instance

	self.Instance.Destroying:Once(
		function() components[self.Instance] = nil end
	)

	components[self.Instance] = self
	return self
end

function Component.new<Instance, S>(
	instance: Instance,
	source: S?
): Component<Instance> & S
	return Component(instance, { extends = Component }, source)
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

setmetatable(Component, Meta)

return table.freeze(Component) :: setmetatable<
	{
		--- Creates a new component
		new: typeof(Component.new),
		--- Returns `Component` from `Instance` or nil if not exists.
		getComponent: typeof(Component.getComponent),
	},
	{
		__call: typeof(Meta.__call),
	}
>
