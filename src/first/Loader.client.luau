--[[
	Client-side loader

	Written by: FordenRo
	Version: 1.0.0
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not game:IsLoaded() then game.Loaded:Wait() end

for _, controller in ReplicatedStorage.Shared.Controllers:GetChildren() do
	if controller:IsA("ModuleScript") then
		task.defer(function() require(controller) end)
	end
end

for _, service in ReplicatedStorage.Shared.Services:GetChildren() do
	if service:IsA("ModuleScript") then
		task.defer(function() require(service) end)
	end
end
