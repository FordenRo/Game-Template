--[[
    Roblox * Units = Real

    Real / Units = Roblox
]]
local Units = {}

--- Kilograms
Units.Mass = 21.952

--- `studs` -> `m`
Units.Length = 0.28

--- `studs/s` -> `m/s`
Units.Velocity = Units.Length

--- `RMU/s2` -> `N/m (kg/s2)`
Units.Stiffness = 1 / Units.Mass

--- `RMU/s` -> `N*s/m (kg/s)`
Units.Damping = 1 / Units.Mass

--- `Rowtons (RMU*studs/s2)` -> `N (kg*m/s2)`
Units.Force = Units.Mass * Units.Length

--- `Rowtons*studs (RMU*studs2/s2)` -> `N*m (kg*m2/s2)`
Units.Torque = Units.Force * Units.Length

return table.freeze(Units)
