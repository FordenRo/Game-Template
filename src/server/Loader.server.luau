local ReplicatedStorage = game:GetService("ReplicatedStorage")

for _, handler in script.Parent.Handlers:GetChildren() do
	if handler:IsA("ModuleScript") then
		task.defer(function() require(handler) end)
	end
end

for _, service in ReplicatedStorage.Shared.Services:GetChildren() do
	if service:IsA("ModuleScript") then
		task.defer(function() require(service) end)
	end
end
