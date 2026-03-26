local Base = require("@self/Base")
local Class = require("../Packages/Class")

local InterfaceController = {}
InterfaceController.extends = Base

export type InterfaceController = Base.BaseInterfaceController

type Self = InterfaceController

function InterfaceController.new(): InterfaceController
	local self: Self = Class(InterfaceController, Base.new())

	return self
end

return InterfaceController.new()
