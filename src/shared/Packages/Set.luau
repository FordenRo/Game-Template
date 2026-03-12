--!native
local Signal = require("./Signal")

-- Preload globals
local table = table
local next = next

local Set = { get = {} }
local Meta = {}

export type Set<V> = typeof(setmetatable(
	{} :: {
		--- Whether the set has no items.
		IsEmpty: boolean,

		--[[
			Fired immediately after an item is added to the set.

			```luau
			local set = Set()
			set.ItemAdded:Connect(function(value)
				print(`Fired {value}`)
			end)
			set:Add("test") -- Fired "test"
			```
		]]
		ItemAdded: Signal.Signal<V>,
		--[[
			Fired immediately after an item is removed from the array.

			```luau
			local set = Set("test")
			set.ItemAdded:Connect(function(value)
				print(`Fired {value}`)
			end)
			set:Remove("test") -- Fired "test"
			```
		]]
		ItemRemoved: Signal.Signal<V>,

		--- Adds a `value` to the set.
		Add: (self: Set<V>, value: V) -> (),
		--- Adds given set to the set.
		Merge: (self: Set<V>, value: Set<V> | { [V]: any }) -> (),
		--- Removes the `value` from the set.
		Remove: (self: Set<V>, value: V) -> (),
		--- Checks if a value contains in the set.
		Contains: (self: Set<V>, value: V) -> boolean,
		--- Returns mapped set using the `f` function.
		Mapped: typeof(Set.Mapped),
		--- Returns filtered set using the `f` function.
		Filtered: (self: Set<V>, f: (V) -> boolean) -> Set<V>,
		--- Returns sorted array from the set using the `f` function.
		Sorted: (self: Set<V>, f: (V, V) -> boolean) -> Set<V>,
		--- Returns a shallow copy of the set.
		Clone: <Set>(self: Set) -> Set,
		--- Returns a deep copy of the set.
		DeepClone: <Set>(self: Set) -> Set,
		--- Returns set content as an array.
		toArray: (self: Set<V>) -> { V },
		--- Returns the table that linked to the set.
		asTable: (self: Set<V>) -> { [V]: true },
	},
	{} :: {
		__len: (self: Set<V>) -> number,
		__concat: typeof(Set.__concat),
		__add: typeof(Set.__add),
		__iter: (self: Set<V>) -> () -> (number, V),
	}
))

type Self = setmetatable<{
	__table: { any },
}, { __index: Set<any> }>

--#region Constructor methods

function Meta.__call<V>(_, ...: V): Set<V> return Set.fromArray({ ... }) end

function Set.fromTable<V>(t: { [V]: true }): Set<V>
	local self: Self = setmetatable({
		__table = t,
		ItemAdded = Signal.new(),
		ItemRemoved = Signal.new(),
	}, Set)

	table.freeze(self)
	return self
end

function Set.fromArray<V>(t: { V }): Set<V>
	local mapped = {}
	for _, v in t do
		mapped[v] = true
	end
	return Set.fromTable(mapped)
end

function Set.isSet(obj: any)
	return typeof(obj) == "table" and getmetatable(obj) == Set
end

--#endregion

function Set.get.IsEmpty(self: Self) return next(self.__table) == nil end

--#region Methods

function Set.Add(self: Self, value: any)
	if self:Contains(value) then return end

	self.__table[value] = true
	self.ItemAdded:Fire(value)
end

function Set.Merge(self: Self, value: any)
	for v, _ in value do
		self:Add(v)
	end
end

function Set.Remove(self: Self, value: any)
	if not self:Contains(value) then return end

	self.__table[value] = nil
	self.ItemRemoved:Fire(value)
end

function Set.Contains(self: Self, value: any) return self.__table[value] ~= nil end

function Set.Mapped<V, M>(self: Self, f: (V) -> M): Set<M>
	local t = {}
	for v, _ in self.__table do
		t[f(v)] = true
	end
	return Set.fromTable(t)
end

function Set.Filtered(self: Self, f: (any) -> boolean)
	local t = {}
	for v, _ in self.__table do
		if f(v) then t[v] = true end
	end
	return Set.fromTable(t)
end

function Set.Sorted(self: Self, f: (any, any) -> boolean)
	local t = self:toArray()
	table.sort(t, f)
	return t
end

function Set.Clone(self: Self)
	return table.freeze(
		setmetatable({ __table = table.clone(self.__table) }, Set)
	)
end

local function deepClone<T>(t: T): T
	local clone = table.clone(t)
	for k, v in clone do
		if typeof(v) == "table" then clone[k] = deepClone(v) end
	end
	return clone
end

function Set.DeepClone(self: Self) return Set.fromTable(deepClone(self.__table)) end

function Set.toArray(self: Self)
	local list = {}
	for v, _ in self.__table do
		table.insert(list, v)
	end
	return list
end

function Set.asTable(self: Self) return self.__table end

--#endregion

--#region Metamethods

function Set.__index(self: Self, k: any)
	return Set[k] or Set.get[k] and Set.get[k](self) or self.__table[k]
end

function Set.__newindex(self: Self, k: any, v: any) error() end

function Set.__concat<V, A>(self: Self, obj: { A }): Set<V | A>
	local t = table.clone(self.__table)
	for v, _ in obj do
		t[v] = true
	end
	return Set.fromTable(t)
end

function Set.__add<V, A>(self: Set<V>, obj: A): Set<V | A>
	local t = table.clone(self.__table)
	t[obj] = true
	return Set.fromTable(t)
end

function Set.__len(self: Self) return #self:toArray() end

function Set.__iter(self: Self) return next, self:toArray() end

function Set.__tostring(self: Self)
	return `Set({table.concat(
		self:Mapped(function(v) return tostring(v) end):toArray(),
		", "
	)})`
end

--#endregion

setmetatable(Set, Meta)

return table.freeze(Set) :: setmetatable<{
	fromTable: typeof(Set.fromTable),
	fromArray: typeof(Set.fromArray),
	isSet: typeof(Set.isSet),
}, {
	__call: typeof(Meta.__call),
}>
