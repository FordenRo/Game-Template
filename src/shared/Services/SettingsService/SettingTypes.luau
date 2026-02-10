local Array = require("../../Packages/Array")

local Types = {}

type function getreturns(t: type) return table.unpack(t:returns().head) end

export type Flag = getreturns<typeof(Types.Flag)>
export type Slider = getreturns<typeof(Types.Slider)>
export type Number = getreturns<typeof(Types.Number)>
export type Option = getreturns<typeof(Types.Option)>
export type Tab = getreturns<typeof(Types.Tab)>
export type Group = {
	Type: string,
	Title: string,
	Description: string,
	Parent: Tab | Group,
	Index: number,
}
export type Versions = getreturns<typeof(Types.Versions)>

function Types.Flag(
	id: number,
	title: string,
	default: boolean,
	parent: Tab | Group,
	index: number?,
	description: string?
)
	return {
		Type = "Flag",
		Id = id,
		Title = title,
		Parent = parent,
		Default = default,
		Index = index or 0,
		Description = description or "",
	}
end

function Types.Slider(
	id: number,
	title: string,
	default: number,
	min: number,
	max: number,
	step: number,
	parent: Tab | Group,
	index: number?,
	description: string?
)
	return {
		Type = "Slider",
		Id = id,
		Title = title,
		Parent = parent,
		Default = default,
		Min = min,
		Max = max,
		Step = step,
		Index = index or 0,
		Description = description or "",
	}
end

function Types.Number(
	id: number,
	title: string,
	default: number,
	min: number,
	max: number,
	step: number,
	parent: Tab | Group,
	index: number?,
	description: string?
)
	return {
		Type = "Number",
		Id = id,
		Title = title,
		Parent = parent,
		Default = default,
		Min = min,
		Max = max,
		Step = step,
		Index = index or 0,
		Description = description or "",
	}
end

function Types.Option(
	id: number,
	title: string,
	default: number,
	options: { string },
	parent: Tab | Group,
	index: number?,
	description: string?
)
	return {
		Type = "Option",
		Id = id,
		Title = title,
		Parent = parent,
		Default = default,
		Options = options,
		Index = index or 0,
		Description = description or "",
	}
end

function Types.Tab(title: string, index: number?, description: string?)
	return {
		Type = "Tab",
		Title = title,
		Index = index or 0,
		Description = description or "",
	}
end

function Types.Group(
	title: string,
	parent: Tab | Group,
	index: number?,
	description: string?
)
	return {
		Type = "Group",
		Title = title,
		Parent = parent,
		Index = index or 0,
		Description = description or "",
	}
end

function Types.Versions<V>(latest: V, ...): V
	local versions = Array(...):Reversed():asTable()
	table.insert(versions, latest)

	return setmetatable({}, {
		__index = function(_, k)
			if k == "v" then return versions end
			return latest[k]
		end,
	})
end

return Types
