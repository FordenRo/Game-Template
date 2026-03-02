local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TryCall = require(ReplicatedStorage.Shared.Packages.TryCall)

for _, handler in script.Parent.Handlers:GetChildren() do
	if handler:IsA("ModuleScript") then
		task.defer(
			TryCall,
			function() require(handler) end,
			nil,
			function(err)
				debug.traceback(`Error while loading {handler.Name}: {err}`)
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
