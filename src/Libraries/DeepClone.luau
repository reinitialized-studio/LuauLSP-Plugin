--!strict
--[[
	Core/Type/CoreModule.luau
	A CoreModule Template
	https://code.reinitialized.studio/reinitialized.studio/reframe
]]
-- Dependencies
--- Roblox Services
--- Core
---- Assets
---- Constants
---- Libraries
local TypeChecker = require(script.Parent.TypeChecker)
---- Utilities
---- GlobalTypes
--- Script
-- Typings
--- Luau Typings
type test = {
	metatable: test,
}
--- Runtime Typings
-- Constants
-- Variables
-- Private API
-- Public API
local function DeepClone<A>(ToClone: A): A
	TypeChecker.BuiltInTypes.Table(ToClone)

	local CopiedTable = table.clone(ToClone :: any)
	if typeof(getmetatable(ToClone :: any)) == "table" then
		setmetatable(CopiedTable, getmetatable(ToClone :: any))
	end

	for Key, Value in ToClone :: any do
		if typeof(Key) == "table" then
			if Key == ToClone then
				Key = CopiedTable
			else
				Key = DeepClone(Key)
			end
		end
		if typeof(Value) == "table" then
			if Value == ToClone then
				Value = CopiedTable
			else
				Value = DeepClone(Value)
			end
		end
		if CopiedTable[Key] ~= Value then
			CopiedTable[Key] = Value
		end
	end

	return (CopiedTable :: any) :: A
end
-- Initialization
--- Return Public API
return DeepClone
