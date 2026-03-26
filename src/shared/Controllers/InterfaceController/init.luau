local Base = require("@self/Base")
local Class = require("../Packages/Class")

local InterfaceController = {}
Class(InterfaceController, Base)

export type InterfaceController = Base.BaseInterfaceController

type Self = InterfaceController

function InterfaceController.init(self: Self) self:Super():init() end

return InterfaceController.new() :: InterfaceController
