--[[
	Array data type

	Written by: FordenRo
	Version: 1.0.0
]]

--!native
local Signal = require("./Signal")

-- Preload globals
local table = table
local next = next

local Array = { get = {} }
local Meta = {}

export type Array<V> = typeof(setmetatable(
	{} :: {
		--- Whether the array has no items.
		IsEmpty: boolean,
		--- The first item of the array.
		First: V?,

		--[[
			Fired immediately after an item of the array changes.

			```luau
			local array = Array(10, 22, "sd", 46)
			array.ItemChanged:Connect(function(index: number, new, old)
				print(`Fired {index} {new} {old}`)
			end)
			array[1] = 4 -- Fired 1, 4, 10
			```
		]]
		ItemChanged: Signal.Signal<number, V, V>,

		--[[
			Fired immediately after an item is added to the array.

			```luau
			local array = Array()
			array.ItemAdded:Connect(function(index: number, value)
				print(`Fired {index} {value}`)
			end)
			array:Add("test") -- Fired 1 "test"
			```
		]]
		ItemAdded: Signal.Signal<number, V>,

		--[[
			Fired immediately after an item is removed from the array.

			```luau
			local array = Array(5)
			array.ItemAdded:Connect(function(index: number, value)
				print(`Fired {index} {value}`)
			end)
			array:Remove(1) -- Fired 1 5
			```
		]]
		ItemRemoved: Signal.Signal<number, V>,

		--- Returns array content as a table.
		asTable: (self: Array<V>) -> { V },

		--[[
			Adds a `value` to the array at the given index or at the end.

			This will fire `ItemAdded` signal.
		]]
		Add: (self: Array<V>, value: V, index: number?) -> (),

		--- Adds all values to the array.
		AddAll: (self: Array<V>, ...V) -> (),

		--- Adds given table or array to the array.
		Merge: (self: Array<V>, { V } | Array<V>) -> (),

		--[[
			Removes an item at the index from the array and returns it.

			This will fire `ItemRemoved` signal.
		]]
		RemoveAt: (self: Array<V>, index: number) -> V,

		--[[
			Removes the `value` from the array and returns index of it.

			This will fire `ItemRemoved` signal.
		]]
		Remove: (self: Array<V>, value: V) -> number?,

		--- Returns an index of the given `value`.
		IndexOf: (self: Array<V>, value: V) -> number?,

		--- Checks if a value contains in the array.
		Contains: (self: Array<V>, value: V) -> boolean,

		--- Returns mapped array using the `f` function.
		Mapped: typeof(Array.Mapped),

		--- Returns filtered array using the `f` function.
		Filtered: (self: Array<V>, f: (V) -> boolean) -> Array<V>,

		--- Returns reversed array.
		Reversed: (self: Array<V>) -> Array<V>,

		--- Return sorted array using the `f` function.
		Sorted: (self: Array<V>, f: (V, V) -> boolean) -> Array<V>,

		--- Returns randomized array.
		Randomized: (self: Array<V>, seed: number?) -> Array<V>,

		--- Returns an array containing only unique items.
		Unified: (self: Array<V>) -> Array<V>,

		--- Returns a copy of the array.
		Clone: <Array>(self: Array) -> Array,

		--- Returns a deep copy of the array.
		DeepClone: <Array>(self: Array) -> Array,
	} & { V },
	{} :: {
		__len: (self: Array<V>) -> number,
		__concat: typeof(Array.__concat),
		__add: typeof(Array.__add),
		__mul: typeof(Array.__mul),
		__iter: (self: Array<V>) -> () -> (number, V),
	}
))

type Self = {
	__table: { any },
} & Array<any>

function Meta.__call<V>(_, ...: V): Array<V> return Array.fromTable({ ... }) end

function Array.fromTable<V>(t: { V }): Array<V>
	local self = setmetatable({
		__table = t,
		ItemChanged = Signal.new(),
		ItemAdded = Signal.new(),
		ItemRemoved = Signal.new(),
	}, Array)

	table.freeze(self)
	return self
end

function Array.fromKeys<V>(t: V): Array<keyof<V>>
	local keys = {}
	for k, _ in t do
		table.insert(keys, k)
	end
	return Array.fromTable(keys)
end

function Array.filled<V>(count: number, obj: V): Array<V>
	return Array.fromTable(table.create(count, obj))
end

function Array.isArray(obj: any)
	return typeof(obj) == "table" and getmetatable(obj) == Array
end

function Array.get.First(self: Self) return self[1] end

function Array.get.IsEmpty(self: Self) return next(self.__table) == nil end

function Array.Add(self: Self, value: any, index: number?)
	if index then
		table.insert(self.__table, index, value)
	else
		table.insert(self.__table, value)
	end
	self.ItemAdded:Fire(index or #self.__table, value)
end

function Array.AddAll(self: Self, ...: any)
	for _, v in { ... } do
		self:Add(v)
	end
end

function Array.Merge(self: Self, value: any)
	for _, v in value do
		self:Add(v)
	end
end

function Array.RemoveAt(self: Self, index: number)
	local val = table.remove(self.__table, index)
	self.ItemRemoved:Fire(index, val)
	return val
end

function Array.Remove(self: Self, value: any)
	local index = self:IndexOf(value)
	if not index then return end
	self.ItemRemoved:Fire(index, self:RemoveAt(index))
	return index
end

function Array.IndexOf(self: Self, value: any)
	return table.find(self.__table, value)
end

function Array.Contains(self: Self, value: any)
	return table.find(self.__table, value) ~= nil
end

function Array.Mapped<V, M>(self: Array<V>, f: (V) -> M): Array<M>
	local t = {}
	for k, v in self do
		table.insert(t, f(v))
	end
	return Array.fromTable(t)
end

function Array.Filtered(self: Self, f: (any) -> boolean)
	local t = {}
	for _, v in self do
		if f(v) then table.insert(t, v) end
	end
	return Array.fromTable(t)
end

function Array.Reversed(self: Self)
	local t = {}
	for i = #self, 1, -1 do
		table.insert(t, self[i])
	end
	return Array.fromTable(t)
end

function Array.Sorted(self: Self, f: (any, any) -> boolean)
	local arr = self:Clone()
	table.sort(arr.__table, f)
	return arr
end

function Array.Randomized(self: Self, seed: number?)
	local arr = self:Clone()
	Random.new(seed):Shuffle(arr.__table)
	return arr
end

function Array.Unified(self: Self)
	local arr = Array()
	for _, v in self do
		if not arr:Contains(v) then table.insert(arr.__table, v) end
	end
	return arr
end

function Array.Clone(self: Self)
	return Array.fromTable(table.clone(self.__table))
end

local function deepClone<T>(t: T): T
	local clone = table.clone(t)
	for k, v in clone do
		if typeof(v) == "table" then clone[k] = deepClone(v) end
	end
	return clone
end

function Array.DeepClone(self: Self)
	return Array.fromTable(deepClone(self.__table))
end

function Array.asTable(self: Self) return self.__table end

--- Metamethods ---

function Array.__index(self: Self, k: number | string)
	if typeof(k) == "string" then return Array[k] or Array.get[k](self) end
	return self.__table[k]
end

function Array.__newindex(self: Self, k: number, v: any)
	local old = self.__table[k]
	if old == v then return end
	self.__table[k] = v

	self.ItemChanged:Fire(k, v, old)
end

function Array.__eq(self: Self, obj: any)
	return typeof(obj) == "table" and (obj.__table or obj) == self.__table
end

function Array.__len(self: Self) return #self.__table end

function Array.__iter(self: Self) return next, self.__table end

function Array.__concat<V, A>(self: Array<V>, obj: { A }): Array<V | A>
	return Array.fromTable(
		table.move(obj.__table or obj, 1, #obj, #self + 1, self.__table)
	)
end

function Array.__add<V, A>(self: Array<V>, obj: A): Array<V | A>
	local t = table.clone(self.__table)
	table.insert(t, obj)
	return Array.fromTable(t)
end

function Array.__mul<V>(self: Array<V>, v: number): Array<V>
	local arr = Array()
	for i = 1, v do
		arr ..= self
	end
	return arr
end

function Array.__tostring(self: Self)
	return `Array({table.concat(self.__table, ", ")})`
end

setmetatable(Array, Meta)

return table.freeze(Array) :: setmetatable<
	{
		--- Creates an Array from the table.
		fromTable: typeof(Array.fromTable),
		--- Creates an Array from table keys.
		fromKeys: typeof(Array.fromKeys),
		--- Creates an Array filled with `obj`
		filled: typeof(Array.filled),
		--- Checks if an `obj` is an Array.
		isArray: typeof(Array.isArray),
	},
	{
		__call: typeof(Meta.__call),
	}
>
