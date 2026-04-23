--!strict
local ModuleLoader = {}

local function loadContainer(container: Instance): {[string]: any}
	local loaded: {[string]: any} = {}

	for _, child in next, container:GetChildren() do
		if child:IsA("ModuleScript") then
			loaded[child.Name] = require(child)

		elseif next(child:GetChildren()) ~= nil then
			local sub = loadContainer(child)

			if next(sub) ~= nil then
				loaded[child.Name] = sub
			end
		end
	end

	return loaded
end

function ModuleLoader.Load(root: Instance): {[string]: any}
	return loadContainer(root)
end

return ModuleLoader