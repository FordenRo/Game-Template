if not game:IsLoaded() then game.Loaded:Wait() end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TryCall = require("../shared/Packages/TryCall")

for _, controller in ReplicatedStorage.Shared.Controllers:GetChildren() do
	if controller:IsA("ModuleScript") then
		task.defer(
			TryCall,
			function() require(controller) end,
			nil,
			function(err)
				debug.traceback(`Error while loading {controller.Name}: {err}`)
			end
		)
	end
end

for _, service in ReplicatedStorage.Shared.Services:GetChildren() do
	if service:IsA("ModuleScript") then
		task.defer(
			TryCall,
			function() require(service) end,
			nil,
			function(err)
				debug.traceback(`Error while loading {service.Name}: {err}`)
			end
		)
	end
end
