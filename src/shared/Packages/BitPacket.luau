--!native
local BitBuffer = require("./BitBuffer")
local Class = require("./Class")

type BitBuffer = BitBuffer.BitBuffer

-- Preload globals
local table = table
local pcall = pcall
local math = math

local BitPacket = {}
BitPacket.extends = Class

export type BitPacket<V> = {
	--- Writes the value to provided BitBuffer.
	Write: (self: BitPacket<V>, bb: BitBuffer, value: V) -> (),
	--- Reads the value from provided BitBuffer.
	Read: (self: BitPacket<V>, bb: BitBuffer) -> V,
	--- Size of the packet in bits.
	Size: number?,

	--- Creates BitBuffer and writes provided value to it. Returns the BitBuffer.
	Serialize: (self: BitPacket<V>, value: V) -> BitBuffer,
	--- Reads the value from provided BitBuffer.
	Deserialize: (self: BitPacket<V>, bb: BitBuffer) -> V,
} & Class.Class

type Deserializable<T> = {
	deserialize: (bb: BitBuffer) -> T,
}

type Self = {
	_write: (bb: BitBuffer, value: any) -> (),
	_read: (bb: BitBuffer) -> any,
} & BitPacket<any>

function BitPacket.new<V>(
	write: (bb: BitBuffer, value: V) -> (),
	read: (bb: BitBuffer) -> V,
	size: number?
): BitPacket<V>
	local self: Self = Class(BitPacket)

	self._write = write
	self._read = read
	self.Size = size

	return self
end

function BitPacket.Write(self: Self, bb: BitBuffer, value: any)
	self._write(bb, value)
end

function BitPacket.Read(self: Self, bb: BitBuffer) return self._read(bb) end

function BitPacket.Serialize(self: Self, value: any)
	local bb = BitBuffer.new(self.Size and math.floor(self.Size / 8))
	self:Write(bb, value)
	bb:Shrink()
	return bb
end

function BitPacket.Deserialize(self: Self, bb: BitBuffer) return self:Read(bb) end

local function writeObject(bb: BitBuffer, base: any, value: any)
	if Class.isClass(base) and (base :: Class.Class):IsA(BitPacket) then
		(base :: BitPacket<any>):Write(bb, value)
		return
	end

	assert(
		typeof(value.Serialize) == "function",
		"Object must be a `BitPacket` or must have `Serialize` method."
	)
	bb:WriteBitBufferRaw(value:Serialize())
end

local function readObject(bb: BitBuffer, base: any)
	if Class.isClass(base) and (base :: Class.Class):IsA(BitPacket) then
		return (base :: BitPacket<any>):Read(bb)
	end

	assert(
		typeof(base.deserialize) == "function",
		"Object must be a `BitPacket` or must have `deserialize` method."
	)
	return base.deserialize(bb)
end

function BitPacket.Packet(items: {
	[string]: BitPacket<any> | Deserializable<any>,
}): BitPacket<{ [string]: any }>
	local size = 0
	local mapped = {}
	for k, v in items do
		if v.size then
			size += v.size
		end
		table.insert(mapped, { k, v })
	end
	table.sort(mapped, function(a, b) return a[1] < b[1] end)

	return BitPacket.new(function(bb, t)
		for _, v in mapped do
			writeObject(bb, v[2], t[v[1]])
		end
	end, function(bb)
		local t = {}
		for _, v in mapped do
			t[v[1]] = readObject(bb, v[2])
		end
		return t
	end, size)
end

function BitPacket.Uint(bitCount: number?): BitPacket<number>
	return BitPacket.new(
		function(bb: BitBuffer, value) bb:WriteUint(value, bitCount) end,
		function(bb: BitBuffer) return bb:ReadUint(bitCount) end,
		bitCount
	)
end

function BitPacket.Int(bitCount: number?): BitPacket<number>
	return BitPacket.new(
		function(bb: BitBuffer, value) bb:WriteInt(value, bitCount) end,
		function(bb: BitBuffer) return bb:ReadInt(bitCount) end,
		bitCount
	)
end

BitPacket.Bool = BitPacket.new(
	function(bb: BitBuffer, value) bb:WriteBool(value) end,
	function(bb: BitBuffer) return bb:ReadBool() end,
	1
) :: BitPacket<boolean>

function BitPacket.String(bitCount: number?): BitPacket<string>
	return BitPacket.new(
		function(bb: BitBuffer, value) bb:WriteString(value, bitCount) end,
		function(bb: BitBuffer) return bb:ReadString(bitCount) end,
		bitCount
	)
end

function BitPacket.SymString(
	symbols: string,
	bitCount: number?
): BitPacket<string>
	return BitPacket.new(
		function(bb: BitBuffer, value)
			bb:WriteSymString(value, symbols, bitCount)
		end,
		function(bb: BitBuffer) return bb:ReadSymString(symbols, bitCount) end,
		bitCount
	)
end

BitPacket.Player = BitPacket.new(
	function(bb: BitBuffer, value) bb:WritePlayer(value) end,
	function(bb: BitBuffer) return bb:ReadPlayer() end,
	32
) :: BitPacket<Player>

BitPacket.Float = BitPacket.new(
	function(bb: BitBuffer, value) bb:WriteFloat(value) end,
	function(bb: BitBuffer) return bb:ReadFloat() end,
	32
) :: BitPacket<number>

function BitPacket.Color3(bitCount: number?): BitPacket<Color3>
	bitCount = bitCount or 8
	return BitPacket.new(
		function(bb: BitBuffer, value) bb:WriteColor3(value, bitCount) end,
		function(bb: BitBuffer) return bb:ReadColor3(bitCount) end,
		bitCount * 3
	)
end

function BitPacket.EnumItem(enum: Enum): BitPacket<EnumItem>
	local _, bitCount = math.frexp(#enum:GetEnumItems())
	return BitPacket.new(
		function(bb: BitBuffer, value: EnumItem) bb:WriteEnumItem(enum, value) end,
		function(bb: BitBuffer) return bb:ReadEnumItem(enum) end,
		bitCount
	)
end

function BitPacket.Optional<T>(
	item: Deserializable<T> | BitPacket<T>
): BitPacket<T?>
	return BitPacket.new(function(bb: BitBuffer, value)
		local has = value ~= nil
		bb:WriteBool(has)
		if has then writeObject(bb, item, value) end
	end, function(bb: BitBuffer)
		if bb:ReadBool() then return readObject(bb, item) end
		return nil
	end, item.Size)
end

function BitPacket.FixedArray<T>(
	item: BitPacket<T> | Deserializable<T>,
	size: number
): BitPacket<{ T }>
	return BitPacket.new(function(bb: BitBuffer, value)
		for i = 1, size do
			writeObject(bb, item, value[i])
		end
	end, function(bb: BitBuffer)
		local t = {}
		for i = 1, size do
			t[i] = readObject(bb, item)
		end
		return t
	end, item.Size and item.Size * size)
end

function BitPacket.Array<T>(
	item: BitPacket<T> | Deserializable<T>,
	bitCount: number?
): BitPacket<{ T }>
	return BitPacket.new(
		function(bb: BitBuffer, value)
			bb:WriteUint(#value, bitCount)
			BitPacket.FixedArray(item, #value):Write(bb, value)
		end,
		function(bb: BitBuffer)
			return BitPacket.FixedArray(item, bb:ReadUint(bitCount)):Read(bb)
		end,
		item.Size
	)
end

function BitPacket.InfiniteArray<T>(
	item: BitPacket<T> | Deserializable<T>
): BitPacket<{ T }>
	return BitPacket.new(
		function(bb: BitBuffer, value)
			BitPacket.FixedArray(item, #value):Write(bb, value)
		end,
		function(bb: BitBuffer)
			local t = {}
			while true do
				local success, value = pcall(readObject, bb, item)
				if not success then break end

				table.insert(t, value)
			end
			return t
		end,
		item.Size
	)
end

return table.freeze(BitPacket) :: {
	--- Creates a packet with provided `write` and `read` methods.
	new: typeof(BitPacket.new),

	Packet: typeof(BitPacket.Packet),
	--- Unsigned integer packet with size of 8 bits or `bitCount` if provided.
	Uint: typeof(BitPacket.Uint),
	--- Signed integer packet with size of 8 bits or `bitCount` if provided.
	Int: typeof(BitPacket.Int),
	--- 1-bit boolean packet.
	Bool: typeof(BitPacket.Bool),
	--- String packet with maximum length of 2 ^ `bitCount`.
	String: typeof(BitPacket.String),
	--- String packet with custom `symbols` sheet with maximum length of 2 ^ `bitCount`.
	SymString: typeof(BitPacket.SymString),
	--- 32-bit player value packet.
	Player: typeof(BitPacket.Player),
	--- 32-bit float value packet.
	Float: typeof(BitPacket.Float),
	--- Color3 value packet with size of 24 bits or `bitCount` * 3 if provided.
	Color3: typeof(BitPacket.Color3),
	--- Enum item packet of provided `enum`.
	EnumItem: typeof(BitPacket.EnumItem),
	--- Optional packet. The first bit describes existence of provided item.
	Optional: typeof(BitPacket.Optional),
	--- Array packet with provided item and given maximum `size`.
	FixedArray: typeof(BitPacket.FixedArray),
	--- Array packet with provided item and maximum length of 255 bits or 2 ^ `bitCount`.
	Array: typeof(BitPacket.Array),
	--[[
		Array packet with provided item and no maximum length.

		This won't provide the length of the array.
		It must be at the end of the buffer.
	]]
	InfiniteArray: typeof(BitPacket.InfiniteArray),
}
