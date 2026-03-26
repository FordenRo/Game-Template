--!native
local Signal = require("./Signal")

local Class = {}
local Meta = {}

export type Class = {
	--[[
		Fired immediately after a property of the class changes.

		```luau
		local class = Class.new({ test = 5 })
		class.Changed:Connect(function(property: string)
			print(`Fired "{property}"!`)
		end)
		class.test = 6 -- Fired "test"!
		```
	]]
	Changed: Signal.Signal<string>,

	--[[
		Fires immediately after the given property of the class changes.
		
		```luau
		local class = Class.new({ test = 5, name = "st" })
		class:GetPropertyChangedSignal("test"):Connect(function()
			print("Fired!")
		end)
		class.test = 6 -- Fired!
		class.name = "test" -- will not fire
		```
	]]
	GetPropertyChangedSignal: (
		self: Class,
		property: string
	) -> Signal.Signal<>,

	--- Gets the value of the class bypassing any getters.
	RawGet: (self: Class, key: string) -> any?,

	--- Sets the value of the class bypassing any setters and signals.
	RawSet: (self: Class, key: string, value: any) -> (),

	--- Returns a metatable of the class's parent that this class extends.
	Super: <Class>(self: Class) -> Class,

	--- Returns true if an class's base matches or inherits from a given base.
	IsA: (self: Class, base: any) -> boolean,

	--- Returns true if an class's base equals a given base.
	TypeOf: (self: Class, base: any) -> boolean,

	--- Creates a deep copy of an class.
	Clone: <Class>(self: Class) -> Class,
}

type Self = {
	__propChangedSignals: { [string]: Signal.Signal<> },
	__table: {},
	__base: Base,
} & Class

type Base = {
	extends: Base?,
	implements: { Base }?,
	onImplemented: (self: Base) -> (),
	onExtended: (self: Base) -> (),
	set: { [string]: (self: Base, value: any) -> boolean? }?,
	get: { [string]: (self: Base) -> any }?,
	change: { [string]: (self: Base) -> () }?,
}

--#region Utils

local function getExtendedGetter(base: Base, k: string)
	if base.get and base.get[k] then return base.get[k] end
	return base.extends and getExtendedGetter(base.extends, k)
end

local function getExtendedValue(base: Base, k: string)
	local value = base[k] or base.extends and getExtendedValue(base.extends, k)
	if value then return value end

	if base.implements then
		for _, v in base.implements do
			local implValue = getExtendedValue(v, k)
			if implValue then return implValue end
		end
	end

	return nil
end

local function getExtendedSetter(base: Base, k: string)
	if base.set and base.set[k] then return base.set[k] end
	return base.extends and getExtendedSetter(base.extends, k)
end

local function callChangeds(self, base: Base, k: string)
	if base.change and base.change[k] then base.change[k](self) end
	if base.extends then callChangeds(self, base.extends, k) end
	if base.implements then
		for _, v in base.implements do
			callChangeds(self, v, k)
		end
	end
end

local function callInitMethods(self, base: Base)
	local ext = base.extends
	if ext then
		if ext.onExtended then ext.onExtended(self) end
		callInitMethods(self, ext)
	end
	if base.implements then
		for _, v in base.implements do
			if v.onImplemented then v.onImplemented(self) end
			callInitMethods(self, v)
		end
	end
end

--#endregion

local ClassMeta = {}
do -- Set meta methods
	local metamethods = {
		"__index",
		"__newindex",
		"__call",
		"__concat",
		"__unm",
		"__add",
		"__sub",
		"__mul",
		"__div",
		"__idiv",
		"__mod",
		"__pow",
		"__tostring",
		"__eq",
		"__lt",
		"__le",
		"__len",
		"__iter",
	}
	for _, v in metamethods do
		ClassMeta[v] = function(self, ...)
			local callback = getExtendedValue(self.__base, v)
			return callback and callback(self, ...)
		end
	end
end

function Meta.__call<B, S>(_, base: B, source: S?): S & B & Class
	local t = source and source.__table or source or {}

	local self: Self = setmetatable({
		__table = t,
		__base = base,
		__propChangedSignals = source and source.__propChangedSignals or {},
		Changed = source and source.Changed or Signal.new(),
	}, ClassMeta)

	callInitMethods(self, base)
	return self
end

function Class.new<S>(source: S?): S & Class
	return Class({ extends = Class }, source)
end

function Class.isClass(obj: any): boolean
	return typeof(obj) == "table" and getmetatable(obj) == ClassMeta
end

function Class.GetPropertyChangedSignal(self: Self, property: string)
	local signal = self.__propChangedSignals[property]
	if not signal then
		signal = Signal.new()
		self.__propChangedSignals[property] = signal
	end
	return signal
end

local function deepClone<T>(t: T): T
	local clone = table.clone(t)
	for k, v in clone do
		if typeof(v) == "table" then clone[k] = deepClone(v) end
	end
	return clone
end

function Class.Clone(self: Self)
	return setmetatable({
		__table = deepClone(self.__table),
		__base = self.__base,
		__propChangedSignals = deepClone(self.__propChangedSignals),
		Changed = Signal.new(),
	}, ClassMeta)
end

function Class.RawGet(self: Self, key: string) return self.__table[key] end

function Class.RawSet(self: Self, key: string, value: any)
	self.__table[key] = value
end

function Class.Super(self: Self)
	return setmetatable({
		__table = self.__table,
		__base = self.__base.extends or Class,
	}, ClassMeta)
end

function Class.IsA(self: Self, base: Base?)
	if not base then return false end

	if self:TypeOf(base) then return true end
	if self.__base.implements then
		for _, v in self.__base.implements do
			self:IsA(v)
		end
	end
	return self:IsA(base.extends)
end

function Class.TypeOf(self: Self, base: any) return self.__base == base end

--#region Metamethods

function Class.__index(self: Self, k: string)
	local base = self.__base

	local get = getExtendedGetter(base, k)
	if get then return get(self) end

	local v = self.__table[k]
	return if v ~= nil then v else getExtendedValue(base, k)
end

function Class.__newindex(self: Self, k: string, v: any)
	local set = getExtendedSetter(self.__base, k)
	if set then
		if not set(self, v) then return end
	else
		if self.__table[k] == v then return end
		self.__table[k] = v
	end

	callChangeds(self, self.__base, k)
	self.Changed:Fire(k)
	if self.__propChangedSignals[k] then self.__propChangedSignals[k]:Fire() end
end

function Class.__eq(self: Self, obj: any)
	return typeof(obj) == "table" and obj.__table == self.__table
end

function Class.__tostring(self: Self)
	local fields = {}
	for k, v in self.__table do
		table.insert(
			fields,
			`\t{tostring(k)} = {tostring(v):gsub("\n", "\n\t")}`
		)
	end
	return `Class({table.concat(fields, "\n")})`
end

--#endregion

setmetatable(Class, Meta)

return table.freeze(Class) :: setmetatable<
	{
		--- Constructs a new class.
		new: typeof(Class.new),
		--- Check if an object is a Class.
		isClass: typeof(Class.isClass),
	},
	{
		__call: typeof(Meta.__call),
	}
>
