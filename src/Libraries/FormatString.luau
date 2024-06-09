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
--- Runtime Typings
local string_StringifyTableShort = "{%s}"
local string_StringifyTableLong = "{\n%s\n}"
local string_TableEntry = "%s = %s"
-- Variables
-- Private API
local function StringifyTable<A>(ProvidedTable: A): string
	local TableToStringify = TypeChecker.BuiltInTypes.Table(ProvidedTable)
	local StringifiedArray: { string } = {}

	for Key, Value in TableToStringify do
		if typeof(Key) == "table" then
			Key = StringifyTable(Key)
		else
			Key = tostring(Key)
		end
		if typeof(Value) == "table" then
			Value = StringifyTable(Value)
		else
			Value = tostring(Value)
		end

		table.insert(StringifiedArray, string_TableEntry:format(Key, Value))
	end

	if #StringifiedArray < 5 then
		return string_StringifyTableShort:format(table.concat(StringifiedArray, ", "))
	else
		return string_StringifyTableLong:format(table.concat(StringifiedArray, "\n"))
	end
end
-- Public API
local function FormatString(Message: string, ...): string
	TypeChecker.BuiltInTypes.String(Message)

	local StringifiedArguments = {}
	local TypeOf = ""
	for Number = 1, select("#", ...) do
		TypeOf = typeof(select(Number, ...))
		if TypeOf == "table" then
			StringifiedArguments[Number] = StringifyTable(select(Number, ...))
		elseif TypeOf == "nil" then
			StringifiedArguments[Number] = "nil"
		else
			StringifiedArguments[Number] = tostring(select(Number, ...))
		end
	end

	return Message:format(table.unpack(StringifiedArguments))
end
-- Initialization
--- Return Public API
return FormatString
