local Types = {}

type function getreturns(t: type) return table.unpack(t:returns().head) end
type KeyCodes = keyof<typeof(Enum.KeyCode)>

export type BaseAction = {
	Type: string,
	Id: number,
	Title: string,
	Bindings: {
		{
			KeyCode: KeyCodes,
			UIButton: GuiObject,
			PressedThreshold: number,
			ReleasedThreshold: number,
		}
	},
	Index: number,
	Description: string,
}
export type BoolAction = getreturns<typeof(Types.BoolAction)>
export type MouseAction = getreturns<typeof(Types.MouseAction)>
export type Action1D = getreturns<typeof(Types.Action1D)>
export type Action2D = getreturns<typeof(Types.Action2D)>
export type Action3D = getreturns<typeof(Types.Action3D)>
export type Context = {
	Id: number,
	Title: string,
	Actions: { [string]: BaseAction },
	Index: number,
	Description: string,
}

function Types.BoolAction(
	id: number,
	title: string,
	bindings: {
		{
			KeyCode: KeyCodes,
			UIButton: GuiObject,
			PressedThreshold: number,
			ReleasedThreshold: number,
		}
	},
	index: number?,
	description: string?
)
	return {
		Type = Enum.InputActionType.Bool,
		Id = id,
		Title = title,
		Bindings = bindings,
		Index = index or 0,
		Description = description or "",
	}
end

function Types.MouseAction(
	id: number,
	title: string,
	bindings: {
		{
			KeyCode: "MousePosition" | "Touch",
		}
	},
	index: number?,
	description: string?
)
	return {
		Type = Enum.InputActionType.ViewportPosition,
		Id = id,
		Title = title,
		Bindings = bindings,
		Index = index or 0,
		Description = description or "",
	}
end

function Types.Action1D(
	id: number,
	title: string,
	bindings: {
		{
			Up: KeyCodes,
			Down: KeyCodes,
			KeyCode: KeyCodes,
		}
	},
	index: number?,
	description: string?
)
	return {
		Type = Enum.InputActionType.Direction1D,
		Id = id,
		Title = title,
		Bindings = bindings,
		Index = index or 0,
		Description = description or "",
	}
end

function Types.Action2D(
	id: number,
	title: string,
	bindings: {
		{
			Up: KeyCodes,
			Down: KeyCodes,
			Left: KeyCodes,
			Right: KeyCodes,
			KeyCode: "Thumbstick1" | "Thumbstick2",
		}
	},
	index: number?,
	description: string?
)
	return {
		Type = Enum.InputActionType.Direction2D,
		Id = id,
		Title = title,
		Bindings = bindings,
		Index = index or 0,
		Description = description or "",
	}
end

function Types.Action3D(
	id: number,
	title: string,
	bindings: {
		{
			Up: KeyCodes,
			Down: KeyCodes,
			Left: KeyCodes,
			Right: KeyCodes,
			Forward: KeyCodes,
			Backward: KeyCodes,
		}
	},
	index: number?,
	description: string?
)
	return {
		Type = Enum.InputActionType.Direction3D,
		Id = id,
		Title = title,
		Bindings = bindings,
		Index = index or 0,
		Description = description or "",
	}
end

function Types.Context<V>(
	id: number,
	title: string,
	actions: V,
	index: number?,
	description: string?
)
	return {
		Id = id,
		Title = title,
		Actions = actions,
		Index = index or 0,
		Description = description or "",
	}
end

return Types
