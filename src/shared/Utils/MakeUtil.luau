--- Utility module for creating constraints and wires.
local MakeUtil = {}

--- Creates a WeldConstraint between two BaseParts and parents it to part0.
function MakeUtil.Weld(part0: BasePart, part1: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0
	return weld
end

--- Welds the given part to all BaseParts found in the instance hierarchy.
--- If the instance is a BasePart, welds directly; otherwise, welds to all descendants that are BaseParts.
function MakeUtil.DeepWeld(part: BasePart, instance: Instance)
	if instance:IsA("BasePart") then
		MakeUtil.Weld(part, instance)
		return
	end

	for _, v in instance:QueryDescendants("BasePart") do
		MakeUtil.Weld(part, v)
	end
end

--- Creates a Wire between two instances.
function MakeUtil.Wire(source: Instance, target: Instance)
	local wire = Instance.new("Wire")
	wire.SourceInstance = source
	wire.TargetInstance = target
	wire.Parent = source
	return wire
end

--- Creates a Motor6D between two BaseParts with proper CFrame calculation and parents it to part0.
function MakeUtil.Motor(part0: BasePart, part1: BasePart)
	local motor = Instance.new("Motor6D")
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C1 = part1.CFrame:Inverse() * part0.CFrame
	motor.Parent = part0
	return motor
end

return table.freeze(MakeUtil)
