--!native
local Players = game:GetService("Players")

local Class = require("./Class")

-- Preload globals
local math = math
local buffer = buffer
local bit32 = bit32
local string = string

local BitBuffer = { change = {} }
BitBuffer.extends = Class

--#region Symbols sheets
BitBuffer.Sym = {}
BitBuffer.Sym.HEX = "0123456789ABCDEF"
BitBuffer.Sym.UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
BitBuffer.Sym.LOWER = "abcdefghijklmnopqrstuvwxyz"
BitBuffer.Sym.ALPHA = BitBuffer.Sym.UPPER .. BitBuffer.Sym.LOWER
BitBuffer.Sym.DIGIT = "0123456789"
BitBuffer.Sym.XDIGIT = BitBuffer.Sym.DIGIT .. "ABCDEFabcdef"
BitBuffer.Sym.ALNUM = BitBuffer.Sym.ALPHA .. BitBuffer.Sym.DIGIT
BitBuffer.Sym.PUNCT = "-!\"#$%&'()*+,./:;<=>?@[\\]_`{|}~"
BitBuffer.Sym.BLANK = " \t"
BitBuffer.Sym.SPACE = BitBuffer.Sym.BLANK .. "\v\r\n\f"
BitBuffer.Sym.PRINT = BitBuffer.Sym.ALNUM
	.. BitBuffer.Sym.PUNCT
	.. BitBuffer.Sym.SPACE
--#endregion

export type BitBuffer = setmetatable<
	{
		--- Current size in bits.
		Size: number,
		--- The internal buffer.
		RawBuffer: buffer,
		--- Current BitBuffer position.
		Cursor: number,

		--- Writes an unsigned integer with size of 8 bits or `bitCount` if provided.
		WriteUint: (self: BitBuffer, value: number, bitCount: number?) -> (),
		--- Reads an unsigned integer with size of 8 bits or `bitCount` if provided.
		ReadUint: (self: BitBuffer, bitCount: number?) -> number,

		--- Writes an signed integer with size of 8 bits or `bitCount` if provided.
		WriteInt: (self: Self, value: number, bitCount: number?) -> (),
		--- Reads an signed integer with size of 8 bits or `bitCount` if provided.
		ReadInt: (self: Self, bitCount: number?) -> number,

		--- Writes a 1-bit boolean.
		WriteBool: (self: BitBuffer, value: boolean) -> (),
		--- Reads a 1-bit boolean.
		ReadBool: (self: BitBuffer) -> boolean,

		--- Writes a string without writing the length of it.
		WriteStringRaw: (self: BitBuffer, value: string) -> (),
		--- Reads a string from `length` bits.
		ReadStringRaw: (self: BitBuffer, length: number) -> string,

		--[[
			Writes a string with maximum length of 2 ^ `bitCount`.

			To read it, you must use `BitBuffer:ReadString()`.
		]]
		WriteString: (self: BitBuffer, value: string, bitCount: number?) -> (),
		--[[
			Reads a string with maximum length of 2 ^ `bitCount`.

			String must be written with `BitBuffer:WriteString()`.
		]]
		ReadString: (self: BitBuffer, bitCount: number?) -> string,

		--- Writes a string with custom `symbols` sheet.
		WriteSymStringRaw: (
			self: BitBuffer,
			value: string,
			symbols: string
		) -> (),
		--- Reads a string from `length` bits with custom `symbols` sheet.
		ReadSymStringRaw: (
			self: BitBuffer,
			symbols: string,
			length: number
		) -> string,

		--[[
			Writes a string with custom `symbols` sheet
			with maximum length of 2 ^ `bitCount`.

			To read it, you must use `BitBuffer:ReadSymString()`.
		]]
		WriteSymString: (
			self: BitBuffer,
			value: string,
			symbols: string,
			bitCount: number?
		) -> (),
		--[[
			Reads a string with custom `symbols` sheet
			with maximum length of 2 ^ `bitCount`.

			String must be written with `BitBuffer:WriteSymString()`.
		]]
		ReadSymString: (
			self: BitBuffer,
			symbols: string,
			bitCount: number?
		) -> string,

		--- Writes a 32-bit player value.
		WritePlayer: (self: BitBuffer, player: Player) -> (),
		--- Reads a 32-bit player value.
		ReadPlayer: (self: BitBuffer) -> Player,

		--- Writes a 32-bit float value.
		WriteFloat: (self: BitBuffer, value: number) -> (),
		--- Reads a 32-bit float value.
		ReadFloat: (self: BitBuffer) -> number,

		--- Writes a Color3 value with size of 24 bits or `bitCount` * 3 if provided.
		WriteColor3: (self: BitBuffer, value: Color3, bitCount: number?) -> (),
		--- Reads a Color3 value with size of 24 bits or `bitCount` * 3 if provided.
		ReadColor3: (self: BitBuffer, bitCount: number?) -> Color3,

		--- Writes an item of provided `enum`.
		WriteEnumItem: (self: BitBuffer, enum: Enum, value: EnumItem) -> (),
		--- Reads an item of provided `enum`.
		ReadEnumItem: (self: BitBuffer, enum: Enum) -> EnumItem,

		--- Writes a raw buffer. Basically just merges provided buffer.
		WriteBufferRaw: (self: BitBuffer, value: buffer) -> (),
		--- Reads a raw buffer from `bitCount` bits.
		ReadBufferRaw: (self: BitBuffer, bitCount: number) -> buffer,

		--[[
			Writes a buffer with maximum size of 2 ^ `bitCount` bytes.

			To read it, you must use `BitBuffer:ReadBuffer()`.
		]]
		WriteBuffer: (self: BitBuffer, value: buffer, bitCount: number?) -> (),
		--[[
			Reads a buffer with maximum size of 2 ^ `bitCount` bytes.

			Buffer must be written with `BitBuffer:WriteBuffer()`.
		]]
		ReadBuffer: (self: BitBuffer, bitCount: number?) -> buffer,

		--[[
			Writes a BitBuffer without writing the size of it.
			Basically just merges provided BitBuffer.
		]]
		WriteBitBufferRaw: (self: BitBuffer, value: BitBuffer) -> (),
		--[[
			Reads a BitBuffer from `bitCount` bits.

			You cannot read a BitBuffer written with `BitBuffer:WriteBitBuffer()`.
		]]
		ReadBitBufferRaw: (self: BitBuffer, bitCount: number) -> BitBuffer,

		--[[
			Writes a BitBuffer with maximum size of 2 ^ `bitCount`.

			To read it, you must use `BitBuffer:ReadBitBuffer()`.
		]]
		WriteBitBuffer: (
			self: BitBuffer,
			value: BitBuffer,
			bitCount: number?
		) -> (),
		--[[
			Reads a BitBuffer with maximum size of 2 ^ `bitCount`.

			BitBuffer must be written with `BitBuffer:WriteBitBuffer()`.
		]]
		ReadBitBuffer: (self: BitBuffer, bitCount: number?) -> BitBuffer,

		--- Shrinks the internal buffer to the real size.
		Shrink: (self: BitBuffer) -> (),

		--[[
			Returns the buffer. Additionally writes 3 bits in the start
			to describe the bits offset of the size.

			To convert it back, you must use `BitBuffer.fromBuffer()`.
		]]
		toBuffer: (self: BitBuffer) -> buffer,
		--[[
			Returns hex string without size offset.
		]]
		toRawHex: (self: BitBuffer) -> string,
		--[[
			Returns hex string with size offset in the first char
			to describe the bits offset of the size.

			To convert it back, you must use `BitBuffer.fromHex()`.
		]]
		toHex: (self: BitBuffer) -> string,
	},
	{ __index: Class.Class }
>

type Self = BitBuffer

--#region Constructor methods

function BitBuffer.new(byteCount: number?): BitBuffer
	local self: Self = Class(BitBuffer)

	self.RawBuffer = buffer.create(byteCount or 1024)
	self.Cursor = 0
	self.Size = 0

	return self
end

function BitBuffer.fromRawBuffer(b: buffer): BitBuffer
	local self: Self = BitBuffer.new(buffer.len(b))

	self:WriteBufferRaw(b)

	self.Cursor = 0
	return self
end

function BitBuffer.fromBuffer(b: buffer): BitBuffer
	local subBits = buffer.readbits(b, 0, 3)
	local bitCount: number = buffer.len(b) * 8 - subBits - 3

	local self: Self = BitBuffer.new(math.ceil(bitCount / 8))

	local offset = 0
	while offset <= bitCount - 32 do
		self:WriteUint(buffer.readbits(b, 3 + offset, 32), 32)
		offset += 32
	end
	local tail = bitCount % 32
	if tail > 0 then
		self:WriteUint(buffer.readbits(b, 3 + offset, tail), tail)
	end

	self.Cursor = 0
	return self
end

function BitBuffer.fromRawHex(s: string): BitBuffer
	local self: Self = BitBuffer.new(math.ceil(#s / 2))

	local charset = BitBuffer.Sym.HEX
	for i = 1, #s do
		self:WriteUint(charset:find(s:sub(i, i) - 1), 4)
	end

	self.Cursor = 0
	return self
end

function BitBuffer.fromHex(s: string): BitBuffer
	local self: Self = BitBuffer.new(math.ceil((#s - 1) / 2))

	local charset = BitBuffer.Sym.HEX
	local tail = charset:find(s:sub(1, 1)) :: number - 1

	for i = 2, #s - (tail > 0 and 1 or 0) do
		self:WriteUint((charset:find(s:sub(i, i)) - 1), 4)
	end
	if tail > 0 then
		local u = #s
		self:WriteUint(charset:find(s:sub(u, u)) - 1, tail)
	end

	self.Cursor = 0
	return self
end

--#endregion

function BitBuffer.change.Size(self: Self)
	local sizeB = math.ceil(self.Size / 8)
	if buffer.len(self.RawBuffer) >= sizeB then return end

	local oldB = self.RawBuffer
	self.RawBuffer = buffer.create(sizeB)
	buffer.copy(self.RawBuffer, 0, oldB, 0)
end

--#region Methods

function BitBuffer.WriteUint(self: Self, value: number, bitCount: number?)
	bitCount = bitCount or 8
	self.Size += bitCount
	buffer.writebits(self.RawBuffer, self.Cursor, bitCount, value)
	self.Cursor += bitCount
end

function BitBuffer.ReadUint(self: Self, bitCount: number?)
	bitCount = bitCount or 8
	assert(self.Cursor + bitCount <= self.Size, "Buffer has exceeds the size.")
	local value = buffer.readbits(self.RawBuffer, self.Cursor, bitCount)
	self.Cursor += bitCount
	return value
end

function BitBuffer.WriteInt(self: Self, value: number, bitCount: number?)
	bitCount = bitCount or 8
	self:WriteUint(value + 2 ^ (bitCount - 1), bitCount)
end

function BitBuffer.ReadInt(self: Self, bitCount: number?)
	bitCount = bitCount or 8
	return self:ReadUint(bitCount) - 2 ^ (bitCount - 1)
end

function BitBuffer.WriteBool(self: Self, value: boolean)
	self:WriteUint(value and 1 or 0, 1)
end

function BitBuffer.ReadBool(self: Self) return self:ReadUint(1) == 1 end

function BitBuffer.WriteStringRaw(self: Self, value: string)
	for i = 1, #value do
		self:WriteUint(string.byte(value, i))
	end
end

function BitBuffer.ReadStringRaw(self: Self, length: number)
	local s = ""
	for i = 1, length do
		s ..= string.char(self:ReadUint())
	end
	return s
end

function BitBuffer.WriteString(self: Self, value: string, bitCount: number?)
	self:WriteUint(#value, bitCount)
	self:WriteStringRaw(value)
end

function BitBuffer.ReadString(self: Self, bitCount: number)
	return self:ReadStringRaw(self:ReadUint(bitCount))
end

function BitBuffer.WriteSymStringRaw(self: Self, value: string, symbols: string)
	local _, bitCount = math.frexp(#symbols)
	for i = 1, #value do
		local symbol = value:sub(i, i)
		self:WriteUint(
			assert(
				(symbols:find(symbol)),
				`Could't parse symbol at {i}: {symbol}`
			) - 1,
			bitCount
		)
	end
end

function BitBuffer.ReadSymStringRaw(self: Self, symbols: string, length: number)
	local _, bitCount = math.frexp(#symbols)
	local s = ""
	for i = 1, length do
		local idx = self:ReadUint(bitCount) + 1
		s ..= symbols:sub(idx, idx)
	end
	return s
end

function BitBuffer.WriteSymString(
	self: Self,
	value: string,
	symbols: string,
	bitCount: number?
)
	self:WriteUint(#value, bitCount)
	self:WriteSymStringRaw(value, symbols)
end

function BitBuffer.ReadSymString(
	self: Self,
	symbols: string,
	bitCount: number?
)
	return self:ReadSymStringRaw(symbols, self:ReadUint(bitCount))
end

function BitBuffer.WritePlayer(self: Self, player: Player)
	self:WriteUint(player.UserId, 32)
end

function BitBuffer.ReadPlayer(self: Self)
	return Players:GetPlayerByUserId(self:ReadUint(32))
end

local function binaryToFloat(value: number): number
	local sign = bit32.extract(value, 31) == 1 and -1 or 0
	local mantissa = bit32.extract(value, 0, 23)
	local exponent = bit32.extract(value, 24, 7) * 2
		+ math.floor(bit32.extract(value, 16, 8) / 128)
	if exponent == 0 then return 0 end
	mantissa = (math.ldexp(mantissa, -23) + 1) * sign
	return math.ldexp(mantissa, exponent - 127)
end

local function floatToBinary(value: number): number
	if value == 0 then return 0 end
	local sign = 0
	if value < 0 then sign = 1 end
	local mantissa, exponent = math.frexp(value)
	mantissa = (mantissa * 2 - 1) * math.ldexp(0.5, 24)
	exponent = exponent + 126
	return math.round(2 ^ 31 * sign + 2 ^ 23 * exponent + mantissa)
end

function BitBuffer.WriteFloat(self: Self, value: number)
	self:WriteUint(floatToBinary(value), 32)
end

function BitBuffer.ReadFloat(self: Self) return binaryToFloat(self:ReadUint(32)) end

function BitBuffer.WriteColor3(self: Self, value: Color3, bitCount: number?)
	bitCount = bitCount or 32
	self:WriteUint(math.ldexp(value.R, bitCount) - 1)
	self:WriteUint(math.ldexp(value.G, bitCount) - 1)
	self:WriteUint(math.ldexp(value.B, bitCount) - 1)
end

function BitBuffer.ReadColor3(self: Self, bitCount: number?)
	bitCount = bitCount or 32
	return Color3.fromRGB(
		self:ReadUint(bitCount),
		self:ReadUint(bitCount),
		self:ReadUint(bitCount)
	)
end

function BitBuffer.WriteEnumItem(self: Self, enum: Enum, value: EnumItem)
	local _, bitCount = math.frexp(#enum:GetEnumItems())
	self:WriteUint(value.Value, bitCount)
end

function BitBuffer.ReadEnumItem(self: Self, enum: Enum)
	local _, bitCount = math.frexp(#enum:GetEnumItems())
	return enum:FromValue(self:ReadUint(bitCount))
end

function BitBuffer.WriteBufferRaw(self: Self, value: buffer)
	for i = 1, buffer.len(value) do
		self:WriteUint(buffer.readu8(value, i))
	end
end

function BitBuffer.ReadBufferRaw(self: Self, byteCount: number)
	local b = buffer.create(byteCount)
	for i = 0, byteCount - 1 do
		buffer.writeu8(b, i, self:ReadUint())
	end
	return b
end

function BitBuffer.WriteBuffer(self: Self, value: buffer, bitCount: number?)
	bitCount = bitCount or 32
	self:WriteUint(buffer.len(value), bitCount)
	self:WriteBufferRaw(value)
end

function BitBuffer.ReadBuffer(self: Self, bitCount: number?)
	bitCount = bitCount or 32
	local size = self:ReadUint(bitCount)

	local b = buffer.create(size)
	for i = 1, size do
		buffer.writebits(b, i, size, self:ReadUint(size))
	end
	return b
end

function BitBuffer.WriteBitBufferRaw(self: Self, value: BitBuffer)
	local lastCursor = value.Cursor
	value.Cursor = 0
	for i = 0, value.Size - 32, 32 do
		self:WriteUint(value:ReadUint(32), 32)
	end
	local tail = value.Size % 32
	if tail > 0 then self:WriteUint(value:ReadUint(tail), tail) end
	value.Cursor = lastCursor
end

function BitBuffer.ReadBitBufferRaw(self: Self, bitCount: number)
	local bb = BitBuffer.new(bitCount)
	for i = 0, bitCount - 32, 32 do
		bb:WriteUint(self:ReadUint(32), 32)
	end
	local tail = bitCount % 32
	if tail > 0 then bb:WriteUint(self:ReadUint(tail), tail) end
	return bb
end

function BitBuffer.WriteBitBuffer(
	self: Self,
	value: BitBuffer,
	bitCount: number?
)
	bitCount = bitCount or 32
	self:WriteUint(value.Size, bitCount)
	self:WriteBitBufferRaw(value)
end

function BitBuffer.ReadBitBuffer(self: Self, bitCount: number?)
	bitCount = bitCount or 32
	local size = self:ReadUint(bitCount)
	return self:ReadBitBufferRaw(size)
end

function BitBuffer.Shrink(self: Self)
	local sizeB = math.ceil(self.Size / 8)
	if buffer.len(self.RawBuffer) == sizeB then return end

	local oldB = self.RawBuffer
	self.RawBuffer = buffer.create(sizeB)
	buffer.copy(self.RawBuffer, 0, oldB, 0, sizeB)
end

function BitBuffer.toBuffer(self: Self)
	local byteCount = math.ceil((self.Size + 3) / 8)
	local bb = BitBuffer.new(byteCount)
	bb:WriteUint(byteCount * 8 - (self.Size + 3), 3)
	bb:WriteBitBufferRaw(self)
	return bb.RawBuffer
end

function BitBuffer.toRawHex(self: Self)
	local lastCursor = self.Cursor
	self.Cursor = 0

	local charset = BitBuffer.Sym.HEX
	local s = ""
	for i = 1, math.floor(self.Size / 4) do
		local u = self:ReadUint(4) + 1
		s ..= charset:sub(u, u)
	end
	local tail = self.Size % 4
	if tail > 0 then
		local u = self:ReadUint(tail) + 1
		s ..= charset:sub(u, u)
	end

	self.Cursor = lastCursor
	return s
end

function BitBuffer.toHex(self: Self)
	local u = self.Size % 4 + 1
	return BitBuffer.Sym.HEX:sub(u, u) .. self:toRawHex()
end

--#endregion

return table.freeze(BitBuffer) :: {
	--- Creates a clean BitBuffer with internal buffer size of `bytesCount` bytes.
	new: typeof(BitBuffer.new),

	--[[
		Creates BitBuffer from raw buffer.

		Not recommended, because this will provide non-real size of the buffer.
		This will cause to problems with shrinking and will leave unnecessary
		bits at the end of the buffer.
	]]
	fromRawBuffer: typeof(BitBuffer.fromRawBuffer),

	--[[
		Creates BitBuffer from buffer.

		The buffer must be got with `BitBuffer:toBuffer()`.
		This won't work on default buffers.
	]]
	fromBuffer: typeof(BitBuffer.fromBuffer),

	--[[
		Creates BitBuffer from hex string without size offset.

		Not recommended, because this will provide non-real size of the buffer.
	]]
	fromRawHex: typeof(BitBuffer.fromRawHex),

	--[[
		Creates BitBuffer from hex string.

		The string must be got with `BitBuffer:toHex()`.
	]]
	fromHex: typeof(BitBuffer.fromHex),

	--- Symbol sheets to use in `BitBuffer:WriteSymString()`.
	Sym: typeof(BitBuffer.Sym),
}
