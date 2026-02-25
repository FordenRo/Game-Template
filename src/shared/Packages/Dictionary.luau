--!native
local Signal = require("./Signal")

-- Preload globals
local table = table

local Dictionary = { get = {} }
local Meta = {}

export type Dictionary<V> = typeof(setmetatable(
	{} :: {
		--- Keys getter of the dictionary.
		Keys: { string },
		--- Values getter of the dictionary.
		Values: { V },
		--- Whether the dictionary is empty.
		IsEmpty: boolean,
		--- Fired immediately after the dictionary is changed.
		Changed: Signal.Signal<string, V, V>,

		--- Merges given `value` with the dictionary.
		Merge: (self: Dictionary<V>, value: any) -> (),
		--- Returns a key of the given `value`.
		KeyOf: (self: Dictionary<V>, value: V) -> string,
		--- Checks if a key contains in the dictionary.
		ContainsKey: (self: Dictionary<V>, key: string) -> boolean,
		--- Checks if a value contains in the dictionary.
		ContainsValue: (self: Dictionary<V>, value: V) -> boolean,
		--- Returns mapped dictionary using the `f` function.
		Mapped: typeof(Dictionary.Mapped),
		--- Rturns filtered dictionary using the `f` function.
		Filtered: (
			self: Dictionary<V>,
			f: (V, string) -> boolean
		) -> Dictionary<V>,
		--- Returns the table of the dictionary.
		asTable: (self: Dictionary<V>) -> { [string]: V },
		--- Returns a copy of the dictionary.
		Clone: <Dictionary>(self: Dictionary) -> Dictionary,
		--- Returns a deep copy of the dictionary.
		DeepClone: <Dictionary>(self: Dictionary) -> Dictionary,
	},
	{} :: {
		__len: (self: Dictionary<V>) -> number,
		__concat: typeof(Dictionary.__concat),
		__iter: (self: Dictionary<V>) -> () -> (string, V),
	}
))

type Self = {
	__table: { [string]: any },
} & Dictionary<any>

function Meta.__call<V>(_, t: { [string]: V }): Dictionary<V>
	local self = setmetatable({
		__table = t,
		Changed = Signal.new(),
	}, Dictionary)

	table.freeze(self)
	return self
end

function Dictionary.zip<V>(keys: { string }, values: { V }): Dictionary<V>
	local t = {}
	for i, k in keys do
		t[k] = values[i]
	end
	return Dictionary(t)
end

function Dictionary.isDictionary(obj: any): boolean
	return typeof(obj) == "table" and getmetatable(obj) == Dictionary
end

--#region Getters

function Dictionary.get.Keys(self: Self)
	local t = {}
	for k, _ in self do
		table.insert(t, k)
	end
	return t
end

function Dictionary.get.Values(self: Self)
	local t = {}
	for _, v in self do
		table.insert(t, v)
	end
	return t
end

function Dictionary.get.IsEmpty(self: Self) return next(self.__table) == nil end

--#endregion

--#region Methods

function Dictionary.Merge(self: Self, value: any)
	for k, v in value do
		self[k] = v
	end
end

function Dictionary.KeyOf(self: Self, value: any)
	for k, v in self do
		if v == value then return k end
	end
	return nil
end

function Dictionary.ContainsKey(self: Self, key: any) return self[key] ~= nil end

function Dictionary.ContainsValue(self: Self, value: any)
	return self:KeyOf(value) ~= nil
end

function Dictionary.Mapped<V, M>(
	self: Dictionary<V>,
	f: (V, string) -> M
): Dictionary<M>
	local t = {}
	for k, v in self do
		t[k] = f(v, k)
	end
	return Dictionary(t)
end

function Dictionary.Filtered(self: Self, f: (any, any) -> boolean)
	local t = {}
	for k, v in self do
		if f(v, k) then t[k] = v end
	end
	return Dictionary(t)
end

function Dictionary.Clone(self: Self)
	return Dictionary(table.clone(self.__table))
end

local function deepClone<T>(t: T): T
	local clone = table.clone(t)
	for k, v in clone do
		if typeof(v) == "table" then clone[k] = deepClone(v) end
	end
	return clone
end

function Dictionary.DeepClone(self: Self)
	return Dictionary(deepClone(self.__table))
end

function Dictionary.asTable(self: Self) return self.__table end

--#endregion

--#region Metamethods

function Dictionary.__index(self: Self, k)
	return Dictionary[k]
		or Dictionary.get[k] and Dictionary.get[k](self)
		or self.__table[k]
end

function Dictionary.__newindex(self: Self, k, v)
	local old = self.__table[k]
	if old == v then return end
	self.__table[k] = v

	self.Changed:Fire(k, v, old)
end

function Dictionary.__eq(self: Self, obj: any)
	return typeof(obj) == "table" and (obj.__table or obj) == self.__table
end

function Dictionary.__len(self: Self) return #self.Keys end

function Dictionary.__iter(self: Self) return next, self.__table end

function Dictionary.__concat<V, A>(self: Dictionary<V>, obj: { A }): Dictionary<V | A>
	local t = table.clone(self.__table)
	for k, v in obj do
		t[k] = v
	end
	return Dictionary(t)
end

function Dictionary.__tostring(self: Self)
	if self.IsEmpty then return "Dictionary()" end

	local str = "\n"
	for k, v in self do
		str ..= `\t{tostring(k)} = {tostring(v)}\n`
	end
	return `Dictionary({str})`
end

--#endregion

setmetatable(Dictionary, Meta)

return table.freeze(Dictionary) :: setmetatable<
	{
		--- Creates a Dictionary of the keys and the values.
		zip: typeof(Dictionary.zip),
	},
	{
		__call: typeof(Meta.__call),
	}
>
