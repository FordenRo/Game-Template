local CollectionService = game:GetService("CollectionService")

local TagsConfig
if script.Parent.Parent:FindFirstChild("TagsConfig") then
	TagsConfig = require("../TagsConfig")
end

local function init()
	if not TagsConfig then return nil end

	for tag, callback in TagsConfig :: { [string]: (v: Instance) -> () } do
		for _, v in CollectionService:GetTagged(tag) do
			callback(v)
		end
		CollectionService:GetInstanceAddedSignal(tag)
			:Connect(function(v) callback(v) end)
	end

	return nil
end

return init()
